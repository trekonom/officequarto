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
Rscript ../dev/check_writeback.R        # checks header/footer/body/metadata/style-mapping/style-pruning of the result
Rscript ../dev/check_option_aliases.R   # unit-checks oq_resolve_aliased()/oq_resolve_inverted_aliased()
Rscript ../dev/check_caption_parsing.R  # unit-checks oq_split_caption_text() (table caption text-splitting)
Rscript ../dev/check_style_map.R        # unit-checks oq_resolve_style_map()/oq_apply_style_map()
Rscript ../dev/check_crossref.R         # unit-checks oq_apply_crossref_text()
```

`template/report.qmd` includes a small fenced code block specifically so the style-pruning
"removed but still referenced" warning path (see below) has real coverage, not just the
always-safe unused-style case.

`template/_extensions` is a symlink to `../_extensions` — this is how the extension is exercised
during development without a separate `quarto add` install. `template/_quarto.yml` sets
`officequarto.keep-rendered: true`, so rendering produces `report.docx` (final, in-place
overwritten) and `report.quarto-rendered.docx` (the pre-write-back debug copy) in `template/`
(both gitignored); clean up with:

```bash
rm -f template/report.docx template/report.quarto-rendered.docx
rm -rf template/.quarto template/report_files
```

Regenerate the sample template (`template/original.docx`), including the nine ACME custom
paragraph styles used to test style-mapping (body/bullet/number/letter/code-block/table-caption/
plot/plot-caption/title):

```bash
Rscript dev/make_sample_docx.R   # needs R packages: officer, xml2
```

To verify the extension also works as a genuine external install (not just via the dev symlink),
`quarto add <path-to-this-repo>` into a throwaway project and repeat the render/check above.

There is no linter/formatter configured for the R scripts in this repo.

## Workflow

New features (and exploratory/spike work) should always be implemented on a feature branch, not
directly on `main` — create the branch first, then do the work. Only merge to `main` once the
feature/spike is complete and reviewed.

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
    ├── style_pruning.R       style-pruning core logic (pure functions, no side effects of
    │                          its own — called from writeback.R)
    ├── option_aliases.R      canonical-name/officedown-alias resolution (pure functions, no
    │                          side effects of its own — called from writeback.R)
    ├── table_mapping.R       table style/layout/width/conditional-formatting core logic
    │                          (pure functions, no side effects of its own — called from
    │                          writeback.R)
    ├── table_caption_mapping.R  table caption style/prefix/separator/bold core logic
    │                          (pure functions, no side effects of its own — called from
    │                          writeback.R)
    ├── plot_mapping.R        figure style/align core logic (pure functions, no side
    │                          effects of its own — called from writeback.R)
    ├── plot_caption_mapping.R  figure caption paragraph detection (pure functions, no
    │                          side effects of its own — called from writeback.R; the
    │                          actual text-rewriting logic lives in table_caption_mapping.R
    │                          and is shared, not duplicated)
    ├── style_map.R           free-form style-map (officedown: mapstyles) core logic
    │                          (pure functions, no side effects of its own — called from
    │                          writeback.R)
    ├── page_mapping.R        page size/margins core logic (pure functions, no side
    │                          effects of its own — called from writeback.R)
    └── crossref_mapping.R    cross-reference text rewriting core logic (pure functions,
                               no side effects of its own — called from writeback.R)

template/                     example/dev project
├── _quarto.yml                project: type: officequarto; format.docx.reference-doc +
│                               format.docx.officequarto (styles/lists/pandoc-styles/
│                               keep-rendered/...)
├── original.docx              sample reference-doc (custom header/footer/properties/styles)
└── report.qmd                 the .qmd rendered against original.docx
```

### Render/write-back flow

1. Quarto/Pandoc render the `.qmd` with `original.docx` as `reference-doc`. This alone is enough
   to inherit styles, headers, footers, and section properties from the original — native Pandoc
   behavior, no custom code involved.
2. `scripts/writeback.R` runs automatically as a post-render hook. For each rendered `.docx`
   output it:
   - Resolves `reference-doc` and the optional `officequarto.styles`/`officequarto.lists`/
     `officequarto.pandoc-styles`/`officequarto.keep-rendered` config via
     `quarto inspect <project_dir>` (parsed JSON) rather than hand-parsing `_quarto.yml` — this
     correctly reflects resolved/merged config.
   - Unzips the rendered docx into a temp `work_dir`.
   - Merges `docProps/core.xml` fields (`dc:subject`, `cp:keywords`, `dc:description`,
     `cp:category`) and copies `docProps/custom.xml` from the original — these are the properties
     Pandoc does *not* carry over from `reference-doc` (it writes fresh, largely empty ones).
   - If `officequarto.styles`/`officequarto.lists` is configured, applies style-mapping to
     `word/document.xml` (see below) via `style_mapping.R`.
   - Always (unconditionally, no config): removes every style definition in the rendered
     `word/styles.xml` whose ID isn't present in `reference-doc`'s own `word/styles.xml` (see
     "Style pruning" below).
   - If `officequarto.keep-rendered` is `true`, copies the still-untouched rendered docx to
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

