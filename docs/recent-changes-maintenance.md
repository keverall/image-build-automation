# recent-changes.md — maintenance guide

<a id="top"></a>

## Table of Contents

- [Numbering convention](#numbering-convention)
- [Adding a new entry](#adding-a-new-entry)
- [Section template](#section-template)
  - [NN) One-line, title-case heading](#nn-one-line-title-case-heading)
- [Anchor conventions](#anchor-conventions)
- [Keeping the TOC + summary table in sync](#keeping-the-toc-summary-table-in-sync)
- [Running `make fix-docs` (this is how the TOC is regenerated)](#running-make-fix-docs-this-is-how-the-toc-is-regenerated)
- [Regenerating the DOCX corpus](#regenerating-the-docx-corpus)
- [Sorting discipline](#sorting-discipline)

How to keep `recent-changes.md` (the repo-wide changelog at the project root)
ordered, contiguous, and link-valid, and how to regenerate its Word DOCX.

<a id="numbering-convention"></a>

## Numbering convention

- Sections are numbered **contiguously `1..N` and stored in reverse-chronological order**: the **newest** change is `§N` (highest number, at the top) and the **oldest** is `§1` (at the bottom).
- The **date** in each section's `| Date | … | Author |` row is the source of truth for ordering. Numbers must follow that order — i.e. strictly descending in the file.
- If a section is ever deleted, **renumber** the remaining ones so the sequence stays `NN, NN-1, …, 2, 1` with no gaps. A gap is what makes the PO ask "where's §15?".

<a id="adding-a-new-entry"></a>

## Adding a new entry

1. Insert the new section as the **first** block under `## Change details` (newest first).
2. Number it **current max + 1** (e.g. after §38 → §39).
3. Date it today and add its row **first** in the `## Summary of changes` table. The `## Table of Contents` is generated from the headings — run `make fix-docs` to regenerate it (see below).
4. Update any narrative `§N` cross-references in older entries if their numbers shifted.

<a id="section-template"></a>

## Section template

```markdown

<a id="nn-one-line-title-case-heading"></a>

### NN) One-line, title-case heading

| **Date** | **Change description summary** | **Author** |  
| --- | --- | --- |
| 2026-09-03 | Concise bullet summary of what + why (≤ 1 line, no prose wrap). | Kev Everall |  

<a name="root-cause-NN"></a>

#### Root cause

What was broken / what assumption was wrong.

<a name="fix-NN"></a>

#### Fix

- **`affected/file.ext`** — what changed, how, and why this resolves it.
- Keep bullets parallel: file/area first, then change + rationale.

<a name="verification-NN"></a>

#### Verification

- Concrete checks: test counts, parser passes, regenerated artifacts, lint.
```

- `NN` is the section number; `<slug>` is the heading lower-cased, spaces → `-`, punctuation stripped (matches `## Table of Contents`.
- The `| Date | summary | Author |` row **must** be the first table in the section — it feeds the `## Summary of changes` table and the ordering. Without it the entry is unsorted/orphaned (this is exactly how a section ends up stranded at the bottom). The row text must be **identical** in the section and in the summary table — a divergence (e.g. a truncated section row) breaks the one-to-one mapping when the summary table is re-sorted.

<a id="anchor-conventions"></a>

## Anchor conventions

- **Section anchor** (above the heading): `<a id="NN-<slug>"></a>`.
- **Sub-anchors** (above each `####`): `<a name="root-cause-NN">`, `<a name="fix-NN">`, `<a name="verification-NN">`, `<a name="caveats-NN">`, and any custom ones (`scope-NN`, `commands-NN`, `callers-NN`, etc.). The trailing number **must** equal the section number — rename both together when renumbering.
- **Internal links** use these exact ids; `[NN) Title](#NN-<slug>)` in the TOC and `<a name="…-NN">` in sub-anchors.
- Headings themselves are `### NN) …`. Keep the `NN) ` prefix and the closing `)` — the TOC generator (and readers) key on it.

<a id="keeping-the-toc-summary-table-in-sync"></a>

## Keeping the TOC + summary table in sync

Two blocks reference every section by number:

1. `## Table of Contents` — `   - [NN) Title](#NN-<slug>)` per entry, newest first. **Auto-generated**: `make fix-docs` strips the old block and rebuilds it from the H2/H3 headings, sorting numbered runs newest/highest first (`Sort-NumberedTocRuns` in `scripts/Docs.Common.ps1`). Do not hand-edit it — manual edits are stripped and regenerated.
2. `## Summary of changes` — one `| date | summary | author |  ` row per entry, newest first. **Hand-maintained**: it is *not* regenerated, so add/move its row by hand.

Both must end up in the same order as the `## Change details` body (`NN, NN-1, …, 1`). When you add or renumber a section, update the summary table in the same pass (same position, same number), then run `make fix-docs` to regenerate the TOC.

<a id="running-make-fix-docs-this-is-how-the-toc-is-regenerated"></a>

## Running `make fix-docs` (this is how the TOC is regenerated)

`make fix-docs` runs `bitbucket-md-anchor-toc.ps1` → `Build-CanonicalContent` (`scripts/Docs.Common.ps1`), which:

- strips the existing `## Table of Contents` block and **regenerates** it from the H2/H3 headings — so there is always exactly one TOC, never a duplicate,
- places an `<a id="…"></a>` above every `H2`/`H3`,
- **sorts numbered runs** (`NN) …`) newest/highest first via `Sort-NumberedTocRuns`. The direction is inferred from the run's own first vs last number, so an ascending procedural doc (`1..N`) is left alone,
- **preserves** the manually-numbered `<a name="root-cause-NN">` / `<a name="fix-NN">` / `<a name="verification-NN">` sub-anchors: they precede `####` headings, and only H2/H3 anchors are regenerated.

It is idempotent — re-running makes no further changes once the file is canonical.

- Run `make fix-docs` after adding/renumbering a section to regenerate the TOC.
- To **validate links** without rewriting the file, use the dry-run: `make fix-docs-dryrun`.

<a id="regenerating-the-docx-corpus"></a>

## Regenerating the DOCX corpus

The Word DOCX artifacts are generated (not hand-edited):

```bash
make word-docs          # all root *.md + docs/**/*.md + wip/*.md -> ./docx/
make word-docs-clean    # rm -rf docx/
```

- Output mirrors `docs/` under the project-root `docx/` (no `docs/` prefix): `docs/Automation/foo.md` → `docx/Automation/foo.docx`.
- Root docs (`README.md`, `recent-changes.md`, …) land at `docx/<name>.docx`. `wip/SSO.md` → `docx/wip/SSO.docx`.
- `docx/` is not in `.gitignore`; commit the regenerated set when the changelog/docs change.

<a id="sorting-discipline"></a>

## Sorting discipline

- **Newest first = highest number first.** The `## Change details` body, the `## Table of Contents`, and the `## Summary of changes` table must **all** read `NN, NN-1, …, 2, 1` top-to-bottom (currently `38, 37, …, 1`). The number is the sequence — date each entry, but order by number.
- **Keep the body physically in that order.** The TOC is generated from the headings and normalised by `Sort-NumberedTocRuns`, so a scrambled body would still produce a sorted TOC — but the document has to read in order top-to-bottom, so fix the **body**, not just the TOC.
- **Contiguous numbers** follow that order: after sorting, numbers read `38, 37, 36, …, 2, 1` with no gaps. If they don't, renumber.
- If you can't run `make word-docs` (pandoc not installed), the source of truth is `wip/SSO.md` + the `<a id>`/`<a name>` scheme above; the DOCX is regenerated from that.
