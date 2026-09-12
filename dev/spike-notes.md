# Spike Notes

Results from Phase 0 (Setup & Spike), verified on 2026-08-28 with
`quarto 1.8.24`, `Rscript 4.5.2`, `pandoc 3.10.1`.

## Spike A — `reference-doc` alone is enough for style inheritance

`format: docx: reference-doc: original.docx` is enough, **with no custom code at all**, to inherit
styles, header, footer, and section properties (margins, paper size) from an arbitrary original
`.docx`. This is native Pandoc behavior (the docx writer uses the reference document as a template
for `styles.xml`, `header*.xml`, `footer*.xml`, and `sectPr`).

**Surprising additional finding that fundamentally changed Phase 3:** A `.docx` rendered via
`reference-doc` already contains the original's header/footer/section properties *completely and
unchanged* — verified via an `unzip` diff between `original.docx` and the raw Pandoc result
`report.docx`, even before any custom post-render code had run. The originally planned "manually
strip the original docx's body and splice in the rendering body, while preserving header/footer"
(Phase 3 spec) is thus already handled for the core use case by Pandoc itself — an additional XML
merge step brings no added value here.

An attempt to still implement the manual body-replacement described in the concept
(`officer::body_add_docx()`, to insert the rendering output into a copy of the original) failed on
an `officer 0.7.3` bug/edge case: as soon as a document's body is fully emptied (0 paragraphs) or
two structurally very similar documents (both with their own header/footer/sections, since both
descend from `original.docx`) are merged, `print()` throws an error during re-serialization in
`process_sections_content()` (a row-count mismatch between content sections and header/footer
files). Reproducible with a minimal example (two paragraphs, one header, one footer).

**Consequence for Phase 3:** The post-render hook no longer assembles the body itself, but instead
works with the already-correct Pandoc result (see "What the hook actually still contributes"
below).

## What the hook actually still contributes

What Pandoc does **not** carry over from the original: `docProps/core.xml` (title, subject,
keywords, description, category) and `docProps/custom.xml` (freely defined custom properties, e.g.
confidentiality level, document number). Pandoc instead writes a new, largely empty `core.xml`
based on the `.qmd` metadata. This is exactly what `scripts/writeback.R` handles: it works with a
copy of the already-correct rendered `.docx` in a temporary directory, transfers
`dc:subject`/`cp:keywords`/`dc:description`/`cp:category` as well as `docProps/custom.xml` from the
original into it, and thereby overwrites the `.docx` produced by Quarto directly in place (no
second output file; optionally, `officequarto-keep-rendered: true` additionally keeps the
unpatched Pandoc result as `<name>.quarto-rendered.docx`).