### Configuration namespace (`officequarto`, single top-level key)

All configuration lives under one `format.docx.officequarto` key — no `officequarto-`-prefixed
sibling keys directly under `format.docx` (an earlier design; explicitly restructured on the
user's request, since the growing number of sibling keys had gotten verbose). Every option group
is a subsection inside it: `officequarto.styles`, `officequarto.lists`, `officequarto.tables`,
`officequarto.plots`, `officequarto.style-map`, `officequarto.page`, `officequarto.crossref`,
`officequarto.pandoc-styles`, plus the scalar `officequarto.keep-rendered`. `writeback.R` reads the
whole block once (`officequarto_config <- inspect$config$format$docx$officequarto`) and passes each
named sub-list down to the relevant group's config-resolution code — the resolution logic itself
(`oq_resolve_aliased()` etc.) is unaffected, since it already only ever saw the sub-list for its
own group, never the full `format.docx` object. As part of this restructuring, list options
(`list-bullet`/`list-number`/`list-letter`) were split out of the old combined
`officequarto-styles` into their own `officequarto.lists` subsection, sibling to
`officequarto.tables`/`officequarto.plots` — see "Style-mapping" below. This is a breaking change
with no back-compat fallback for the old flat keys (consistent with this project's prototype status
and no-backwards-compat-hacks philosophy) — `template/_quarto.yml` was migrated; `../hello-wordto`
(external consumer project) was deliberately left on the old schema, out of scope for this change.

### Style-mapping (`officequarto.styles.body`, `officequarto.lists.*`)

Body text is configured under `officequarto.styles: { body }`; list options live in their own
sibling subsection, `officequarto.lists: { list-bullet, list-number, list-letter }` — split out
from a single combined `styles` section specifically so it could mirror `officequarto.tables`/
`officequarto.plots` as its own named group (see "Configuration namespace" above). All fields
across both subsections are optional, independent. Values are Word **display names** (`w:name`),
not internal style IDs — `style_mapping.R` resolves those against `word/styles.xml` of the
rendered output and aborts with the list of available paragraph styles if a configured name isn't
found (fail loud, no silent fallback).

Key empirical fact driving the implementation (verified against real rendered output, not just
Pandoc docs — see `dev/spike-notes.md` Spike D): Pandoc does **not** use one fixed style ID for
body text and one for lists. It picks context-dependent style names that must already exist in
`reference-doc` (e.g. `FirstParagraph` for the paragraph right after a heading, `Compact` for
tight-list items — used for **both** bullet and numbered lists identically). Consequences for the
detection logic in `style_mapping.R`:

- **List paragraphs** are detected by the presence of `<w:numPr>`, never by style name.
- List type is resolved via `word/numbering.xml`: `numId` → `abstractNumId` → level-0
  `w:numFmt`. `bullet` → `list-bullet`; `lowerLetter`/`upperLetter` (produced by Pandoc from
  markdown `a.`/`A.` list markers — verified empirically, see `dev/spike-notes.md`) →
  `list-letter` (`officequarto_letter_num_fmts` in `style_mapping.R`; officequarto-only, no
  officedown equivalent); anything else (`decimal`, roman numerals, ...) → `list-number`. One
  style per list *type*, not per nesting level — matches {officedown}'s `ol.style`/`ul.style`
  design.
- **Body paragraphs** (no `<w:numPr>`) are matched against an allowlist of known Pandoc body-role
  style names (`officequarto_body_role_styles` in `style_mapping.R`: `Normal`, `FirstParagraph`,
  `Compact`, `BodyText`, `Body Text`). A reference-doc that makes Pandoc pick a body role outside
  this list will not be recognized — documented limitation.
- Only `word/document.xml` (main body) is patched — not footnotes/comments.

### Option aliases (`option_aliases.R`)

`officequarto`'s own option names (`officequarto.lists.list-bullet`/`list-number`, and future
ported {officedown} option groups) are deliberately **not** a mechanical 1:1 translation of
{officedown}'s option names (only `.` → `_`) — they're chosen fresh, to read clearly on their own
without prior {officedown} knowledge. To ease migration for {officedown} users, the original
{officedown} option name (`.` → `_`, e.g. `ol_style`, `ul_style`) remains usable as an **alias**
within the same config section, resolving to the same value as the canonical name.

