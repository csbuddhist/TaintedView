# TaintedView · 不净观修学资料

一个辅助修习不净观的跨平台资料应用：用清晰的分类和舒适的阅读体验，呈现相关的书籍、图片、视频和应用。

- **目标平台**：Android、iOS、Windows、macOS、Linux
- **多语言**：中文、English（界面和内容均支持）
- **原始需求**：[requirement/prd.md](requirement/prd.md)

## 开源范围

项目计划将代码、文档、书稿和图片一并开源。代码与文档采用 [Apache License 2.0](LICENSE)；书稿和图片包含第三方作品，其公开发布及再授权范围须以各作品的授权依据为准。授权核实完成前，请勿将这些内容视为已获 Apache 2.0 授权。

## 当前进度

| 模块 | 状态 | 说明 |
|---|---|---|
| 书稿规整 | ✅ 完成 | 24 本书，1001 章，约 245 万字，统一成标准 Markdown |
| 书稿预处理脚本 | ✅ 完成 | [tools/build_books.py](tools/build_books.py)：Markdown → App 用的 JSON |
| 本地阅读预览页 | ✅ 完成 | [tools/preview/index.html](tools/preview/index.html)：目录、翻页、排版设置、朗读 |
| 开发环境文档 | ✅ 完成 | [docs/setup-macos.md](docs/setup-macos.md)：macOS 搭建环境与打 APK |
| 0.1 安卓 App | ⏳ 待开发 | Flutter，计划放在 `app/` 目录 |

## 目录结构

```text
TaintedView/
├── requirement/prd.md        原始需求
├── books/                    书稿（唯一的内容来源）
│   ├── catalog.json          全部书目（脚本生成）
│   ├── build_report.md       预处理报告（脚本生成）
│   └── <分类>/<书>/
│       ├── README.md         书名、元数据、目录
│       ├── 001-章名.md        每章一个文件
│       ├── images/           书中图片
│       └── _app/             App 用的 JSON（脚本生成，可随时删除重建）
├── books_original/           规整前的原始书稿（一次性备份）
├── tools/
│   ├── build_books.py        书稿预处理脚本
│   └── preview/index.html    本地阅读预览页
├── docs/setup-macos.md       macOS 开发环境与打包文档
└── .claude/launch.json       预览服务器启动配置
```

`books/` 是规整后的书稿，`books_original/` 是原始备份。两者的公开发布需先完成第三方授权核实。

## 快速开始

需要 Python 3.10 或更高版本，不依赖第三方库。

```bash
# 1. 由 books/ 生成 App 数据（书目、目录树、章节 JSON）
python tools/build_books.py

# 2. 在项目根目录启动本地服务器
python -m http.server 8765
```

然后在浏览器打开 <http://localhost:8765/tools/preview/>。

---

## 功能与特性

### 1. 书稿格式（books/）

每本书是一个目录，任何 Markdown 查看器（VS Code、Typora、Obsidian、GitHub）都能直接浏览：

- `README.md`：书名、`> 分类：… | 原文件：…` 元数据，以及 `## 目录` 下带链接的多级列表。
- 每章一个 `NNN-章名.md`，以 `# 章名` 开头。段落之间空一行，段内没有硬换行。
- 图片放在 `images/`，用相对路径引用。
- `README.md` 中的 `<!-- normalized-by: build_books.py -->` 标记表示这本书已经规整过，脚本不会再对它做断行合并等清洗。

### 2. 书稿预处理（tools/build_books.py）

**两个用途**

1. **规整原始书稿**：把来自 GitBook、CHM、EXE、PDF、DOC 等不同来源的 Markdown，统一成上面的格式（`--md-out`）。
2. **生成 App 数据**：输出结构化 JSON，App 和预览页直接加载，不用在运行时解析 Markdown。

**目录识别**（按优先级）
1. `SUMMARY.md`（GitBook 格式）
2. `README.md` 里的 `## 目录` 链接列表（支持多级和不带链接的分组节点）
3. 只有一个 README 的单文件书，依次尝试：
   - Markdown 标题
   - 正文里的「目录」段落，与正文中的标题逐条匹配，忽略「（五则）」这类括注
   - 「第X章 / 卷X」样式的短行
   - 独占一行的短句
   - 都不行时按字数切分

目录没有引用到的 md 文件，会按文件名顺序追加到末尾，并记入报告。

**文本清洗**（只对未规整的书稿执行）
- 合并 OCR 和 PDF 造成的硬换行：中文之间直接拼接，西文之间补一个空格；短标题不会被并进上一段。
- 去掉孤立页码，以及反复出现的 PDF 页眉。
- 去掉 CHM 残留的「封面 | 目录 | 上一页 | 下一页」导航文字，修复被拆开的「带链接图片」。
- 把 HTML（`<p>`、`<br>`、`<table>`）降级为普通段落；去掉段首全角空格（缩进交给阅读器控制）。
- 合并「关 于 本 书」这类逐字加空格的写法，去掉缺失的图片和与标题重复的段落。
- 站内章节链接改写为 `chapter:<cid>`，外部链接保留。

**命令**

```bash
python tools/build_books.py                                    # 默认：JSON 写入各书的 _app/
python tools/build_books.py --out DIR                          # JSON 和图片集中输出到 DIR
python tools/build_books.py --src RAW --out TMP --md-out books # 把原始书稿规整后写入 books/
```

