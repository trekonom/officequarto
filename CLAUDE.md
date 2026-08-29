# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`officequarto` is a prototype Quarto extension. It lets any existing Word document act as the
`reference-doc` for a Quarto/Pandoc docx render (styles, layout, headers/footers, section
properties carry over natively via Pandoc), and adds a post-render hook that writes document
metadata and remapped paragraph styles back into a copy of that original document. It mirrors the
idea behind the R package {officedown}, but ships as an installable Quarto extension instead.

Not a package in the traditional sense — there is no build/lint/test tooling beyond the R scripts
described below. Not currently version-controlled with any CI.

## Commands

Render the example project and verify the hook end-to-end:

```bash
cd template
quarto render report.qmd
Rscript ../dev/check_writeback.R   # checks header/footer/body/metadata/style-mapping/style-pruning of the result
```

`template/report.qmd` includes a small fenced code block specifically so the style-pruning
"removed but still referenced" warning path (see below) has real coverage, not just the
always-safe unused-style case.

`template/_extensions` is a symlink to `../_extensions` — this is how the extension is exercised
during development without a separate `quarto add` install. `template/_quarto.yml` sets
`officequarto-keep-rendered: true`, so rendering produces `report.docx` (final, in-place
overwritten) and `report.quarto-rendered.docx` (the pre-write-back debug copy) in `template/`
(both gitignored); clean up with:

```bash
rm -f template/report.docx template/report.quarto-rendered.docx
rm -rf template/.quarto template/report_files
```

Regenerate the sample template (`template/original.docx`), including the four ACME custom
paragraph styles used to test style-mapping (body/bullet/number/code-block):

```bash
Rscript dev/make_sample_docx.R   # needs R packages: officer, xml2
```

To verify the extension also works as a genuine external install (not just via the dev symlink),
`quarto add <path-to-this-repo>` into a throwaway project and repeat the render/check above.

There is no linter/formatter configured for the R scripts in this repo.

## Architecture

```
_extensions/officequarto/
├── _extension.yml            contributes: project: { project: { type: default,
│                                                       post-render: [scripts/writeback.R] } }
└── scripts/
    ├── writeback.R           post-render hook: orchestration (env vars, quarto inspect,
    │                         metadata merge, zip/unzip), sources style_mapping.R + style_pruning.R
    ├── style_mapping.R       style-mapping core logic (pure functions, no side effects of
    │                          its own — called from writeback.R)
    └── style_pruning.R       style-pruning core logic (pure functions, no side effects of
                               its own — called from writeback.R)

template/                     example/dev project
├── _quarto.yml                project: type: officequarto; format.docx.reference-doc +
│                               format.docx.officequarto-styles + officequarto-pandoc-styles
│                               + officequarto-keep-rendered
├── original.docx              sample reference-doc (custom header/footer/properties/styles)
└── report.qmd                 the .qmd rendered against original.docx
```

### Render/write-back flow

1. Quarto/Pandoc render the `.qmd` with `original.docx` as `reference-doc`. This alone is enough
   to inherit styles, headers, footers, and section properties from the original — native Pandoc
   behavior, no custom code involved.
