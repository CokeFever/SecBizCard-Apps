import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';

part 'image_picker_service.g.dart';

@riverpod
ImagePickerService imagePickerService(Ref ref) {
  return ImagePickerService(ImagePicker());
}

class ImagePickerService {
  final ImagePicker _picker;

  ImagePickerService(this._picker);

  /// Picks an image from the gallery
  Future<Either<Failure, File>> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        return left(const GeneralFailure('No image selected'));
      }

      final compressedImage = await compressImage(File(image.path));
      return compressedImage;
    } catch (e) {
      return left(GeneralFailure(e.toString()));
    }
  }

  /// Picks an image from the camera
  Future<Either<Failure, File>> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        return left(const GeneralFailure('No image captured'));
      }

      final compressedImage = await compressImage(File(image.path));
      return compressedImage;
    } catch (e) {
      return left(GeneralFailure(e.toString()));
    }
  }

  /// Compresses an image to reduce file size
  Future<Either<Failure, File>> compressImage(File imageFile) async {
    try {
      // Read the image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return left(const GeneralFailure('Failed to decode image'));
      }

      // Resize if needed (max 1024x1024)
      img.Image resized = image;
      if (image.width > 1024 || image.height > 1024) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
        );
      }

      // Compress as JPEG with 85% quality
      final compressed = img.encodeJpg(resized, quality: 85);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(compressed);

      return right(tempFile);
    } catch (e) {
      return left(GeneralFailure(e.toString()));
    }
  }
}
