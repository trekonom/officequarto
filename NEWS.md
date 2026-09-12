# officequarto 2.0.0

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
