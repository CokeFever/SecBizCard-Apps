import 'package:uuid/uuid.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:SecBizCard_OCR/secbizcard_ocr.dart';

class OCRService {
  static const _uuid = Uuid();
  final _ocrPlugin = SecBizCardOcr();

  Future<UserProfile?> recognizeBusinessCard(String imagePath) async {
    final result = await _ocrPlugin.recognizeBusinessCard(imagePath);
    
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
      createdAt: DateTime.now(),
      originalImagePath: imagePath,
      source: 'ocr',
      customFields: result.customFields,
    );
  }

  void dispose() {
    _ocrPlugin.dispose();
  }
}
