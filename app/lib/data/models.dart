/// 书稿数据模型，对应 tools/build_books.py 输出的 JSON。
library;

class CatalogEntry {
  CatalogEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.subCategory,
    required this.chars,
    required this.chapters,
    required this.path,
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> j) => CatalogEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String? ?? '',
        subCategory: j['subCategory'] as String? ?? '',
        chars: j['chars'] as int? ?? 0,
        chapters: j['chapters'] as int? ?? 0,
        path: j['path'] as String,
      );

  final String id;
  final String title;
  final String category;
  final String subCategory;
  final int chars;
  final int chapters;

  /// 书籍目录，相对 assets/data/。
  final String path;
}

class TocNode {
  TocNode({required this.title, this.chapter, this.children = const []});

  factory TocNode.fromJson(Map<String, dynamic> j) => TocNode(
        title: j['title'] as String,
        chapter: j['chapter'] as String?,
        children: [
          for (final c in (j['children'] as List? ?? const []))
            TocNode.fromJson(c as Map<String, dynamic>),
        ],
      );

  final String title;
  final String? chapter;
  final List<TocNode> children;

  bool contains(String cid) =>
      chapter == cid || children.any((c) => c.contains(cid));
}

class ChapterMeta {
  ChapterMeta({required this.id, required this.title, required this.chars});

  factory ChapterMeta.fromJson(Map<String, dynamic> j) => ChapterMeta(
        id: j['id'] as String,
        title: j['title'] as String,
        chars: j['chars'] as int? ?? 0,
      );

  final String id;
  final String title;
  final int chars;
}

class Book {
  Book({
    required this.entry,
    required this.toc,
    required this.chapters,
  });

  factory Book.fromJson(CatalogEntry entry, Map<String, dynamic> j) => Book(
        entry: entry,
        toc: [
          for (final n in (j['toc'] as List? ?? const []))
            TocNode.fromJson(n as Map<String, dynamic>),
        ],
        chapters: [
          for (final c in (j['chapters'] as List? ?? const []))
            ChapterMeta.fromJson(c as Map<String, dynamic>),
        ],
      );

  final CatalogEntry entry;
  final List<TocNode> toc;
  final List<ChapterMeta> chapters;

  String get id => entry.id;
  String get title => entry.title;

  int indexOf(String cid) => chapters.indexWhere((c) => c.id == cid);

  ChapterMeta? chapter(String cid) {
    final i = indexOf(cid);
    return i < 0 ? null : chapters[i];
  }
}

/// 段落块类型：h 标题、p 段落、li 列表项、quote 引用、img 图片、pre 预格式文本。
class Block {
  Block({required this.id, required this.t, this.text = '', this.level = 0, this.src});

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        id: j['id'] as String,
        t: j['t'] as String,
        text: j['text'] as String? ?? '',
        level: j['level'] as int? ?? 0,
        src: j['src'] as String?,
      );

  final String id;
  final String t;
  final String text;
  final int level;
  final String? src;
}

class Chapter {
  Chapter({required this.id, required this.title, required this.blocks});

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        title: j['title'] as String,
        blocks: [
          for (final b in (j['blocks'] as List? ?? const []))
            Block.fromJson(b as Map<String, dynamic>),
        ],
      );

  final String id;
  final String title;
  final List<Block> blocks;
}
