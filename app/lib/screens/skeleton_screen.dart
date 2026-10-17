import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 白骨观：WebView 里的 3D 骨骼（assets/skeleton/，由 tool/skeleton 生成）。
/// 单指旋转、双指缩放和平移，轻点骨骼显示名称。
class SkeletonScreen extends StatefulWidget {
  const SkeletonScreen({super.key});

  @override
  State<SkeletonScreen> createState() => _SkeletonScreenState();
}

class BoneName {
  const BoneName(this.zh, this.en);

  final String zh;
  final String en;
}

/// 读取 bones.json：FMA 编号 → 中英文骨名。
Map<String, BoneName> parseBoneNames(String json) => {
      for (final e in (jsonDecode(json) as Map<String, dynamic>).entries)
        e.key: BoneName(e.value['zh'] as String, e.value['en'] as String),
    };

class _SkeletonScreenState extends State<SkeletonScreen> {
  late final WebViewController _web;
  Map<String, BoneName> _names = const {};
  BoneName? _selected;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Bones', onMessageReceived: _onMessage)
      ..loadFlutterAsset('assets/skeleton/index.html');
    rootBundle.loadString('assets/skeleton/bones.json').then((s) {
      if (mounted) setState(() => _names = parseBoneNames(s));
    });
  }

  void _onMessage(JavaScriptMessage message) {
    final msg = jsonDecode(message.message) as Map<String, dynamic>;
    setState(() {
      switch (msg['type']) {
        case 'ready':
          _ready = true;
        case 'error':
          _error = msg['message'] as String?;
        case 'select':
          final id = msg['id'] as String?;
          _selected = id == null ? null : _names[id] ?? BoneName(id, '');
      }
    });
  }

  void _reset() {
    _web.runJavaScript('resetView(); clearSelection();');
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('白骨观'),
        actions: [
          IconButton(icon: const Icon(Icons.center_focus_strong), tooltip: '复位', onPressed: _reset),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '模型来源',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: '白骨观 3D 骨骼',
              children: const [
                Text('单指拖动旋转，双指捏合缩放、拖动平移，轻点骨骼显示名称。\n\n'
                    '骨骼模型来自 BodyParts3D，© The Database Center for Life Science，'
                    '依 CC BY 4.0 授权使用；为在手机上流畅显示做了简化。'),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1C1B19),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _web)),
          if (_error != null)
            Center(child: Text('模型加载失败：$_error', style: const TextStyle(color: Colors.white)))
          else if (!_ready)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _selected == null
                    ? Text(
                        _ready ? '轻点骨骼查看名称' : '',
                        key: const ValueKey('hint'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      )
                    : Card(
                        key: ValueKey(_selected!.zh),
                        child: ListTile(
                          leading: const Icon(Icons.label_important_outline),
                          title: Text(_selected!.zh, style: theme.textTheme.titleLarge),
                          subtitle: _selected!.en.isEmpty ? null : Text(_selected!.en),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _web.runJavaScript('clearSelection();');
                              setState(() => _selected = null);
                            },
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
