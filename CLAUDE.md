# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`officequarto` is an R package (DESCRIPTION/NAMESPACE/`R/`/`tests/testthat/` at the repo root) that
bundles, as `inst/_extensions/officequarto/`, the Quarto extension it powers. It lets any existing
Word document act as the `reference-doc` for a Quarto/Pandoc docx render (styles, layout,
headers/footers, section properties carry over natively via Pandoc), and adds a post-render hook
that writes document metadata and remapped paragraph styles back into a copy of that original
document. It mirrors the idea behind the R package {officedown}, but also ships as an installable
Quarto extension (bundled inside the same R package, see below). It also registers `knit_print`
methods so {officer}'s run/paragraph/block constructors (`ftext()`, `fp_par()`,
`block_pour_docx()`, ...) can be used directly inline in a `.qmd`, mirroring {officedown}'s
equivalent feature for `.Rmd` — see "officer inline syntax" in the feature reference below.

The R package is a **required runtime dependency** of the extension, not just a dev-time
convenience — the extension's post-render hook (`inst/_extensions/officequarto/scripts/
writeback.R`) is a thin shim that calls the package's exported `oq_writeback()`. There is
deliberately no separate `quarto add` install path anymore: `oq_create_project()`
(`R/create-project.R`, exported) scaffolds a new project — including copying the bundled extension
in via `system.file("_extensions", package = "officequarto")` — directly from R, modeled on
`usethis::create_project()`. Named `oq_create_project()`, not `create_officequarto_project()` (an
earlier choice, briefly used) — consistency with the package's internal `oq_` prefix convention won
out over the argument that this is the one function meant for direct end-user typing. See README's
Usage section.

`oq_quarto_yml_template()` (private helper, `R/create-quarto-yml.R`) deliberately writes **every**
`officequarto` option into the scaffolded `_quarto.yml`, not just a minimal skeleton — a
self-documenting starting point. Two rules decide each option's written value: boolean/enum/
numeric options with a real behavioral default (what happens when the key is absent, e.g.
`keep-rendered: false`, `tables.conditional.first-row: false`, `crossref.numbered: true`) get that
literal value; string/style-name options with no universal default (`styles.body`,
`tables.style`/`caption.style`, `plots.*`, every `page.size.*`/`margins.*`, ...) get YAML `null`,
since only the user's own `reference-doc` can supply a real value — every such field in
`R/writeback.R` is gated behind `!is.null(...)`, so `null` is behaviorally identical to omitting
the key. `officequarto.style-map` is excluded from the active YAML entirely (shown only as a
commented-out shape example) — it's a free-form, user-defined map with no fixed keys, unlike every
other group, so it has no meaningful default entries to show.

`oq_create_project()` also accepts a `quarto_yml` argument (mirroring `reference_doc`'s shape): a
path to an existing `_quarto.yml`-style file, copied verbatim to `path/_quarto.yml` instead of
generating one via `oq_quarto_yml_template()`. Deliberately a raw file copy, not a parse-and-merge —
this package has no YAML-parsing dependency at all (`oq_quarto_yml_template()`'s own doc comment
explains the same no-`yaml`-dependency stance for *writing*), and adding one just to merge an
officequarto config block into an arbitrary pre-existing file was out of scope, confirmed with the
user. Consequence: `quarto_yml`'s content is never inspected, so if `reference_doc` is *also*
supplied, its `.docx` is still copied into the project as usual, but nothing injects a matching
`reference-doc:` line into the custom file — the user owns that key themselves.

`oq_create_quarto_yml(path, overwrite)` (`R/create-quarto-yml.R`, exported) is the standalone
counterpart: writes exactly the content `oq_quarto_yml_template()` produces (with `reference-doc`
always omitted) to an arbitrary `path` (default `"_quarto.yml"`), for use outside of scaffolding a
whole new project — e.g. converting an existing Quarto project to officequarto, or building a
**reusable** starting point meant to be hand-edited once and reused across future projects (also
what a user would naturally reach for to build the file later passed to `oq_create_project()`'s own
`quarto_yml`). Deliberately has **no** `reference_doc` argument — an earlier version did, but a
reference doc's filename is project-specific, so baking one into what's meant to be a reusable
template worked against its whole purpose, and risked the same kind of silent mismatch already
called out above for `quarto_yml` + `reference_doc` together (confirmed with the user, fixed
immediately after the initial PR merged). `oq_create_project()`'s own default-generation path (no
`quarto_yml` supplied) still needs to bake in a `reference_doc` for that one concrete project, so
the shared file-writing logic lives in a private `oq_write_quarto_yml(path,
reference_doc_basename, overwrite)` (`#' @noRd`, also `R/create-quarto-yml.R`) that both
`oq_create_project()` (`R/create-project.R`; may pass a basename) and `oq_create_quarto_yml()`
(never does) call — keeping `oq_quarto_yml_template()`'s pure content generation, the
file-write/overwrite-guard logic, and the public no-reference_doc surface all cleanly separated in
their own file, distinct from `oq_create_project()`'s own project-scaffolding concerns (extension
copy, starter `.qmd`, RStudio open). `oq_create_quarto_yml()` is one of the fully
`@param`/`@return`-documented exported functions (see the roxygen note below), matching the
"roxygen is minimal except for exported functions" convention.