`oq_resolve_aliased(config, canonical_key, alias_key, group_label, warn_fn)` in
`option_aliases.R` implements this: if both keys are set to the same value, or only one is set,
that value is used silently; if both are set to *different* values, the canonical key wins and
`warn_fn` is called with a message naming the discarded alias value (`writeback.R` wires this to
`log_msg` via a small `warn_msg` wrapper, prefixed `"Warnung: "` — same pattern as `fail_fn` in
`oq_resolve_style_id`, so this file stays a pure function collection with no side effects of its
own, consistent with `style_mapping.R`/`style_pruning.R`). This is the reference pattern for
porting further {officedown} option groups (tables, captions, page layout, etc.) — each new
canonical option that has an {officedown} equivalent should resolve through
`oq_resolve_aliased()` the same way `list-bullet`/`list-number` do for `ul_style`/`ol_style`.

### Table options (`officequarto.tables`, `table_mapping.R`)

Gruppe 1 of the ongoing {officedown}-option port (see `README.md`'s Option reference table for the
full canonical-name/alias list, filled in incrementally as further groups land). Configured under
`format: docx: officequarto: tables: { style, layout, width }`, each field independently optional
(per-field opt-in, same philosophy as `officequarto.styles`/`officequarto.lists` — an unset field is left exactly as
Pandoc rendered it; **deliberately no** auto-fill with officedown's own always-on defaults
(`style: "Table"`, `layout: "autofit"`, `width: 1.0`), since those are officedown-template-specific
assumptions that would fail loudly for most real-world `reference-doc` files that don't happen to
define a table style literally named `"Table"` — explicit design decision, confirmed with the
user). `style`/`layout`/`width` also accept the officedown aliases `tables_style`/`tables_layout`/
`tables_width` via `oq_resolve_aliased()` (see "Option aliases" above), resolved once per render
(not per output file, since config doesn't vary per file) into `table_style_val`/
`table_layout_val`/`table_width_val` in `writeback.R`.

- `style` is resolved against `reference-doc`'s **table**-type styles, not paragraph styles —
  `oq_style_name_to_id()` in `style_mapping.R` was generalized with a `type` parameter
  (`"paragraph"` default, `"table"` for this) rather than duplicated, since the display-name → 
  styleId lookup logic is identical for both OOXML style types.
- `layout`/`width` are written directly onto every `w:tbl`'s `w:tblPr` (`oq_apply_table_options()`
  in `table_mapping.R` finds/creates `w:tblPr` for each `w:tbl` in `word/document.xml`, applying
  whichever of `style`/`layout`/`width` were configured). `layout` maps 1:1 to OOXML's
  `w:tblLayout/@w:type` (`autofit`/`fixed`, validated against exactly those two values, fail-loud
  otherwise); `width` (0..1, relative to page width) maps to `w:tblW` with `w:type="pct"` and
  `w:w` in fiftieths-of-a-percent (`round(width * 5000)`, so `100%` = `5000`).
- New `w:tblPr` child elements are inserted at their OOXML-schema-correct position
  (`officequarto_tblpr_order` in `table_mapping.R`, `oq_add_tbl_pr_child()`), not blindly appended
  — verified empirically that a naively appended `w:tblLayout` lands after Pandoc's own
  `w:tblLook`, which is out of CT_TblPrBase's defined child sequence; Word itself tolerates this,
  but schema-correct order is the more portable choice.
- Paragraph-style-mapping and table-option application now share a single read/write pass over
  `word/document.xml` per output file (previously only paragraph-style-mapping owned that
  read/write) — the combined gate is `!is.null(style_config) || !is.null(code_block_config) ||
  !is.null(table_config)`, with `styles_doc`/`document_doc` read once and `document_doc` written
  once at the end, each sub-feature applied conditionally in between.

### Table conditional formatting (`officequarto.tables.conditional`, Gruppe 2)

Maps onto `w:tblLook`, the OOXML element controlling which of a table style's conditional
formatting variants apply (Word's "Table Style Options" checkboxes: Header Row, Total Row,
First/Last Column, Banded Rows/Columns) — already present on every Pandoc-rendered table (verified
empirically, `w:tblLook` with `firstRow`/`lastRow`/`firstColumn`/`lastColumn`/`noHBand`/`noVBand`
plus a legacy `w:val` bitmask that officequarto deliberately leaves untouched, since modern Word
reads the individual named attributes, not the legacy bitmask). Each of `first-row`/`first-column`/
`last-row`/`last-column`/`band-rows`/`band-columns` is independently optional, same per-field
opt-in philosophy as Gruppe 1.

`band-rows`/`band-columns` are a deliberate polarity flip from officedown's `no_hband`/`no_vband`
(negative/double-negative naming, confirmed with the user before implementing) — the OOXML
attributes themselves (`noHBand`/`noVBand`) stay negatively phrased, so the inversion happens only
at the officequarto option layer: `oq_apply_table_options()`/`oq_set_tbl_look()` in
`table_mapping.R` hold the resolved values in `officequarto`'s own positive polarity and invert
only when writing the `noHBand`/`noVBand` OOXML attribute (`officequarto_tbllook_attrs` maps each
canonical field to its OOXML attribute name plus an `invert` flag).

