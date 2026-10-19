import 'package:flutter/material.dart';

import '../data/media.dart';
import 'media_screens.dart';
import 'shelf_screen.dart';
import 'skeleton_screen.dart';

/// 启动主界面：图书、图片、视频、白骨观四个入口。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _Section(
        title: '图书',
        subtitle: '不净观相关书籍',
        icon: Icons.menu_book,
        builder: (_) => const ShelfScreen(),
      ),
      _Section(
        title: '图片',
        subtitle: '自建分类，本地或链接',
        icon: Icons.photo_library_outlined,
        builder: (_) => const MediaCategoriesScreen(kind: MediaKind.image),
      ),
      _Section(
        title: '视频',
        subtitle: '自建分类，本地或链接',
        icon: Icons.video_library_outlined,
        builder: (_) => const MediaCategoriesScreen(kind: MediaKind.video),
      ),
      _Section(
        title: '白骨观',
        subtitle: '3D 人体骨骼',
        icon: Icons.accessibility_new,
        builder: (_) => const SkeletonScreen(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('不净观')),
      body: LayoutBuilder(
        builder: (context, box) => GridView.count(
          crossAxisCount: box.maxWidth >= 720 ? 4 : 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [for (final s in sections) _SectionCard(section: s)],
        ),
      ),
    );
  }
}

class _Section {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: section.builder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primaryContainer,
                child: Icon(section.icon, size: 32, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(section.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                section.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