2. `scripts/writeback.R` runs automatically as a post-render hook. For each rendered `.docx`
   output it:
   - Resolves `reference-doc` and the optional `officequarto-styles`/`officequarto-pandoc-styles`/
     `officequarto-keep-rendered` config via `quarto inspect <project_dir>` (parsed JSON) rather
     than hand-parsing `_quarto.yml` — this correctly reflects resolved/merged config.
   - Unzips the rendered docx into a temp `work_dir`.
   - Merges `docProps/core.xml` fields (`dc:subject`, `cp:keywords`, `dc:description`,
     `cp:category`) and copies `docProps/custom.xml` from the original — these are the properties
     Pandoc does *not* carry over from `reference-doc` (it writes fresh, largely empty ones).
   - If `officequarto-styles` is configured, applies style-mapping to `word/document.xml` (see
     below) via `style_mapping.R`.
   - Always (unconditionally, no config): removes every style definition in the rendered
     `word/styles.xml` whose ID isn't present in `reference-doc`'s own `word/styles.xml` (see
     "Style pruning" below).
   - If `officequarto-keep-rendered` is `true`, copies the still-untouched rendered docx to
     `<name>.quarto-rendered.docx` before it gets overwritten (debug artifact, analogous to
     Quarto's own `keep-md`).
   - Re-zips `work_dir` into a temp file, then copies that over the original rendered path
     in-place — there is no separate `<name>.written-back.docx` output file anymore.
3. There is deliberately **no** manual body-splice step (originally planned, later dropped — see
   "Body write-back" below).

### Body write-back — why it doesn't exist

The original design planned to strip the original docx's body and splice in the rendered content
manually (via `officer::body_add_docx()`). This was abandoned: Pandoc's `reference-doc` mechanism
already reproduces headers/footers/section-properties correctly on its own, and the manual splice
hit an `officer 0.7.3` bug (`process_sections_content`/`extract_hof` row-count mismatch) when
merging two structurally similar documents. `writeback.R` therefore treats the Pandoc-rendered
docx as already correct for body/header/footer/layout, and only patches metadata and styles on top
of it. See `dev/spike-notes.md` (Spike A) for the full empirical trail.

### Style-mapping (`officequarto-styles`)

Configured under `format: docx: officequarto-styles: { body, list-bullet, list-number }` (all
optional, independent). Values are Word **display names** (`w:name`), not internal style IDs —
`style_mapping.R` resolves those against `word/styles.xml` of the rendered output and aborts with
the list of available paragraph styles if a configured name isn't found (fail loud, no silent
fallback).

Key empirical fact driving the implementation (verified against real rendered output, not just
Pandoc docs — see `dev/spike-notes.md` Spike D): Pandoc does **not** use one fixed style ID for
body text and one for lists. It picks context-dependent style names that must already exist in
`reference-doc` (e.g. `FirstParagraph` for the paragraph right after a heading, `Compact` for
tight-list items — used for **both** bullet and numbered lists identically). Consequences for the
detection logic in `style_mapping.R`:

- **List paragraphs** are detected by the presence of `<w:numPr>`, never by style name.
- Bullet vs. numbered is resolved via `word/numbering.xml`: `numId` → `abstractNumId` → level-0
  `w:numFmt` (`bullet` vs. anything else). One style per list *type*, not per nesting level —
  matches {officedown}'s `ol.style`/`ul.style` design.
- **Body paragraphs** (no `<w:numPr>`) are matched against an allowlist of known Pandoc body-role
  style names (`officequarto_body_role_styles` in `style_mapping.R`: `Normal`, `FirstParagraph`,
  `Compact`, `BodyText`, `Body Text`). A reference-doc that makes Pandoc pick a body role outside
  this list will not be recognized — documented limitation.
- Only `word/document.xml` (main body) is patched — not footnotes/comments.

### Style pruning (always on by default)

Pandoc's docx writer unconditionally adds its own style definitions on top of whatever
`reference-doc` defines — most visibly a full set of syntax-highlighting styles (`SourceCode`,
`*Tok`) for code blocks, even when the rendered document has none (verified empirically:
`original.docx` has 27 styles, the raw Pandoc output has 59 — all 32 extras, nothing from the
original lost; also verified against `../hello-wordto`'s real 476-style UU template: 508 raw →
476 pruned, exact match). {officedown} has the same behavior; it's Pandoc's docx writer, not
something specific to `reference-doc`. `style_pruning.R` removes every style in the rendered
`word/styles.xml` whose ID isn't in `reference-doc`'s own `word/styles.xml`. If a to-be-removed
style is still referenced somewhere in the rendered content
(`w:pStyle`/`w:rStyle`/`w:tblStyle` in `document.xml`/`footnotes.xml`/`endnotes.xml`/`comments.xml`
— e.g. a real code block, or Pandoc's own body/list role names like `FirstParagraph`/`Compact` when
`officequarto-styles` isn't configured for that role and `reference-doc` doesn't happen to define
them), it is still removed and `writeback.R` logs a warning; the affected content falls back to
Word's default formatting rather than erroring out. Runs independently of whether
`officequarto-styles` is configured, always after the style-mapping step (so it prunes against the
final, already-remapped `document.xml`).

