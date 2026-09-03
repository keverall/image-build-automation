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


# ---------------------------------------------------------------------------
# DOCX styling via a pandoc reference-doc
# ---------------------------------------------------------------------------
#
# pandoc attaches ``<w:tblStyle w:val="Table"/>`` to every table it emits, but
# the default reference doc's "Table" style has NO borders (so tables are
# invisible in Word / Word for the Web). ``scripts/reference.docx`` therefore
# defines a "Table" style with single borders (theme-aware ``w:color="auto"``,
# so black on a light page, white on a dark page) and a landscape page setup,
# so every generated document renders bordered, landscape tables out of the
# box. Column widths are left to pandoc's content-proportional grid (the DOCX
# equivalent of the RTF priority-based resize) within the wide landscape page.

REFERENCE_DOCX = Path(__file__).resolve().parent / "reference.docx"

# Single light-grey borders, visible on both light and dark page backgrounds.
_BORDERS = (
    "<w:tblBorders>"
    '<w:top w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    '<w:left w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    '<w:bottom w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    '<w:right w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    '<w:insideH w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    '<w:insideV w:val="single" w:sz="6" w:space="0" w:color="808080"/>'
    "</w:tblBorders>"
)


def _inject_table_borders(xml: str) -> str:
    """Force single borders onto every table's tblPr (belt-and-suspenders with
    the reference-doc Table style) so Word for the Web always renders them."""

    def fix(m: re.Match) -> str:
        pr = m.group(0)
        if "<w:tblBorders" not in pr:
            pr = pr.replace("</w:tblPr>", _BORDERS + "</w:tblPr>", 1)
        return pr

    return re.sub(r"<w:tblPr>.*?</w:tblPr>", fix, xml, flags=re.S)


def _force_landscape(xml: str) -> str:
    def fix(m: re.Match) -> str:
        sp = m.group(0)
        sp = re.sub(r"<w:pgSz\b[^>]*/>", "", sp)
        sp = re.sub(
            r"(<w:sectPr\b[^>]*>)",
            r'\1<w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>',
            sp,
            count=1,
        )
        return sp

    return re.sub(r"<w:sectPr\b.*?</w:sectPr>", fix, xml, flags=re.S)


def _post_process(path: Path) -> None:
    with zipfile.ZipFile(path, "r") as zin:
        names = zin.namelist()
        data = {n: zin.read(n) for n in names}
    document = data.get("word/document.xml")
    if document is not None:
        xml = document.decode("utf-8")
        xml = _inject_table_borders(xml)
        xml = _force_landscape(xml)
        data["word/document.xml"] = xml.encode("utf-8")
    tmp = path.with_name(path.name + ".tmp")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, data[n])
    tmp.replace(path)


def convert_file(input_path: Path, output_path: Path, pandoc: str) -> int:
    md = preprocess(input_path.read_text(encoding="utf-8"))
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
        ]
        if REFERENCE_DOCX.exists():
            cmd += ["--reference-doc", str(REFERENCE_DOCX)]
        cmd += [str(tmp_md), "-o", str(output_path)]
        proc = subprocess.run(
            cmd, capture_output=True, text=True, check=False
        )
        if proc.returncode != 0:
            tail = (proc.stderr or "").strip().splitlines()
            msg = tail[-1] if tail else "pandoc exited with code %d" % proc.returncode
            raise RuntimeError(msg)
    finally:
        tmp_md.unlink(missing_ok=True)
    _post_process(output_path)
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
