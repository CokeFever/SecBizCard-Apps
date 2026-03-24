import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';

class ProfileAvatar extends ConsumerWidget {
  final UserProfile? profile;
  final double radius;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    this.profile,
    this.radius = 50,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveRepo = ref.read(driveRepositoryProvider);
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.canvasColor;

    ImageProvider? imageProvider;

    // 1. High Priority: Cloud Drive avatar
    if (profile?.avatarDriveFileId != null) {
      imageProvider = CachedNetworkImageProvider(
        driveRepo.getFileUrl(profile!.avatarDriveFileId!),
      );
    } 
    // 2. Medium Priority: profile.photoUrl (could be HTTP or Local Path)
    else if (profile?.photoUrl != null) {
      final url = profile!.photoUrl!;
      if (url.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(url);
      } else {
        // If it's a local path, check if file exists
        final file = File(url);
        if (file.existsSync()) {
          imageProvider = FileImage(file);
        }
      }
    }

    // 3. Low Priority (Fallback): Firebase Auth photoURL
    if (imageProvider == null) {
      final authUser = fire_auth.FirebaseAuth.instance.currentUser;
      final authPhotoUrl = authUser?.photoURL;
      if (authPhotoUrl != null && authPhotoUrl.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(authPhotoUrl);
      }
    }

    // 4. Final Placeholder
    if (imageProvider == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(
          Icons.person,
          size: radius,
          color: theme.hintColor,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: imageProvider,
    );
  }
}
