# 不净观 App（0.1）

Flutter 阅读器，读取 `../books/` 生成的书稿数据，离线阅读。

- 书架：按分类列出全部书籍，顶部显示最近在读的一本
- 书籍页：多级目录，开始 / 继续阅读
- 阅读页：段落块渲染（标题、段落、列表、引用、图片），站内章节链接，章末上一章 / 下一章
- 排版：主题（跟随系统、白、护眼、夜间）、字号、行距、段距、首行缩进，设置自动保存
- 阅读进度按「章节 + 段落」保存

## 构建

环境搭建见 [docs/setup-macos.md](../docs/setup-macos.md)。

```bash
python3 app/tool/sync_books.py      # books/ → app/assets/data/，并刷新 pubspec.yaml 的 assets 清单
cd app
flutter test
flutter build apk --release --split-per-abi
```

`assets/data/` 是生成目录，不入库；书稿有改动后重新运行 `sync_books.py` 即可。