Because canonical and alias now have *opposite* polarity for `band-rows`/`band-columns`
(`no_hband: false` means the same thing as `band-rows: true`), the existing `oq_resolve_aliased()`
doesn't apply as-is — its conflict check compares raw values for equality, which would be
misleading across a polarity flip. `oq_resolve_inverted_aliased()` (`option_aliases.R`) is the
same-shaped sibling function for this one case: it negates the alias's raw value before comparing
against/falling back from the canonical value. `oq_resolve_table_bool_option()` (`table_mapping.R`)
wraps whichever of the two applies (via an `invert` flag) plus fail-loud boolean-type validation,
used for all six conditional fields in `writeback.R`.

### Table captions (`officequarto.tables.caption`, `table_caption_mapping.R`, Gruppe 3)

The hardest group implemented so far, because Quarto's docx table captions currently render as
**static, already-baked-in text** (`"Table 1: My caption"` as a single `<w:r><w:t>` run, verified
empirically — see `dev/spike-notes.md` for the full trail), not a real Word field. There is no
live number to reformat around; `officequarto` has to locate and text-parse the already-rendered
caption instead.

- **Detection**: Pandoc actually has **two** structurally different representations for a
  captioned table, depending on whether the table carries a Quarto crossref ID (verified
  empirically against a real external consumer project, `../hello-wordto`, whose plain — non-
  crossref — captions were silently unstyled until this was found and fixed; see `dev/spike-
  notes.md` Spike L for the full trail): with a `{#tbl-xyz}` ID, Pandoc wraps caption+table in a
  synthetic 1×1 "wrapper" table (single cell holding the caption paragraph, styled
  `ImageCaption`, immediately followed by the real, nested table); *without* a crossref ID (plain
  `: My caption` markdown syntax), there is **no wrapper at all** — the caption paragraph (styled
  `TableCaption`, a different, dedicated ID — not shared with figures in this case) sits as a
  plain sibling immediately before the real `w:tbl`, both direct children of `w:body`.
  `oq_find_table_caption_paragraphs()` therefore matches a paragraph styled `TableCaption` *or*
  `ImageCaption` whose **immediately following sibling** is a `w:tbl` — adjacency, not "parent has
  a `w:tbl` child anywhere", which was the original (and, for the non-wrapped case, broken)
  design: `w:body` almost always contains *some* `w:tbl` somewhere, so that looser check matched
  every `ImageCaption` paragraph in the whole document, including figure captions elsewhere in the
  body — table and figure captions ended up silently swapped. `oq_table_caption_content()` (used
  by `$above`, see "Caption position" below) was fixed the same way: it now returns the caption
  paragraph's immediately-following-sibling `w:tbl` directly, instead of searching the parent for
  *a* `w:tbl` child (which, in the non-wrapped case, could return an unrelated table elsewhere in
  the body). Plain (non-crossref) captions are also never numbered by Quarto at all — the caption
  text is the user's own, with no generated "Table N:" prefix — which matters for
  `oq_split_caption_text()`'s digit-anchoring below: a plain caption's text could in principle
  contain a digit that accidentally matches officequarto's own running caption count, causing a
  spurious (harmless but semantically meaningless) split; documented as a known edge case, not
  fixed, since it doesn't misapply anything when `prefix`/`separator`/`number-bold` aren't
  configured for that caption.
- **The wrapper table itself is a trap for Gruppe 1/2**: `oq_apply_table_options()`'s table
  selector is `//w:tbl[not(.//w:tbl)]` (excludes any `w:tbl` containing a nested `w:tbl`) —
  discovered as a real bug during Gruppe 3 testing: without this filter, `style`/`layout`/`width`/
  `conditional` were being applied to Pandoc's invisible structural wrapper table too, not just the
  real data table inside it. `check_writeback.R`'s own table-lookup XPath needed the identical
  fix.
- **style** remaps the `ImageCaption` pStyle exactly like `code-block` remaps `SourceCode` (direct
  equality, not an allowlist — Pandoc's own fixed ID).
- **prefix/separator/number-bold** require locating the split point between Pandoc's
  auto-generated prefix and the user's actual caption text within that single run.
  `oq_split_caption_text()` does this by anchoring on the **number itself**, not the surrounding
  text — the generated prefix's shape depends on the user's own `crossref.tbl-title`/`title-delim`
  settings *and* gets reshaped by Pandoc's own smart-typography conversion (verified empirically: a
  configured `title-delim: "--"` renders as a real "–" character, with a non-breaking space before
  the number), so reconstructing the expected string from config is unreliable — but digits survive
  typographic conversion untouched. `officequarto` counts captioned-table paragraphs in document
  order itself (identical to how Quarto numbers them, since only captioned tables produce a caption
  paragraph at all) and anchors the split via a digit-boundary lookaround regex (`(?<!
  [\p{L}\p{N}])N(?![\p{L}\p{N}])`) so e.g. expected number `1` doesn't falsely match inside `1990`
  appearing in the caption text itself. If the expected number isn't found in the anchorable form,
  the caption is left untouched rather than guessed at (`matched = FALSE`).
