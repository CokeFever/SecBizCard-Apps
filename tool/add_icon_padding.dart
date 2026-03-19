// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final inputPath = 'assets/icon/icon_adaptive_foreground.png';
  final outputPath = 'assets/icon/icon_adaptive_foreground_padded.png';

  print('Loading $inputPath...');
  final inputFile = File(inputPath);
  final bytes = await inputFile.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Failed to load image');
    return;
  }

  print('Original size: ${image.width}x${image.height}');

  // Target: logo should be ~66% of canvas for circular mask safety
  // This means we need to scale down and add padding
  final targetSize = 1024;
  final logoSize = (targetSize * 0.70).toInt(); // 70% of canvas = ~717px
  final padding = (targetSize - logoSize) ~/ 2; // ~153px on each side

  print('Resizing to ${logoSize}x${logoSize} with ${padding}px padding...');

  // Resize the original image
  final resized = img.copyResize(image, width: logoSize, height: logoSize);

  // Create new canvas with transparent background
  final canvas = img.Image(
    width: targetSize,
    height: targetSize,
    numChannels: 4,
  );

  // Composite resized image onto canvas at center
  img.compositeImage(canvas, resized, dstX: padding, dstY: padding);

  // Save
  final outputBytes = img.encodePng(canvas);
  await File(outputPath).writeAsBytes(outputBytes);

  print('Saved to $outputPath');
  print('Done! Now copy this file to replace icon_adaptive_foreground.png');
}
