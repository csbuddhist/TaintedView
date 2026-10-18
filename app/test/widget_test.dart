import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taintedview/data/media.dart';
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
        id: 'b1',
        title: 't',
        category: 'c',
        subCategory: '',
        chars: 0,
        chapters: 0,
        path: 'books/b1',
      ),
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
    await tester.pumpWidget(
      TaintedViewApp(
        repo: BookRepository(),
        settings: ReaderSettings(prefs),
        progress: ProgressStore(prefs),
        media: MediaStore(prefs, root: Directory.systemTemp),
      ),
    );
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

  test('parseMediaLink 只接受 http/https 并补全协议', () {
    expect(parseMediaLink(' example.com/a.jpg ').toString(), 'https://example.com/a.jpg');
    expect(parseMediaLink('http://x.cn/v.mp4')?.scheme, 'http');
    expect(parseMediaLink('ftp://x.cn/a.jpg'), isNull);
    expect(parseMediaLink('   '), isNull);
    expect(linkDisplayName(Uri.parse('https://x.cn/p/%E5%9B%BE.jpg')), '图.jpg');
    expect(linkDisplayName(Uri.parse('https://x.cn/')), 'x.cn');
  });

  test('MediaStore 分类、文件和链接可持久化，删除时清理文件', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final root = await Directory.systemTemp.createTemp('media_test');
    addTearDown(() => root.delete(recursive: true));

    final store = MediaStore(prefs, root: root);
    final c = store.createCategory(MediaKind.image, ' 骨相 ');
    store.createCategory(MediaKind.video, '开示');
    await store.addFile(c, 'a.JPG', Stream.value([1, 2, 3]));
    store.addLink(c, Uri.parse('https://x.cn/b.png'));

    final reloaded = MediaStore(prefs, root: root);
    final cats = reloaded.categories(MediaKind.image);
    expect(cats.map((c) => c.name), ['骨相']);
    expect(reloaded.categories(MediaKind.video).single.name, '开示');
    final items = cats.single.items;
    expect(items.map((i) => i.name), ['a.JPG', 'b.png']);
    final file = reloaded.fileOf(items[0])!;
    expect(file.path, startsWith(root.path));
    expect(file.path, endsWith('.JPG'));
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(items[1].isLink, isTrue);
    expect(reloaded.fileOf(items[1]), isNull);

    await reloaded.removeItem(cats.single, items[0]);
    expect(await file.exists(), isFalse);
    await reloaded.addFile(cats.single, 'c.png', Stream.value([9]));
    final dir = Directory('${root.path}/${cats.single.id}');
    expect(await dir.exists(), isTrue);
    await reloaded.deleteCategory(cats.single);
    expect(await dir.exists(), isFalse);
    expect(MediaStore(prefs, root: root).categories(MediaKind.image), isEmpty);
  });

  testWidgets('图片栏目新建分类并添加链接', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final media = MediaStore(prefs, root: Directory.systemTemp);
    await tester.pumpWidget(
      TaintedViewApp(
        repo: BookRepository(),
        settings: ReaderSettings(prefs),
        progress: ProgressStore(prefs),
        media: media,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有分类'), findsOneWidget);

    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '九想图');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('九想图'), findsOneWidget);
    expect(find.text('0 项'), findsOneWidget);

    await tester.tap(find.text('九想图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加图片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加图片链接'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'not a url');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入有效'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'https://example.com/a.jpg');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final cat = media.categories(MediaKind.image).single;
    expect(cat.items.single.url, 'https://example.com/a.jpg');
    expect(find.byType(Image), findsOneWidget);
  });
}