**Known limitation:** If the rendered Pandoc document doesn't yet know about the `docProps/
custom.xml` part itself (registered in `[Content_Types].xml`/`_rels/.rels`), simply overwriting
this file would create an unreferenced part. In the tested case (original as `reference-doc`), the
part is already correctly registered by Pandoc; for more exotic source documents this isn't
guaranteed and remains a documented limitation of the prototype.

## Spike B — `contributes: project:` in `_extension.yml`

Works as expected, **but is not a zero-config mechanism**: `quarto add` only installs the
extension files. The post-render hook only becomes active once the user's project sets
`project: { type: officequarto }` in its own `_quarto.yml`. Verified by counter-test: with
`project: type: default` (no `officequarto`), `writeback.R` demonstrably does **not** run —
`report.written-back.docx` is not produced. With `project: type: officequarto`, the hook runs
reliably on every `quarto render`.

## Spike C — Environment variables in the post-render script

Reliably available (confirmed via `Sys.getenv()`):

- `QUARTO_PROJECT_OUTPUT_FILES` — newline-separated list of output files, **relative** to
  `QUARTO_PROJECT_OUTPUT_DIR` (in the test: `report.docx`)
- `QUARTO_PROJECT_OUTPUT_DIR` — absolute path (in the test: `.../template`)
- `QUARTO_PROJECT_RENDER_ALL` — `"1"` on a full render
- `QUARTO_PROJECT_DIR` — absolute project root, used among other things to locate
  `original.docx` and the project configuration

No environment variable provides the path of the `reference-doc` itself — for that, `quarto
inspect <project_dir>` is called and `config.format.docx["reference-doc"]` is read from the JSON.
This is more robust than hand-parsing `_quarto.yml`'s own YAML, because `quarto inspect` already
resolves merges/defaults.

## Spike D — Style mapping (body/lists), verified on 2026-08-28

The initial assumption from research (officedown/Pandoc internals) was that Pandoc uses fixed
style IDs `Normal` (body) and `ListParagraph` (lists). This turned out to be **incomplete**: on the
actual rendered document it showed that Pandoc picks different style names depending on context,
which must exist in `reference-doc`:

- Body paragraphs directly following a heading → `FirstParagraph`
- List paragraphs from "tight" markdown lists (no blank line between entries, the normal case) →
  `Compact` — **for both bullet and numbered lists alike**
- `Normal`/`ListParagraph` only occur in other constellations (e.g. "loose" lists, body paragraphs
  with no preceding heading)

Verified via `unzip`+Python regex diff on the real `report.docx`: all 9 paragraphs carried explicit
`pStyle` values from `{Title, Titre2, FirstParagraph, Compact}`; `ListParagraph` did not occur at
all. **Consequence:** list paragraphs are not detected by style name, but by the presence of
`<w:numPr>` (reliable, independent of the chosen style name); body paragraphs are detected via an
allowlist of known role names (`Normal`, `FirstParagraph`, `Compact`, `BodyText`, `Body Text`) —
see `scripts/style-mapping.R`.

Also verified: `word/numbering.xml` reliably resolves `numId` → `abstractNumId` → `w:numFmt` (level
0); in the test the bullet list had `numFmt="bullet"`, the numbered list `numFmt="decimal"` — with
different `numId`s (1001 vs. 1002), but identical `pStyle` (`Compact`) at the paragraph level.
Without the `numFmt` detour, bullet vs. numbered would not have been distinguishable.

Also confirmed: `word/styles.xml` in the rendered output contains all style definitions from
`reference-doc` unchanged (including one's own custom styles) plus styles additionally needed by
Pandoc (e.g. syntax-highlighting token styles) — no second extraction from `reference-doc` is
needed, `work_dir/word/styles.xml` is sufficient. And: `quarto inspect` returns a newly added
nested key `format.docx.officequarto-styles` just as reliably as `reference-doc` (confirmed via a
counter-test with a test value).

## Spike E — Style pruning, verified on 2026-08-29

A finding from Spike D that seemed harmless at first glance ("plus styles additionally needed by
Pandoc, e.g. syntax-highlighting token styles") turned out to be bigger than expected:
`original.docx` defines 27 styles; the raw Pandoc result (`report.quarto-rendered.docx`, before any
officequarto post-processing) contains 59 — 32 extra ones, exclusively syntax-highlighting styles
(`SourceCode`, `KeywordTok`, `StringTok`, ...), even though `report.qmd` did not contain a single
code block at the time of testing. Verified via a style-ID diff (`w:styleId` in `word/styles.xml`):
all 27 original styles are present unchanged, the 32 extras come exclusively from Pandoc — nothing
is lost. According to the user, {officedown} shows the same behavior; it is therefore a general
property of Pandoc's docx writer, not specific to the `reference-doc` mechanism.

At the user's explicit request, `writeback.R` has since removed these extras again (by default):
the reference-doc's `word/styles.xml` is additionally extracted from the original alongside
`core.xml`/`custom.xml`, and every `<w:style>` in the rendered `word/styles.xml` whose `styleId`
doesn't occur there is removed (`scripts/style-pruning.R`).

Also tested the edge case "style is still in use": a test paragraph with a real code block in
`report.qmd` ensures that `SourceCode`/`KeywordTok`/... are actually referenced via
`w:pStyle`/`w:rStyle`. Deliberate decision (confirmed by the user): even then the style is removed
rather than kept — the affected paragraph/run falls back to Word's default formatting, and
`writeback.R` logs a warning listing the affected style IDs for this. Verified: the resulting
`document.xml`/`styles.xml` remains well-formed XML (no crash, no corrupted file), the `pStyle`
value `SourceCode` continues to exist on the paragraph even though the style definition is missing
— exactly the behavior Word tolerates (silent fallback to default formatting, no repair dialog).

Counter-test against a real external project (`../hello-wordto`, a UU Word template with 476
styles, `hello-wordto.qmd` without any code): the raw Pandoc result had 508 styles (476 + the same
32 extras), and after pruning exactly 476 again — identical to the template. Confirms that the
behavior isn't specific to the small ACME test template, but applies generally to arbitrary
reference-docs, even very large ones.

## Spike F — Code-block exception (`officequarto-pandoc-styles.code-block`), verified on 2026-08-29

Before the first commit of Spike E, a request came in for an opt-in exception for exactly this
code-block case: either keep Pandoc's own code-block formatting entirely, or remap the code-block
paragraphs onto a custom reference-doc style (analogous to `body`/`list-bullet`/`list-number`),
while the default (no code-block config) remains unchanged.

`SourceCode` turned out (unlike `Normal`/`FirstParagraph`/`Compact` in Spike D) to be a stable,
context-independent Pandoc style ID for the code-block paragraph itself — a simple equality check
in `oq_apply_style_mapping` is enough, no allowlist needed. For `code-block: true`, it's enough to
extend the set of "styles to keep" before the pruning call with all `SourceCode`/`*Tok` IDs
(`oq_is_pandoc_code_style_id()`) — `oq_prune_foreign_styles` itself needed no change for this,
since it already accepts an arbitrary "keep set" to begin with.

Subsequent request (still before the first commit of this feature): `code-block` should not be
nested under `officequarto-styles`, but placed in its own, sibling section
`officequarto-pandoc-styles` (rationale: it's about styles added by Pandoc, not about remapping
one's own reference-doc styles — a different configuration area in substance). This required
widening the gate condition for the style-mapping block in `writeback.R` from
`!is.null(style_config)` to `!is.null(style_config) || !is.null(code_block_config)`, otherwise
`code-block` would not have taken effect at all without `officequarto-styles`
(body/list-bullet/list-number) also being set — verified via a test case with *only*
`officequarto-pandoc-styles.code-block` set (no `officequarto-styles` in the config): the
code-block paragraph is still correctly remapped to the configured style, body paragraphs remain
untouched at Pandoc's role names. `oq_resolve_style_id()` also had to be adapted: the full
configuration path for error messages is now passed in by the caller (`"officequarto-styles.body"`
vs. `"officequarto-pandoc-styles.code-block"`), instead of hard-coding the prefix
`officequarto-styles.`.

Verified (`template/_quarto.yml` now permanently uses `officequarto-pandoc-styles:
{code-block: "Code ACME"}` as a string-mapping test case, a fourth ACME custom style in
`dev/make-sample-docx.R`):
- `code-block` unset (default): unchanged from Spike E (32 removed, including `SourceCode`).
- `code-block: "Code ACME"`: the `SourceCode` paragraph is remapped to `CodeACME` (no more
  `SourceCode` reference, no warning for it), but the `*Tok` run styles in the code block remain
  referenced-but-removed (warning as before) — deliberately separate concerns of block style vs.
  syntax-highlighting colors.
- `code-block: true` (tested manually in a scratch project, not part of the permanent test
  template): 0 removed, all 32 `SourceCode`/`*Tok` styles remain unchanged, no warning, full
  syntax-highlighting coloring in the result.
- Invalid value (e.g. a number): aborts immediately with a clear error message, before the
  per-output-file loop even runs.

## Spike G — `list-letter` (letter lists), verified on 2026-08-29

Question before implementation: does Pandoc's docx writer even produce a `w:numFmt` value for
letter lists (`a.`/`b.`/`c.` or `A.`/`B.`/`C.` in the markdown source) distinguishable from
`bullet`/`decimal`, or does this fall under Pandoc's generic numbering like everything else?

Checked empirically via a direct `pandoc test.md -o test.docx --standalone` (test markdown with
one letter list, one number list, and one uppercase-letter list each), independent of officequarto:
`word/numbering.xml` afterwards contains `w:numFmt` values `bullet`, `decimal`, **and**
`lowerLetter` (for `a.`/`b.`/`c.`) as distinct, distinguishable values — uppercase markers
(`A.`/`B.`) would analogously be `upperLetter` (not separately tested, but per the OOXML spec the
expected counterpart to `lowerLetter`). Letter lists are thus just as reliably detectable via
`word/numbering.xml` as bullet vs. number lists in Spike D — no special handling needed, just an
additional branch in the existing `numFmt` case distinction.

Implemented as its own bucket `list-letter` (`officequarto_letter_num_fmts <- c("lowerLetter",
"upperLetter")` in `style-mapping.R`), separate from `list-number` (which continues to cover
`decimal`, roman numerals, etc.) — both cases combined into one option instead of separate options
for lower-/uppercase letters, analogous to how `list-number` already combines `decimal` and roman
numerals into one bucket. Has no officedown precedent (officedown only knows `ol.style`/
`ul.style`), so introduced as an officequarto-only option with no alias — no conflict with the
[[officedown alias convention]] (see `option-aliases.R`), since there simply is no officedown name
to map to.

Verified on the working test project (fifth ACME custom style `BuchstabierungACME` in
`dev/make-sample-docx.R`, third list `a./b./c.` in `template/report.qmd`,
`officequarto-styles.list-letter: "Buchstabierung ACME"` in `template/_quarto.yml`): 3 letter-list
paragraphs are correctly remapped to `BuchstabierungACME`, `list-number` (separately mapped to
`NummerierungACME`) remains unchanged at still only 3 paragraphs — no mixing of the two buckets.

## Spike H — Table base options (Gruppe 1) and skipping `tab.lp`, verified on 2026-08-29

Two open questions before implementing `officequarto-tables` (Gruppe 1 of the officedown option
port: `style`/`layout`/`width`; officedown precedent: `tables = list(style=, layout=, width=,
topcaption=, tab.lp=)`):

**1. Does officequarto need a `tab.lp`/`fig.lp` equivalent?** Researched (Quarto's own crossref
documentation, `quarto.org/docs/authoring/cross-reference-options.html` and
`.../cross-references.html`, as well as a Quarto maintainer discussion on docx crossrefs,
`github.com/orgs/quarto-dev/discussions/8503`) rather than assumed: No. `tab.lp` in
officedown/bookdown is a pure **authoring-syntax concept** — the prefix by which bookdown's
`\@ref(tab:xyz)` parser recognizes that a label refers to a table — not a rendering switch.
Quarto's own equivalent (`#tbl-xyz`/`#fig-xyz`) is a fixed, non-configurable Quarto authoring
convention that is already resolved when the `.qmd` is parsed — long before `writeback.R` (which
only ever sees the fully rendered docx) runs at all. No point of integration in the post-render
architecture. The visible prefix-text concern ("Tabelle" instead of "Table") is furthermore already
natively solved by Quarto's own `crossref.tbl-title`/`fig-title` YAML options — no officequarto
option needed for that. Side finding for a later Gruppe 3 (table/figure captions): Quarto's docx
crossref captions are currently static, already-baked-in text rather than real Word `SEQ` fields
(an open Quarto gap) — officequarto's post-render XML access would be a plausible place to retrofit
this later.