- **number-bold** splits the single run into two (`oq_write_caption_run()`): the first carries
  `prefix + number` with an explicit `w:b` (`"1"`/`"0"`, always written when configured — even
  `false`, to explicitly override any bold inherited from the paragraph style rather than silently
  no-op), the second carries `separator + rest` with no explicit bold override, so it inherits
  whatever the (possibly remapped) caption style itself specifies. Any further pre-existing runs
  after the first (e.g. inline formatting inside a human-authored multi-run caption) are left
  completely untouched and remain correctly positioned after the new second run, since only the
  first run's text is ever parsed/split.
- **Not ported**: officedown's `tnd`/`tns` (per-section numbering depth, e.g. `"2-1"`) — Quarto
  numbers tables globally, not per heading section, so there's no existing counter to key off of;
  replicating this would mean officequarto independently tracking heading boundaries and
  maintaining its own numbering scheme, substantially bigger than anything else in this port.

### Figure options (`officequarto.plots`, `plot_mapping.R`, Gruppe 4)

Mirrors Gruppe 1's `style` for the paragraph holding a figure, plus `align` (maps to `w:jc`, find-
or-create like `w:tblLayout`/`w:tblW` in Gruppe 1). Figure paragraphs are detected via presence of
a `w:drawing` descendant (`oq_find_plot_paragraphs()`) rather than by style name — verified
empirically (rendering a minimal figure) that Pandoc assigns the SAME context-dependent role name
to image paragraphs as to body-text paragraphs (e.g. `Compact`), meaning `officequarto.styles.body`
would otherwise silently also remap image paragraphs. Fixed by excluding any paragraph containing
a `w:drawing` from the body-role check in `oq_apply_style_mapping()` (`style_mapping.R`) — the two
features now cleanly own disjoint sets of paragraphs.

Figures are ALSO wrapped in Pandoc's synthetic 1×1 caption-wrapper table (same mechanism as
Gruppe 3's captioned tables) whenever they have a caption — this surfaced a second real bug in
`oq_apply_table_options()`'s table selector, found via this group's own test render (`"Tabellen-
Optionen angewendet: 2 Tabelle(n)."` where 1 was expected, once the test figure got a caption): the
Gruppe-3-era `[not(.//w:tbl)]` filter (excludes tables containing a nested table) correctly
excluded a *table's* own wrapper, but not a *figure's* wrapper (which has no nested `w:tbl` at
all, just an image paragraph + caption paragraph). Replaced with a more precise, direct signature:
`//w:tbl[not(./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val='ImageCaption')]` — excludes any table whose own
direct cell contains an `ImageCaption`-styled paragraph, which identifies the wrapper itself
(regardless of what it wraps) rather than inferring it from nested-table presence. This detection
depends on `oq_apply_table_options()` running **before** `oq_apply_captions()` (the caption
style/text/position pass, Gruppe 3/5, see below) in `writeback.R`'s per-file block (current order)
— by the time captions would have remapped `ImageCaption` to a user style, this signature would no
longer match.

officedown's `fig.lp` was dropped for the identical reason as `tab.lp` (see above) — no
Quarto/post-render equivalent. `topcaption` (caption position, tables *and* figures) was
deliberately deferred out of this group rather than implemented per-group: it's a structural
paragraph-reorder operation (move the caption paragraph before/after its table or image within the
wrapper cell), conceptually identical for both — implemented later as one combined follow-up once
figure captions (Gruppe 5) existed, see "Caption position" below, rather than building the same
reordering logic twice.

### Figure captions (`officequarto.plots.caption`, `plot_caption_mapping.R`, Gruppe 5)

Identical fields, identical mechanism, and identical `tnd`/`tns` exclusion rationale as Gruppe 3
(table captions) — implemented as a refactor rather than a duplicate: `oq_apply_table_captions()`
was generalized into `oq_apply_captions(document_doc, captions, caption_options)`
(`table_caption_mapping.R`), which now takes an already-found paragraph node-set instead of finding
it itself, so the identical text-rewriting logic (`oq_split_caption_text()`/
`oq_write_caption_run()`, all still in `table_caption_mapping.R`) serves both groups. Only the
paragraph-finding differs: `oq_find_plot_caption_paragraphs()` (`plot_caption_mapping.R`) mirrors
`oq_find_table_caption_paragraphs()` — same `pStyle="ImageCaption"` check (figures, unlike tables,
use this one ID regardless of crossref ID — see Gruppe 3's Detection note and `dev/spike-notes.md`
Spike L), but adjacency in the other direction: the caption's **immediately preceding sibling**
must contain a `w:drawing` (an image paragraph), matching Pandoc's default "caption below figure"
position in both the wrapped and non-wrapped case alike. `oq_plot_caption_content()` returns that
preceding sibling directly, for the same reason `oq_table_caption_content()` does (see above).
`writeback.R` calls `oq_apply_captions()` twice, once
per finder, each with its own independent 1-based numbering counter — table and figure captions
have separate number sequences in Quarto ("Table 1"/"Figure 1" independently), so they must not
share a single running count.

