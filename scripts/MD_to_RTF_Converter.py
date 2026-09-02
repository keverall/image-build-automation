#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MD_to_RTF_Converter.py — Markdown to RTF converter for Windows help docs.

Converts selected Markdown documentation files into RTF (Rich Text Format) for
use on Windows clients (WordPad, Word, etc.).

Supported Markdown features:
  - Headings H1–H6      -> bold paragraphs at descending font sizes
  - Bold / italic       -> \\b / \\i
  - Inline code         -> Courier New span
  - Fenced code blocks  -> shaded monospace block
  - Pipe tables         -> bordered RTF tables with shaded header row
  - Blockquotes         -> indented italic block
  - Unordered lists     -> bullet + tab
  - Horizontal rules    -> bottom border paragraph
  - Links               -> HYPERLINK field (http/https) or plain text
  - <a id>/<a name>     -> bookmarks attached to the following heading
  - YAML front-matter   -> stripped (dynamic-code-docs files)

TOC: a Table of Contents is generated once at the top of every document from the
headings; each heading carries a bookmark so TOC entries jump to it. The source
markdown's own "Table of Contents" / "In this document" bullet lists are skipped
in the body to avoid duplication.

Usage:
  python3 MD_to_RTF_Converter.py                 # batch convert all source docs
  python3 MD_to_RTF_Converter.py <in.md> <out.rtf>  # convert a single file

Output layout:
  doc/windows/help/rtf/  (mirrors source directory structure)
"""

import re
import sys
from datetime import date
from pathlib import Path

# ---------------------------------------------------------------------------
# RTF document constants
# ---------------------------------------------------------------------------

PAGE_WIDTH_TWIPS = 11906
MARGIN_TWIPS = 1440
USABLE_WIDTH_TWIPS = PAGE_WIDTH_TWIPS - (2 * MARGIN_TWIPS)  # 9026

RTF_HEADER = (
    r"{\rtf1\ansi\ansicpg1252\deff0\widowctrl"
    r"{\fonttbl{\f0 Calibri;}{\f1 Courier New;}}"
    r"{\colortbl;\red0\green0\blue0;\red244\green244\blue244;\red232\green232\blue232;}"
    r"{\*\generator MD-to-RTF Converter;}"
)

RTF_FOOTER = r"}"

HEADING_SIZES = {1: 32, 2: 28, 3: 24, 4: 22, 5: 20, 6: 20}
BODY_SIZE = 22       # 11pt
CODE_SIZE = 20       # 10pt
TOC_SIZE = 22        # 11pt

# Characters that are valid in RTF ANSI (cp1252) and need no unicode escape.
# Everything else (emoji, smart quotes, non-Latin) is either mapped or dropped.
_CHAR_MAP = {
    "\u2018": "'", "\u2019": "'", "\u201c": '"', "\u201d": '"',
    "\u2013": "-", "\u2014": "-", "\u2026": "...", "\u2022": "-",
    "\u00a0": " ", "\u2192": "->", "\u2190": "<-", "\u00b4": "'",
    "\u201a": ",", "\u201e": '"', "\u2032": "'", "\u2033": '"',
    "\u00ab": "<<", "\u00bb": ">>", "\u2009": " ", "\u200b": "",
    "\u200e": "", "\u200f": "", "\u00a0": " ",
}


# ---------------------------------------------------------------------------
# Escaping / sanitising
# ---------------------------------------------------------------------------


def sanitise(text):
    """Replace common Unicode punctuation and strip emoji/symbols for cp1252 RTF."""
    out = []
    for ch in text:
        if ch in _CHAR_MAP:
            out.append(_CHAR_MAP[ch])
            continue
        o = ord(ch)
        # Keep ASCII and Latin-1 (cp1252 overlap) as-is; escape the rest away.
        if 32 <= o <= 126:
            out.append(ch)
        elif 160 <= o <= 255:
            # Latin-1 supplement; cp1252 shares most of these.
            out.append(ch)
        else:
            # Emoji / symbol / CJK -> drop. (Leaves clean ASCII text behind.)
            pass
    s = "".join(out)
    # Collapse runs of spaces left by removed symbols.
    s = re.sub(r"[ \t]{2,}", " ", s)
    return s


def rtf_escape(text):
    """Escape text for RTF: backslash, braces, percent, and newlines."""
    text = sanitise(text)
    text = text.replace("\\", "\\\\")
    text = text.replace("{", "\\{")
    text = text.replace("}", "\\}")
    # Escape % so the result is safe to use with the % string-format operator.
    text = text.replace("%", "%%")
    text = text.replace("\n", "\\par\n")
    text = text.replace("\r", "")
    return text


def slugify(s):
    """Create a safe bookmark/id token from heading text."""
    s = re.sub(r"[`*_]", "", s).strip().lower()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s)
    s = s.strip("-")  # drop leading/trailing hyphen left by a stripped emoji
    return s or "section"


def is_table_sep(line):
    """Return True if line is a Markdown table separator row."""
    return bool(re.match(r"^\s*\|?[\s:\-|]+\|?\s*$", line)) and "-" in line


def split_row(line):
    """Split a pipe-delimited table row into trimmed cells."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


