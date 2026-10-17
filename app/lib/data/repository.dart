import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// 从 assets/data/ 读取书目、书籍和章节，并做内存缓存。
class BookRepository {
  BookRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const root = 'assets/data';

  final AssetBundle _bundle;
  List<CatalogEntry>? _catalog;
  final Map<String, Book> _books = {};
  final Map<String, Chapter> _chapters = {};

  Future<Map<String, dynamic>> _json(String path) async =>
      jsonDecode(await _bundle.loadString('$root/$path')) as Map<String, dynamic>;

  Future<List<CatalogEntry>> catalog() async {
    if (_catalog != null) return _catalog!;
    final j = await _json('catalog.json');
    return _catalog = [
      for (final b in j['books'] as List) CatalogEntry.fromJson(b as Map<String, dynamic>),
    ];
  }

  Future<Book> book(String id) async {
    final cached = _books[id];
    if (cached != null) return cached;
    final entry = (await catalog()).firstWhere((e) => e.id == id);
    return _books[id] = Book.fromJson(entry, await _json('${entry.path}/book.json'));
  }

  Future<Chapter> chapter(Book book, String cid) async {
    final key = '${book.id}/$cid';
    final cached = _chapters[key];
    if (cached != null) return cached;
    if (_chapters.length > 20) _chapters.clear();
    return _chapters[key] = Chapter.fromJson(await _json('${book.entry.path}/chapters/$cid.json'));
  }

  /// img.src 相对 book.json 所在目录。
  String imageAsset(Book book, String src) {
    final parts = '$root/${book.entry.path}'.split('/');
    for (final seg in src.split('/')) {
      if (seg == '..') {
        parts.removeLast();
      } else if (seg.isNotEmpty && seg != '.') {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }
}