### Caption position (`caption.above`, combined tables+figures follow-up)

Implements the `topcaption` field deferred from both Gruppe 1 (tables) and Gruppe 4 (figures),
built once both had full caption infrastructure (Gruppe 3/5) to share. Lives at
`officequarto.tables.caption.above`/`officequarto.plots.caption.above` — nested under `caption`
rather than as a flat top-level field like officedown's `topcaption`, since a proper `caption`
sub-section now exists and this option belongs there with the rest.

**Key empirical fact that shapes the whole feature**: Pandoc's own, unconfigured default caption
position already matches {officedown}'s own per-type default — captions render **above** tables
and **below** figures out of the box (verified directly against real rendered XML). `above` is
therefore needed only to *override* that default, never to achieve it; per-field opt-in (unset =
untouched) means this "just works" without any active default-matching logic.

Implementation, split for reuse:
- `oq_move_caption(caption_p, content_node, above)` (`table_caption_mapping.R`) does the actual
  reorder. xml2 has no native "move a node" primitive — `xml_add_sibling(..., copy = FALSE)` was
  verified empirically to still copy rather than move (leaves the original in place, producing a
  duplicate) — so the move is copy-then-remove-original (`copy = TRUE` followed by
  `xml2::xml_remove()` on the original reference). Verified this leaves only a harmless, valid
  redundant `xmlns:w` re-declaration on the moved node (libxml2's normal behavior when copying a
  node across contexts), nothing that affects document validity or Word's rendering.
- Folded into `oq_apply_captions()` (not a separate pass) as the **last** step per caption, after
  style remap and text rewrite — deliberately, since those mutate the paragraph in place and must
  happen while it's still attached to the tree; moving first would mean operating on an already-
  detached node for the rest.
- `content_finder` parameter (`function(caption_p, ns) -> node`) supplies the type-specific
  "what does this caption belong to" lookup: `oq_table_caption_content()` (the nested `w:tbl`) vs.
  `oq_plot_caption_content()` (the drawing-paragraph) — mirroring the split already used for
  `oq_find_table_caption_paragraphs()`/`oq_find_plot_caption_paragraphs()`.