**2. Resolve `style` against which styles?** `officequarto-tables.style` references table styles
(`w:type="table"`), not paragraph styles like `body`/`list-*` — `oq_style_name_to_id()` in
`style-mapping.R` was therefore extended with a `type` parameter (`"paragraph"` default, `"table"`
for this case), instead of creating a second, nearly identical function. When checking the test
template it turned out: `original.docx` (produced by `officer::read_docx()`) already contains four
built-in table styles, including the base style with the ID `TableauNormal` (not `TableNormal` as
in the generic OOXML example — officer's base template is named in French). The new ACME table
style (`TabelleACME`) is therefore built on top of `TableauNormal`, not an assumed `TableNormal`.

**Additional implementation finding (not researched in advance, discovered during the first test
render):** an element newly created via `xml2::xml_add_child(tbl_pr, "w:tblLayout")` without
`.where` simply lands as the last child of `w:tblPr` — for a `w:tblPr` already pre-populated by
Pandoc with `w:tblStyle`, `w:tblW`, `w:tblLook`, that means it lands *after* `w:tblLook`, even
though `w:tblLayout` must, per the OOXML schema (`CT_TblPrBase`), come *before* `w:tblLook`. Word
itself tolerates this (still renders correctly), but it isn't schema-compliant. Fixed via
`oq_add_tbl_pr_child()` (`table-mapping.R`), which determines the target position from a fixed
`officequarto_tblpr_order` sequence instead of blindly appending — verified via a
`check-writeback.R` assertion on the actual resulting child-element order (`tblStyle, tblW,
tblLayout, tblLook`).

## Spike I — Table captions (Gruppe 3), verified on 2026-08-29

Before implementing `officequarto-tables.caption`, checked empirically how Quarto/Pandoc actually
produce table captions in docx output (test render: a `#tbl-example` table with a caption,
independent of officequarto, via a direct `quarto render`):

**Structure:** a captioned table is embedded by Pandoc into a synthetic 1x1 "wrapper" table, whose
single cell contains the caption paragraph (`pStyle="ImageCaption"`) followed by the actual, nested
table (plus `w:bookmarkStart`/`w:bookmarkEnd` for the crossref anchor). `ImageCaption` here is a
single, fixed Pandoc style, shared by both table AND figure captions — there is no dedicated
"TableCaption" style ID.

**Important finding that retroactively affected the Gruppe 1/2 implementation:**
`oq_apply_table_options()`'s original `//w:tbl` selection unintentionally matched BOTH tables (the
invisible wrapper table AND the real data table) due to this wrapper structure — verified on our
own test render ("Table options applied: 2 table(s)." instead of the expected 1, as soon as the
test table got a caption). Fixed via `[not(.//w:tbl)]` in the XPath selection (excludes any `w:tbl`
that itself contains a nested `w:tbl`) — the same fix was also needed in `check-writeback.R`'s own
table-lookup XPath.

