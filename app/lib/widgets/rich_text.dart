import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 段落文本只含两种内联标记：**粗体** 与 [文字](链接)。
final _inline = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)');

/// 把段落文本解析成 TextSpan。返回的手势识别器需要由调用方在 dispose 时释放。
List<InlineSpan> parseInline(
  String text, {
  required TextStyle linkStyle,
  required void Function(String href) onLink,
  required List<GestureRecognizer> recognizers,
}) {
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
    } else {
      final href = m.group(3)!;
      final r = TapGestureRecognizer()..onTap = () => onLink(href);
      recognizers.add(r);
      spans.add(TextSpan(text: m.group(2), style: linkStyle, recognizer: r));
    }
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return spans;
}

/// 去掉内联标记后的纯文本，例如供朗读使用。
String plainText(String text) =>
    text.replaceAllMapped(_inline, (m) => m.group(1) ?? m.group(2)!);