- Verified end-to-end in both directions against the test template (table caption moved *after*
  its table, figure caption moved *before* its image — both against Pandoc's native default) — and
  that Pandoc's `w:bookmarkStart`/`w:bookmarkEnd` crossref anchors, which aren't touched by the
  move, remain correctly positioned regardless.

### Free-form style mapping (`officequarto.style-map`, `style_map.R`, Gruppe 7)

Officedown's `mapstyles` renamed to `officequarto.style-map` (Schritt A confirmed with the user
before implementing) — its own subsection (sibling of `officequarto.styles`/`.lists`/`.tables`/
`.plots`), not nested inside `officequarto.styles`, since mixing a free-form map with that
section's fixed named slots (`body`) would be confusing. No section-level officedown alias exists
(unlike every other group's per-field aliases) — `mapstyles:` itself isn't recognized, only the
new name.

Deliberately asymmetric source/target handling, mirroring the `SourceCode`/`code-block` precedent
in `style_mapping.R`: the **target** (map key) is a real, user-facing style resolved via
`oq_resolve_style_id()` against display names, fail-loud like everywhere else. The **source**
values are matched by direct `pStyle` equality (`oq_apply_style_map()`), not resolved as display
names, and silently a no-op if a given source ID doesn't occur in the document at all (there's no
reason to fail loudly over an ID that simply isn't used). `oq_resolve_style_map()` builds a flat
source-ID → target-ID map from the nested config and fails loudly if the same source ID is claimed
by two different targets (ambiguous).

**Caveat, found via a real-world user report against `../hello-wordto` (see `dev/spike-notes.md`
Spike M):** the source IDs are only unconditionally portable ("Pandoc's own stable, technical style
IDs") for roles Pandoc invents itself when nothing better exists (`Normal`, `FirstParagraph`,
`Compact`, `SourceCode`, `ImageCaption`/`TableCaption` — see Spike L). For a role with a genuine
*built-in Word equivalent* — confirmed for blockquotes — Pandoc's docx writer instead reuses
whatever style ID `reference-doc` already defines for that built-in role, which can be localized
(e.g. `Bloktekst` for a Dutch template's "Block Text" style, not the generic `BlockQuote`) — same
underlying phenomenon as the caption-style localization in Spike L, just via a different Pandoc
code path (built-in-role reuse rather than caption-structure generation). `officequarto`'s own
`original.docx` test template happens to define no blockquote-equivalent style at all, so Pandoc
falls back to its generic `BlockQuote` ID there — which is why the README/here-documented
`"Zitat ACME": [BlockQuote]` example "worked" without ever having been exercised end-to-end against
real blockquote content in `template/report.qmd` (`check_style_map.R` only uses synthetic XML with
made-up IDs; `check_writeback.R` only exercises the `Title` case). No code fix — `style-map`'s
equality-match mechanism works exactly as designed; this is a documentation gap about Pandoc's own
behavior, now called out in README with a pointer to verify actual `pStyle`s via
`officequarto.keep-rendered: true` rather than assuming a fixed name.

Runs **last** in `writeback.R`'s style-mapping pipeline, deliberately after `officequarto.styles`/
`.lists`/`.pandoc-styles`/`.tables`/`.plots` — by that point most paragraphs already carry their final
`pStyle`, so a typical rule (keyed on Pandoc's own generated names) naturally only touches
paragraphs none of the curated options already claimed, while a rule deliberately keyed on an
already-remapped target name can still reach and further override it, since matching is always
against whatever `pStyle` a paragraph currently has at that point in the pipeline.

### Page layout (`officequarto.page`, `page_mapping.R`, Gruppe 8)

Unlike every other group, this touches section properties (`w:sectPr`/`w:pgSz`/`w:pgMar`), not
paragraph or table styles — and unlike `tab.lp`/`fig.lp`, this one genuinely needed a post-render
implementation rather than pointing at a native Quarto/Pandoc equivalent: page size/margins already
carry over from `reference-doc` via Pandoc's normal section-properties inheritance, but Pandoc's
docx writer has no YAML override mechanism for them at all (unlike its LaTeX/PDF writer's
`geometry` options), so overriding them without hand-editing `reference-doc` requires a direct XML
patch.

One combined top-level section `officequarto.page` (`size`/`margins` sub-groups), not two separate
sections mirroring officedown's `page_size`/`page_margins` — confirmed with the user in Schritt A,
consistent with how `officequarto.tables` groups `conditional`/`caption` rather than splitting into
more top-level sections. `orient` renamed to `orientation` (also confirmed); the officedown alias
stays `page_size_orient` (officedown's literal historical name, needed verbatim for migration
regardless of the new canonical spelling).

Values are in inches (matching officedown) converted to twips (`× 1440`) for OOXML. Applied
uniformly to every `w:sectPr` in the document (`oq_apply_page_options()`) — most documents have
exactly one; a document with genuinely different per-section page layouts isn't the target
scenario, matching officedown's own single-section assumption. No automatic `width`/`height` swap
when `orientation: landscape` is set — same as officedown, the user owns dimension consistency.

New generic helper `oq_resolve_fields()` (`option_aliases.R`) added for this group specifically: it
wraps `oq_resolve_aliased()` over a whole named vector of `canonical -> alias` pairs at once,
returning a resolved named list — introduced here because this group has ten near-identical fields
(three `size` + seven `margins`), where the previous one-call-per-field pattern used by every
earlier group would have been pure repetition.

**Verified empirically** (comparing `officequarto.keep-rendered`'s pre-patch debug copy against the
final output) that Pandoc's own unpatched `w:sectPr` already orders `pgMar` before `pgSz` before
`type` — technically not `CT_SectPr`'s defined schema sequence (which places `type` before `pgSz`
before `pgMar`), but Word tolerates it and it predates any officequarto involvement: this code only
updates existing `w:pgSz`/`w:pgMar` nodes' attributes in place via `xml_find_first()`, it never
creates or repositions them (both already exist in every real `reference-doc`-derived render), so
there was nothing here for officequarto to have broken or to fix — unlike the Gruppe 1 `w:tblPr`
child-ordering issue, which was a real, first-created-by-officequarto ordering bug.

### Cross-reference text (`officequarto.crossref`, `crossref_mapping.R`, Gruppe 9)

The last group of the officedown port, and the one closest in spirit to the reasons `tab.lp`/
`fig.lp` got dropped — but implemented anyway (explicit user call after weighing the tradeoff):
`@tbl-xyz`/`@fig-xyz` cross-references are, like captions, already resolved to static text (a
`w:hyperlink[@w:anchor]` run reading e.g. `"Table 1"`) before `writeback.R` ever sees the document —
confirmed empirically during the original `tab.lp` research. There's no live field to flip;
`officequarto.crossref.numbered: false` (officedown: `reference_num`) works by finding every
cross-reference hyperlink whose anchor matches a known caption's bookmark and replacing its text
with that caption's own descriptive text.

- **Where the replacement text comes from**: `oq_apply_captions()` (`table_caption_mapping.R`,
  Gruppe 3/5's shared function) was extended to *always* compute `oq_split_caption_text()`'s
  `$rest` and record it against the caption's bookmark name (`oq_caption_anchor_name()`) in a
  returned `anchor_text` map — regardless of whether `needs_text_rewrite` is true, i.e. regardless
  of whether `officequarto.tables.caption`/`officequarto.plots.caption` are configured at all. Only
  the actual in-place XML rewrite (`oq_write_caption_run()`) stays gated on that; the parse+collect
  step is unconditional. This was necessary because Gruppe 9 needs the descriptive text even when
  the user hasn't touched caption styling — `writeback.R` reflects this by widening the gate that
  decides whether the table/plot caption block runs at all to `!is.null(table_caption_config) ||
  crossref_rewrite_needed` (and the plot equivalent), so Gruppe 9 alone is enough to trigger
  caption discovery, "running silently" with an otherwise-empty `caption_options`.
- **Reading `w:anchor`/`w:name`**: another instance of the read/write attribute-prefix asymmetry
  already documented above for `w:val` — reading uses the *unprefixed* local name (`xml_attr(node,
  "anchor")`/`xml_attr(node, "name")`), verified empirically here as it was for `styleId` earlier;
  only *writing* needs the `w:`-prefixed form.
- `oq_apply_crossref_text()` (`crossref_mapping.R`) does the actual replacement: for a matched
  hyperlink, the first run gets the replacement text, any further runs in the same hyperlink are
  removed (Pandoc's generated crossref hyperlinks are a single run in practice; this is defensive,
  not the expected case).
- Only ever active when `numbered` is explicitly `false` — Pandoc's own default (numbered) already
  matches officedown's own default, so there's nothing to do when unset, same pattern as
  `caption.above`.

officedown's `tab.lp`/`fig.lp` (bookdown cross-reference label-prefix options) were deliberately
**not** ported — researched explicitly before implementing Gruppe 1: they're a source-syntax
concept for bookdown's `\@ref(tab:xyz)` parser, not a rendering option, and have no integration
point in officequarto's post-render architecture (Quarto's own `#tbl-xyz`/`#fig-xyz` crossrefs are
already resolved to static content before `writeback.R` ever sees the docx). The visible caption
prefix text concern is already covered natively by Quarto's own `crossref.tbl-title`/`fig-title`
YAML keys — no `officequarto` option needed for that. Tangential finding that turned out to matter
directly for Gruppe 3 (table captions, see above): Quarto's docx crossref captions currently render
as static baked-in text rather than real Word `SEQ` fields (open upstream gap) — this is exactly
why Gruppe 3's `prefix`/`separator`/`number-bold` had to be implemented as text-parsing rather than
field manipulation.

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
`officequarto.styles`/`officequarto.lists` isn't configured for that role and `reference-doc`
doesn't happen to define them), it is still removed and `writeback.R` logs a warning; the affected
content falls back to Word's default formatting rather than erroring out. Runs independently of
whether `officequarto.styles`/`officequarto.lists` is configured, always after the style-mapping
step (so it prunes against the final, already-remapped `document.xml`).

`oq_is_pandoc_code_style_id(id)` in `style_pruning.R` identifies Pandoc's fixed syntax-highlighting
style-ID family (`id == "SourceCode" | grepl("Tok$", id)` — a stable naming convention of Pandoc's
docx writer). `dev/check_writeback.R` sources `style_pruning.R` directly to reuse this helper
rather than duplicating the pattern.

**Escape hatch: `officequarto.pandoc-styles.code-block`** (optional, default unset → prune as
above). Deliberately its own subsection, sibling of `officequarto.styles`/`officequarto.lists`
(not nested inside either) — it's about Pandoc-added styles, not about remapping reference-doc
styles, and is independent of whether `officequarto.styles`/`officequarto.lists` is configured
at all (`writeback.R` gates the whole style-mapping block on `!is.null(style_config) ||
!is.null(lists_config) || !is.null(code_block_config)`, not on `style_config`/`lists_config`
alone, so `code-block` works standalone):
- `true` — exempts `SourceCode` + all `*Tok` styles from pruning entirely (`writeback.R` computes
  `union(ref_style_ids, code_style_ids)` as the keep-set passed to `oq_prune_foreign_styles`, which
  needed no signature change for this). Pandoc's own code-block styling, including syntax-
  highlighting colors, survives untouched.
- a style name (string) — resolved via the same `oq_resolve_style_id` used for `body`/
  `list-bullet`/`list-number` (that function takes the fully-qualified config key, e.g.
  `"officequarto.pandoc-styles.code-block"` vs. `"officequarto.styles.body"`, for its error
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
  YAML parsing — this is what makes nested keys like `format.docx.officequarto.tables` reliable.
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