# ---------------------------------------------------------------------------
# Inline conversion (to RTF)
# ---------------------------------------------------------------------------


def inline_to_rtf(text):
    """Convert inline Markdown (bold, code, links) to RTF.

    All literal text is escaped exactly once via rtf_escape.
    """
    # Protect inline code spans first.
    code_spans = []

    def stash(m):
        code_spans.append(m.group(1))
        return "\x00C%d\x00" % (len(code_spans) - 1)

    text = re.sub(r"`([^`\n]+?)`", stash, text)

    # Escape everything outside code spans.
    parts = text.split("\x00")
    for i in range(0, len(parts), 2):
        parts[i] = rtf_escape(parts[i])
    text = "\x00".join(parts)

    # External links -> HYPERLINK field.
    text = re.sub(
        r"\[([^\]]+)\]\((https?://[^)\s]+)\)",
        lambda m: r"{\field{\*\fldinst HYPERLINK \"%s\"}{\fldrslt %s}}"
        % (m.group(2), rtf_escape(m.group(1))),
        text,
    )
    # Any other link -> keep visible text only.
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)

    # Bold then italic.
    text = re.sub(r"\*\*(.+?)\*\*", r"\\b \1\\b0", text)
    text = re.sub(r"(?<!\\)\*(?!\*)(.+?)\*(?!\*)", r"\\i \1\\i0", text)

    # Restore code spans (escaped).
    def restore(m):
        idx = int(m.group(1))
        return r"{\f1 %s\f0}" % rtf_escape(code_spans[idx])

    text = re.sub(r"\x00C(\d+)\x00", restore, text)
    return text


# ---------------------------------------------------------------------------
# Block-level RTF builders
# ---------------------------------------------------------------------------


def heading_rtf(level, raw, bookmark=None):
    lvl = min(max(level, 1), 6)
    size = HEADING_SIZES[lvl]
    body = inline_to_rtf(raw)
    # Always attach a bookmark (prefer explicit anchor, else slug of text) so the
    # generated Table of Contents PAGEREF fields resolve in Word/WordPad.
    bm = bookmark if bookmark else slugify(raw)
    mark = r"{\*\bkmkstart %s}{\*\bkmkend %s}" % (bm, bm)
    return r"\pard\sa120\sb120\fs%d\b %s\b0%s\par" % (size, body, mark)


def paragraph_rtf(text):
    body = inline_to_rtf(text)
    return r"\pard\sa80\fs%d %s\par" % (BODY_SIZE, body)


def code_block_rtf(code):
    escaped = rtf_escape(code.rstrip("\n"))
    return (
        r"{\pard\sa80\sb80\fs" + str(CODE_SIZE) + r"\fi0"
        r"\brdrt\brdrs\brdrw10\brdrb\brdrs\brdrw10"
        r"\clcbpat2\cf2"
        r"{\f1 " + escaped + r"\f0}\par}"
    )


def blockquote_rtf(lines):
    body = r"\par\n".join(inline_to_rtf(l) for l in lines)
    return r"\pard\li360\ri360\sa80\fs%d\i %s\i0\par" % (BODY_SIZE, body)


def list_rtf(items):
    out = []
    for it in items:
        body = inline_to_rtf(it)
        out.append(r"\pard\li360\fi-360\fs%d\'95\tab %s\par" % (BODY_SIZE, body))
    return "".join(out)


def hrule_rtf():
    return r"\pard\brdrb\brdrs\brdrw20\brsp20\sa120\sb120\par"


