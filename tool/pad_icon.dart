import 'dart:io';
import 'package:image/image.dart';

void main() async {
  // Input: The current full-size icon (transparent background)
  const inputPath = 'assets/icon/icon.png';
  // Output: The new padded icon for adaptive foreground
  const outputPath = 'assets/icon/icon_adaptive_foreground.png';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('File not found: $inputPath');
    exit(1);
  }

  // Decode the image
  final bytes = await file.readAsBytes();
  final image = decodeImage(bytes);

  if (image == null) {
    print('Could not decode image');
    exit(1);
  }

  print('Original size: ${image.width}x${image.height}');

  // Create a new empty image of the same size (transparent)
  final newImage = Image(width: image.width, height: image.height);

  // Calculate scaling
  // Google recommends foreground content be about 66% of the layer size.
  // We'll scale it to 65% to be safe and ensure the shield tip (bottom) is visible.
  const scaleFactor = 0.65;
  final newWidth = (image.width * scaleFactor).round();
  final newHeight = (image.height * scaleFactor).round();

  // Resize using interpolation
  // Use average for high-quality downscaling to prevent aliasing (jagged edges)
  final scaledImage = copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: Interpolation.average,
  );

  // Calculate position to center it
  final x = (image.width - newWidth) ~/ 2;
  final y = (image.height - newHeight) ~/ 2;

  // Composite the scaled image onto the new canvas
  compositeImage(newImage, scaledImage, dstX: x, dstY: y);

  // Save the new image
  final outFile = File(outputPath);
  await outFile.writeAsBytes(encodePng(newImage));

  print('Saved padded icon to $outputPath');
}