**Core problem for prefix/separator/number-bold:** the caption is entirely static, baked-in text —
"Table 1: My table caption" as ONE `<w:r><w:t>` run, no real Word SEQ field (already confirmed by
the `tab.lp` research before Gruppe 1, see above; here verified again on the actual XML). Attempted:
predicting the generated prefix from `crossref.tbl-title`/`title-delim`, in order to cut it off
specifically during replacement. Empirically discarded: a test render with
`crossref: {tbl-title: "Tabelle", title-delim: "--"}` produced the text `"Tabelle\xa01– My table
caption"` — Pandoc's smart-typography conversion turns `"--"` into a real en dash ("–") and inserts
a non-breaking space before the number; the actually rendered text thus deviates from the
configured raw value, so predicting it from config would be unreliable.

**Solution:** anchor on the number itself instead of the surrounding text — digits are unaffected
by the typography conversion. `officequarto` counts table captions itself in document order
(identical to Pandoc's own counting, since only captioned tables produce a caption paragraph at
all) and searches for the expected number via a word-boundary lookaround regex (`(?<!
[\p{L}\p{N}])N(?![\p{L}\p{N}])`), not via a simple substring match — verified among other things
against the edge case where the searched-for number happens to also occur as part of another
number within the actual caption text (e.g. "1" in "1990"), see `dev/check-caption-parsing.R`.

## Spike J — Figure base options (Gruppe 4), verified on 2026-08-29

Before implementing `officequarto-plots`, checked empirically (test render: a `#fig-example`
figure with a caption, independent of officequarto, via a direct `quarto render`) how Pandoc
structures a figure in docx output.

**Finding 1 — figure paragraphs carry the same role name as body paragraphs:** the paragraph
carrying the `w:drawing` has `pStyle="Compact"` — the same context-dependent Pandoc role name that
`officequarto_body_role_styles` (Spike D) already treats as "body text". Without a countermeasure,
`officequarto-styles.body` (if configured) would therefore also incorrectly remap figure
paragraphs. Fixed via an explicit exception in `oq_apply_style_mapping()` (`style-mapping.R`):
paragraphs with a `w:drawing` descendant are excluded from the body-role check and instead
dedicated to `oq_apply_plot_options()` (`plot-mapping.R`) — figure paragraphs are detected via the
presence of `w:drawing`, not via the style name (the same principle as list paragraphs being
detected via `w:numPr`, not via the style name, Spike D).

**Finding 2 — figures are also embedded in Pandoc's 1x1 wrapper table:** identical structure as
for captioned tables (Spike I), just with image content instead of table content in the cell. This
meant a second real bug, only discovered during this group's own test render:
`oq_apply_table_options()`'s Gruppe 3 filter (`[not(.//w:tbl)]`, excludes tables with a nested
table) correctly detected the table-wrapper case, but NOT the figure-wrapper case (whose cell
contains no nested `w:tbl`, just an image paragraph and a caption paragraph) — the log incorrectly
showed "Table options applied: 2 table(s)." instead of the expected 1, as soon as the test figure
got a caption. Fixed via a more precise, direct detection signature instead of the indirect
derivation via nested tables: `//w:tbl[not(./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val='ImageCaption')]`
— excludes any table whose own direct cell contains an `ImageCaption`-styled paragraph, regardless
of whether that cell wraps a table or a figure. This requires `oq_apply_table_options()` to run
BEFORE `oq_apply_table_captions()` (the current order in `writeback.R`) — after that point,
`ImageCaption` might already have been remapped to a user style and the signature would no longer
match.

