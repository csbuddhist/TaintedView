import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderTheme {
  system('跟随系统'),
  light('白'),
  sepia('护眼'),
  dark('夜间');

  const ReaderTheme(this.label);
  final String label;
}

/// 阅读排版设置，修改后立即持久化。
class ReaderSettings extends ChangeNotifier {
  ReaderSettings(this._prefs)
      : _fontSize = _prefs.getDouble('fontSize') ?? 19,
        _lineHeight = _prefs.getDouble('lineHeight') ?? 1.8,
        _paragraphGap = _prefs.getDouble('paragraphGap') ?? 14,
        _indent = _prefs.getBool('indent') ?? true,
        _theme = ReaderTheme.values.asNameMap()[_prefs.getString('theme')] ?? ReaderTheme.system;

  final SharedPreferences _prefs;
  double _fontSize;
  double _lineHeight;
  double _paragraphGap;
  bool _indent;
  ReaderTheme _theme;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get paragraphGap => _paragraphGap;
  bool get indent => _indent;
  ReaderTheme get theme => _theme;

  set fontSize(double v) {
    _fontSize = v;
    _prefs.setDouble('fontSize', v);
    notifyListeners();
  }

  set lineHeight(double v) {
    _lineHeight = v;
    _prefs.setDouble('lineHeight', v);
    notifyListeners();
  }

  set paragraphGap(double v) {
    _paragraphGap = v;
    _prefs.setDouble('paragraphGap', v);
    notifyListeners();
  }

  set indent(bool v) {
    _indent = v;
    _prefs.setBool('indent', v);
    notifyListeners();
  }

  set theme(ReaderTheme v) {
    _theme = v;
    _prefs.setString('theme', v.name);
    notifyListeners();
  }
}

class ReadingPosition {
  const ReadingPosition(this.chapter, this.block, this.updatedAt);

  final String chapter;

  /// 章内第几个段落块（从 0 开始）。
  final int block;
  final DateTime updatedAt;
}

/// 每本书的阅读进度，以「章节 id + 段落序号」定位。
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs);

  final SharedPreferences _prefs;

  ReadingPosition? of(String bookId) {
    final raw = _prefs.getString('progress:$bookId');
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    return ReadingPosition(
      parts[0],
      int.tryParse(parts[1]) ?? 0,
      DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[2]) ?? 0),
    );
  }

  void save(String bookId, String chapter, int block) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prefs.setString('progress:$bookId', '$chapter|$block|$now');
    notifyListeners();
  }
}
