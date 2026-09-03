#!/usr/bin/env env python3
"""MD_to_DOCX_Converter.py - Markdown -> Word DOCX with clickable links.

Unlike the RTF converter, a DOCX stores bookmarks and intra-document
hyperlinks as native OOXML (<w:bookmarkStart>/<w:hyperlink w:anchor=...>),
so links are active in Word/LibreOffice the instant the file opens - no field
update is required.

Word (and LibreOffice) reject bookmark names that begin with a digit, so every
bookmark name is run through valid_bm_name() on BOTH the target and the link,
keeping them in sync. The Markdown source's anchors are normalised into
pandoc-recognised forms (heading ``{#id}`` attributes and ``<div id>`` for
reference entries) so pandoc preserves them as bookmarks instead of hashing
or dropping them.

Usage:
    word-docs                       Convert all Markdown docs (root, docs/, wip/)
                                    to project-root docx/ with bookmarks/links.
    python3 MD_to_DOCX_Converter.py                 # all docs -> docx/
    python3 MD_to_DOCX_Converter.py <in.md> <out.docx>
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HEADERS = ("http://", "https://", "mailto:")

# A4 portrait is 11906 x 16838 twips; landscape swaps the edges.
LANDSCAPE_W = 16838
LANDSCAPE_H = 11906
_NAME_BAD = re.compile(r"[^A-Za-z0-9_-]")
_HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
_STANDALONE_ANCHOR = re.compile(r'^<a\s+(?:id|name)=["\']([^"\']+)["\']\s*></a>\s*$', re.I)
_INLINE_ANCHOR = re.compile(r'^<a\s+(?:id|name)=["\']([^"\']+)["\']\s*></a>(.*)$', re.I)
_INT_LINK = re.compile(r"\[([^\]]+)\]\(#([^)\s]+)\)")


def slugify(text: str) -> str:
    s = re.sub(r"[`*_]", "", text).strip().lower()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "section"


def valid_bm_name(name: str) -> str:
    """Return a Word-safe bookmark name: letters/digits/hyphens, starts with a letter."""
    s = _NAME_BAD.sub("-", name).lower()
    s = re.sub(r"-+", "-", s).strip("-")
    if not s:
        return "section"
    if not s[0].isalpha():
        s = "bm-" + s
    return s or "section"


def preprocess(md: str) -> str:
    """Normalise anchors/links so pandoc emits valid, preserved bookmarks.

    Word/DOCX bookmark names must start with a letter and - crucially here -
    pandoc rewrites any bookmark name longer than ~32 characters to a SHA-1
    hash, which desyncs bookmarks from their link targets. We avoid both:

      * Every heading gets a short, unique, letter-led id ``secN`` (well under
        the 32-char ceiling, so pandoc keeps the literal name).
      * Reference anchors become ``<div id="ref-N">`` (already short/valid).
      * Every internal link target ``#Y`` is rewritten to the same id used for
        its target (heading -> ``secN`` via heading_map, references kept as
        ``ref-N``), so bookmarks and links always match.

    The markdown's own bullet Table of Contents is preserved (its links are
    rewritten to the ``secN`` ids) so the document renders a clickable,
    field-free TOC the instant it is opened.
    """
    # First pass: assign short ids to headings and record anchor->secN map.
    lines = md.split("\n")
    heading_id: dict[int, str] = {}
    heading_map: dict[str, str] = {}
    pending: str | None = None
    index = 0
    for line in lines:
        m = _STANDALONE_ANCHOR.match(line)
        if m:
            pending = m.group(1)
            continue
        h = _HEADING.match(line)
        if h:
            index += 1
            hid = "sec%d" % index
            heading_id[index] = hid
            if pending is not None:
                heading_map[valid_bm_name(pending)] = hid
            heading_map[valid_bm_name(slugify(h.group(2).strip()))] = hid
            pending = None

    # Second pass: emit normalised markdown.
    out: list[str] = []
    pending = None
    index = 0
    for line in lines:
        m = _STANDALONE_ANCHOR.match(line)
        if m:
            pending = m.group(1)
            continue
        h = _HEADING.match(line)
        if h:
            text = h.group(2).strip()
            index += 1
            out.append("%s %s {#%s}" % (h.group(1), text, heading_id[index]))
            pending = None
            continue
        m = _INLINE_ANCHOR.match(line)
        if m:
            aid = valid_bm_name(m.group(1))
            rest = m.group(2).rstrip()
            out.append('<div id="%s">%s</div>' % (aid, rest))
            continue
        out.append(line)

    text = "\n".join(out)

    def _rewrite_link(m: re.Match) -> str:
        norm = valid_bm_name(m.group(2))
        target = heading_map.get(norm, norm)
        return "[%s](#%s)" % (m.group(1), target)

    text = _INT_LINK.sub(_rewrite_link, text)
    return text


_TABLE_SEP = re.compile(r"^\s*\|?[\s:\-|]+\|?\s*$")


def _has_markdown_table(md: str) -> bool:
    """Return True if the markdown contains at least one pipe-table.

    Mirror pandoc's pipe-table rule: a separator row (only ``-``, ``:`` and
    ``|``) must be immediately preceded by a header row that also contains a
    ``|``. This avoids false positives from horizontal rules (``---``) or prose
    lines that merely happen to match the separator shape.
    """
    in_fence = False
    lines = md.split("\n")
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if (
            "|" in line
            and "-" in line
            and _TABLE_SEP.match(line)
            and i > 0
            and "|" in lines[i - 1]
        ):
            return True
    return False


# ---------------------------------------------------------------------------
# DOCX post-processing: borders (dark-mode safe), landscape, autofit columns
# ---------------------------------------------------------------------------
#
# pandoc emits tables with no borders (so they vanish on a dark page) and a
# fixed column layout. Word also defaults to portrait, which clips the wide
# command/fleet tables. We patch the generated OOXML to match the RTF rules:
#   * every table gets single borders with w:color="auto" (black on a light
#     page, white on a dark page) so they stay visible in either theme;
#   * the column layout switches to "autofit" so Word sizes each column to its
#     content (the DOCX-native equivalent of the RTF priority-based resize:
#     first column natural/capped, a primary prose column takes the slack);
#   * any document that actually contains a table is set to landscape so the
#     full long-edge width is available.


def _add_table_borders_and_autofit(xml: str) -> str:
    def fix_tblpr(m: re.Match) -> str:
        pr = m.group(0)
        if re.search(r"<w:tblLayout\b", pr):
            pr = re.sub(
                r"<w:tblLayout\b[^>]*>",
                '<w:tblLayout w:type="autofit"/>',
                pr,
            )
        else:
            pr = pr.replace(
                "</w:tblPr>",
                '<w:tblLayout w:type="autofit"/></w:tblPr>',
                1,
            )
        if not re.search(r"<w:tblBorders\b", pr):
            borders = (
                "<w:tblBorders>"
                '<w:top w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                '<w:left w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                '<w:bottom w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                '<w:right w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                '<w:insideH w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                '<w:insideV w:val="single" w:sz="6" w:space="0" w:color="auto"/>'
                "</w:tblBorders>"
            )
            pr = pr.replace("</w:tblPr>", borders + "</w:tblPr>", 1)
        return pr

    return re.sub(r"<w:tblPr>.*?</w:tblPr>", fix_tblpr, xml, flags=re.S)


def _set_landscape(xml: str) -> str:
    def fix_sect(m: re.Match) -> str:
        sp = m.group(0)
        sp = re.sub(r"<w:pgSz\b[^>]*/>", "", sp)
        sp = re.sub(
            r"(<w:sectPr\b[^>]*>)",
            r'\1<w:pgSz w:w="%d" w:h="%d" w:orient="landscape"/>'
            % (LANDSCAPE_W, LANDSCAPE_H),
            sp,
            count=1,
        )
        return sp

    return re.sub(r"<w:sectPr\b.*?</w:sectPr>", fix_sect, xml, flags=re.S)


def _ensure_default_font_auto(sxml: str) -> str:
    """Defensively force the default run colour to "auto" (theme-aware)."""
    if "<w:color w:val=\"auto\"" in sxml:
        return sxml
    if "<w:rPrDefault>" in sxml:
        sxml = re.sub(
            r"(<w:rPrDefault>\s*<w:rPr[^>]*>)",
            r'\1<w:color w:val="auto"/>',
            sxml,
            count=1,
        )
        if "<w:color w:val=\"auto\"" not in sxml:
            sxml = re.sub(
                r"<w:rPrDefault>",
                "<w:rPrDefault><w:rPr><w:color w:val=\"auto\"/></w:rPr>",
                sxml,
                count=1,
            )
    else:
        sxml = re.sub(
            r"(<w:docDefaults[^>]*>)",
            r'\1<w:rPrDefault><w:rPr><w:color w:val="auto"/></w:rPr></w:rPrDefault>',
            sxml,
            count=1,
        )
    return sxml


def _post_process_docx(path: Path, landscape: bool) -> None:
    with zipfile.ZipFile(path, "r") as zin:
        names = zin.namelist()
        data = {n: zin.read(n) for n in names}

    document = data.get("word/document.xml")
    if document is not None:
        xml = document.decode("utf-8")
        xml = _add_table_borders_and_autofit(xml)
        if landscape:
            xml = _set_landscape(xml)
        data["word/document.xml"] = xml.encode("utf-8")

    styles = data.get("word/styles.xml")
    if styles is not None:
        data["word/styles.xml"] = _ensure_default_font_auto(
            styles.decode("utf-8")
        ).encode("utf-8")

    tmp = path.with_name(path.name + ".tmp")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, data[n])
    tmp.replace(path)


def convert_file(input_path: Path, output_path: Path, pandoc: str) -> int:
    md = preprocess(input_path.read_text(encoding="utf-8"))
    landscape = _has_markdown_table(md)
    with tempfile.NamedTemporaryFile(
        "w", suffix=".md", delete=False, encoding="utf-8"
    ) as f:
        f.write(md)
        tmp_md = Path(f.name)
    try:
        cmd = [
            pandoc,
            "-f", "markdown-tex_math_dollars",
            "--toc-depth=6",
            str(tmp_md), "-o", str(output_path)
        ]
        proc = subprocess.run(
            cmd, capture_output=True, text=True, check=False
        )
        if proc.returncode != 0:
            tail = (proc.stderr or "").strip().splitlines()
            msg = tail[-1] if tail else "pandoc exited with code %d" % proc.returncode
            raise RuntimeError(msg)
    finally:
        tmp_md.unlink(missing_ok=True)
    _post_process_docx(output_path, landscape)
    return output_path.stat().st_size


def discover_md_files(repo_root: Path):
    root = repo_root
    out_root = root / "docx"

    def pair(p: Path) -> tuple[Path, Path]:
        rel = p.relative_to(root)
        parts = rel.parts
        # Mirror the docs/ folder structure under docx/, stripping the leading
        # "docs/" prefix (e.g. docs/Automation/foo.md -> docx/Automation/foo.docx)
        # so the docx tree mirrors docs/. docs/-root files flatten to docx/ roots.
        if len(parts) >= 2 and parts[0] == "docs":
            rel = rel.relative_to("docs")
        return p, out_root / rel.with_suffix(".docx")

    # Root markdown docs (skip auto-generated agent instruction files).
    for p in sorted(root.glob("*.md")):
        if p.name in ("AGENTS.md", "CRUSH.md"):
            continue
        yield pair(p)

    docs = root / "docs"
    if docs.exists():
        for p in sorted(docs.rglob("*.md")):
            yield pair(p)

    wip = root / "wip"
    if wip.exists():
        for p in sorted(wip.glob("*.md")):
            yield pair(p)

    wip = root / "wip"
    if wip.exists():
        for p in sorted(wip.glob("*.md")):
            yield pair(p)


def _find_pandoc() -> str | None:
    for candidate in (
        shutil.which("pandoc"),
        str(Path.home() / "bin" / "pandoc"),
        "/home/keverall/bin/pandoc",
    ):
        if candidate and Path(candidate).exists():
            return candidate
    return None


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent

    if len(sys.argv) == 3:
        out = Path(sys.argv[2])
        out.parent.mkdir(parents=True, exist_ok=True)
        pandoc = _find_pandoc() or "pandoc"
        size = convert_file(Path(sys.argv[1]), out, pandoc)
        print("wrote %s (%d bytes)" % (sys.argv[2], size))
        return

    pandoc = _find_pandoc()
    if not pandoc:
        print("pandoc not found; install pandoc or add it to PATH", file=sys.stderr)
        sys.exit(1)
    out_root = repo_root / "docx"
    pairs = list(discover_md_files(repo_root))
    if not pairs:
        print("No source markdown files found.", file=sys.stderr)
        sys.exit(1)
    count = 0
    for src, out in pairs:
        out.parent.mkdir(parents=True, exist_ok=True)
        try:
            size = convert_file(src, out, pandoc)
            count += 1
            print("  wrote %s (%d bytes)" % (out, size))
        except Exception as e:  # noqa: BLE001
            print("  [WARN] failed to convert %s: %s" % (src, e), file=sys.stderr)
    print("Converted %d markdown files to DOCX under %s" % (count, out_root))


if __name__ == "__main__":
    main()
