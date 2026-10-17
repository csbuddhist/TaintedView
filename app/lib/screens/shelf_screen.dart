import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/format.dart';
import 'book_screen.dart';
import 'reader_screen.dart';

/// 书架：按分类列出全部书籍，顶部显示最近在读的一本。
class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  Future<List<CatalogEntry>>? _catalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalog ??= AppScope.of(context).repo.catalog();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('不净观书架')),
      body: FutureBuilder<List<CatalogEntry>>(
        future: _catalog,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('书目加载失败：${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final books = snap.data!;
          return ListenableBuilder(
            listenable: scope.progress,
            builder: (context, _) => _buildList(context, books),
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CatalogEntry> books) {
    final progress = AppScope.of(context).progress;
    final groups = <String, List<CatalogEntry>>{};
    for (final b in books) {
      groups.putIfAbsent(b.category, () => []).add(b);
    }

    CatalogEntry? recent;
    DateTime? recentAt;
    for (final b in books) {
      final p = progress.of(b.id);
      if (p != null && (recentAt == null || p.updatedAt.isAfter(recentAt))) {
        recent = b;
        recentAt = p.updatedAt;
      }
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (recent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.auto_stories),
                title: Text('继续阅读《${recent.title}》'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _resume(context, recent!),
              ),
            ),
          ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              '${entry.key}（${entry.value.length}）',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final b in entry.value) _BookTile(entry: b),
        ],
      ],
    );
  }

  Future<void> _resume(BuildContext context, CatalogEntry entry) async {
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final book = await scope.repo.book(entry.id);
    final p = scope.progress.of(entry.id);
    if (p == null || book.indexOf(p.chapter) < 0) return;
    navigator.push(MaterialPageRoute(
      builder: (_) => ReaderScreen(book: book, chapterId: p.chapter, initialBlock: p.block),
    ));
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.entry});

  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).progress.of(entry.id);
    final sub = [
      '${entry.chapters} 章',
      formatChars(entry.chars),
      if (p != null) '已读过',
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(child: Text(entry.title.replaceAll(RegExp(r'[《》]'), '').characters.first)),
      title: Text(entry.title),
      subtitle: Text(sub),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookScreen(entry: entry)),
      ),
    );
  }
}