## Spike K — Crossref numbering (Gruppe 9), verified on 2026-08-29

Before implementing `officequarto-crossref.numbered`, two things were checked empirically instead
of assumed.

**1. `w:anchor`/`w:name` are unprefixed when reading.** The existing documentation (see
`CLAUDE.md`) already notes that xml2 attribute WRITES on OOXML nodes need the namespace prefix
(`xml_attr(node, "w:val") <- x`, not `"val"`). For the reverse case — READING — this had not yet
been explicitly verified; Gruppe 9 needs `w:anchor` (on `w:hyperlink`) and `w:name` (on
`w:bookmarkStart`) to be reliably readable. Confirmed via a small xml2 test script: reading only
works UNPREFIXED (`xml_attr(node, "anchor")`/`xml_attr(node, "name")`) — the prefixed attempt
(`"w:anchor"`) returns `NA`. This matches the already-known behavior of `styleId` (also read
unprefixed there) — so it's a general xml2 asymmetry between reading and writing, not an isolated
case.

**2. Structure of Pandoc's generated crossref hyperlinks.** Already captured during the `tab.lp`
research before Gruppe 1 (test render of a `@tbl-example` reference):
`<w:hyperlink w:anchor="tbl-example">` with a single
`<w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>Table 1</w:t></w:r>` — structured
identically to the captions themselves (static, baked-in text, no Word field). This means: the
replacement text for `numbered: false` cannot come from a live field, but must be done via text
replacement — like prefix/separator/number-bold in Gruppe 3/5.

**Design consequence:** rather than searching for and parsing captions a second time for Gruppe 9,
`oq_apply_captions()` (Gruppe 3/5, `table-caption-mapping.R`) was extended to ALWAYS (not only when
`needs_text_rewrite`) determine the caption text via `oq_split_caption_text()` and collect it,
together with the associated bookmark name (`oq_caption_anchor_name()`, finds `w:bookmarkStart` as
a sibling of the caption in the same wrapper cell), in an `anchor_text` return value — independent
of whether `officequarto-tables.caption`/`-plots.caption` are configured themselves.
`writeback.R` widens the gate that decides whether the caption-processing block runs at all to
include `crossref_rewrite_needed` (true only for explicit `numbered: false`) — Gruppe 9 alone is
enough to silently trigger caption detection, even without any Gruppe 3/5 configuration of its
own.

Verified on the working test project: `report.qmd` received a sentence with `@tbl-kennzahlen`/
`@fig-umsatz` references; after rendering with `officequarto-crossref: {reference_num: false}`
(officedown alias), both hyperlinks correctly show the plain caption text
("Quartalskennzahlen"/"Umsatzentwicklung") instead of "Table 1"/"Figure 1" — and unaffected by the
simultaneously configured `prefix`/`separator` of the captions themselves (which only affect the
caption paragraph, not the plain `rest` text collected in `anchor_text`).

## Spike L — Captions without a crossref ID (`TableCaption` vs. `ImageCaption`), verified on 2026-08-29

User bug report against `../hello-wordto` (a real external consumer project, not a dev symlink
setup): `officequarto-tables.caption.style` was NOT applied to the table caption there despite
being configured. `hello-wordto.qmd` uses plain Pandoc captions without a crossref ID
(`: Table 1 Caption` or `![Figure 1 ...](img){fig-alt=...}`, no `{#tbl-...}`/`{#fig-...}`) — unlike
`template/report.qmd` in this repo, which only ever tested crossref-managed captions
(`{#tbl-kennzahlen}`/`{#fig-umsatz}`). Root-cause analysis via a direct comparison of the raw
(`officequarto-keep-rendered`) against the finished, patched Pandoc output yielded two previously
unknown, empirically verified facts:

**1. Two structurally different Pandoc representations for captions**, depending on whether a
crossref ID was assigned:

- *With* `{#tbl-...}`/`{#fig-...}` (the only case tested so far): caption+content are packed into a
  synthetic 1×1 wrapper table, both caption types share the Pandoc style `ImageCaption` (already
  documented, see Gruppe 3 above).
- *Without* a crossref ID (a plain markdown caption): NO wrapper table — the caption paragraph and
  the content (`w:tbl` or image paragraph) sit as plain siblings directly in the document body
  (`w:body`). AND: table captions here use a DIFFERENT, previously unknown style —
  `TableCaption`, not `ImageCaption` — while figure captions continue to use `ImageCaption` (the
  image paragraph itself additionally carries `CaptionedFigure`). The real table also gets its own
  `<w:tblCaption w:val="..." />` in this case, added to its `w:tblPr` (an accessibility attribute,
  untouched by officequarto).

  Also: plain (crossref-less) captions are not numbered by Quarto at all — the caption text is
  pure, unmodified user text with no generated "Table N:"/"Figure N:" prefix. In rare cases,
  `oq_split_caption_text()`'s digit-anchoring can therefore produce a match (caption text happens
  to contain, as a standalone digit, exactly the running number officequarto is internally
  counting), even though semantically no generated number is present at all — remains a documented
  edge-case limitation (no bug fix needed for the reported error, but worth keeping in mind).

