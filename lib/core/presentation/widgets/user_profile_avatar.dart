import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';

class UserProfileAvatar extends ConsumerWidget {
  final String? photoUrl;
  final String? driveFileId;
  final String displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserProfileAvatar({
    super.key,
    required this.photoUrl,
    this.driveFileId,
    required this.displayName,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine initials
    String initials = '';
    if (displayName.isNotEmpty) {
      initials = displayName
          .trim()
          .split(' ')
          .take(2)
          .map((e) => e.isNotEmpty ? e[0] : '')
          .join()
          .toUpperCase();
      if (initials.isEmpty && displayName.isNotEmpty) {
        initials = displayName[0].toUpperCase();
      }
    }

    final bgColor = backgroundColor ?? Colors.blueGrey[100];
    final fgColor = foregroundColor ?? Colors.blueGrey[800];
    
    ImageProvider? imageProvider;

    // 1. Try local path/network URL from photoUrl
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(photoUrl!);
      } else {
        final file = File(photoUrl!);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    // 2. Fallback to Drive ID if photoUrl failed/is missing
    if (imageProvider == null && driveFileId != null && driveFileId!.isNotEmpty) {
      final driveRepo = ref.read(driveRepositoryProvider);
      imageProvider = CachedNetworkImageProvider(driveRepo.getFileUrl(driveFileId!));
    }

    if (imageProvider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: imageProvider,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: fgColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
