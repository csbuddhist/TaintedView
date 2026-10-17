import 'package:flutter/widgets.dart';

import 'data/prefs.dart';
import 'data/repository.dart';

/// 向下传递全局单例：书稿仓库、阅读设置和阅读进度。
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.settings,
    required this.progress,
    required super.child,
  });

  final BookRepository repo;
  final ReaderSettings settings;
  final ProgressStore progress;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repo != oldWidget.repo || settings != oldWidget.settings || progress != oldWidget.progress;
}
