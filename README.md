# TaintedView · 不净观修学资料

一个辅助修习不净观的跨平台资料应用：用清晰的分类和舒适的阅读体验，呈现相关的书籍、图片、视频和 3D 骨骼模型。

当前版本：**0.3.0**（Flutter，已在 Android 上测试）

## 已实现的功能

### App（[app/](app/)）

**主界面**：图书、图片、视频、白骨观四个栏目，宽屏下四列排布。

**图书**
- 书架：按分类列出全部 23 本书（983 章，约 228 万字），顶部显示最近在读的一本
- 书籍页：多级目录，开始 / 继续 / 从头阅读
- 阅读页：渲染标题、段落、列表、引用、图片；站内章节链接可跳转；章末自动生成上一章 / 下一章
- 排版设置：主题（跟随系统、白、护眼、夜间）、字号、行距、段距、首行缩进，自动保存
- 阅读进度按「章节 + 段落」保存，下次打开回到原处
- 全部书稿打包在 App 内，离线可读

**朗读**
- 调用系统 TTS，从屏幕上的段落开始朗读，高亮并跟随当前段落，读完一章自动接读下一章
- 底部控制栏：暂停 / 继续、倍速（0.75–2×，自动保存）、停止
- 朗读中轻点任意段落，即从该段读起
- 长段落按句切分（每段不超过 300 字），避开安卓 TTS 的长度限制
- 没装中文语音或合成失败时会给出提示，不会卡在「朗读中」
- 需要手机装有中文语音

**图片 / 视频**
- 自建分类，可新建、重命名、删除
- 分类下可从本地多选文件（复制到应用内保存），或添加 http / https 链接
- 看图可左右滑动、双指缩放；视频用内置播放器播放，链接打不开时可转到浏览器
- 长按条目可重命名、删除

**白骨观**
- 3D 人体骨骼（238 块，来自 BodyParts3D），离线加载
- 单指旋转，双指缩放和平移，轻点骨骼高亮并显示中英文名称

**其他**
- 莲花与剑的新图标，系统桌面上显示为「TaintedView」

### 书稿与工具

| 模块 | 说明 |
|---|---|
| 书稿规整 | 23 本书统一成标准 Markdown，每章一个文件，任何 Markdown 查看器都能直接浏览 |
| 预处理脚本 | [tools/build_books.py](tools/build_books.py)：规整原始书稿，并把 Markdown 转成 App 用的 JSON |
| App 数据同步 | [app/tool/sync_books.py](app/tool/sync_books.py)：`books/` → `app/assets/data/`，同时刷新 `pubspec.yaml` 的资源清单 |
| 骨骼模型生成 | [app/tool/skeleton/](app/tool/skeleton/)：BodyParts3D OBJ → 每块骨头一个网格的 GLB，打包离线查看器 |
| 网页阅读预览 | [tools/preview/index.html](tools/preview/index.html)：书架、目录、翻页、排版设置、朗读，App 阅读器的网页原型 |
| 开发环境文档 | [docs/setup-macos.md](docs/setup-macos.md)：macOS 搭建环境与打 APK |

## 收录书目

全部为简体中文，共 23 本、983 章、约 228 万字。点击书名可直接浏览该书的 Markdown 目录。