def table_rtf(header, rows):
    ncol = len(header)
    widths = [USABLE_WIDTH_TWIPS // ncol] * ncol
    out = []

    def row_cells(cells, header_row=False):
        # cell border control words
        border = r"\clbrdrt\brdrs\clbrdrl\brdrs\clbrdrb\brdrs\clbrdrr\brdrs"
        res = []
        for c in cells:
            shade = r"\clcbpat3 " if header_row else ""
            bold = r"\b " if header_row else ""
            end = r"\b0 " if header_row else ""
            res.append(
                r"{\pard\fi0\li60\ri60\fs%d\sa40\sb40 %s%s%s%s\cell}"
                % (BODY_SIZE, shade, bold, end, inline_to_rtf(c))
            )
        return res

    # Header
    out.append(r"\trowd\trgaph60")
    pos = 0
    for w in widths:
        pos += w
        out.append(r"%s\cellx%d" % (r"\clbrdrt\brdrs\clbrdrl\brdrs\clbrdrb\brdrs\clbrdrr\brdrs", pos))
    out.extend(row_cells(header, header_row=True))
    out.append(r"\row")

    # Data
    for row in rows:
        out.append(r"\trowd\trgaph60")
        pos = 0
        for w in widths:
            pos += w
            out.append(r"%s\cellx%d" % (r"\clbrdrt\brdrs\clbrdrl\brdrs\clbrdrb\brdrs\clbrdrr\brdrs", pos))
        out.extend(row_cells(row, header_row=False))
        out.append(r"\row")

    return "".join(out)


# ---------------------------------------------------------------------------
# Front-matter / TOC extraction
# ---------------------------------------------------------------------------


def strip_front_matter(md):
    m = re.match(r"^\s*---\n.*?\n---\n", md, re.S)
    if m:
        return md[m.end():]
    return md


def extract_headings(md_lines):
    """Return list of (level, text, anchor) for headings (anchor from <a id>).

    Headings that appear inside fenced code blocks are skipped, matching the
    real rendering (the main loop also treats them as code, not headings).
    """
    headings = []
    pending = None
    in_code = False
    for line in md_lines:
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        if pending is not None:
            pending = None
            continue
        ma = re.match(r'^\s*<a\s+(?:name|id)=["\']([^"\']+)["\']', line, re.I)
        if ma and line.strip().endswith(">"):
            pending = ma.group(1)
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            text = m.group(2).strip()
            if text.lower() in ("table of contents", "contents"):
                continue
            headings.append((len(m.group(1)), text, pending))
    return headings


def toc_rtf(headings):
    if not headings:
        return ""
    out = [r"\pard\sa60\sb120\fs%d\b Table of Contents\b0\par" % TOC_SIZE]
    for lvl, text, anchor in headings:
        indent = 360 * max(0, lvl - 1)
        # Use the same bookmark the heading carries (explicit anchor, else slug).
        bmk = anchor if anchor else slugify(text)
        # HYPERLINK \l "bookmark" renders the heading text (not a page number) and
        # jumps to the bookmark when clicked - unlike PAGEREF which shows a page #.
        out.append(
            r"\pard\li%d\fi-360\fs%d\'95\tab {\field{\*\fldinst HYPERLINK \l \"%s\"}{\fldrslt %s}}\par"
            % (indent, TOC_SIZE, bmk, inline_to_rtf(text))
        )
    out.append(r"\pard\sa120\par")
    return "".join(out)


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------


def convert_md_to_rtf(md, title=None):
    md = strip_front_matter(md)
    lines = md.split("\n")
    headings = extract_headings(lines)

    out = []
    if title:
        out.append(r"\pard\sa40\sb200\fs36\b %s\b0\par" % rtf_escape(title))
    out.append(r"\pard\sa120\fs18\i Generated %s\i0\par" % rtf_escape(date.today().isoformat()))

    if headings:
        out.append(toc_rtf(headings))
        out.append(r"\page")

    # Skip-body state: when we hit a heading whose text is a TOC marker, suppress
    # the immediately following bullet list (it's a duplicate of our generated TOC).
    skip_next_list = False
    pending_id = None
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]

        ma = re.match(r'^\s*<a\s+(?:name|id)=["\']([^"\']+)["\']', line, re.I)
        if ma and line.strip().endswith(">"):
            pending_id = ma.group(1)
            i += 1
            continue

        if re.match(r"^\s*<(p|div|span)\s+class=", line, re.I):
            i += 1
            continue

        # Fenced code block
        if line.lstrip().startswith("```"):
            i += 1
            buf = []
            while i < n and not lines[i].lstrip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1  # consume closing fence
            out.append(code_block_rtf("\n".join(buf)))
            skip_next_list = False
            continue

        # Heading
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            raw = m.group(2).strip()
            lvl = len(m.group(1))
            if raw.lower() in ("table of contents", "contents"):
                i += 1
                skip_next_list = True
                continue
            bm = pending_id
            pending_id = None
            out.append(heading_rtf(lvl, raw, bookmark=bm))
            skip_next_list = False
            i += 1
            continue

        # Blockquote
        if line.lstrip().startswith(">"):
            buf = []
            while i < n and lines[i].lstrip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append(blockquote_rtf(buf))
            skip_next_list = False
            continue

        # Unordered list (skip if it's a duplicate TOC list)
        if line.lstrip().startswith("- ") or line.lstrip().startswith("* "):
            if skip_next_list:
                # consume the whole list without rendering
                while i < n and (lines[i].lstrip().startswith("- ") or lines[i].lstrip().startswith("* ")):
                    i += 1
                skip_next_list = False
                continue
            buf = []
            while i < n and (lines[i].lstrip().startswith("- ") or lines[i].lstrip().startswith("* ")):
                buf.append(lines[i].lstrip()[2:])
                i += 1
            out.append(list_rtf(buf))
            skip_next_list = False
            continue

        # Horizontal rule
        if re.match(r"^\s*---\s*$", line):
            out.append(hrule_rtf())
            i += 1
            skip_next_list = False
            continue

        # Table
        if "|" in line and i + 1 < n and is_table_sep(lines[i + 1]):
            header = split_row(line)
            i += 2
            rows = []
            while i < n and "|" in lines[i] and lines[i].strip():
                rows.append(split_row(lines[i]))
                i += 1
            out.append(table_rtf(header, rows))
            skip_next_list = False
            continue

        # Blank
        if not line.strip():
            i += 1
            continue

        # Paragraph
        buf = [line]
        i += 1
        while (
            i < n
            and lines[i].strip()
            and not lines[i].lstrip().startswith(("#", ">", "-", "*", "<"))
            and not lines[i].lstrip().startswith("```")
            and not re.match(r"^\s*---\s*$", lines[i])
            and "|" not in lines[i]
        ):
            buf.append(lines[i])
            i += 1
        text = " ".join(b.strip() for b in buf)
        out.append(paragraph_rtf(text))
        skip_next_list = False

    body = "\n".join(out)
    return RTF_HEADER + body + RTF_FOOTER


