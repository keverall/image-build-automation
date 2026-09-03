#!/usr/bin/env python3

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
  docs/rtf/  (mirrors source directory structure)
"""

import re
import sys
from datetime import date
from pathlib import Path

# ---------------------------------------------------------------------------
# RTF document constants
# ---------------------------------------------------------------------------

PAGE_WIDTH_TWIPS = 11906
PAGE_HEIGHT_TWIPS = 16838
LANDSCAPE_WIDTH_TWIPS = PAGE_HEIGHT_TWIPS
LANDSCAPE_HEIGHT_TWIPS = PAGE_WIDTH_TWIPS
MARGIN_TWIPS = 1440
# Every RTF doc page is landscape (A4 long edge) so tables always have the
# full 13,958 twips of usable width and Word renders them consistently.
USABLE_WIDTH_TWIPS = LANDSCAPE_WIDTH_TWIPS - (2 * MARGIN_TWIPS)
USABLE_WIDTH_LANDSCAPE_TWIPS = USABLE_WIDTH_TWIPS

RTF_HEADER = (
    r"{\rtf1\ansi\ansicpg1252\deff0\widowctrl"
    r"{\fonttbl{\f0 Calibri;}{\f1 Courier New;}}"
    r"{\colortbl;\red0\green0\blue0;\red244\green244\blue244;\red232\green232\blue232;}"
    r"{\*\generator MD-to-RTF Converter;}"
    + r"\landscape"
    + r"\paperw" + str(LANDSCAPE_WIDTH_TWIPS) + r"\paperh" + str(LANDSCAPE_HEIGHT_TWIPS)
    + r"\margl" + str(MARGIN_TWIPS) + r"\margr" + str(MARGIN_TWIPS)
    + r"\margt" + str(MARGIN_TWIPS) + r"\margb" + str(MARGIN_TWIPS)
)

RTF_FOOTER = r"}"

HEADING_SIZES = {1: 32, 2: 28, 3: 24, 4: 22, 5: 20, 6: 20}
BODY_SIZE = 22  # 11pt
CODE_SIZE = 20  # 10pt
TOC_SIZE = 22  # 11pt

# Characters that are valid in RTF ANSI (cp1252) and need no unicode escape.
# Everything else (emoji, smart quotes, non-Latin) is either mapped or dropped.
_CHAR_MAP = {
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\u2013": "-",
    "\u2014": "-",
    "\u2026": "...",
    "\u2022": "-",
    "\u00a0": " ",
    "\u2192": "->",
    "\u2190": "<-",
    "\u00b4": "'",
    "\u201a": ",",
    "\u201e": '"',
    "\u2032": "'",
    "\u2033": '"',
    "\u00ab": "<<",
    "\u00bb": ">>",
    "\u2009": " ",
    "\u200b": "",
    "\u200e": "",
    "\u200f": "",
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


def valid_bm_name(s):
    """Normalize to an RTF/Word bookmark name.

    Word and LibreOffice reject bookmark names that do not start with a letter
    (e.g. "1-identity-..."); digit-leading names produce no anchor, which breaks
    every internal link (TOC + citations) that targets them. Prefix such names
    so the bookmark is actually created. The same normalization MUST be applied
    to both the target (bookmark) and the link (\\l) so they stay in sync.
    """
    s = re.sub(r"[^A-Za-z0-9_-]", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    if not s:
        return "section"
    if not s[0].isalpha():
        s = "bm-" + s
    return s or "section"


def is_table_sep(line):
    """Return True if line is a Markdown table separator row."""
    return bool(re.match(r"^\s*\|?[\s:\-|]+\|?\s*$", line)) and "-" in line


def split_row(line):
    """Split a pipe-delimited table row into trimmed cells.

    Markdown authors escape a literal pipe inside a cell as ``\\|``; honour
    that escape so the row isn't split in the wrong place.
    """
    s = line.strip()
    s = re.sub(r"\\\|", "\x00P\x00", s)
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    cells = [c.replace("\x00P\x00", "|").strip() for c in s.split("|")]
    return cells


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
        # Convert HTML anchor tags into RTF bookmarks so inline citations can
        # jump to them; drop the now-empty closing </a> tags. Anchors appear
        # both on their own line (handled at block level) and inline, e.g.
        # "<a id="ref-1"></a>[1] ...". The bookmark control words are injected
        # after escaping so they are not mangled. Names are normalized to a
        # valid RTF bookmark name (no leading digit) and the SAME normalization
        # is applied to the citation links below so they resolve.
        parts[i] = re.sub(
            r'<a\s+(?:name|id)=["\']([^"\']+)["\']\s*/?>',
            lambda m: (
                r"{\*\bkmkstart %s}{\*\bkmkend %s}"
                % (valid_bm_name(m.group(1)), valid_bm_name(m.group(1)))
            ),
            parts[i],
        )
        parts[i] = parts[i].replace("</a>", "")
    text = "\x00".join(parts)

    # External links -> HYPERLINK field.
    text = re.sub(
        r"\[([^\]]+)\]\((https?://[^)\s]+)\)",
        lambda m: (
            r"{\field{\*\fldinst HYPERLINK \"%s\"}{\fldrslt %s}}"
            % (m.group(2), rtf_escape(m.group(1)))
        ),
        text,
    )
    # Internal anchor links (#anchor) -> HYPERLINK \l "anchor" so citations
    # like [3](#ref-3) remain clickable and jump to the reference bookmark.
    # Use single backslashes + \" quotes to match the external-link field form
    # (which Word/LibreOffice accept); names are normalized to match targets.
    text = re.sub(
        r"\[([^\]]+)\]\(#([^)\s]+)\)",
        lambda m: (
            r"{\field{\*\fldinst HYPERLINK \l \"%s\"}{\fldrslt %s}}"
            % (valid_bm_name(m.group(2)), m.group(1))
        ),
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


def heading_rtf(level, raw, bookmark=None, page_break=False):
    lvl = min(max(level, 1), 6)
    size = HEADING_SIZES[lvl]
    body = inline_to_rtf(raw)
    # Always attach a bookmark (prefer explicit anchor, else slug of text) so the
    # generated Table of Contents PAGEREF fields resolve in Word/WordPad.
    bm = bookmark if bookmark else slugify(raw)
    bm = valid_bm_name(bm)
    mark = r"{\*\bkmkstart %s}{\*\bkmkend %s}" % (bm, bm)
    pb = r"\pagebb\par" if page_break else ""
    return r"%s\pard\sa120\sb120\fs%d\b %s\b0%s\par" % (pb, size, body, mark)


def paragraph_rtf(text):
    body = inline_to_rtf(text)
    return r"\pard\sa80\fs%d %s\par" % (BODY_SIZE, body)


def code_block_rtf(code):
    escaped = rtf_escape(code.rstrip("\n"))
    return (
        r"{\pard\sa80\sb80\fs" + str(CODE_SIZE) + r"\fi0"
        r"\brdrt\brdrs\brdrw10\brdrb\brdrs\brdrw10"
        r"\clcbpat2"
        r"{\f1 " + escaped + r"\f0}\par}"
    )


def blockquote_rtf(lines):
    body = r"\par\n".join(inline_to_rtf(line) for line in lines)
    return r"\pard\li360\ri360\sa80\fs%d\i %s\i0\par" % (BODY_SIZE, body)


def list_rtf(items):
    out = []
    for it in items:
        body = inline_to_rtf(it)
        out.append(r"\pard\li360\fi-360\fs%d\'95\tab %s\par" % (BODY_SIZE, body))
    return "".join(out)


def hrule_rtf():
    return r"\pard\brdrb\brdrs\brdrw20\brsp20\sa120\sb120\par"


def _column_widths(header, rows):
    """Column widths with priority-based allocation.

    Allocation order (so the most important columns keep their natural width):
      1. First column  — sized to its longest cell (capped so it folds at ~24
         chars instead of growing without bound), floor ~12 chars.
      2. Last column   — sized to its longest cell, capped at ~40% of the page.
      3. Middle column(s) — get whatever is left, but never below ~20 chars.

    Widths are measured in twips; Calibri 11pt ≈ 86 twips per character +
    120 twips of inset padding (li60/ri60) per cell.
    """
    ncol = len(header)
    if ncol == 0:
        return [], False
    # Every document is landscape, so tables always use the long-edge width.
    use_landscape = True
    total = USABLE_WIDTH_LANDSCAPE_TWIPS
    per_char = 82
    pad = 130

    raw = []
    for i in range(ncol):
        longest = len(header[i])
        for r in rows:
            if i < len(r):
                longest = max(longest, len(r[i]))
        raw.append(longest)

    def w(chars, char_limit):
        """twips needed for `chars` chars, clamped to [char_limit]."""
        return min(chars * per_char + pad, char_limit * per_char + pad)

    if ncol == 1:
        return [total], use_landscape
    first = max(w(raw[0], 24), 12 * per_char + pad)  # col1: natural, capped 24
    if ncol == 2:
        return [first, total - first], use_landscape

    # Identify the column with the longest content — that one gets the bulk of
    # the page so the prose column (usually "Describe"/"Description") stays wide.
    other_cols = list(range(1, ncol - 1)) + [ncol - 1]
    primary = max(other_cols, key=lambda i: raw[i])

    # All non-primary columns: size to their content with a sensible cap so a
    # short label column doesn't steal space, but allow up to 36 chars for
    # value columns like Command/Aliases.
    non_primary_target = {}
    for i in other_cols:
        if i == primary:
            continue
        cap_chars = 40 if i < ncol - 1 else 28
        non_primary_target[i] = min(w(raw[i], cap_chars), total * 18 // 100)

    floor = 600
    np_total = sum(non_primary_target.values())
    primary_w = max(total - first - np_total, 20 * per_char + pad)
    widths = [0] * ncol
    widths[0] = first
    for i, val in non_primary_target.items():
        widths[i] = val
    widths[primary] = primary_w
    widths = [max(floor, x) for x in widths]

    # Final guard: shrink the primary column if still over (it's the only one
    # we're willing to sacrifice below its floor is unacceptable, so just trim).
    if sum(widths) > total:
        widths[primary] -= sum(widths) - total
    return widths, use_landscape


def table_rtf(header, rows):
    widths, use_landscape = _column_widths(header, rows)
    out = []
    # Leading blank line before the table so it doesn't sit flush against the
    # preceding paragraph.
    out.append(r"\par")

    border = r"\clbrdrt\brdrs\clbrdrl\brdrs\clbrdrb\brdrs\clbrdrr\brdrs"

    def row_cells(cells, header_row=False):
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

    def emit_row(cells, header_row):
        out.append(r"\trowd\trgaph60")
        pos = 0
        for w in widths:
            pos += w
            out.append(r"%s\cellx%d" % (border, pos))
        out.extend(row_cells(cells, header_row=header_row))
        out.append(r"\row")

    emit_row(header, header_row=True)
    for row in rows:
        emit_row(row, header_row=False)

    # Always leave a blank line between a table and whatever paragraph follows.
    out.append(r"\pard\sa120\par")

    return "".join(out)


# ---------------------------------------------------------------------------
# Front-matter / TOC extraction
# ---------------------------------------------------------------------------


def strip_front_matter(md):
    m = re.match(r"^\s*---\n.*?\n---\n", md, re.S)
    if m:
        return md[m.end() :]
    return md


def extract_headings(md_lines):
    """Return list of (level, text, anchor) for headings (anchor from <a id>).

    Headings that appear inside fenced code blocks are skipped, matching the
    real rendering (the main loop also treats them as code, not headings).

    A pending <a id="..."> anchor stays armed across blank lines so it still
    attaches to the heading that follows it (markdown allows any number of
    blank lines between an anchor and its heading).
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
        ma = re.match(r'^\s*<a\s+(?:name|id)=["\']([^"\']+)["\']', line, re.I)
        if ma and line.strip().endswith(">"):
            # A later anchor replaces a still-pending one; safer than guessing.
            pending = ma.group(1)
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            text = m.group(2).strip()
            if text.lower() in ("table of contents", "contents"):
                pending = None
                continue
            headings.append((len(m.group(1)), text, pending))
            pending = None
    return headings


