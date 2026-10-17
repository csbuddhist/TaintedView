import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taintedview/data/models.dart';
import 'package:taintedview/data/prefs.dart';
import 'package:taintedview/data/repository.dart';
import 'package:taintedview/data/speech.dart';
import 'package:taintedview/main.dart';
import 'package:taintedview/screens/skeleton_screen.dart';
import 'package:taintedview/widgets/rich_text.dart';

void main() {
  test('parseInline 识别粗体和链接', () {
    final links = <String>[];
    final recognizers = <GestureRecognizer>[];
    final spans = parseInline(
      '前文**重点**中间[第五章](chapter:c005)结尾',
      linkStyle: const TextStyle(),
      onLink: links.add,
      recognizers: recognizers,
    ).cast<TextSpan>();
    expect(spans.map((s) => s.text), ['前文', '重点', '中间', '第五章', '结尾']);
    expect(spans[1].style?.fontWeight, FontWeight.bold);
    (spans[3].recognizer as TapGestureRecognizer).onTap!();
    expect(links, ['chapter:c005']);
  });

  test('imageAsset 按 book.json 所在目录解析相对路径', () {
    final book = Book(
      entry: CatalogEntry(
          id: 'b1', title: 't', category: 'c', subCategory: '', chars: 0, chapters: 0, path: 'books/b1'),
      toc: const [],
      chapters: const [],
    );
    final repo = BookRepository();
    expect(repo.imageAsset(book, 'images/图一.jpg'), 'assets/data/books/b1/images/图一.jpg');
    expect(repo.imageAsset(book, '../x/a.jpg'), 'assets/data/books/x/a.jpg');
  });

  testWidgets('主界面进入图书书架', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(TaintedViewApp(
      repo: BookRepository(),
      settings: ReaderSettings(prefs),
      progress: ProgressStore(prefs),
    ));
    await tester.pumpAndSettle();
    for (final t in ['图书', '图片', '视频', '白骨观']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('图书'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(find.text('不净观书架'), findsOneWidget);
    expect(find.text('寿康宝鉴'), findsOneWidget);
  });
  test('bones.json 每块骨头都有中英文名', () {
    final names = parseBoneNames(File('assets/skeleton/bones.json').readAsStringSync());
    expect(names.length, greaterThan(200));
    expect(names['FMA24486']?.zh, '右髌骨');
    expect(names.values.where((b) => b.zh.isEmpty || b.en.isEmpty), isEmpty);
  });

  test('朗读文本去掉内联标记，图片不读', () {
    expect(speakableText(Block(id: '1', t: 'p', text: '前文**重点**看[第五章](chapter:c005)。')), '前文重点看第五章。');
    expect(speakableText(Block(id: '2', t: 'img', src: 'a.jpg')), '');
  });

  test('splitForSpeech 按句切分且不超过上限', () {
    expect(splitForSpeech('一二三。四五六！七八'), ['一二三。四五六！七八']);
    expect(splitForSpeech('一二三。四五六！七八', max: 5), ['一二三。', '四五六！', '七八']);
    final long = '字' * 23;
    final parts = splitForSpeech(long, max: 10);
    expect(parts.join(), long);
    expect(parts.every((p) => p.length <= 10), isTrue);
    expect(splitForSpeech('  '), isEmpty);
  });
}