# ---------------------------------------------------------------------------
# File discovery & batch
# ---------------------------------------------------------------------------


def discover_md_files(repo_root):
    root = Path(repo_root)
    pairs = []

    def add(p):
        rel = p.relative_to(root)
        pairs.append((p, rel.with_suffix(".rtf")))

    readme = root / "README.md"
    if readme.exists():
        add(readme)

    auto = root / "docs" / "Automation"
    for name in ("automation_commands.md", "runbook-requirements.md", "runbook-requirements-v2.md"):
        p = auto / name
        if p.exists():
            add(p)

    dcd = root / "docs" / "dynamic-code-docs"
    if dcd.exists():
        for p in sorted(dcd.glob("*.md")):
            add(p)

    wip = root / "wip"
    if wip.exists():
        for p in sorted(wip.glob("*.md")):
            add(p)

    return pairs


def convert_file(input_path, output_path):
    md = input_path.read_text(encoding="utf-8")
    rtf = convert_md_to_rtf(md, title=input_path.stem)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rtf, encoding="utf-8")
    return len(rtf)


def main():
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent

    if len(sys.argv) == 3:
        size = convert_file(Path(sys.argv[1]), Path(sys.argv[2]))
        print("wrote %s (%d bytes)" % (sys.argv[2], size))
        return

    out_base = repo_root / "doc" / "windows" / "help" / "rtf"
    pairs = discover_md_files(repo_root)
    if not pairs:
        print("No source markdown files found.", file=sys.stderr)
        sys.exit(1)

    count = 0
    for src, rel_rtf in pairs:
        out = out_base / rel_rtf
        try:
            convert_file(src, out)
            count += 1
        except Exception as e:  # noqa: BLE001
            print("  [WARN] failed to convert %s: %s" % (src, e), file=sys.stderr)

    print("Converted %d markdown files to RTF under %s" % (count, out_base))


if __name__ == "__main__":
    main()
