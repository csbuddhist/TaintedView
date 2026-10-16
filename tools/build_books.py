#!/usr/bin/env python3
"""把 books/ 下的 Markdown 书稿预处理成 App 可直接加载的结构化 JSON。

用法:
    python tools/build_books.py                 # 默认：JSON 写入每本书目录下的 _app/
    python tools/build_books.py --out DIR       # JSON 与图片集中输出到 DIR/books/<bookId>/
    python tools/build_books.py --md-out DIR    # 另外导出规整后的 Markdown 书稿

默认输出（books/ 即唯一书稿来源，_app/ 可随时删除重建）:
    books/catalog.json                       全部书目（path 为书籍目录）
    books/build_report.md                    处理统计与异常清单
    books/<分类>/<书>/_app/book.json          书籍元数据 + 统一目录树 + 章节清单
    books/<分类>/<书>/_app/chapters/<cid>.json  章节段落块
    img 的 src 一律相对 book.json 所在目录。

书籍识别规则（按优先级）:
    1. 有 SUMMARY.md            -> GitBook 目录
    2. README.md 含「## 目录」链接 -> README 目录
    3. 只有 README.md 单文件     -> 按 Markdown 标题 / 正文内「目录」/ 字数 切章
    目录未引用的 md 文件按文件名排序追加到末尾，并记入报告。

段落块: {"id": "p0001", "t": "h|p|li|quote|img|pre", "text": "...", "level": 2, "src": "..."}
    text 保留 **粗体** 与 [链接](...)；站内章节链接改写为 chapter:<cid>。
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote, unquote

# ---------------------------------------------------------------- 常量与正则

TERMINAL = set("。！？!?；;：:…”」』）)】》—～~\"'’")
CJK = r"㐀-䶿一-鿿豈-﫿"
RE_CJK_CHAR = re.compile(f"[{CJK}]")
RE_HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
RE_LIST = re.compile(r"^(\s*)[-*+]\s+(.*)$")
RE_OLIST = re.compile(r"^\s*\d+[.)]\s+")
RE_IMG = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
RE_LINK = re.compile(r"(?<!!)\[([^\]]+)\]\(([^)\s]+)\)")
RE_TOC_LINK = re.compile(r"^\[(.+)\]\(([^)]+)\)\s*$")
RE_PAGENUM = re.compile(r"^(?:[-—－\s]*\d{1,4}[-—－\s]*|第\s*\d{1,4}\s*页|\d{1,4}\s*/\s*\d{1,4})$")
RE_META = re.compile(r"^>\s*分类：(.*?)\s*[|｜]\s*原文件：`?([^`]*)`?\s*$")
RE_CHAPTER = re.compile(r"^(?:第[一二三四五六七八九十百零〇\d]+[章篇卷回部]|卷[一二三四五六七八九十]+)")
RE_LINKED_IMG = re.compile(r"\[(!\[[^\]]*\]\([^)\s]+\))\]\([^)\s]+\)")
RE_CHM_NAV = re.compile(r"封[\s　]*面[\s　]*\|[\s　]*目[\s　]*录(?:[\s　]*\|[\s　]*[上下]一页)*")
RE_HTML_HINT = re.compile(r"<(?:p|br|table|tr|td|tbody|span|div)\b", re.I)
RE_LEADING_WS = re.compile(r"^[\s　]+")
INDENT_START = re.compile(r"^(?:　|\s{2,})")

PDF_MERGE_MIN_LEN = 12        # 不以句末标点结尾、且长度≥此值的段落视为被 PDF 断行
SHORT_TITLE_LEN = 16          # 不超过此长度、不以标点结尾的独立短行视为标题
FALLBACK_CHUNK_CHARS = 20000  # 无法识别章节时按字数切分
NORMALIZED_MARK = "<!-- normalized-by: build_books.py -->"  # 规整后的书稿不再做断行合并等清洗


# ---------------------------------------------------------------- 数据结构

@dataclass
class Block:
    t: str
    text: str = ""
    level: int | None = None
    src: str | None = None
    indented: bool = False    # 原文行首有缩进，说明是作者有意分段

    def to_json(self, bid: str) -> dict:
        d = {"id": bid, "t": self.t}
        if self.text:
            d["text"] = self.text
        if self.level is not None:
            d["level"] = self.level
        if self.src is not None:
            d["src"] = self.src
        return d


@dataclass
class TocNode:
    title: str
    href: str | None = None
    children: list["TocNode"] = field(default_factory=list)
    chapter: str | None = None


@dataclass
class Chapter:
    cid: str
    title: str
    source: Path
    blocks: list[Block] = field(default_factory=list)


@dataclass
class Stats:
    mode: str = ""
    pdf_merges: int = 0
    page_numbers: int = 0
    page_headers: int = 0
    issues: list[str] = field(default_factory=list)

    def issue(self, msg: str) -> None:
        self.issues.append(msg)


# ---------------------------------------------------------------- 文本规整

def is_cjk(ch: str) -> bool:
    return bool(RE_CJK_CHAR.match(ch)) or ch in "，。！？；：、“”‘’（）《》「」『』【】…—"


def join_lines(lines: list[str]) -> str:
    """合并段内软换行：中文之间直接拼接，西文之间补一个空格。"""
    out = ""
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if out and not (is_cjk(out[-1]) or is_cjk(line[0])):
            out += " "
        out += line
    return out


def tidy(text: str) -> str:
    text = text.replace(" ", " ")
    text = RE_LEADING_WS.sub("", text).rstrip()
    # 「关 于 本 书」这种逐字加空格的写法 -> 「关于本书」
    if re.fullmatch(rf"(?:[{CJK}] )+[{CJK}]", text):
        return text.replace(" ", "")
    text = re.sub(r"[ \t　]{2,}", " ", text)
    # 中文之间孤立的空格（OCR 残留）
    text = re.sub(rf"(?<=[{CJK}，。！？；：、]) (?=[{CJK}，。！？；：、])", "", text)
    return text


def html_to_markdownish(text: str) -> str:
    """少量书稿是 doc 转出的 HTML 表格/段落，降级为纯文本段落。"""
    text = re.sub(r"<br\s*/?>\s*", "\n", text, flags=re.I)
    text = re.sub(r"</(?:p|tr|td|div|li|h\d)>", "\n\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    return html.unescape(text)


def plain_len(text: str) -> int:
    text = RE_LINK.sub(r"\1", text)
    return len(re.sub(r"[*\s　]", "", text))


# ---------------------------------------------------------------- Markdown 块解析

def parse_blocks(md: str, stats: Stats, clean: bool = True) -> list[Block]:
    if RE_HTML_HINT.search(md):
        md = html_to_markdownish(md)
    if clean:
        md = RE_LINKED_IMG.sub(r"\1", md)          # [![](a.jpg)](http://…) -> ![](a.jpg)
        md = RE_CHM_NAV.sub("", md)                # 「封　面 | 目　录 | 上一页 | 下一页」导航残留
    lines = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")

    blocks: list[Block] = []
    para: list[str] = []
    para_indented = False

    def flush():
        nonlocal para, para_indented
        if para:
            text = tidy(join_lines(para))
            if text:
                blocks.append(Block("p", text, indented=para_indented))
            para, para_indented = [], False

    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("```"):
            flush()
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            blocks.append(Block("pre", "\n".join(code)))
            i += 1
            continue
        if not stripped:
            flush()
        elif m := RE_HEADING.match(stripped):
            flush()
            blocks.append(Block("h", tidy(m.group(2)), level=len(m.group(1))))
        elif re.fullmatch(r"(?:[-*_]\s*){3,}", stripped):
            flush()
        elif stripped.startswith(">"):
            flush()
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:])
                i += 1
            text = tidy(join_lines(quote))
            if text:
                blocks.append(Block("quote", text))
            continue
        elif m := RE_LIST.match(line):
            flush()
            blocks.append(Block("li", tidy(m.group(2))))
        elif INDENT_START.match(raw) and para:
            # 段内出现行首缩进 = 新段落（如「　　」开头的古籍排版）
            flush()
            para, para_indented = [line], True
        else:
            if not para:
                para_indented = bool(INDENT_START.match(raw))
            para.append(line)
        i += 1
    flush()

    # 去掉孤立页码，以及反复出现的短行（PDF 页眉，如「《风月场之恐怖》寿康学会整理版」）
    counts: dict[str, int] = {}
    for b in blocks:
        if b.t == "p" and 10 <= plain_len(b.text) <= 30:
            counts[b.text] = counts.get(b.text, 0) + 1
    kept = []
    for b in blocks:
        if clean and b.t == "p" and RE_PAGENUM.fullmatch(b.text):
            stats.page_numbers += 1
            continue
        if clean and b.t == "p" and counts.get(b.text, 0) >= 3 and looks_like_title(b):
            stats.page_headers += 1
            continue
        kept.append(b)
    return split_images(kept)


def split_images(blocks: list[Block]) -> list[Block]:
    """段落中的图片拆成独立 img 块。"""
    out = []
    for b in blocks:
        if b.t not in ("p", "li") or "![" not in b.text:
            out.append(b)
            continue
        pos = 0
        for m in RE_IMG.finditer(b.text):
            before = b.text[pos:m.start()].strip()
            if before:
                out.append(Block(b.t, before, indented=b.indented))
            out.append(Block("img", m.group(1).strip(), src=m.group(2)))
            pos = m.end()
        rest = b.text[pos:].strip()
        if rest:
            out.append(Block(b.t, rest))
    return out


def merge_pdf_lines(blocks: list[Block], stats: Stats) -> list[Block]:
    """PDF 抽取的文本每行成段：上一段未以句末标点结尾、下一段非缩进中文开头时拼接。"""
    out: list[Block] = []
    for b in blocks:
        prev = out[-1] if out else None
        if (
            prev is not None
            and prev.t == "p" and b.t == "p"
            and not b.indented
            and prev.text[-1] not in TERMINAL
            and plain_len(prev.text) >= PDF_MERGE_MIN_LEN
            and is_cjk(b.text[0])
            and not looks_like_title(b)
        ):
            prev.text += b.text
            stats.pdf_merges += 1
            continue
        out.append(b)
    return out


def looks_like_title(b: Block) -> bool:
    """PDF 版式里独占一行、很短且不以标点结尾的段落，多半是标题。"""
    return b.t == "p" and plain_len(b.text) <= SHORT_TITLE_LEN and b.text[-1] not in TERMINAL \
        and "，" not in b.text


def drop_noise(blocks: list[Block]) -> list[Block]:
    """去掉缺图的 img 块，以及紧跟在标题后、与标题同名的重复段落。"""
    out: list[Block] = []
    last_h = None
    for b in blocks:
        if b.t == "img" and not b.src:
            continue
        if b.t == "p" and last_h is not None and norm_title(b.text) == norm_title(last_h.text):
            continue
        last_h = b if b.t == "h" else (last_h if b.t == "img" else None)
        out.append(b)
    return out


def title_key(s: str) -> str:
    """目录条目与正文标题匹配用：再去掉「（五则）」之类的括注。"""
    return re.sub(r"[（(][^（()）]*[)）]$", "", norm_title(s))


def norm_title(s: str) -> str:
    s = RE_LINK.sub(r"\1", s)
    s = re.sub(r"[●○◎■□◆◇★☆·•\s　*#]", "", s)
    s = re.sub(r"[.…·．]{2,}\s*\d*$", "", s)   # 目录行尾的「……12」
    s = re.sub(r"\d+$", "", s)
    return s


# ---------------------------------------------------------------- 目录解析

def parse_toc_list(lines: list[str]) -> list[TocNode]:
    roots: list[TocNode] = []
    stack: list[tuple[int, TocNode]] = []
    for line in lines:
        m = RE_LIST.match(line.replace("\t", "    "))
        if not m:
            continue
        indent, body = len(m.group(1)), m.group(2).strip()
        lm = RE_TOC_LINK.match(body)
        node = TocNode(tidy(lm.group(1)), unquote(lm.group(2))) if lm else TocNode(tidy(body))
        while stack and stack[-1][0] >= indent:
            stack.pop()
        (stack[-1][1].children if stack else roots).append(node)
        stack.append((indent, node))
    return roots


def readme_parts(text: str) -> tuple[str | None, dict, list[str] | None, str]:
    """拆出 README 的标题、元数据、目录列表行、剩余正文。"""
    lines = text.replace("\r\n", "\n").split("\n")
    title, meta, toc, body = None, {}, None, []
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        if title is None and (m := RE_HEADING.match(s)) and len(m.group(1)) == 1:
            title = tidy(m.group(2))
        elif not meta.get("origin") and (m := RE_META.match(s)):
            meta |= {"category": m.group(1).strip(), "origin": m.group(2).strip()}
        elif s == NORMALIZED_MARK:
            meta["normalized"] = True
        elif toc is None and re.fullmatch(r"#{2,3}\s*目\s*录\s*", s):
            toc = []
            i += 1
            while i < len(lines) and not RE_HEADING.match(lines[i].strip()):
                toc.append(lines[i])
                i += 1
            continue
        else:
            body.append(lines[i])
        i += 1
    return title, meta, toc, "\n".join(body)


# ---------------------------------------------------------------- 单文件书切章

def split_single(blocks: list[Block], title: str, stats: Stats) -> list[tuple[str, list[Block]]]:
    # a. Markdown 标题
    levels = {}
    for b in blocks:
        if b.t == "h" and b.level and b.level > 1:
            levels[b.level] = levels.get(b.level, 0) + 1
    for lv in sorted(levels):
        if levels[lv] >= 3:
            stats.mode = f"单文件·按 H{lv} 切章"
            return cut_at(blocks, lambda b: b.t == "h" and b.level == lv, title)

    # b. 正文里的「目录」段落 + 后续短行为条目，再在正文中按顺序找到同名段落
    for ti, b in enumerate(blocks):
        nt = norm_title(b.text) if b.t == "p" else ""
        if nt.endswith("目录") and len(nt) <= 12:
            entries, j = [], ti + 1
            while j < len(blocks) and blocks[j].t in ("p", "li") and plain_len(blocks[j].text) <= 40 \
                    and not blocks[j].text.endswith("。"):
                entries.append(title_key(blocks[j].text))
                j += 1
            entries = [e for e in entries if e]
            marks, k = set(), j
            for e in entries:
                for idx in range(k, len(blocks)):
                    if blocks[idx].t == "p" and title_key(blocks[idx].text) == e:
                        marks.add(idx)
                        k = idx + 1
                        break
            if len(marks) >= 3:
                stats.mode = f"单文件·按正文目录切章（{len(marks)}/{len(entries)} 条命中）"
                if len(marks) < len(entries) * 0.6:
                    stats.issue(f"正文目录只命中 {len(marks)}/{len(entries)} 条，请人工核对章节划分")
                body = blocks[:ti] + blocks[j:]
                shift = j - ti
                marks = {m - shift for m in marks}
                for m in marks:
                    body[m] = Block("h", body[m].text, level=2)
                return cut_at(body, lambda b, _ids={id(body[m]) for m in marks}: id(b) in _ids, title)
            break

    # PDF/doc 版式：独占一行的短句当标题（连续多行短句只取第一行，其余多为作者署名）
    marks = []
    for idx, b in enumerate(blocks):
        if idx and looks_like_title(b) and plain_len(b.text) >= 2 \
                and not (marks and marks[-1] == idx - 1) \
                and idx + 1 < len(blocks) and blocks[idx + 1].t == "p":
            marks.append(idx)
    body = list(blocks)
    for m in marks:
        body[m] = Block("h", body[m].text, level=3)
    heads = {id(body[m]) for m in marks}

    # c. 短行标题中有 ≥3 个「第X章 / 卷X」，只在这些位置切章，其余短行作为章内小标题
    chap = [m for m in marks if RE_CHAPTER.match(norm_title(body[m].text))]
    if len(chap) >= 3:
        stats.mode = f"单文件·按「第X章」切章（{len(chap)} 处）"
        stats.issue(f"按「第X章」样式推断出 {len(chap)} 个章节，请抽查")
        for m in chap:
            body[m].level = 2
        return cut_at(body, lambda b, _ids={id(body[m]) for m in chap}: id(b) in _ids, title)

    # d. 短行标题数量适中（平均每章 ≥800 字）时全部作为章节
    total = sum(plain_len(b.text) for b in blocks)
    if len(marks) >= 3 and total / (len(marks) + 1) >= 800:
        stats.mode = f"单文件·按短行标题切章（{len(marks)} 处）"
        stats.issue(f"按独立短行推断出 {len(marks)} 个章节标题，请抽查是否准确")
        for m in marks:
            body[m].level = 2
        return cut_at(body, lambda b: id(b) in heads, title)

    # e. 按字数切，尽量切在小标题处，并用该小标题命名
    stats.mode = "单文件·按字数切分"
    stats.issue("未识别出可靠的章节标题，已按字数切分" + ("（切在小标题处）" if marks else "，建议人工补充标题"))
    chunks, cur, n = [], [], 0
    for b in body:
        if n >= FALLBACK_CHUNK_CHARS and (id(b) in heads or (not marks and b.t == "p")):
            chunks.append(cur)
            cur, n = [], 0
        cur.append(b)
        n += plain_len(b.text)
    if cur:
        chunks.append(cur)
    if len(chunks) == 1:
        return [(title, chunks[0])]
    return [(c[0].text if id(c[0]) in heads else f"第{i + 1}部分", c) for i, c in enumerate(chunks)]


def cut_at(blocks, is_head, title) -> list[tuple[str, list[Block]]]:
    parts: list[tuple[str, list[Block]]] = []
    cur_title, cur = "开篇", []
    for b in blocks:
        if is_head(b):
            if any(x.t != "h" for x in cur):
                parts.append((cur_title, cur))
            cur_title, cur = RE_LINK.sub(r"\1", b.text), [b]
        else:
            cur.append(b)
    if cur:
        parts.append((cur_title, cur))
    return parts


# ---------------------------------------------------------------- 单本书处理

class BookBuilder:
    def __init__(self, book_dir: Path, category: str, src_root: Path, out_root: Path | None):
        self.dir = book_dir
        self.category = category
        self.rel = book_dir.relative_to(src_root).as_posix()
        self.id = "b" + hashlib.sha1(self.rel.encode("utf-8")).hexdigest()[:8]
        self.inplace = out_root is None
        self.out = book_dir / "_app" if self.inplace else out_root / "books" / self.id
        self.stats = Stats()
        self.chapters: list[Chapter] = []
        self.by_file: dict[Path, Chapter] = {}
        self.images: dict[Path, str] = {}

    def new_chapter(self, title: str, source: Path) -> Chapter:
        ch = Chapter(f"c{len(self.chapters) + 1:03d}", title, source)
        self.chapters.append(ch)
        return ch

    def read(self, p: Path) -> str:
        return p.read_text(encoding="utf-8-sig", errors="replace")

    def build(self) -> dict:
        md_files = sorted(p for p in self.dir.rglob("*.md"))
        readme = self.dir / "README.md"
        summary = self.dir / "SUMMARY.md"
        title, meta, toc_lines, readme_body = (None, {}, None, "")
        if readme.exists():
            title, meta, toc_lines, readme_body = readme_parts(self.read(readme))

        toc: list[TocNode] = []
        if summary.exists():
            self.stats.mode = "SUMMARY.md 目录"
            s_title, _, _, s_body = readme_parts(self.read(summary))
            title = title or s_title
            toc = parse_toc_list(s_body.split("\n"))
            content_files = [p for p in md_files if p != summary]
        elif toc_lines is not None and any(RE_TOC_LINK.match(RE_LIST.match(l).group(2).strip())
                                           for l in toc_lines if RE_LIST.match(l)):
            self.stats.mode = "README 目录"
            toc = parse_toc_list(toc_lines)
            content_files = [p for p in md_files if p != readme]
            if plain_len(readme_body) > 50:
                intro = self.new_chapter("简介", readme)
                self.by_file[readme.resolve()] = intro
                toc.insert(0, TocNode("简介", chapter=intro.cid))
        else:
            content_files = [p for p in md_files if p != readme]

        title = title or re.sub(r"^\d+", "", self.dir.name) or self.dir.name

        if not content_files and readme.exists():
            # 单文件书
            blocks = parse_blocks(readme_body, self.stats)
            for ctitle, cblocks in split_single(blocks, title, self.stats):
                ch = self.new_chapter(ctitle, readme)
                ch.blocks = cblocks
                toc.append(TocNode(ctitle, chapter=ch.cid))
        else:
            toc = self.resolve_toc(toc, content_files)

        normalized = meta.get("normalized", False)
        for ch in self.chapters:
            if not ch.blocks:
                ch.blocks = parse_blocks(self.chapter_source(ch), self.stats, clean=not normalized)
            if not normalized:
                ch.blocks = merge_pdf_lines(ch.blocks, self.stats)
            if not ch.blocks:
                self.stats.issue(f"章节为空：{ch.title}（{ch.source.name}）")

        for ch in self.chapters:
            for b in ch.blocks:
                self.rewrite_refs(b, ch)
            ch.blocks = drop_noise(ch.blocks)
            # 每章以标题开头：首段就是章名时升为标题，否则补一个
            if not ch.blocks or ch.blocks[0].t != "h":
                if ch.blocks and ch.blocks[0].t == "p" and norm_title(ch.blocks[0].text) == norm_title(ch.title):
                    ch.blocks[0] = Block("h", ch.blocks[0].text, level=1)
                else:
                    ch.blocks.insert(0, Block("h", ch.title, level=1))
        self.title, self.meta, self.toc = title, meta, toc
        return self.write(title, meta, toc)

    def chapter_source(self, ch: Chapter) -> str:
        if ch.source.name == "README.md":
            _, _, _, body = readme_parts(self.read(ch.source))
            return body
        return self.read(ch.source)

    def resolve_toc(self, toc: list[TocNode], files: list[Path]) -> list[TocNode]:
        def visit(nodes: list[TocNode]) -> list[TocNode]:
            kept = []
            for n in nodes:
                if n.href and not n.href.startswith(("http:", "https:")):
                    target = (self.dir / n.href.split("#")[0]).resolve()
                    if target.suffix.lower() == ".md" and target.exists():
                        ch = self.by_file.get(target)
                        if ch is None:
                            ch = self.new_chapter(n.title, target)
                            self.by_file[target] = ch
                        n.chapter = ch.cid
                    else:
                        self.stats.issue(f"目录链接指向不存在的文件：{n.title} -> {n.href}")
                n.children = visit(n.children)   # 先登记父节点，保证章节顺序与目录一致
                if n.chapter or n.children:
                    kept.append(n)
                elif not n.href:
                    self.stats.issue(f"目录条目无链接且无子项，已忽略：{n.title}")
            return kept

        toc = visit(toc)
        orphans = [p for p in files if p.resolve() not in self.by_file]
        if orphans:
            self.stats.issue(f"{len(orphans)} 个文件未列入目录，已按文件名追加："
                             + "、".join(p.name for p in orphans[:5]) + ("…" if len(orphans) > 5 else ""))
            for p in orphans:
                head = next((b.text for b in parse_blocks(self.read(p), Stats()) if b.t == "h"), None)
                ch = self.new_chapter(head or re.sub(r"^\d+[-_ ]*", "", p.stem), p)
                self.by_file[p.resolve()] = ch
                toc.append(TocNode(ch.title, chapter=ch.cid))
        return toc

    def rewrite_refs(self, b: Block, ch: Chapter) -> None:
        base = ch.source.parent
        if b.t == "img":
            b.src = self.asset(base, b.src)
            return

        def repl(m: re.Match) -> str:
            text, href = m.group(1), unquote(m.group(2))
            if href.startswith(("http:", "https:", "mailto:", "chapter:")):
                return m.group(0)
            path, _, _anchor = href.partition("#")
            if not path:
                return text
            target = (base / path).resolve()
            if target.suffix.lower() == ".md":
                if (c := self.by_file.get(target)) is not None:
                    return f"[{text}](chapter:{c.cid})"
                self.stats.issue(f"站内链接无法解析，已转为纯文本：{text} -> {href}（{ch.source.name}）")
                return text
            if (asset := self.asset(base, href)) is not None:
                return f"[{text}]({asset})"
            return text

        if b.text:
            b.text = RE_LINK.sub(repl, b.text)

    def asset(self, base: Path, href: str | None) -> str | None:
        if not href:
            return None
        if href.startswith(("http:", "https:")):
            return href
        src = (base / unquote(href)).resolve()
        if not src.exists():
            self.stats.issue(f"图片缺失：{href}")
            return None
        if src not in self.images:
            name = src.name
            if name in self.images.values():
                name = hashlib.sha1(str(src).encode()).hexdigest()[:6] + "_" + name
            self.images[src] = name
        if self.inplace:
            return "../" + src.relative_to(self.dir).as_posix()
        return f"images/{self.images[src]}"

    def write(self, title: str, meta: dict, toc: list[TocNode]) -> dict:
        if self.out.exists():
            shutil.rmtree(self.out)
        (self.out / "chapters").mkdir(parents=True)

        chapter_meta = []
        total_chars = 0
        for ch in self.chapters:
            blocks = [b.to_json(f"p{i + 1:04d}") for i, b in enumerate(ch.blocks)]
            chars = sum(plain_len(b.text) for b in ch.blocks if b.t != "img")
            total_chars += chars
            chapter_meta.append({"id": ch.cid, "title": ch.title, "chars": chars, "blocks": len(blocks),
                                 "source": ch.source.relative_to(self.dir).as_posix()})
            dump(self.out / "chapters" / f"{ch.cid}.json", {"id": ch.cid, "title": ch.title, "blocks": blocks})

        if self.images and not self.inplace:
            (self.out / "images").mkdir()
            for src, name in self.images.items():
                shutil.copy2(src, self.out / "images" / name)

        def toc_json(nodes):
            return [{k: v for k, v in {"title": n.title, "chapter": n.chapter,
                                        "children": toc_json(n.children) or None}.items() if v}
                    for n in nodes]

        book = {
            "id": self.id,
            "title": title,
            "lang": "zh-Hans",
            "category": self.category,
            "subCategory": meta.get("category"),
            "origin": meta.get("origin"),
            "source": self.rel,
            "chars": total_chars,
            "toc": toc_json(toc),
            "chapters": chapter_meta,
        }
        dump(self.out / "book.json", book)
        return book

    def write_markdown(self, out_dir: Path) -> None:
        """导出规整后的 Markdown 书稿：README.md（元数据+目录）+ 每章一个无硬换行的 md 文件。

        导出结果可以替换原始 books/，本脚本再次读取时走「README 目录」分支，且跳过清洗。
        """
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True)

        files: dict[str, str] = {}
        for i, ch in enumerate(self.chapters, 1):
            safe = re.sub(r'[\\/:*?"<>|\s]+', "_", ch.title).strip("._")[:40] or "chapter"
            files[ch.cid] = f"{i:03d}-{safe}.md"

        def link(m: re.Match) -> str:
            text, href = m.group(1), m.group(2)
            if href.startswith("chapter:"):
                return f"[{text}]({quote(files[href[8:]])})"
            return m.group(0)

        for ch in self.chapters:
            lines = []
            if not ch.blocks or ch.blocks[0].t != "h":
                lines.append(f"# {ch.title}")
            for b in ch.blocks:
                text = RE_LINK.sub(link, b.text) if b.text else ""
                if b.t == "h":
                    lines.append(f"{'#' * (b.level or 2)} {text}")
                elif b.t == "li":
                    lines.append(f"- {text}")
                elif b.t == "quote":
                    lines.append(f"> {text}")
                elif b.t == "img":
                    lines.append(f"![{text}]({b.src})")
                elif b.t == "pre":
                    lines.append(f"```\n{b.text}\n```")
                else:
                    lines.append(text)
            (out_dir / files[ch.cid]).write_text("\n\n".join(lines) + "\n", encoding="utf-8")

        def toc_lines(nodes: list[TocNode], depth: int = 0):
            for n in nodes:
                pad = "  " * depth
                yield f"{pad}- [{n.title}]({quote(files[n.chapter])})" if n.chapter else f"{pad}- {n.title}"
                yield from toc_lines(n.children, depth + 1)

        meta_line = f"> 分类：{self.meta.get('category') or self.category}　|　原文件：`{self.meta.get('origin') or self.rel}`"
        readme = [f"# {self.title}", "", meta_line, "", NORMALIZED_MARK, "", "## 目录", "", *toc_lines(self.toc)]
        (out_dir / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")

        if self.images:
            (out_dir / "images").mkdir()
            for src, name in self.images.items():
                shutil.copy2(src, out_dir / "images" / name)


def dump(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


# ---------------------------------------------------------------- 入口

def discover(src: Path):
    for cat in sorted(p for p in src.iterdir() if p.is_dir()):
        for book in sorted(p for p in cat.iterdir() if p.is_dir()):
            if any(book.rglob("*.md")):
                yield cat.name, book


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    root = Path(__file__).resolve().parent.parent
    ap.add_argument("--src", type=Path, default=root / "books")
    ap.add_argument("--out", type=Path, help="集中输出目录；省略则写入各书目录下的 _app/")
    ap.add_argument("--md-out", type=Path, help="同时导出规整后的 Markdown 书稿（目录结构与 --src 相同）")
    args = ap.parse_args()
    args.src = args.src.resolve()
    if args.out:
        args.out = args.out.resolve()
    if args.md_out:
        args.md_out = args.md_out.resolve()
    index_dir = args.out or args.src
    index_dir.mkdir(parents=True, exist_ok=True)
    catalog, report = [], ["# 书稿预处理报告", ""]
    report.append("| 书名 | 分类 | 方式 | 章节 | 字数 | PDF断行合并 | 页码/页眉删除 | 异常 |")
    report.append("|---|---|---|---:|---:|---:|---:|---:|")
    details = []

    for category, book_dir in discover(args.src):
        bb = BookBuilder(book_dir, category, args.src, args.out)
        try:
            book = bb.build()
            if args.md_out:
                bb.write_markdown(args.md_out / bb.rel)
        except Exception as e:  # 单本失败不影响其他书
            print(f"[失败] {book_dir}: {e!r}", file=sys.stderr)
            report.append(f"| {book_dir.name} | {category} | **处理失败** {e!r} | | | | | |")
            continue
        s = bb.stats
        catalog.append({k: book[k] for k in ("id", "title", "lang", "category", "subCategory", "chars")}
                       | {"chapters": len(book["chapters"]),
                          "path": bb.rel if bb.inplace else f"books/{bb.id}"})
        report.append(f"| {book['title']} | {category} | {s.mode or '多文件'} | {len(book['chapters'])} | "
                      f"{book['chars']:,} | {s.pdf_merges} | {s.page_numbers}/{s.page_headers} | {len(s.issues)} |")
        if s.issues:
            details.append(f"\n### {book['title']}（`{bb.rel}` → `{bb.id}`）\n")
            details.extend(f"- {msg}" for msg in s.issues[:30])
            if len(s.issues) > 30:
                details.append(f"- …另有 {len(s.issues) - 30} 条")
        print(f"[完成] {book['title']}: {len(book['chapters'])} 章, {book['chars']:,} 字, {len(s.issues)} 条异常")

    dump(index_dir / "catalog.json", {"version": 1, "books": catalog})
    report += ["", "## 异常明细", *details] if details else []
    report_name = "build_report.md" if args.out is None else "report.md"
    (index_dir / report_name).write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"\n共 {len(catalog)} 本，书目写入 {index_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
