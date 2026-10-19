# 不净观 App（TaintedView 0.3.0）

Flutter 阅读器，读取 `../books/` 生成的书稿数据，离线阅读。

- 主界面：图书、图片、视频、白骨观四个栏目
- 图片 / 视频：自建分类，分类下可从本地选择文件（复制到应用内保存）或添加 http / https 链接；看图可左右滑动、双指缩放，视频用内置播放器播放；长按条目可重命名、删除
- 白骨观：3D 人体骨骼（238 块），单指旋转、双指缩放和平移，轻点骨骼显示中英文名称
- 书架：按分类列出全部书籍，顶部显示最近在读的一本
- 书籍页：多级目录，开始 / 继续阅读
- 阅读页：段落块渲染（标题、段落、列表、引用、图片），站内章节链接，章末上一章 / 下一章
- 朗读：调用系统 TTS 从当前段落开始朗读，高亮并跟随当前段落，自动接读下一章；可暂停、调倍速（0.75–2×），朗读中轻点某段即从该段读起。需要手机装有中文语音
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

应用图标源文件在 `assets/icon/`，改动后运行 `dart run flutter_launcher_icons` 重新生成各平台图标。

## 白骨观骨骼模型

`assets/skeleton/` 已入库，平时无需重新生成。模型来自 [BodyParts3D](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html)
（"BodyParts3D, © The Database Center for Life Science licensed under CC Attribution 4.0 International"），
每块骨头一个网格，节点名为 FMA 编号，`bones.json` 存中英文骨名。重新生成：

```bash
# 先下载 partof_BP3D_4.0_obj_99.zip（约 65 MB）和 partof_element_parts.txt 到 <bp3d>，解压 zip 到同一目录
python3 app/tool/skeleton/build_skeleton.py <bp3d> <tmp>
cd app/tool/skeleton && npm install && node build.mjs <tmp>
```

查看器是 WebView 里的 three.js（`tool/skeleton/src/`），webview_flutter 目前只支持安卓、iOS 和 macOS。