| # | 书名 | 分类 | 子分类 | 章数 | 字数 |
|---:|---|---|---|---:|---:|
| 1 | [戒淫断欲圣典汇编](books/佛典戒邪淫/001戒淫断欲圣典汇编/README.md) | 佛典戒邪淫 | 戒邪淫-现代 | 10 | 2.8 万 |
| 2 | [寿康宝鉴](books/戒邪淫书籍/001寿康宝鉴/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 3 | 4.9 万 |
| 3 | [《寿康宝鉴》白话](books/戒邪淫书籍/002寿康宝鉴白话版/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 97 | 17.4 万 |
| 4 | [欲海回狂](books/戒邪淫书籍/003欲海回狂/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 48 | 8.2 万 |
| 5 | [《欲海回狂》白话](books/戒邪淫书籍/004欲海回狂白话版/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 57 | 8.6 万 |
| 6 | [伤精与养精康复之道](books/戒邪淫书籍/005彭鑫博士伤精与养精康复之道/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 56 | 12.8 万 |
| 7 | [彭博士文集](books/戒邪淫书籍/006彭鑫博士文集/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 59 | 11.5 万 |
| 8 | [节欲主义](books/戒邪淫书籍/007节欲主义/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 2 | 2.4 万 |
| 9 | [淫报启示录](books/戒邪淫书籍/008淫报启示录/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 1 | 1.0 万 |
| 10 | [心向光明远离邪淫第二版](books/戒邪淫书籍/009心向光明远离邪淫第二版/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 449 | 97.5 万 |
| 11 | [戒淫修福保命](books/戒邪淫书籍/010戒淫修福保命/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 12 | 4.1 万 |
| 12 | [让生命恢复纯净](books/戒邪淫书籍/011让生命恢复纯净/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 64 | 10.0 万 |
| 13 | [家庭宝筏](books/戒邪淫书籍/012家庭宝筏/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 21 | 4.1 万 |
| 14 | [幸福婚姻经典集要](books/戒邪淫书籍/013幸福婚姻经典集要/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 1 | 2.5 万 |
| 15 | [保富法](books/戒邪淫书籍/014保富法/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 22 | 7.2 万 |
| 16 | [养生保命集](books/戒邪淫书籍/015养生保命集/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 9 | 2.9 万 |
| 17 | [漫谈两性关系](books/戒邪淫书籍/016漫谈两性关系/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 10 | 6.4 万 |
| 18 | [风月场所之恐怖](books/戒邪淫书籍/017风月场所之恐怖/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 10 | 1.3 万 |
| 19 | [孝与戒淫](books/戒邪淫书籍/018孝与戒淫/README.md) | 戒邪淫书籍 | 戒邪淫-现代 | 7 | 5.6 万 |
| 20 | [重写戒淫证辑](books/戒邪淫书籍/019重写戒淫证辑/README.md) | 戒邪淫书籍 | 戒邪淫书籍 | 15 | 2.7 万 |
| 21 | [生死关全集](books/戒邪淫书籍/020生死关全集/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 19 | 10.2 万 |
| 22 | [文昌帝君戒邪淫文](books/戒邪淫书籍/021文昌帝君戒邪淫文/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 5 | 1.7 万 |
| 23 | [关圣帝君戒淫经注解](books/戒邪淫书籍/022关圣帝君戒淫经注解/README.md) | 戒邪淫书籍 | 戒邪淫-相关 | 6 | 1.9 万 |

## 快速开始

### 构建 App

环境搭建见 [docs/setup-macos.md](docs/setup-macos.md)。

```bash
python3 tools/build_books.py        # books/ → 各书的 _app/ JSON
python3 app/tool/sync_books.py      # 同步到 app/assets/data/
cd app
flutter test
flutter build apk --release --split-per-abi
```

更多说明（图标、骨骼模型重新生成）见 [app/README.md](app/README.md)。

### 网页预览

需要 Python 3.10 或更高版本，不依赖第三方库。在项目根目录运行：

```bash
python3 -m http.server 8765
```

然后在浏览器打开 <http://localhost:8765/tools/preview/>。

## 目录结构

```text
TaintedView/
├── app/                      Flutter App
│   ├── lib/                  源码（screens / data / widgets）
│   ├── assets/               图标、骨骼模型；data/ 为生成目录，不入库
│   └── tool/                 sync_books.py、skeleton/ 模型生成脚本
├── books/                    书稿（唯一的内容来源）
│   ├── catalog.json          全部书目（脚本生成）
│   └── <分类>/<书>/
│       ├── README.md         书名、元数据、目录
│       ├── 001-章名.md        每章一个文件
│       ├── images/           书中图片
│       └── _app/             App 用的 JSON（脚本生成，可随时删除重建）
├── books_original/           规整前的原始书稿（一次性备份）
├── tools/
│   ├── build_books.py        书稿预处理脚本
│   └── preview/index.html    网页阅读预览
└── docs/setup-macos.md       macOS 开发环境与打包文档
```

## 书稿格式

每本书是一个目录：

- `README.md`：书名、`> 分类：… | 原文件：…` 元数据，以及 `## 目录` 下带链接的多级列表。
- 每章一个 `NNN-章名.md`，以 `# 章名` 开头。段落之间空一行，段内没有硬换行。
- 图片放在 `images/`，用相对路径引用。
- `README.md` 中的 `<!-- normalized-by: build_books.py -->` 标记表示这本书已经规整过，脚本不会再对它做断行合并等清洗。

### 新增一本书

- **已经是规整格式**：直接放进 `books/<分类>/<书>/`，然后运行 `python3 tools/build_books.py` 和 `python3 app/tool/sync_books.py`。
- **原始格式**（GitBook、CHM、EXE、PDF、DOC 等转出的 Markdown）：先放到临时目录（例如 `inbox/<分类>/<书>/`），然后运行：
  ```bash
  python3 tools/build_books.py --src inbox --out /tmp/check --md-out books
  python3 tools/build_books.py
  ```
  第一条把规整结果写入 `books/`，第二条刷新全部书目。看一下 `/tmp/check/report.md` 里的异常清单，再抽查章节划分是否合理。

> 注意：如果已经手工修改过 `books/`，就不要再从 `books_original/` 整体重新导出，否则手工修改会被覆盖。

### 预处理脚本做了什么

- **目录识别**（按优先级）：`SUMMARY.md` → `README.md` 的 `## 目录` 链接列表 → 单文件书依次尝试 Markdown 标题、正文「目录」段落、「第X章 / 卷X」短行、独占一行的短句，最后按字数切分。目录没引用到的 md 文件按文件名追加到末尾，并记入报告。
- **文本清洗**（只对未规整的书稿执行）：合并 OCR / PDF 造成的硬换行，去掉孤立页码、重复页眉和 CHM 导航残留，HTML 降级为普通段落，去掉段首全角空格，合并逐字加空格的写法；站内章节链接改写为 `chapter:<cid>`。

### App 数据格式

```jsonc
// books/catalog.json
{ "version": 1, "books": [
  { "id": "b31a412a9", "title": "寿康宝鉴", "lang": "zh-Hans", "category": "戒邪淫书籍",
    "subCategory": "…", "chars": 49132, "chapters": 3, "path": "戒邪淫书籍/001寿康宝鉴" } ] }

// <书>/_app/book.json
{ "id": "…", "title": "…", "origin": "原始文件名", "chars": 171349,
  "toc": [ { "title": "第一部分", "chapter": "c004", "children": [ { "title": "第一章", "chapter": "c005" } ] } ],
  "chapters": [ { "id": "c001", "title": "内容简介", "chars": 752, "blocks": 14, "source": "001-内容简介.md" } ] }

// <书>/_app/chapters/c001.json
{ "id": "c001", "title": "内容简介", "blocks": [
  { "id": "p0001", "t": "h", "level": 1, "text": "内容简介" },
  { "id": "p0002", "t": "p", "text": "正文，保留 **粗体** 和 [链接](chapter:c005)" },
  { "id": "p0003", "t": "img", "src": "../images/a.jpg" } ] }
```

- 段落块类型 `t`：`h`（标题）、`p`（段落）、`li`（列表项）、`quote`（引用）、`img`（图片）、`pre`（预格式文本）。
- `bookId` 由书籍的相对路径哈希得到；目录不改名，`bookId` 就不变。
- 每个段落块有固定 id（`c003:p0012`），阅读进度和朗读定位都用它。

## 技术选型

| 方面 | 实现 |
|---|---|
| 框架 | Flutter |
| 阅读器 | 预处理好的 JSON + `scrollable_positioned_list` 懒加载，每个段落块一个富文本 |
| 本地存储 | `shared_preferences`（排版设置、阅读进度、图片 / 视频分类） |
| 朗读 | `flutter_tts`（系统 TTS） |
| 图片 / 视频 | `file_picker`、`video_player` + `chewie` |
| 白骨观 | `webview_flutter` 中的 three.js 离线查看器 |

平台说明：白骨观依赖的 webview_flutter 目前只支持安卓、iOS 和 macOS；系统 TTS 不支持 Linux。

## 后续计划

- 全文搜索、收藏和书签、远程更新书目
- 英文界面与多语言内容
- iOS 和桌面端适配，大屏布局
- 离线神经网络 TTS、修习辅助（计时、引导）

## 开源与授权

代码与文档采用 [Apache License 2.0](LICENSE)。书稿和图片包含第三方作品，其公开发布及再授权范围须以各作品的授权依据为准；授权核实完成前，请勿将这些内容视为已获 Apache 2.0 授权。

骨骼模型来自 [BodyParts3D](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html)："BodyParts3D, © The Database Center for Life Science licensed under CC Attribution 4.0 International"。