Testing goes through testthat/`R CMD check` like any other package, run in CI via GitHub Actions
(`.github/workflows/R-CMD-check.yaml`, matrix of macOS/Windows/Ubuntu × release/devel/oldrel) on
every push/PR to `main`; the pkgdown site (`.github/workflows/pkgdown.yaml`) also rebuilds and
redeploys automatically on push to `main`. Some ad-hoc `dev/` tooling remains for the checks that
need a live `quarto render` against the external `quarto` CLI — `template/` plus the three fixtures
`auto-number`, `block-markers` and `numbering-hook` (see Commands below) — none of them is part of
that automatic CI run.

## Commands

A human-facing subset of this section (the commands relevant to a contributor, not the
architecture rationale) is mirrored in `CONTRIBUTING.md` — keep both in sync when these commands
change.

Package-level checks (pure R logic, no `quarto render` needed):

```r
devtools::document()   # (re-)generate NAMESPACE/man after any roxygen change
devtools::test()       # runs every tests/testthat/test-*.R
devtools::test(filter = "style-map")   # one test file (tests/testthat/test-style-map.R); or testthat::test_file(<path>)
devtools::check()      # full R CMD check
```

Render the example project and verify the hook end-to-end (needs the package installed first, so
the extension shim's `library(officequarto)`/`officequarto::oq_writeback()` call resolves):

```bash
Rscript dev/install.R                   # devtools::document() + devtools::install(), from the repo root
cd template
quarto render report.qmd
Rscript ../dev/check-writeback.R        # checks header/footer/body/metadata/style-mapping/style-pruning of the result
```

`template/report.qmd` includes a small fenced code block specifically so the style-pruning
"removed but still referenced" warning path (see below) has real coverage, not just the
always-safe unused-style case.

`template/_extensions` is a symlink to `../inst/_extensions` — this is how the extension is
exercised during development against this repo's own in-tree copy, without needing a separate
install elsewhere. Since the actual OOXML logic now lives in the installed `officequarto` package
rather than in sourced scripts, editing anything under `R/` requires the
`devtools::document()`/`devtools::install()` step above before the next render picks up the
change — the symlink alone only keeps *shim* edits (`inst/_extensions/officequarto/scripts/
writeback.R` itself) instantly live. `template/_quarto.yml` sets `officequarto.keep-rendered:
true`, so rendering produces `report.docx` (final, in-place overwritten) and
`report.quarto-rendered.docx` (the pre-write-back debug copy) in `template/` (both gitignored);
clean up with:

```bash
rm -f template/report.docx template/report.quarto-rendered.docx
rm -rf template/.quarto template/report_files
```

Every `quarto render` (in `template/`, the fixtures, experiment directories) also leaves a stray
`.gitignore` and a `.quarto/` directory behind in the rendered directory; delete them before
committing (`.quarto/` is gitignored, the stray `.gitignore` is not).

`officequarto.crossref.auto-number` has its own dedicated end-to-end fixture,
`dev/fixtures/auto-number/` (own `_quarto.yml`/`_extensions` symlink, now pointing at
`../../../inst/_extensions`, mirroring `template/`'s), kept separate since `template/_quarto.yml`
sets `crossref.numbered: false` (mutually exclusive with `auto-number` by design):

```bash
cd dev/fixtures/auto-number
quarto render report.qmd
Rscript ../../check-auto-number-e2e.R
```

`BLOCK_*` comment markers (the extension's `markers.lua` filter) have their own fixture too,
`dev/fixtures/block-markers/`:

```bash
cd dev/fixtures/block-markers
quarto render report.qmd
Rscript ../../check-block-markers-e2e.R
```

The knitr-hook numbering (`oq_numbering()`, including the `refs.lua` Quarto-notation filter) has a
fixture as well; the second render uses `officequarto.crossref.auto-number: true` on the same document
and additionally renders `mixed.qmd` (hook-numbered + native items):

```bash
cd dev/fixtures/numbering-hook
quarto render
(cd with-auto-number && quarto render)
Rscript ../../check-numbering-hook-e2e.R
```

**Verifying in real Word (macOS).** XML checks (`xmllint`, python-docx, xml2) have missed bugs that
real Word caught — a corrupt docx, references losing their label — so changes that touch the
docx structure or fields are opened in Word via AppleScript (save as `check.applescript`, run
`osascript check.applescript`; Word must not already have the same file open while rendering):

```applescript
tell application "Microsoft Word"
  open POSIX file "/abs/path/report.docx"
  delay 9 -- the first open after Word was idle needs ~9 s (4 s timed out)
  set d to active document
  repeat with i from 1 to (count of fields of d)
    try
      update field (field i of d) -- "update fields of d" is not supported
    end try
  end repeat
  set out to {}
  repeat with i from 1 to (count of paragraphs of d)
    set end of out to ((content of text object of (paragraph i of d)) as string)
  end repeat
  set nSections to count of sections of d
  close d saving no
  return {nSections, out}
end tell
```

The `SEQ`/`REF` fields carry no cached result (see "Live numbering" in `dev/design-notes.md`), so updating them is what makes
captions and references show their text. A `missing value` error on `close`, or an empty result, means
the document had not finished opening — raise the delay, or poll (`repeat … if (count of paragraphs
of d) > 50 then exit repeat … delay 1`). Large documents (the UU template) make `open` itself exceed
AppleScript's default timeout (`-1712`): wrap the whole script in `with timeout of 600 seconds … end timeout`. Properties such as `bold of font object of (text object of
(paragraph i of d))` answer formatting questions (e.g. whether a `REF` result inherits bold).

**Before opening a PR** (the render-based checks are not part of CI; run from the repo root, with the
package freshly installed via `Rscript dev/install.R`):

```bash
(cd template && quarto render report.qmd && Rscript ../dev/check-writeback.R)
(cd dev/fixtures/auto-number && quarto render report.qmd && Rscript ../../check-auto-number-e2e.R)
(cd dev/fixtures/block-markers && quarto render report.qmd && Rscript ../../check-block-markers-e2e.R)
(cd dev/fixtures/numbering-hook && quarto render && (cd with-auto-number && quarto render) && Rscript ../../check-numbering-hook-e2e.R)
# cleanup of every render's leftovers:
rm -rf template/.quarto template/.gitignore template/report_files template/report.docx template/report.quarto-rendered.docx
rm -rf dev/fixtures/*/.quarto dev/fixtures/*/.gitignore dev/fixtures/*/*/.quarto dev/fixtures/*/*/.gitignore
```

Plus `devtools::test()` (write it to a `.R` file), and an AppleScript check in real Word (above) for
anything touching docx structure or fields.

Regenerate the sample template (`template/original.docx`), including the sixteen ACME custom
paragraph styles used to test style-mapping (body/bullet/number/letter/code-block/table-caption/
plot/plot-caption/title/footnote-text):

```bash
Rscript dev/make-sample-docx.R   # needs R packages: officer, xml2
```

To verify `oq_create_project()` produces a genuinely working project end-to-end (not
just the dev-symlink path above): `devtools::install()`, then call it against a temp directory
with `reference_doc` pointing at a real `.docx`, then `quarto render` inside the scaffolded
project — the same steps as README's Usage section, just pointed at a temp directory instead of
`my-report/`.

There is no linter/formatter configured for the R scripts in this repo; version bumps are manual
and must touch both `DESCRIPTION`'s `Version:` and `inst/_extensions/officequarto/_extension.yml`'s
`version:` together — no automated sync exists between them.

Roxygen documentation is intentionally minimal for now: only the exported functions
(`oq_writeback()`, `oq_create_project()`, `oq_create_quarto_yml()` and the numbering-hook API
`oq_numbering()`/`oq_fig_hook()`/`oq_tbl_hook()`/`oq_ref()`) carry full `@param`/`@return`
docs. Every internal helper (~40 functions across `R/`) carries a bare `#' @noRd` placeholder — a
deliberate, scoped starting point (this was a structural migration, not a documentation pass), not
an oversight; fleshing these out is a natural, separate follow-up.

## Workflow

New features (and exploratory/spike work) should always be implemented on a feature branch, not
directly on `main` — create the branch first, then do the work. Only merge to `main` once the
feature/spike is complete and reviewed.

## Background investigations

`dev/knitr-hooks/` holds the investigation of which {officedown} mechanisms (knitr hooks,
`knit_print`, comment markers, output-format processors) work in a Quarto docx render: `FINDINGS.md`
(summary), `compatibility-matrix.md`, `quarto-knitr-internals.md`, and `experiments/NN-*/run.R` (each
renders a minimal `.qmd` and asserts on `word/document.xml`). `claims-audit.md` lists which statements
are experiment-backed vs. source-read and what was corrected — check it before trusting a claim about
Quarto/officedown internals. `dev/officedown-analyse.md` maps {officedown}'s options to officequarto's
(parity), and `dev/spike-notes.md` is the empirical trail behind the design decisions below.

## Architecture

```
R/                             package logic - oq_writeback()/oq_create_project()/
│                               oq_create_quarto_yml() and the numbering-hook API (oq_numbering()/
│                               oq_fig_hook()/oq_tbl_hook()/oq_ref()) exported, everything else internal; a
│                               package loads all of R/*.R into one namespace at once, so file
│                               boundaries below are purely organizational
├── writeback.R                 oq_writeback() - post-render hook orchestration (exported)
├── create-project.R            oq_create_project() - project scaffolding (exported)
├── create-quarto-yml.R          oq_create_quarto_yml() - standalone, reusable _quarto.yml
│                                generation (exported); also oq_quarto_yml_template()/
│                                oq_write_quarto_yml(), shared with create-project.R
├── style-mapping.R              style-mapping core logic (pure functions, no side effects of
│                                its own — called from writeback.R)
├── style-pruning.R              style-pruning core logic (pure functions, no side effects of
│                                its own — called from writeback.R)
├── option-aliases.R             canonical-name/officedown-alias resolution (pure functions, no
│                                side effects of its own — called from writeback.R)
├── table-mapping.R              table style/layout/width/conditional-formatting core logic
│                                (pure functions, no side effects of its own — called from
│                                writeback.R)
├── table-caption-mapping.R      table caption style/prefix/separator/bold core logic (also the
│                                shared, generic caption-rewriting logic reused by
│                                plot-caption-mapping.R — called from writeback.R)
├── plot-mapping.R                figure style/align core logic (pure functions, no side
│                                effects of its own — called from writeback.R)
├── plot-caption-mapping.R        figure caption paragraph detection (pure functions, no side
│                                effects of its own — called from writeback.R)
├── style-map.R                   free-form style-map (officedown: mapstyles) core logic (pure
│                                functions, no side effects of its own — called from writeback.R)
├── page-mapping.R                page size/margins core logic (pure functions, no side effects
│                                of its own — called from writeback.R)
├── crossref-mapping.R            cross-reference text rewriting core logic (pure functions, no
│                                side effects of its own — called from writeback.R)
├── caption-unwrap.R              removes Quarto's 1x1 caption wrapper tables, last caption
│                                step (pure functions — called from writeback.R; see "Caption
│                                wrapper unwrapping" in the feature reference below)
├── knit-print.R                  knit_print.run()/knit_print.fp_par()/knit_print.block() -
│                                officer inline syntax support (not exported, S3-registered -
│                                see "officer inline syntax" in the feature reference below)
├── officer-par-merge.R           oq_merge_misplaced_ppr() - fixes up fp_par()'s inline-spliced
│                                w:pPr (see "officer inline syntax" in the feature reference below)
├── style-name-markers.R          oq_resolve_style_name_markers() - turns officer's w:pstlname/
│                                w:tstlname style-name markers into real w:val styleIds (see
│                                "officer inline syntax" in the feature reference below)
├── numbering-hook.R              oq_numbering()/oq_fig_hook()/oq_tbl_hook()/oq_ref() - native
│                                Word figure/table numbering via knitr hooks, installed inside the
│                                knitting R session (exported; see "Numbering hook" in the feature reference below)
└── zzz.R                         .onLoad(): conditional knit_print S3 registration

inst/_extensions/officequarto/  the Quarto extension itself - installed alongside the package,
├── _extension.yml               reachable via system.file("_extensions", package = "officequarto");
│                                contributes: project: { project: { type: default,
│                                post-render: [scripts/writeback.R] },
│                                format: { docx: { filters: [scripts/markers.lua, scripts/refs.lua] } } }
└── scripts/
    ├── writeback.R              thin shim: requireNamespace("officequarto") + officequarto::oq_writeback()
    ├── markers.lua              Pandoc Lua filter for the <!---BLOCK_*---> comment markers (see
    │                            "Block markers" in the feature reference below); no R code involved
    └── refs.lua                 Pandoc Lua filter: Quarto notation (@fig-x) for oq_numbering() items
                                 (see "Numbering hook" in the feature reference below); no R code involved

template/                       example/dev project
├── _quarto.yml                  project: type: officequarto; format.docx.reference-doc +
│                                format.docx.officequarto (styles/lists/pandoc-styles/
│                                keep-rendered/...)
├── original.docx                sample reference-doc (custom header/footer/properties/styles)
└── report.qmd                   the .qmd rendered against original.docx
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
     `word/document.xml` (see below) via `style-mapping.R`.
   - Always (unconditionally, no config): removes every style definition in the rendered
     `word/styles.xml` whose ID isn't present in `reference-doc`'s own `word/styles.xml` (see
     "Style pruning" in the feature reference below).
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
`officequarto.tables`/`officequarto.plots` — see "Style-mapping" in the feature reference below. This is a breaking change
with no back-compat fallback for the old flat keys (consistent with this project's prototype status
and no-backwards-compat-hacks philosophy) — `template/_quarto.yml` was migrated; `../hello-wordto`
(external consumer project) was deliberately left on the old schema, out of scope for this change.

### Feature reference (condensed)

Full rationale, empirical findings and spike trail for every item below: `dev/design-notes.md`
(section names match the headings here). Read the matching section before changing a feature.

- **Style-mapping** (`style-mapping.R`): `officequarto.styles.body` and `officequarto.lists.*` take Word
  *display names*, resolved against the rendered `styles.xml`, fail loud if unknown. Lists are detected by
  `<w:numPr>`, never by style name; list type comes from `numbering.xml` (level-0 `numFmt`). Body
  paragraphs are matched against an allowlist of Pandoc role names (`Normal`, `FirstParagraph`, `Compact`,
  `BodyText`, `Body Text`). List options accept an array (one style per nesting level, clamped to the
  deepest). Paragraphs containing a `w:drawing` are excluded from body mapping (figure options own them).
  `document.xml`, `footnotes.xml` and `endnotes.xml` are patched; `comments.xml` is read-only.
- **Option aliases** (`option-aliases.R`): canonical names are chosen fresh; the {officedown} name
  (`.` -> `_`) stays usable as an alias via `oq_resolve_aliased()` (canonical wins on conflict, with a
  warning). Opposite-polarity options use `oq_resolve_inverted_aliased()`; `oq_resolve_fields()` batches.
- **Tables** (`table-mapping.R`): `style` (resolved against *table* styles), `layout`, `width` (0..1 ->
  `w:tblW` pct, x5000), `conditional.*` (-> `w:tblLook`; `band-rows`/`band-columns` are positive-polarity
  inversions of officedown's `no_hband`/`no_vband`). Every field is opt-in: unset = left as rendered, no
  officedown defaults. New `w:tblPr` children are inserted in schema order. The table selector must
  exclude caption wrapper tables (`oq_apply_table_options()` signature on `ImageCaption`).
- **Captions** (`table-caption-mapping.R`, `plot-caption-mapping.R`): Quarto bakes "Table 1: text" into a
  single static run, so `prefix`/`separator`/`number-bold` text-parse it, anchored on the *number*
  (`oq_split_caption_text()`); the shared `oq_apply_captions()` serves tables and figures with separate
  counters. Caption paragraphs are found by adjacency (table: caption immediately *before* a `w:tbl`;
  figure: immediately *after* a drawing paragraph). Only captions with a real wrapper-cell bookmark count
  toward numbering; plain captions are skipped entirely. `caption.above` moves the caption (copy then
  remove, xml2 cannot move nodes) and is only needed to override Pandoc's defaults (tables above,
  figures below). Not ported: officedown `tnd`/`tns`, `tab.lp`/`fig.lp`.
- **Figures** (`plot-mapping.R`): `style` and `align` (`w:jc`) on paragraphs containing `w:drawing`.
- **style-map** (`style-map.R`): `target display name -> [source pStyle IDs]`; targets resolved and fail
  loud, sources matched by direct equality and silently ignored if unused. Runs last in the style
  pipeline. Source IDs for roles with a built-in Word equivalent (e.g. blockquote) follow the
  reference-doc's own (possibly localized) style IDs - verify with `keep-rendered`. Also applied to
  footnotes/endnotes (`FootnoteText`/`EndnoteText` are valid sources; separator entries excluded by
  `oq_note_paragraph_xpath()`).
- **Page** (`page-mapping.R`): `officequarto.page.size`/`margins` in inches -> twips, applied to every
  `w:sectPr`; existing `w:pgSz`/`w:pgMar` are updated in place, no automatic landscape swap.
- **Crossref** (`crossref-mapping.R`): `numbered: false` replaces cross-reference hyperlink text with the
  caption's descriptive text. `auto-number: true` converts captions and references into live `SEQ`/`REF`
  fields (3 runs each, `w:dirty`, no cached result; the bookmark spans label + number, GH #30). The two
  options are mutually exclusive (checked up front). Two latent bugs were fixed here: bookmark search
  must require a wrapper-cell parent, and plain captions must not consume the counter.
- **Caption wrapper unwrapping** (`caption-unwrap.R`, always on, no option): Quarto's 1x1 wrapper tables are
  collected up front by `oq_find_caption_wrappers()` (the `ImageCaption`/`TableCaption` signature vanishes
  once caption styles are remapped) and removed last among the caption steps; caption detection, bookmarks
  (wrapper-cell parent) and table options all still run against the wrapper first. `keepNext` keeps
  caption and content together. Quarto callouts are tables too but are left alone.
- **Style pruning** (`style-pruning.R`): always removes styles not in `reference-doc`; still-referenced
  removed styles only warn. `pandoc-styles.code-block: true` keeps `SourceCode`/`*Tok`; a style name
  remaps the paragraph role only.
- **officer inline syntax** (`knit-print.R`, `officer-par-merge.R`, `style-name-markers.R`, `zzz.R`):
  pre-render feature, `officer` stays `Suggests`; S3 methods registered in `.onLoad()`. `run`/`fp_par`
  splice inline, `block` objects must be fenced `{=openxml}` blocks (Pandoc bug #5094). Post-render
  fix-ups run unconditionally: `oq_resolve_style_name_markers()` (officer's `pstlname`/`tstlname`
  display-name markers -> real styleIds) *before* `oq_merge_misplaced_ppr()` (second `w:pPr` corrupts the
  docx in Word).
- **Block markers** (`markers.lua`): `BLOCK_TOC`/`PAGEBREAK`/`LANDSCAPE_START|STOP` as a Pandoc Lua
  filter; do not combine with `officequarto.page`.
- **Numbering hook** (`numbering-hook.R`, `refs.lua`): chained knitr hooks emit native Word figure/table
  numbering and strip the Quarto id, so `@fig-x` is resolved by `refs.lua`/`oq_ref()` instead. Mixed hook +
  native items need `crossref.auto-number`. Config only via chunk options (`oq.*`).

### Key constraints/gotchas

- **Project-only feature**: post-render hooks are a Quarto *project* feature; they do not fire for
  `quarto render singlefile.qmd` without a `_quarto.yml` project (upstream limitation, not
  something this extension can work around).
- **`quarto add` alone does not activate the hook.** A consuming project's own `_quarto.yml` must
  set `project: type: officequarto` — otherwise `writeback.R` never runs. Verified by counter-test
  in `dev/spike-notes.md` (Spike B).
- Reading resolved config always goes through `quarto inspect <project_dir>` (JSON), never manual
  YAML parsing — this is what makes nested keys like `format.docx.officequarto.tables` reliable.
- xml2 attribute writes on OOXML nodes must use the namespaced attribute name, i.e.
  `xml_attr(node, "w:val") <- x`, not `xml_attr(node, "val") <- x` (the latter creates an
  unnamespaced attribute and silently produces invalid/ignored XML).
- All docx manipulation in `writeback.R` goes through `zip`/`unzip` (CLI, via `system2()`) +
  `xml2`, not `officer` — `officer` is only used in `dev/make-sample-docx.R` to build the base
  sample document (plus direct `xml2` XML injection there too, since `officer` has no high-level
  API to define new paragraph styles), and in `R/knit-print.R` to call `officer::to_wml()` for
  inline officer syntax (`officer` stays `Suggests`, guarded by `requireNamespace()` — see
  "officer inline syntax" above).
- The final write step zips into a `tempfile()` first, then `file.copy()`s that over the rendered
  path — never zips directly onto the file being overwritten, so a failed/partial zip can't corrupt
  the only output file that exists.
- Since the rendered `.docx` is overwritten in place, having it open in another app (e.g. Word) at
  render time can make the overwrite fail or go unnoticed until the app reloads the file — verified
  in practice against a real external consumer project.
