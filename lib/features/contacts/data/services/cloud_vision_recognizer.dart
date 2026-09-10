import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:SecBizCard_OCR/secbizcard_ocr.dart';

/// Result of a Cloud Vision recognition attempt.
class VisionRecognitionResult {
  VisionRecognitionResult({
    required this.lines,
    this.usedSharedKey = false,
    this.globalUsage,
    this.globalCap,
    this.userUsage,
    this.userCap,
    this.recognitionId,
  });

  final List<OcrLine> lines;
  final bool usedSharedKey;
  final int? globalUsage;
  final int? globalCap;
  final int? userUsage;
  final int? userCap;

  /// Server-issued id for this shared-key recognition, used to attribute a
  /// later "report bad recognition" refund to exactly this call. Null for the
  /// own-key path (no shared quota to refund). Additive; ignored elsewhere.
  final String? recognitionId;
}

/// Signals that the caller should fall back to on-device ML Kit. Carries an
/// optional quota snapshot so the UI can inform the user.
class VisionFallbackException implements Exception {
  VisionFallbackException(this.reason, {this.quotaExceeded = false});
  final String reason;
  final bool quotaExceeded;
  @override
  String toString() => 'VisionFallbackException($reason)';
}

/// Recognizes business cards with Google Cloud Vision, via one of two paths:
///  - the user's OWN key (called directly, billed to them), or
///  - the app's SHARED key (proxied through the recognizeCard Cloud Function,
///    which enforces quota; the shared key never reaches the client).
///
/// Every failure path throws [VisionFallbackException] so the OCR orchestrator
/// can silently drop back to ML Kit (offline safety net).
class CloudVisionRecognizer {
  CloudVisionRecognizer(this._functions);

  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 20);

  /// Recognize using the user's own Cloud Vision API key (direct REST call).
  Future<VisionRecognitionResult> recognizeWithOwnKey(
    String imageBase64,
    String apiKey,
  ) async {
    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
    );
    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': imageBase64},
          'features': [{'type': 'DOCUMENT_TEXT_DETECTION'}],
          'imageContext': {
            'languageHints': ['zh-Hant', 'zh-Hans', 'ja', 'ko', 'en'],
          },
        },
      ],
    });

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);
    } catch (e) {
      // Network error / timeout → fall back.
      throw VisionFallbackException('network_error');
    }

    if (resp.statusCode == 403 || resp.statusCode == 400) {
      // Invalid / restricted / disabled key.
      throw VisionFallbackException('invalid_key');
    }
    if (resp.statusCode != 200) {
      throw VisionFallbackException('vision_http_${resp.statusCode}');
    }

    final lines = _parseVisionJson(resp.body);
    if (lines.isEmpty) throw VisionFallbackException('empty_result');
    return VisionRecognitionResult(lines: lines, usedSharedKey: false);
  }

  /// Recognize using the shared key via the recognizeCard Cloud Function.
  Future<VisionRecognitionResult> recognizeWithSharedKey(
    String imageBase64,
  ) async {
    final callable = _functions.httpsCallable(
      'recognizeCard',
      options: HttpsCallableOptions(timeout: _timeout),
    );

    HttpsCallableResult result;
    try {
      result = await callable.call({'imageBase64': imageBase64});
    } on FirebaseFunctionsException catch (e) {
      throw VisionFallbackException('function_error_${e.code}');
    } catch (e) {
      throw VisionFallbackException('network_error');
    }

    final data = Map<String, dynamic>.from(result.data as Map);
    final usage = data['usage'] is Map
        ? Map<String, dynamic>.from(data['usage'] as Map)
        : const <String, dynamic>{};

    if (data['success'] != true) {
      final reason = data['reason']?.toString() ?? 'needs_fallback';
      throw VisionFallbackException(
        reason,
        quotaExceeded: reason.contains('quota'),
      );
    }

    final rawLines = (data['lines'] as List?) ?? const [];
    final lines = <OcrLine>[];
    for (final item in rawLines) {
      final m = Map<String, dynamic>.from(item as Map);
      final box = Map<String, dynamic>.from(m['box'] as Map? ?? const {});
      final text = m['text']?.toString() ?? '';
      if (text.trim().isEmpty) continue;
      lines.add(OcrLine.fromBox(
        text: text,
        x: (box['x'] as num?) ?? 0,
        y: (box['y'] as num?) ?? 0,
        w: (box['w'] as num?) ?? 0,
        h: (box['h'] as num?) ?? 0,
      ));
    }
    if (lines.isEmpty) throw VisionFallbackException('empty_result');

    return VisionRecognitionResult(
      lines: lines,
      usedSharedKey: true,
      globalUsage: (usage['globalMonth'] as num?)?.toInt(),
      globalCap: (usage['globalCap'] as num?)?.toInt(),
      userUsage: (usage['userMonth'] as num?)?.toInt(),
      userCap: (usage['userCap'] as num?)?.toInt(),
      recognitionId: data['recognitionId']?.toString(),
    );
  }

  /// Parses a raw Vision images:annotate JSON body into [OcrLine]s using the
  /// block/paragraph/word/symbol hierarchy and detected line breaks.
  List<OcrLine> _parseVisionJson(String jsonBody) {
    final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
    final responses = decoded['responses'] as List?;
    if (responses == null || responses.isEmpty) return const [];
    final annotation = (responses.first as Map)['fullTextAnnotation'];
    if (annotation == null) return const [];

    final lines = <OcrLine>[];
    final pages = (annotation['pages'] as List?) ?? const [];
    for (final page in pages) {
      for (final block in ((page as Map)['blocks'] as List?) ?? const []) {
        for (final para in ((block as Map)['paragraphs'] as List?) ?? const []) {
          final current = StringBuffer();
          final vertices = <Map<String, dynamic>>[];
          void flush() {
            final t = current.toString();
            if (t.trim().isNotEmpty) {
              lines.add(OcrLine.fromBox(
                text: t,
                x: _minV(vertices, 'x'),
                y: _minV(vertices, 'y'),
                w: _maxV(vertices, 'x') - _minV(vertices, 'x'),
                h: _maxV(vertices, 'y') - _minV(vertices, 'y'),
              ));
            }
            current.clear();
            vertices.clear();
          }

          for (final word in ((para as Map)['words'] as List?) ?? const []) {
            final symbols = ((word as Map)['symbols'] as List?) ?? const [];
            for (final s in symbols) {
              current.write((s as Map)['text']?.toString() ?? '');
            }
            final bb = word['boundingBox'];
            if (bb is Map && bb['vertices'] is List) {
              for (final v in bb['vertices'] as List) {
                vertices.add(Map<String, dynamic>.from(v as Map));
              }
            }
            String? brk;
            if (symbols.isNotEmpty) {
              final prop = (symbols.last as Map)['property'];
              if (prop is Map) {
                final db = prop['detectedBreak'];
                if (db is Map) {
                  brk = db['type']?.toString();
                }
              }
            }
            if (brk == 'SPACE' || brk == 'SURE_SPACE') {
              current.write(' ');
            } else if (brk == 'EOL_SURE_SPACE' || brk == 'LINE_BREAK') {
              flush();
            }
          }
          flush();
        }
      }
    }
    return lines;
  }

  double _minV(List<Map<String, dynamic>> vs, String k) {
    if (vs.isEmpty) return 0;
    return vs.map((v) => (v[k] as num?)?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b);
  }

  double _maxV(List<Map<String, dynamic>> vs, String k) {
    if (vs.isEmpty) return 0;
    return vs.map((v) => (v[k] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);
  }
}
