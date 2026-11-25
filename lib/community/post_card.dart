import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../garments/catalog.dart';
import '../theme.dart';
import 'api.dart';
import 'community.dart';
import 'models.dart';

/// Ce se poate face dintr-o postare; ecranul care o afișează decide efectul.
enum PostAction { like, comments, openPattern, report, block, delete }

/// O postare: autoarea, textul, poza, link-ul, tiparul și butoanele.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.api,
    required this.onAction,
    this.isMine = false,
    this.loggedIn = false,
  });

  final Post post;
  final CommunityApi api;
  final void Function(PostAction) onAction;
  final bool isMine;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Accent.of(post.author.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: accent.strong,
              foregroundColor: Colors.white,
              child:
                  Text(post.author.displayName.characters.first.toUpperCase()),
            ),
            title: Text(post.author.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(post.hidden
                ? '${timeAgo(post.createdAt)} · ascunsă după raportări'
                : timeAgo(post.createdAt)),
            trailing: _menu(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(post.text, style: theme.textTheme.bodyLarge),
          ),
          if (post.imageUrl != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                api.imageUrl(post.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
              ),
            ),
          if (post.linkUrl != null) _LinkTile(url: post.linkUrl!),
          if (post.pattern != null)
            _PatternTile(
              pattern: post.pattern!,
              onOpen: () => onAction(PostAction.openPattern),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => onAction(PostAction.like),
                  icon: Icon(
                      post.likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: post.likedByMe ? PatronetteColors.rose : null),
                  label: Text('${post.likeCount}'),
                ),
                TextButton.icon(
                  onPressed: () => onAction(PostAction.comments),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('${post.commentCount}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _menu(BuildContext context) {
    final items = <PopupMenuEntry<PostAction>>[
      if (post.canDelete)
        const PopupMenuItem(
            value: PostAction.delete, child: Text('Șterge postarea')),
      if (loggedIn && !isMine) ...[
        const PopupMenuItem(
            value: PostAction.report, child: Text('Raportează')),
        PopupMenuItem(
            value: PostAction.block,
            child: Text('Blochează-o pe ${post.author.displayName}')),
      ],
    ];
    if (items.isEmpty) return null;
    return PopupMenuButton<PostAction>(
      tooltip: 'Mai multe',
      onSelected: onAction,
      itemBuilder: (_) => items,
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    return ListTile(
      leading: const Icon(Icons.link),
      title:
          Text(uri?.host ?? url, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: uri == null
          ? null
          : () async {
              final ok =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Nu am putut deschide link-ul.')));
              }
            },
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.pattern, required this.onOpen});

  final SharedPattern pattern;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final garment =
        kGarments.where((g) => g.id == pattern.garmentId).firstOrNull;
    final accent = Accent.of(garment == null ? 0 : kGarments.indexOf(garment));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      // Material, nu Container colorat: altfel nu se vede efectul de apăsare.
      child: ListTile(
        tileColor: accent.light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.content_cut, color: accent.strong),
        title: Text(garment?.name ?? 'Tipar necunoscut',
            style:
                TextStyle(color: accent.strong, fontWeight: FontWeight.w700)),
        subtitle: const Text('Deschide-l pe măsurile tale',
            style: TextStyle(color: PatronetteColors.ink)),
        trailing: Icon(Icons.chevron_right, color: accent.strong),
        onTap: onOpen,
      ),
    );
  }
}