**2. The previous detection heuristic (`[../w:tbl]` or `[not(../w:tbl)]` — "parent element has any
`w:tbl` child") was only correct by coincidence in the wrapper case.** In the non-wrapper case, the
parent element is `w:body` itself, and `w:body` almost always contains SOME table somewhere in the
document — the check therefore fired on EVERY `ImageCaption` caption in the whole document,
regardless of actual structural proximity. Result in `hello-wordto`: the 3 figure captions (style
`ImageCaption`, siblings of `w:body`, which elsewhere contains a table) were incorrectly picked up
by the TABLE caption finder (the log showed "3 found" instead of the expected 1), while the real
table caption (style `TableCaption`) was recognized by NEITHER finder (style mismatch) — table and
figure captions were thus not just overlooked, but partly outright swapped.

**Fix**: both finders (`oq_find_table_caption_paragraphs()`/`oq_find_plot_caption_paragraphs()`,
`table-caption-mapping.R`/`plot-caption-mapping.R`) as well as the associated content-node finders
(`oq_table_caption_content()`/`oq_plot_caption_content()`, for `$above`) were switched from the
"parent element has a `w:tbl` child" heuristic to direct positional proximity: a table caption is a
paragraph styled `TableCaption` OR `ImageCaption` whose IMMEDIATELY following sibling element is a
`w:tbl`; a figure caption is a paragraph styled `ImageCaption` whose IMMEDIATELY preceding sibling
element contains an image paragraph (`w:drawing`). This demonstrably holds uniformly across both
Pandoc representations (verified: Pandoc's default order is "caption before the table" / "caption
after the figure" in BOTH cases) and is also more precise than the old heuristic even in the
already-working wrapper case.

Regression coverage: `template/report.qmd` gained a second, crossref-less table and figure test
case ("caption without a crossref ID" section, caption texts deliberately WITHOUT digits, so as not
to accidentally also test point 1 above); `check-writeback.R` checks that both also get the
configured style. Re-rendered and verified end-to-end against `../hello-wordto` (the original bug
report): the table AND all three figure captions now correctly carry the configured `"caption"`
style (`Bijschrift` as the resolved style ID in that Dutch-localized `reference-doc`).

## Spike M — `officequarto.style-map` source IDs for built-in Word roles are reference-doc dependent, verified on 2026-08-29

User report against `../hello-wordto`: `officequarto.style-map: {"Quote": [BlockQuote]}` was
supposed to redirect paragraphs of a native markdown blockquote marker (`> ...`) to the `"Quote"`
style — but doesn't work (0 paragraphs remapped), even though the same mechanism works correctly
for paragraphs explicitly tagged via `custom-style="Quote"` (those don't go through `style-map` at
all — Pandoc's `custom-style` handling resolves the target style directly itself).

**Root cause** (verified via `officequarto.keep-rendered: true` + raw-document inspection): the
native `> ` blockquote is actually assigned `pStyle="Bloktekst"` in `../hello-wordto`'s rendering,
not `"BlockQuote"`. The reason: `Bloktekst` is the (Dutch-localized) `styleId` of the built-in Word
style with the display name `"Block Text"` already present in this `reference-doc` — for certain
element types with a built-in Word role equivalent (blockquote is one of them), Pandoc's docx
writer detects that `reference-doc` already defines this role, and then references that style's
real `styleId` instead of using its own generic `"BlockQuote"` ID. officequarto's own
`original.docx` test template, by contrast, defines no built-in blockquote-equivalent style at
all, which is why Pandoc falls back there, for lack of an alternative, to its generic
`"BlockQuote"` ID — which is why the README/CLAUDE.md example (`"Zitat ACME": [BlockQuote]`)
"happened" to work there, but was never actually tested end-to-end against real blockquote content
in `template/report.qmd` (only used as an illustration in the docs, not in `check-style-map.R`,
which only uses synthetic XML test cases with made-up IDs, or in `check-writeback.R`, which only
checks the `Title` case).

**Consequence**: the previous documentation claim that `style-map` source IDs are "Pandoc's own,
stable, technical style IDs" (unconditionally portable) only holds for Pandoc's own generic roles
with no built-in Word equivalent (`Normal`, `FirstParagraph`, `Compact`, `SourceCode`,
`ImageCaption`/`TableCaption` — see Spike L). For roles with a genuine built-in Word counterpart
(confirmed at least for `Blockquote`; presumably also others such as heading levels), the `pStyle`
ID actually assigned by Pandoc depends on the respective `reference-doc` — identical to the already
known localization phenomenon for caption styles. No code change needed (the `style-map` mechanism
itself — equality comparison of the `pStyle` ID — works exactly as designed); this is a
documentation gap, not a bug. README/CLAUDE.md were amended with a corresponding note: before using
`style-map` for built-in-role content, look up the actually rendered `pStyle` via
`officequarto.keep-rendered: true`, instead of assuming a fixed ID like `BlockQuote`.

## Spike O — `numId`/`ilvl` assignment for nested lists, verified on 2026-08-30

Preliminary work for the style-per-nesting-level feature for lists
(`officequarto.lists.list-bullet`/`list-number`/`list-letter` as an array instead of a scalar). Two
questions clarified up front via a real render (a scratch `.qmd` with a 3-level nested bullet list,
a 3-level nested number list, and an `a.` letter list with an `i.` roman-numeral sublist, rendered
against `original.docx`, `word/numbering.xml`/`word/document.xml` of the unpatched Pandoc result
inspected):

- **`w:ilvl` is explicitly set on EVERY list paragraph**, even at the top level (`w:ilvl="0"` is
  always present) — the original assumption "`w:ilvl` implicitly missing means level 0" turns out
  to be irrelevant for Pandoc-generated lists at all, since Pandoc never omits it. Still, keeping a
  default-to-0 fallback in `oq_paragraph_ilvl()` makes sense (defensive, ECMA-376 compliant, in
  case a paragraph ever comes from another source).
- **Pandoc assigns a completely separate `numId` (and thus also a separate `abstractNum`) per
  nesting level** — e.g. the 3-level bullet list got `numId` 1001/1002/1003 for level 0/1/2, each
  with its own `abstractNum`. A single `numId` is NEVER reused across multiple levels.
- **Every `abstractNum` created this way defines the same `w:numFmt` at ALL 9 `w:lvl` entries**
  (e.g. `abstractNum` 991 for the nested bullet level: `bullet` at levels 0 through 8 identically;
  likewise for number and letter lists). Even the transition from a `lowerLetter` list to a nested
  `lowerRoman` sublist (`a.` → `i.`) produces two completely separate `numId`/`abstractNum` pairs
  (1007/99711 purely `lowerLetter`, 1008/99511 purely `lowerRoman`) instead of one shared
  `abstractNum` with mixed formats per level.

**Consequence:** The bucket misclassification feared during planning (a paragraph gets classified
based on level 0 of the `numId`, even though its own level has a different `numFmt`) is
**structurally unreachable** for Pandoc-generated lists — every `numId` carries exactly one
`numFmt` across all levels, so a level-0 lookup is already correct for every paragraph referencing
that `numId`. `oq_num_fmt_map()` therefore remains unchanged (level-0 lookup); there is no
`oq_num_fmt_for()`. What actually is needed and gets implemented: reading `w:ilvl` per paragraph in
order to select the correct **style** level from a configured array (`list-bullet: [...]`) — the
actual issue reported by the user, independent of the (here ruled-out) bucket question.

## Spike P — Bookmark structure around crossref-numbered captions, verified on 2026-08-30

Preliminary work for a planned feature: "real" Word auto-numbering (live `SEQ`/`REF` fields
instead of statically baked-in text for table/figure captions and cross-references, analogous to
{officedown}'s fields produced via `officer`). Before implementation, checked via a real render
(`quarto render report.qmd`, the unpatched `report.quarto-rendered.docx` inspected) what
`oq_caption_anchor_name()`'s previous comment ("an empty bookmark pair as a sibling of the caption,
between the caption and the table") actually means in the raw XML:

**Result: the previous description is wrong/incomplete.** The bookmark is not a tightly adjacent
empty pair between the caption paragraph and the table, but instead spans the **entire cell
content** (caption AND real table, or image AND caption):

- **Tables** (`{#tbl-kennzahlen}`): `<w:tc><w:tcPr/>` → `<w:bookmarkStart w:id="23"
  w:name="tbl-kennzahlen"/>` → caption paragraph (`pStyle="ImageCaption"`, text `"Table 1:
  Quartalskennzahlen"`) → the complete real, nested `<w:tbl>` → `<w:bookmarkEnd w:id="23"/>` → an
  empty `<w:p/>` → `</w:tc>`. So the bookmark spans the caption AND the entire table, not just a
  gap in between.
- **Figures** (`{#fig-umsatz}`): reverse order (image before caption, as documented elsewhere), but
  the same principle: `<w:bookmarkStart w:name="fig-umsatz"/>` → image paragraph → caption
  paragraph (`"Figure 1: Umsatzentwicklung"`) → `<w:bookmarkEnd/>`.
- `w:bookmarkStart`/`w:bookmarkEnd` are pure position markers (not container elements), and can
  therefore mark arbitrarily far-apart sibling positions — exactly what happens here, not a Pandoc
  anomaly, but Pandoc's usual technique for section/heading bookmarks (the same technique can be
  observed at the same level for every heading in the document, e.g. `w:name="kennzahlen"` spans
  the entire "Kennzahlen" section).
- **Confirmed** (a small but important side finding): `w:bookmarkStart/@id` is, like `@name`/
  `@anchor`/`@styleId`, read unprefixed (`xml_attr(node, "id")`, not `"w:id"`) — verified directly
  via an `Rscript` probe, the exact same xml2 asymmetry documented elsewhere.

**Consequence for the planned SEQ/REF field feature:** `oq_find_caption_bookmark()` must NOT
assume that `w:bookmarkEnd` is the next sibling after `w:bookmarkStart` or lies near the caption
paragraph — it must search the entire cell for a `w:bookmarkEnd` with a matching `@id` (an XPath
`@w:id` predicate, as is customary elsewhere in this codebase). Functionally this is not a problem
for the plan: the existing (widely spanning) bookmark is removed anyway and replaced by a new pair,
tightly wrapped around the SEQ field's numeral, with the same name (more precise than the original,
not less) — only the *localization* of the original pair to be removed must take this actual
structure into account, not the originally assumed tight pairing.

**Cross-check against `../hello-wordto`'s real UU template (2026-08-30):** Since
`hello-wordto.qmd` had so far not contained any crossref-numbered tables/figures (only plain
captions without a `{#tbl-...}`/`{#fig-...}` ID), a small test case that permanently stays in the
document ("Example of a crossref-numbered table and figure", "Additional officequarto test cases"
section) was added, to check the above structure against the more complex real-world template as
well (the same caution that already found real bugs in Spike L/M, invisible in the small ACME
template). Result: **identical structure** as above — `w:bookmarkStart` before the caption/image
paragraph, `w:bookmarkEnd` only after the entire cell content, exactly the same order for table
(caption→table) vs. figure (image→caption). No deviation this time — the structure is stable
across both reference-docs tested.

## Spike Q — Two real bugs in live numbering, found via a real render against ../hello-wordto, fixed on 2026-08-30

Unlike Spike P (structure itself stable), this test found two real implementation errors in
`oq_caption_anchor_name()`/`oq_find_caption_bookmark()`/`oq_apply_captions()` — both only uncovered
by the content variety of `../hello-wordto` (real heading bookmarks, a mix of plain and
crossref-numbered captions), no synthetic test would have found them. Added to `hello-wordto.qmd`:
a section "Example of a crossref-numbered table and figure" with a real
`{#tbl-crossref-check}`/`{#fig-crossref-check}` (see Spike P) plus
`officequarto.crossref.auto-number: true` in its `_quarto.yml` — the first real-world test of the
new feature at all.

**Bug 1 — a foreign bookmark stolen:** `oq_caption_anchor_name()`/`oq_find_caption_bookmark()`
searched for the FIRST `w:bookmarkStart` in the caption's parent element, WITHOUT checking whether
that parent element is even a Pandoc wrapper cell. For a PLAIN (non-crossref) caption, the parent
element is instead `w:body` itself (no wrapper table in the non-crossref case) — there, ALL
bookmarks in the document sit as siblings, including every heading's auto-generated anchor bookmark
(Quarto automatically generates a slug bookmark for every heading, e.g.
`example-of-plain-formatted-text`). Without a guard, the function incorrectly grabbed the nearest,
completely unrelated heading bookmark, and `oq_convert_caption_to_field()` then REMOVED it as a
supposed old caption bookmark and built a SEQ field in its place — thereby destroying a real jump
target in the document (verified: 3 bogus `SEQ Figure` fields with the names of three randomly
adjacent heading bookmarks, instead of no match at all). **Fix:** both functions now first check
`xml_name(xml_parent(caption_p)) == "tc"` — a bookmark search only happens at all within a real
wrapper cell. This is structurally exactly the condition under which Pandoc ever creates a caption
bookmark in the first place.

**Bug 2 — the counter thrown off by plain captions:** `oq_apply_captions()` counted EVERY found
caption (plain or crossref-numbered) in one shared, 1-based counter, which was passed as the
"expected number" to `oq_split_caption_text()` — under the assumption that this matches Pandoc's/
Quarto's own counting (as documented in the code comment, but never tested against a document
layout with a plain caption BEFORE a crossref-numbered caption of the SAME type). In fact, Quarto
doesn't number plain captions at all — they don't consume a numbering-sequence step. When
`hello-wordto.qmd` had a plain table caption ("Table 1 Caption", pure placeholder text with no real
number) BEFORE the single real crossref-numbered table ("Table 1: ..."), the latter was assigned
the expected number 2 by officequarto (the second caption found), even though its actual baked-in
number was 1 (it's the only real numbered table) — `oq_split_caption_text()` consequently did NOT
match, and the caption was silently left untouched for EVERY feature (prefix/separator/number-bold,
crossref.numbered: false, and auto-number). **Fix:** the counter in `oq_apply_captions()` is now
only incremented for captions that actually carry a bookmark (`oq_caption_anchor_name()` returns NA
for plain captions, see the fix for Bug 1) — plain captions no longer participate in counting/
parsing at all, exactly matching Quarto's own behavior.

**Important:** Bug 2 affected not just the new `auto-number` feature, but was a pre-existing,
latent bug in the already longer-existing caption logic (`prefix`/`separator`/`number-bold`,
`crossref.numbered: false`) — only unnoticed because officequarto's own test template
(`template/report.qmd`) always places the crossref-numbered table BEFORE the plain one (the
reverse order that triggers the bug never occurred there). Both bugs are now covered by dedicated
regression tests in `dev/check-auto-number.R` (synthetic reproduction of both scenarios) and
re-verified end-to-end against `../hello-wordto` — no more incorrect field conversions, all 18
heading bookmarks untouched, exactly 1 `SEQ Table` + 1 `SEQ Figure` (instead of the previous 1 +
3).

## Open questions from section 3 of the concept — status

| Question | Status |
|---|---|
| Does `contributes: project:` work? | Yes, with the activation requirement noted above |
| Is `reference-doc` enough for style inheritance? | Yes, including header/footer/section properties — more than originally assumed |
| Reliable environment variables? | `QUARTO_PROJECT_OUTPUT_FILES`/`_OUTPUT_DIR`/`_DIR`, see above |
| Is a custom project type needed? | `type:` yes, but `type: default` is enough — the extension doesn't need to define its own custom type |
| Content mapping on write-back? | The MVP writes metadata back, not the body (which is already correct via `reference-doc`) — body/bookmark mapping remains a future extension stage |
| Check R availability? | `writeback.R` checks `xml2`/`jsonlite`, the `quarto` CLI, `zip`/`unzip` via `requireNamespace`/`Sys.which` and aborts with an understandable message; a missing `Rscript` itself naturally cannot be caught by the script (see README) |
