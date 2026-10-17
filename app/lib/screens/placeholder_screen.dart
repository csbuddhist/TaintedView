import 'package:flutter/material.dart';

/// 尚未实现的栏目（图片、视频）的占位页。
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('$title栏目正在建设中，敬请期待', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
