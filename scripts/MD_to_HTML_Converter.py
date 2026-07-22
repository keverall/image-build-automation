#!/usr/bin/env python3
# noqa: N810
# pylint: disable=C0103
"""
MD_to_HTML_Converter.py — Markdown -> HTML converter for Automation test plans.

Why this exists:
  The test-plan .md files use pipe tables, fenced code blocks, blockquotes,
  markdown link TOCs, and <a name>/<a id> anchors. This script turns them into
  a light-theme HTML file that pastes cleanly into Microsoft Word (open in a
  browser -> Ctrl+A -> Ctrl+C -> paste, or File -> Open the .html in Word).

Usage:
  python3 MD_to_HTML_Converter.py <input.md> <output.html>

Features:
  - Headings (#..######) get a slug/id so TOC links resolve (id from a preceding
    <a name>/<a id> anchor, else a slugified fallback).
  - Markdown links [text](#frag) -> <a href="#frag">.
  - Pipe tables -> <table> with bordered cells.
  - Fenced code blocks and `inline code` preserved with light background.
  - Blockquotes and '- ' lists rendered.
  - Forced white background / black text so nothing is black-on-black.
"""

import html
import re
import sys


def inline(text):
    """Convert inline Markdown (links, bold, inline code) to HTML.

    Args:
        text (str): The input text containing inline Markdown.

    Returns:
        str: HTML-escaped text with Markdown elements converted to HTML tags.
    """
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+?)`", r"<code>\1</code>", text)
    return text


def slugify(s):
    """Convert a string into a lowercase, hyphen-separated slug for use as an HTML id.

    Args:
        s (str): The input string to slugify.

    Returns:
        str: A lowercase slug with special characters removed and spaces replaced by
        hyphens.
    """
    s = re.sub(r"[`*]", "", s).strip().lower()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s)
    return s


def is_table_sep(line):
    """Determine whether a line is a Markdown table separator row.

    Args:
        line (str): The line to check.

    Returns:
        bool: True if the line matches a table separator pattern (contains dashes);
        False otherwise.
    """
    return bool(re.match(r"^\s*\|?[\s:\-|]+\|?\s*$", line)) and "-" in line


def split_row(line):
    """Split a pipe-delimited table row into a list of cell strings.

    Args:
        line (str): The raw Markdown table row line.

    Returns:
        list[str]: A list of trimmed cell values.
    """
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def convert(md):
    """Convert a Markdown string into an HTML fragment.

    Handles headings, inline formatting, code blocks, blockquotes, unordered lists,
    pipe tables, and paragraphs.

    Args:
        md (str): The Markdown source text.

    Returns:
        str: An HTML fragment string.
    """
    lines = md.split("\n")
    out = []
    i = 0
    n = len(lines)
    pending_id = None
    while i < n:
        line = lines[i]
        # raw HTML anchor lines (<a name=...> / <a id=...>) -> capture target id
        m_anchor = re.match(r'^\s*<a\s+(?:name|id)=["\']([^"\']+)["\']', line, re.I)
        if m_anchor and line.strip().endswith(">"):
            pending_id = m_anchor.group(1)
            i += 1
            continue
        # raw HTML passthrough for specific tags (e.g., <p class="report-run-date">)
        if re.match(r"^\s*<(p|div|span)\s+class=", line, re.I):
            out.append(line.strip())
            i += 1
            continue
        if line.lstrip().startswith("```"):
            i += 1
            buf = []
            while i < n and not lines[i].lstrip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1
            out.append("<pre><code>" + html.escape("\n".join(buf)) + "</code></pre>")
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            lvl = len(m.group(1))
            raw = m.group(2)
            if pending_id:
                hid = pending_id
                pending_id = None
            else:
                hid = slugify(raw)
            out.append(f'<h{lvl} id="{hid}">{inline(raw)}</h{lvl}>')
            i += 1
            continue
        if line.lstrip().startswith(">"):
            buf = []
            while i < n and lines[i].lstrip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append(
                "<blockquote><p>"
                + "<br>".join(inline(b) for b in buf)
                + "</p></blockquote>"
            )
            continue
        if line.lstrip().startswith("- "):
            buf = []
            while i < n and lines[i].lstrip().startswith("- "):
                buf.append(lines[i].lstrip()[2:])
                i += 1
            out.append("<ul>" + "".join(f"<li>{inline(b)}</li>" for b in buf) + "</ul>")
            continue
        if "|" in line and i + 1 < n and is_table_sep(lines[i + 1]):
            header = split_row(line)
            i += 2
            rows = []
            while i < n and "|" in lines[i] and lines[i].strip():
                rows.append(split_row(lines[i]))
                i += 1
            thead = "<tr>" + "".join(f"<th>{inline(c)}</th>" for c in header) + "</tr>"
            tbody = "".join(
                "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
                for r in rows
            )
            out.append(
                '<table border="1" cellspacing="0" cellpadding="4"><thead>'
                + thead
                + "</thead><tbody>"
                + tbody
                + "</tbody></table>"
            )
            continue
        if not line.strip():
            i += 1
            continue
        buf = [line]
        i += 1
        while (
            i < n
            and lines[i].strip()
            and not lines[i].lstrip().startswith(("#", ">", "|", "-"))
            and not lines[i].lstrip().startswith("```")
        ):
            buf.append(lines[i])
            i += 1
        out.append("<p>" + "<br>".join(inline(b) for b in buf) + "</p>")
    return "\n".join(out)


def main():
    """Entry point: read a Markdown file, convert it to HTML, and write the result."""
    if len(sys.argv) != 3:
        print("usage: python3 MD_to_HTML_Converter.py <input.md> <output.html>")
        sys.exit(1)
    with open(sys.argv[1], encoding="utf-8") as f:
        md = f.read()
    body = convert(md)
    style = (
        "@page Section1{size:297mm 210mm;margin:25.4mm;}"
        "body{background:#ffffff;color:#000000;font-family:Calibri,Arial,sans-serif;margin:20px;}"
        "h1,h2,h3,h4{color:#000000;}"
        ".report-run-date{text-align:right;margin-top:-10px;margin-bottom:20px;color:#000000;font-size:1.2em;font-weight:bold;}"
        "table{border-collapse:collapse;background:#ffffff;color:#000000;"
        "width:100%;table-layout:auto;}"
        "th,td{border:1px solid #999999;padding:6px 10px;color:#000000;"
        "background:#ffffff;word-wrap:break-word;vertical-align:top;}"
        "th{background:#e8e8e8;font-weight:bold;}"
        "code{background:#f4f4f4;color:#000000;padding:1px 3px;}"
        "pre{background:#f4f4f4;color:#000000;padding:8px;border:1px solid #cccccc;"
        "overflow:auto;word-wrap:normal;}"
        "pre code{background:#f4f4f4;color:#000000;}"
        "blockquote{color:#222222;background:#f7f7f7;border-left:3px solid #999999;"
        "padding:6px 10px;}"
        "a{color:#0645ad;}"
    )
    doc = (
        '<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
        + style
        + "</style></head><body>"
        + body
        + "</body></html>"
    )
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(doc)
    print("wrote", sys.argv[2])


if __name__ == "__main__":
    main()
