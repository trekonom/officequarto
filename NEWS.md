# officequarto 0.1.0

Initial development version. Not yet on CRAN.

* Converted the project into a proper R package (`officequarto`), with the Quarto extension it
  powers bundled inside it under `inst/_extensions/`. The R package is now a required runtime
  dependency: the extension's post-render hook is a thin shim that calls the package's exported
  `oq_writeback()`.
* Added `oq_create_project()` to scaffold a new officequarto project from R (modeled on
  `usethis::create_project()`), copying in the bundled extension, an optional reference document,
  and a `_quarto.yml` listing every `officequarto` option at its default value.
* Ported a growing set of {officedown}-analogous configuration options, all nested under a single
  `format.docx.officequarto` key:
  - Paragraph style-mapping for body text and lists (`officequarto.styles`, `officequarto.lists`),
    including per-nesting-level list styles and officedown-compatible option aliases.
  - Table options: style/layout/width, conditional formatting, and captions
    (`officequarto.tables`).
  - Figure options: style/alignment and captions (`officequarto.plots`).
  - Caption position control (`caption.above`) for both tables and figures.
  - Free-form style remapping (`officequarto.style-map`), including footnote/endnote paragraph
    styling.
  - Page size/margins (`officequarto.page`).
  - Cross-reference text control (`officequarto.crossref.numbered`) and live, renumbering Word
    `SEQ`/`REF` fields (`officequarto.crossref.auto-number`).
* Added automatic style pruning: styles Pandoc adds but that are absent from `reference-doc` are
  removed from the rendered `.docx`, with an opt-in escape hatch for code-block styling
  (`officequarto.pandoc-styles.code-block`).
* Added `vignette("architecture")` and `vignette("options")`, and a pkgdown site published from
  `main`.
* Added support for using {officer}'s run/paragraph/block constructors (`ftext()`, `fp_par()`,
  `block_pour_docx()`, ...) directly as inline R expressions in a `.qmd`, the same way {officedown}
  supports in an `.Rmd` — registers `knit_print` methods for {officer}'s S3 classes so this works
  without needing {officedown} itself. See `vignette("officer-syntax")`.
  `fp_par()`'s misplaced `w:pPr` fragment (a structural necessity of the inline mechanism, shared
  with {officedown}) is automatically merged back into the paragraph's real `w:pPr` after render.
* Fixed: the rendered `.docx` could fail to open in Word entirely, from two independent causes,
  both only visible against real Word (not `python-docx`/XML well-formedness checks, which stayed
  silent): a scratch comparison directory (`__original__/`) was leaking into the final `.docx`'s
  zip archive, and any paragraph ending up with more than one `w:pPr` (from `fp_par()` inline
  syntax, or independently from Pandoc's own caption-wrapper-cell paragraphs) is now detected and
  merged down to one, unconditionally, regardless of `officequarto.*` configuration.
