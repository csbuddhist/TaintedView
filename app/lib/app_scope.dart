import 'package:flutter/widgets.dart';

import 'data/media.dart';
import 'data/prefs.dart';
import 'data/repository.dart';

/// 向下传递全局单例：书稿仓库、阅读设置、阅读进度和图片 / 视频分类。
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.settings,
    required this.progress,
    required this.media,
    required super.child,
  });

  final BookRepository repo;
  final ReaderSettings settings;
  final ProgressStore progress;
  final MediaStore media;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repo != oldWidget.repo || settings != oldWidget.settings || progress != oldWidget.progress ||
      media != oldWidget.media;
}
