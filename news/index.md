# Changelog

## officequarto 0.1.0

Initial development version. Not yet on CRAN.

- Converted the project into a proper R package (`officequarto`), with
  the Quarto extension it powers bundled inside it under
  `inst/_extensions/`. The R package is now a required runtime
  dependency: the extension’s post-render hook is a thin shim that calls
  the package’s exported
  [`oq_writeback()`](https://trekonom.github.io/officequarto/reference/oq_writeback.md).
- Added
  [`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
  to scaffold a new officequarto project from R (modeled on
  `usethis::create_project()`), copying in the bundled extension, an
  optional reference document, and a `_quarto.yml` listing every
  `officequarto` option at its default value. It also accepts a
  `quarto_yml` argument to copy in your own `_quarto.yml` instead of
  generating one.
- Added
  [`oq_create_quarto_yml()`](https://trekonom.github.io/officequarto/reference/oq_create_quarto_yml.md),
  a standalone helper that writes a reusable, officequarto-ready
  `_quarto.yml` (the same content
  [`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
  generates internally) to a given path - useful for converting an
  existing Quarto project to officequarto, or as an editable starting
  point for future projects.
- Ported a growing set of {officedown}-analogous configuration options,
  all nested under a single `format.docx.officequarto` key:
  - Paragraph style-mapping for body text and lists
    (`officequarto.styles`, `officequarto.lists`), including
    per-nesting-level list styles and officedown-compatible option
    aliases.
  - Table options: style/layout/width, conditional formatting, and
    captions (`officequarto.tables`).
  - Figure options: style/alignment and captions (`officequarto.plots`).
  - Caption position control (`caption.above`) for both tables and
    figures.
  - Free-form style remapping (`officequarto.style-map`), including
    footnote/endnote paragraph styling.
  - Page size/margins (`officequarto.page`).
  - Cross-reference text control (`officequarto.crossref.numbered`) and
    live, renumbering Word `SEQ`/`REF` fields
    (`officequarto.crossref.auto-number`).
- Added automatic style pruning: styles Pandoc adds but that are absent
  from `reference-doc` are removed from the rendered `.docx`, with an
  opt-in escape hatch for code-block styling
  (`officequarto.pandoc-styles.code-block`).
- Added
  [`vignette("architecture")`](https://trekonom.github.io/officequarto/articles/architecture.md)
  and
  [`vignette("options")`](https://trekonom.github.io/officequarto/articles/options.md),
  and a pkgdown site published from `main`.
- Added support for using {officer}’s run/paragraph/block constructors
  ([`ftext()`](https://davidgohel.github.io/officer/reference/ftext.html),
  [`fp_par()`](https://davidgohel.github.io/officer/reference/fp_par.html),
  [`block_pour_docx()`](https://davidgohel.github.io/officer/reference/block_pour_docx.html),
  …) directly as inline R expressions in a `.qmd`, the same way
  {officedown} supports in an `.Rmd` — registers `knit_print` methods
  for {officer}’s S3 classes so this works without needing {officedown}
  itself. See
  [`vignette("officer-syntax")`](https://trekonom.github.io/officequarto/articles/officer-syntax.md).
  [`fp_par()`](https://davidgohel.github.io/officer/reference/fp_par.html)’s
  misplaced `w:pPr` fragment (a structural necessity of the inline
  mechanism, shared with {officedown}) is automatically merged back into
  the paragraph’s real `w:pPr` after render.
- Fixed: the rendered `.docx` could fail to open in Word entirely, from
  two independent causes, both only visible against real Word (not
  `python-docx`/XML well-formedness checks, which stayed silent): a
  scratch comparison directory (`__original__/`) was leaking into the
  final `.docx`’s zip archive, and any paragraph ending up with more
  than one `w:pPr` (from
  [`fp_par()`](https://davidgohel.github.io/officer/reference/fp_par.html)
  inline syntax, or independently from Pandoc’s own caption-wrapper-cell
  paragraphs) is now detected and merged down to one, unconditionally,
  regardless of `officequarto.*` configuration.
