import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:SecBizCard_OCR/secbizcard_ocr.dart';

class OCRService {
  static const _uuid = Uuid();
  final _ocr = SecBizCardOcr();

  Future<UserProfile?> recognizeBusinessCard(String imagePath) async {
    try {
      final result = await _ocr.recognizeBusinessCard(imagePath);
      return _mapToUserProfile(result, imagePath);
    } catch (e) {
      debugPrint('OCR Error: $e');
      return null;
    }
  }

  UserProfile _mapToUserProfile(OcrResult result, String imagePath) {
    return UserProfile(
      uid: _uuid.v4(),
      email: result.email,
      displayName: result.displayName,
      title: result.title,
      company: result.company,
      phone: result.phone,
      mobile: result.mobile,
      website: result.website,
      address: result.address,
      customFields: result.customFields,
      createdAt: DateTime.now(),
      originalImagePath: imagePath,
      source: 'ocr',
    );
  }

  void dispose() {
    _ocr.dispose();
  }
}
