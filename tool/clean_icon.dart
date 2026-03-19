import 'dart:io';
import 'package:image/image.dart';

void main() async {
  const path = 'assets/icon/icon_foreground.png';
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    exit(1);
  }

  final bytes = await file.readAsBytes();
  final image = decodeImage(bytes);

  if (image == null) {
    print('Could not decode image via decodeImage');
    exit(1);
  }

  print('Processing image: ${image.width}x${image.height}');

  // Process every pixel
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);

      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;

      // Strict high-pass filter for White
      // If it's not very bright, kill it.
      if (r < 230 || g < 230 || b < 230) {
        image.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent
      } else {
        // Ensure it is 100% opaque white if it passes the threshold
        image.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  await file.writeAsBytes(encodePng(image));
  print('Icon cleaned and saved: Non-white pixels removed.');
}