`oq_is_pandoc_code_style_id(id)` in `style_pruning.R` identifies Pandoc's fixed syntax-highlighting
style-ID family (`id == "SourceCode" | grepl("Tok$", id)` — a stable naming convention of Pandoc's
docx writer). `dev/check_writeback.R` sources `style_pruning.R` directly to reuse this helper
rather than duplicating the pattern.

**Escape hatch: `officequarto-pandoc-styles.code-block`** (optional, default unset → prune as
above). Deliberately a separate top-level section, sibling of `officequarto-styles` under
`format.docx` (not nested inside `officequarto-styles`) — it's about Pandoc-added styles, not about
remapping reference-doc styles, and is independent of whether `officequarto-styles` is configured
at all (`writeback.R` gates the whole style-mapping block on `!is.null(style_config) ||
!is.null(code_block_config)`, not on `style_config` alone, so `code-block` works standalone):
- `true` — exempts `SourceCode` + all `*Tok` styles from pruning entirely (`writeback.R` computes
  `union(ref_style_ids, code_style_ids)` as the keep-set passed to `oq_prune_foreign_styles`, which
  needed no signature change for this). Pandoc's own code-block styling, including syntax-
  highlighting colors, survives untouched.
- a style name (string) — resolved via the same `oq_resolve_style_id` used for `body`/
  `list-bullet`/`list-number` (that function takes the fully-qualified config key, e.g.
  `"officequarto-pandoc-styles.code-block"` vs. `"officequarto-styles.body"`, for its error
  message), then `style_ids$code` is applied in `oq_apply_style_mapping`'s paragraph loop via a
  direct `current == "SourceCode"` equality check (not an allowlist — unlike
  `Normal`/`FirstParagraph`/`Compact`, `SourceCode` is a stable, non-context-dependent Pandoc ID).
  Only the paragraph role is remapped; the `*Tok` character styles are deliberately **not**
  exempted from pruning in this case — block formatting and syntax-highlighting colors are treated
  as independent concerns (explicit design decision, not an oversight).
- Anything else (e.g. a number) fails loudly at the top of `writeback.R`, before the per-output-file
  loop, consistent with this project's fail-loud philosophy elsewhere.

### Key constraints/gotchas

- **Project-only feature**: post-render hooks are a Quarto *project* feature; they do not fire for
  `quarto render singlefile.qmd` without a `_quarto.yml` project (upstream limitation, not
  something this extension can work around).
- **`quarto add` alone does not activate the hook.** A consuming project's own `_quarto.yml` must
  set `project: type: officequarto` — otherwise `writeback.R` never runs. Verified by counter-test
  in `dev/spike-notes.md` (Spike B).
- Reading resolved config always goes through `quarto inspect <project_dir>` (JSON), never manual
  YAML parsing — this is what makes nested keys like `format.docx.officequarto-styles` reliable.
- Locating `style_mapping.R` from within `writeback.R` uses the `commandArgs(trailingOnly=FALSE)`
  `--file=` trick (`get_script_dir()`), because Quarto's post-render invocation cwd cannot be
  assumed to be the script's own directory.
- xml2 attribute writes on OOXML nodes must use the namespaced attribute name, i.e.
  `xml_attr(node, "w:val") <- x`, not `xml_attr(node, "val") <- x` (the latter creates an
  unnamespaced attribute and silently produces invalid/ignored XML).
- All docx manipulation goes through `zip`/`unzip` (CLI, via `system2()`) + `xml2`, not `officer`
  — `officer` is only used in `dev/make_sample_docx.R` to build the base sample document (plus
  direct `xml2` XML injection there too, since `officer` has no high-level API to define new
  paragraph styles).
- The final write step zips into a `tempfile()` first, then `file.copy()`s that over the rendered
  path — never zips directly onto the file being overwritten, so a failed/partial zip can't corrupt
  the only output file that exists.
- Since the rendered `.docx` is overwritten in place, having it open in another app (e.g. Word) at
  render time can make the overwrite fail or go unnoticed until the app reloads the file — verified
  in practice against a real external consumer project.
