import 'package:flutter/material.dart';

import '../theme.dart';
import 'api.dart';
import 'models.dart';

/// Poza de profil, sau inițiala pe fundal colorat dacă nu are poză.
class UserAvatar extends StatelessWidget {
  const UserAvatar(
      {super.key, required this.user, required this.api, this.radius = 20});

  final AppUser user;
  final CommunityApi api;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final accent = Accent.of(user.id);
    final initial = user.displayName.isEmpty
        ? '?'
        : user.displayName.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.strong,
      foregroundColor: Colors.white,
      foregroundImage: user.avatarUrl == null
          ? null
          : NetworkImage(api.imageUrl(user.avatarUrl!)),
      onForegroundImageError: user.avatarUrl == null ? null : (_, __) {},
      child: Text(initial, style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
