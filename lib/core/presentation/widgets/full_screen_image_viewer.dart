import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = CachedNetworkImageProvider(imagePath);
    } else {
      imageProvider = FileImage(File(imagePath));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Hero(
            tag: tag,
            child: PhotoView(
              imageProvider: imageProvider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
