import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../widgets/format.dart';
import '../widgets/toc_view.dart';
import 'reader_screen.dart';

/// 书籍详情：基本信息、开始/继续阅读按钮和完整目录。
class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.entry});

  final CatalogEntry entry;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  Future<Book>? _book;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _book ??= AppScope.of(context).repo.book(widget.entry.id);
  }

  void _open(Book book, String cid, [int block = 0]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderScreen(book: book, chapterId: cid, initialBlock: block),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: FutureBuilder<Book>(
        future: _book,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('加载失败：${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final book = snap.data!;
          return ListenableBuilder(
            listenable: progress,
            builder: (context, _) {
              final p = progress.of(book.id);
              final resume = p != null && book.indexOf(p.chapter) >= 0 ? p : null;
              final theme = Theme.of(context);
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 6),
                        Text(
                          '${entry.category} · ${book.chapters.length} 章 · ${formatChars(entry.chars)}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (resume != null)
                              FilledButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: Text('继续：${book.chapter(resume.chapter)!.title}',
                                    overflow: TextOverflow.ellipsis),
                                onPressed: () => _open(book, resume.chapter, resume.block),
                              ),
                            if (book.chapters.isNotEmpty && resume == null)
                              FilledButton(
                                onPressed: () => _open(book, book.chapters.first.id),
                                child: const Text('开始阅读'),
                              ),
                            if (book.chapters.isNotEmpty && resume != null)
                              OutlinedButton(
                                onPressed: () => _open(book, book.chapters.first.id),
                                child: const Text('从头阅读'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text('目录', style: theme.textTheme.titleMedium),
                  ),
                  TocView(
                    book: book,
                    current: resume?.chapter,
                    shrinkWrap: true,
                    onSelect: (cid) => _open(book, cid),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
