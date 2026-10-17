import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/rich_text.dart';
import '../widgets/toc_view.dart';

/// 章节阅读页：按段落块渲染，自动保存阅读位置，章末可翻到上一章/下一章。
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    required this.chapterId,
    this.initialBlock = 0,
  });

  final Book book;
  final String chapterId;
  final int initialBlock;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _positions = ItemPositionsListener.create();
  late String _cid = widget.chapterId;
  late int _initialBlock = widget.initialBlock;
  Future<Chapter>? _chapter;
  int _visibleBlock = 0;
  Timer? _saveTimer;
  late ProgressStore _progress;

  Book get book => widget.book;

  @override
  void initState() {
    super.initState();
    _visibleBlock = _initialBlock;
    _positions.itemPositions.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress = AppScope.of(context).progress;
    _chapter ??= _load(_cid);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onScroll);
    _saveTimer?.cancel();
    _save();
    super.dispose();
  }

  Future<Chapter> _load(String cid) {
    // 打开章节即记为阅读位置；推迟到帧后，避免在构建阶段通知其他页面。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && cid == _cid) _save();
    });
    return AppScope.of(context).repo.chapter(book, cid);
  }

  void _onScroll() {
    final visible = _positions.itemPositions.value.where((p) => p.itemTrailingEdge > 0.02);
    if (visible.isEmpty) return;
    final first = visible.reduce((a, b) => a.index < b.index ? a : b).index;
    if (first == _visibleBlock) return;
    _visibleBlock = first;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  void _save() => _progress.save(book.id, _cid, _visibleBlock);

  void _goTo(String cid, {int block = 0}) {
    if (book.indexOf(cid) < 0) return;
    _saveTimer?.cancel();
    setState(() {
      _cid = cid;
      _initialBlock = block;
      _visibleBlock = block;
      _chapter = _load(cid);
    });
  }

  void _onLink(String href) {
    if (href.startsWith('chapter:')) {
      _goTo(href.substring(8));
    } else if (href.startsWith('http://') || href.startsWith('https://')) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final palette = ReaderPalette.of(settings.theme, MediaQuery.platformBrightnessOf(context));
        final index = book.indexOf(_cid);
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.text,
            title: Text(book.chapters[index].title, style: const TextStyle(fontSize: 17)),
            actions: [
              IconButton(
                tooltip: '目录',
                icon: const Icon(Icons.list),
                onPressed: () => _scaffoldKey.currentState!.openEndDrawer(),
              ),
              IconButton(
                tooltip: '排版',
                icon: const Icon(Icons.text_fields),
                onPressed: () => showReaderSettings(context, settings),
              ),
            ],
          ),
          endDrawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(book.title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TocView(
                      book: book,
                      current: _cid,
                      onSelect: (cid) {
                        Navigator.of(context).pop();
                        _goTo(cid);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: FutureBuilder<Chapter>(
            future: _chapter,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('章节加载失败：${snap.error}'));
              if (!snap.hasData || snap.data!.id != _cid) {
                return const Center(child: CircularProgressIndicator());
              }
              final chapter = snap.data!;
              final blocks = chapter.blocks;
              return SafeArea(
                top: false,
                child: ScrollablePositionedList.builder(
                  key: ValueKey(_cid),
                  itemPositionsListener: _positions,
                  initialScrollIndex: _initialBlock.clamp(0, blocks.length),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  itemCount: blocks.length + 1,
                  itemBuilder: (context, i) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: i < blocks.length
                            ? BlockView(
                                block: blocks[i],
                                book: book,
                                settings: settings,
                                palette: palette,
                                onLink: _onLink,
                              )
                            : _ChapterNav(
                                prev: index > 0 ? book.chapters[index - 1] : null,
                                next: index < book.chapters.length - 1 ? book.chapters[index + 1] : null,
                                palette: palette,
                                onGo: _goTo,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 阅读区配色。
class ReaderPalette {
  const ReaderPalette(this.background, this.text, this.muted, this.accent);

  final Color background;
  final Color text;
  final Color muted;
  final Color accent;

  static const light = ReaderPalette(Color(0xFFFCFBF8), Color(0xFF222222), Color(0xFF8A8580), Color(0xFF8A5A2B));
  static const sepia = ReaderPalette(Color(0xFFF3EAD3), Color(0xFF3B3226), Color(0xFF8C7D63), Color(0xFF8A5A2B));
  static const dark = ReaderPalette(Color(0xFF161616), Color(0xFFC9C6C0), Color(0xFF7D7A75), Color(0xFFD1A26E));

  static ReaderPalette of(ReaderTheme theme, Brightness platform) => switch (theme) {
        ReaderTheme.light => light,
        ReaderTheme.sepia => sepia,
        ReaderTheme.dark => dark,
        ReaderTheme.system => platform == Brightness.dark ? dark : light,
      };
}

class BlockView extends StatefulWidget {
  const BlockView({
    super.key,
    required this.block,
    required this.book,
    required this.settings,
    required this.palette,
    required this.onLink,
  });

  final Block block;
  final Book book;
  final ReaderSettings settings;
  final ReaderPalette palette;
  final void Function(String href) onLink;

  @override
  State<BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends State<BlockView> {
  final List<GestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final b = widget.block;
    final s = widget.settings;
    final p = widget.palette;
    final gap = s.paragraphGap;
    final base = TextStyle(fontSize: s.fontSize, height: s.lineHeight, color: p.text);

    if (b.t == 'img' && b.src != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: gap),
        child: Image.asset(
          AppScope.of(context).repo.imageAsset(widget.book, b.src!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    List<InlineSpan> spans(String text) => parseInline(
          text,
          linkStyle: TextStyle(color: p.accent, decoration: TextDecoration.underline, decorationColor: p.accent),
          onLink: widget.onLink,
          recognizers: _recognizers,
        );

    switch (b.t) {
      case 'h':
        final scale = switch (b.level) { 1 => 1.45, 2 => 1.3, 3 => 1.18, _ => 1.08 };
        return Padding(
          padding: EdgeInsets.only(top: gap * 1.6, bottom: gap * 0.6),
          child: Text.rich(
            TextSpan(children: spans(b.text)),
            textAlign: b.level <= 1 ? TextAlign.center : TextAlign.start,
            style: base.copyWith(fontSize: s.fontSize * scale, fontWeight: FontWeight.bold, height: 1.4),
          ),
        );
      case 'li':
        return Padding(
          padding: EdgeInsets.only(bottom: gap * 0.5, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: base.copyWith(color: p.muted)),
              Expanded(child: Text.rich(TextSpan(children: spans(b.text)), style: base)),
            ],
          ),
        );
      case 'quote':
        return Container(
          margin: EdgeInsets.only(bottom: gap),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: p.muted, width: 3))),
          child: Text.rich(TextSpan(children: spans(b.text)), style: base.copyWith(color: p.muted)),
        );
      case 'pre':
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Text(b.text, style: base.copyWith(fontFamily: 'monospace', fontSize: s.fontSize * 0.85)),
        );
      default:
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Text.rich(
            TextSpan(children: [
              // 两端对齐时全角空格会被当作可伸缩空白摊到整行，缩进改用固定宽度占位。
              if (s.indent) WidgetSpan(child: SizedBox(width: s.fontSize * 2)),
              ...spans(b.text),
            ]),
            style: base,
            textAlign: TextAlign.justify,
          ),
        );
    }
  }
}

class _ChapterNav extends StatelessWidget {
  const _ChapterNav({required this.prev, required this.next, required this.palette, required this.onGo});

  final ChapterMeta? prev;
  final ChapterMeta? next;
  final ReaderPalette palette;
  final void Function(String cid) onGo;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: palette.text,
      side: BorderSide(color: palette.muted.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: style,
                  onPressed: prev == null ? null : () => onGo(prev!.id),
                  child: Text(prev == null ? '已是第一章' : '上一章\n${prev!.title}',
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: style,
                  onPressed: next == null ? null : () => onGo(next!.id),
                  child: Text(next == null ? '全书完' : '下一章\n${next!.title}',
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