def toc_rtf(headings):
    if not headings:
        return ""
    out = [r"\pard\sa60\sb120\fs%d\b Table of Contents\b0\par" % TOC_SIZE]
    for lvl, text, anchor in headings:
        indent = 360 * max(0, lvl - 1)
        # Use the same bookmark the heading carries (explicit anchor, else slug),
        # normalized so Word/LibreOffice actually create the bookmark target.
        bmk = anchor if anchor else slugify(text)
        bmk = valid_bm_name(bmk)
        # HYPERLINK \l "bookmark" renders the heading text (not a page number) and
        # jumps to the bookmark when clicked - unlike PAGEREF which shows a page #.
        out.append(
            r"\pard\li%d\fi-360\fs%d\'95\tab {\field{\*\fldinst HYPERLINK \l \"%s\"}"
            r"{\fldrslt %s}}\par"
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
    out.append(
        r"\pard\sa120\fs18\i Generated %s\i0\par" % rtf_escape(date.today().isoformat())
    )

    if headings:
        out.append(toc_rtf(headings))
        out.append(r"\page")

    # Skip-body state: when we hit a heading whose text is a TOC marker, suppress
    # the immediately following bullet list (it's a duplicate of our generated TOC).
    skip_next_list = False
    pending_id = None
    seen_first_heading = False
    section_start = len("".join(out))  # char offset of the current top-level section
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
            # Only force a page break before a high-level heading (H1 / H2) when
            # the content accumulated under the *previous* heading already
            # fills roughly 70% of a portrait page (≈ 3500 RTF chars). Short
            # sections stay on the same page so the document reads as one
            # flowing sheet instead of dozens of two-line pages.
            section_chars = len("".join(out)) - section_start
            page_break = seen_first_heading and lvl <= 2 and section_chars > 3500
            seen_first_heading = True
            section_start = len("".join(out))
            out.append(heading_rtf(lvl, raw, bookmark=bm, page_break=page_break))
            skip_next_list = False
            i += 1
            continue

        # Blockquote (may contain pipe tables; split at table boundaries so the
        # table renders as a real RTF table rather than as markdown text).
        if line.lstrip().startswith(">"):
            buf = []
            while i < n and lines[i].lstrip().startswith(">"):
                buf.append(lines[i])
                i += 1
            j = 0
            while j < len(buf):
                # Skip blank `>` separators within the quote.
                if not buf[j].strip().lstrip(">").strip() and not (
                    "|" in buf[j]
                    and j + 1 < len(buf)
                    and is_table_sep(re.sub(r"^\s*>\s?", "", buf[j + 1]))
                ):
                    j += 1
                    continue
                # Collect a run of consecutive `>` lines that are NOT a table.
                run = []
                while j < len(buf):
                    raw = buf[j]
                    stripped = re.sub(r"^\s*>\s?", "", raw)
                    if not stripped.strip():
                        # blank `>` line — end the paragraph run, but only if
                        # the next line isn't the start of a table.
                        if (
                            j + 1 < len(buf)
                            and "|" in buf[j + 1]
                            and j + 2 < len(buf)
                            and is_table_sep(re.sub(r"^\s*>\s?", "", buf[j + 2]))
                        ):
                            break
                        break
                    if (
                        "|" in stripped
                        and j + 1 < len(buf)
                        and is_table_sep(re.sub(r"^\s*>\s?", "", buf[j + 1]))
                    ):
                        break
                    run.append(stripped)
                    j += 1
                if run:
                    out.append(blockquote_rtf(run))
                    skip_next_list = False
                # If we hit a table boundary, consume header + sep + body rows.
                if j < len(buf) and "|" in buf[j] and j + 1 < len(buf):
                    header_line = re.sub(r"^\s*>\s?", "", buf[j])
                    sep_line = re.sub(r"^\s*>\s?", "", buf[j + 1])
                    if is_table_sep(sep_line):
                        header = split_row(header_line)
                        j += 2
                        rows = []
                        while j < len(buf):
                            tline = re.sub(r"^\s*>\s?", "", buf[j])
                            if not tline.strip() or "|" not in tline:
                                break
                            rows.append(split_row(tline))
                            j += 1
                        out.append(table_rtf(header, rows))
                        skip_next_list = False
            continue

        # Unordered list (skip if it's a duplicate TOC list)
        if line.lstrip().startswith("- ") or line.lstrip().startswith("* "):
            if skip_next_list:
                # consume the whole list without rendering
                while i < n and (
                    lines[i].lstrip().startswith("- ")
                    or lines[i].lstrip().startswith("* ")
                ):
                    i += 1
                skip_next_list = False
                continue
            buf = []
            while i < n and (
                lines[i].lstrip().startswith("- ") or lines[i].lstrip().startswith("* ")
            ):
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
    for name in (
        "automation_commands.md",
        "runbook-requirements.md",
        "runbook-requirements-v2.md",
    ):
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

    out_base = repo_root / "docs" / "rtf"
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
