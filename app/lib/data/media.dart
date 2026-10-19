import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MediaKind {
  image('图片'),
  video('视频');

  const MediaKind(this.label);
  final String label;
}

/// 分类里的一项：本地文件（已复制到应用目录）或网络链接。
class MediaItem {
  MediaItem({required this.id, required this.name, this.file, this.url, required this.addedAt})
    : assert((file == null) != (url == null));

  final String id;
  String name;

  /// 相对 [MediaStore.root] 的路径（iOS 升级后应用目录的绝对路径会变）。
  final String? file;
  final String? url;
  final DateTime addedAt;

  bool get isLink => url != null;

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id: j['id'] as String,
    name: j['name'] as String,
    file: j['file'] as String?,
    url: j['url'] as String?,
    addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt'] as int),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (file != null) 'file': file,
    if (url != null) 'url': url,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };
}

class MediaCategory {
  MediaCategory({required this.id, required this.kind, required this.name, List<MediaItem>? items})
    : items = items ?? [];

  final String id;
  final MediaKind kind;
  String name;
  final List<MediaItem> items;

  factory MediaCategory.fromJson(Map<String, dynamic> j) => MediaCategory(
    id: j['id'] as String,
    kind: MediaKind.values.byName(j['kind'] as String),
    name: j['name'] as String,
    items: [for (final i in j['items'] as List) MediaItem.fromJson((i as Map).cast<String, dynamic>())],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'items': [for (final i in items) i.toJson()],
  };
}

/// 解析用户输入的链接，只接受 http/https，缺少协议时补上 https。
Uri? parseMediaLink(String input) {
  var s = input.trim();
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) return null;
  return uri;
}

/// 链接的默认显示名：取路径最后一段，没有则用域名。
String linkDisplayName(Uri uri) {
  final segs = uri.pathSegments.where((s) => s.isNotEmpty);
  return segs.isEmpty ? uri.host : segs.last;
}

/// 用户自建的图片 / 视频分类。分类清单存在 SharedPreferences，
/// 选中的本地文件复制到 [root]，这样原文件被删或系统清理缓存后仍可查看。
class MediaStore extends ChangeNotifier {
  MediaStore(this._prefs, {required this.root}) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _categories.addAll([
          for (final c in jsonDecode(raw) as List) MediaCategory.fromJson((c as Map).cast<String, dynamic>()),
        ]);
      } catch (e) {
        debugPrint('媒体分类数据损坏，已忽略：$e');
      }
    }
  }

  static const _key = 'media:categories';

  final SharedPreferences _prefs;

  /// 本地文件的存放目录。
  final Directory root;
  final _categories = <MediaCategory>[];
  int _seq = 0;

  List<MediaCategory> categories(MediaKind kind) => [
    for (final c in _categories)
      if (c.kind == kind) c,
  ];

  MediaCategory? category(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

  void _save() {
    _prefs.setString(_key, jsonEncode([for (final c in _categories) c.toJson()]));
    notifyListeners();
  }

  MediaCategory createCategory(MediaKind kind, String name) {
    final c = MediaCategory(id: _newId(), kind: kind, name: name.trim());
    _categories.add(c);
    _save();
    return c;
  }

  void renameCategory(MediaCategory c, String name) {
    c.name = name.trim();
    _save();
  }

  Future<void> deleteCategory(MediaCategory c) async {
    _categories.remove(c);
    _save();
    final dir = Directory('${root.path}/${c.id}');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  void addLink(MediaCategory c, Uri url, {String? name}) {
    final n = name?.trim();
    c.items.add(
      MediaItem(
        id: _newId(),
        name: n == null || n.isEmpty ? linkDisplayName(url) : n,
        url: url.toString(),
        addedAt: DateTime.now(),
      ),
    );
    _save();
  }

  /// 把字节流写入该分类的目录并登记。
  Future<void> addFile(MediaCategory c, String name, Stream<List<int>> bytes) async {
    final id = _newId();
    final dot = name.lastIndexOf('.');
    final rel = '${c.id}/$id${dot > 0 ? name.substring(dot) : ''}';
    final file = File('${root.path}/$rel');
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
    } catch (_) {
      await sink.close();
      await file.delete();
      rethrow;
    }
    await sink.close();
    c.items.add(MediaItem(id: id, name: name, file: rel, addedAt: DateTime.now()));
    _save();
  }

  void renameItem(MediaItem item, String name) {
    item.name = name.trim();
    _save();
  }

  Future<void> removeItem(MediaCategory c, MediaItem item) async {
    c.items.remove(item);
    _save();
    final f = fileOf(item);
    if (f != null && await f.exists()) await f.delete();
  }

  File? fileOf(MediaItem item) => item.file == null ? null : File('${root.path}/${item.file}');
}