**输出数据格式**

```jsonc
// books/catalog.json
{ "version": 1, "books": [
  { "id": "b49c70f01", "title": "跳出色情陷阱", "lang": "zh-Hans", "category": "戒邪淫书籍",
    "subCategory": "…", "chars": 171349, "chapters": 18, "path": "戒邪淫书籍/000跳出色情陷阱" } ] }

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
- `bookId` 由书籍的相对路径哈希得到；只要目录不改名，`bookId` 就不变。
- 每个段落块有固定 id（`c003:p0012`），阅读进度、书签和朗读定位都用它。
- `img.src` 是相对 `book.json` 所在目录的路径。

**新增一本书**

- **已经是规整格式**：直接放进 `books/<分类>/<书>/`，然后运行 `python tools/build_books.py`。
- **原始格式**：先放到一个临时目录（例如 `inbox/<分类>/<书>/`），然后运行：
  ```bash
  python tools/build_books.py --src inbox --out /tmp/check --md-out books
  python tools/build_books.py
  ```
  第一条命令把规整结果写入 `books/`，第二条刷新全部书目。看一下 `/tmp/check/report.md` 里的异常清单，再抽查章节划分是否合理。

> 注意：如果已经手工修改过 `books/`，就不要再从 `books_original/` 整体重新导出，否则手工修改会被覆盖。

### 3. 本地阅读预览页（tools/preview/）

一个单独的 HTML 文件，只读取 `books/catalog.json` 和 `_app/` 里的 JSON，也是 App 阅读器的网页原型。

- **书架**：按分类显示全部书籍，标出章数、字数，以及上次读到的章节。
- **目录**：多级目录，当前章高亮；窄屏下变成抽屉式。
- **自动翻页**：根据 `book.json` 的章节顺序，在章末生成「上一章 / 下一章」按钮，键盘 ← → 也能翻章。md 文件里不写任何翻页链接。
- **排版设置**：
  - 字体：宋体、霞鹜文楷、楷体、黑体
  - 主题：跟随系统、白、护眼、夜间
  - 可调：字号、行距、段距、字距、首行缩进、版心宽度
- **朗读**（Web Speech API）：
  - 读到哪段就高亮哪段，并自动滚动
  - 可调语速、选择中文音色
  - 点击任意段落从那里开始读，读完一章自动进入下一章
  - 长段落按句切分，避免浏览器中途停止朗读
- **记忆**：阅读设置和每本书的阅读进度保存在浏览器本地。
- 站内章节链接可以跳转；页面每次都读取最新数据，重跑脚本后刷新即可。

---

## 技术架构（App）

| 方面 | 选型 | 理由 |
|---|---|---|
| 跨平台框架 | **Flutter** | 一套代码覆盖 5 个平台，官方支持 Linux 桌面 |
| 状态管理 / 路由 | Riverpod / go_router | |
| 阅读器 | 加载预处理后的 JSON + `ListView.builder` 懒加载，每个段落块一个 `Text.rich` | 单章十几万字也不卡；排版参数实时可调；方便按段落定位和高亮 |
| 本地存储 | drift（SQLite，含 FTS5 全文检索） | 收藏、阅读进度、书签、搜索 |
| 朗读 | 0.1 用 `flutter_tts`（系统 TTS）；后续用 `sherpa-onnx` 离线语音 | 系统 TTS 不支持 Linux；离线模型可以让各平台音色一致 |
| 后台播放 | `audio_service` | 锁屏控制、定时停止 |
| 字体 | 霞鹜文楷、思源宋体（OFL 协议，免费商用） | 内置一款，其余按需下载 |
| 多语言 | 界面用 gen-l10n（ARB 文件）；内容用多语言字段 `{zh, en}` | |
| 视频 / PDF | media_kit / pdfrx | 都支持 5 个平台 |

**没选的方案**：flutter_markdown 一次性构建整棵控件树，大章节会卡，而且官方已停止维护。WebView 方案在 Flutter 下不支持 Linux。

**内容分发**：0.1 版把 `books/` 里的 `_app/` JSON 和图片打包进 App（`.md` 源文件不打包）。后续改为把带版本号的 `catalog.json` 放到国内 CDN（OSS 或 COS），App 增量更新。

**其他需要考虑的点**
- **敏感图像**：部分不净观资料可能包含解剖、尸体类图片。默认模糊显示，点开前提示，设置里可关闭；应用商店分级要如实填写。
- **版权**：每条内容记录来源和授权信息。
- **国内分发**：0.1 版直接分发 APK，之后再上国内应用商店。

## 路线图

- **0.1 · Android**：书架、分类、目录、章节阅读（排版设置、主题）、自动翻页、阅读进度、系统 TTS 朗读、中英文界面
- **0.2**：全文搜索、收藏和书签、离线下载、远程更新书目、图片和视频资料
- **0.3**：iOS 和桌面三端，大屏自适应布局（侧边栏 + 内容区）
- **0.4 以后**：内容管理后台、更多语言、离线神经网络 TTS、修习辅助功能（计时、引导）

## 开发环境

- macOS（推荐，能编译 Android、iOS、macOS）：[docs/setup-macos.md](docs/setup-macos.md)
- 只打 APK 大约需要 6–9 GB 空间；以后做 iOS 和 macOS 版还需要 Xcode（15–40 GB）
- Windows 和 Linux 版计划用 GitHub Actions 在云端自动打包
