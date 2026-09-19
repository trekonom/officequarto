# Contributing to officequarto

Thanks for your interest in contributing! This document covers development setup and
the project's checks.

See also [`CLAUDE.md`](CLAUDE.md) for the full architecture and conventions reference
(written for AI coding agents working in this repo, but equally useful background for
human contributors).

## Development / tests

officequarto is a real R package — the pure-logic unit tests run through testthat/
`R CMD check` like any other package:

```r
devtools::document()   # (re-)generate NAMESPACE/man after any roxygen change
devtools::test()       # runs every tests/testthat/test-*.R
devtools::check()      # full R CMD check
```

Two checks stay outside that automatic suite, since they need a live `quarto render`
against a real `.docx` and the external `quarto` CLI (not appropriate for
`R CMD check`, which must run in a clean, offline environment):

```bash
Rscript -e 'devtools::document(quiet = TRUE); devtools::install(quiet = TRUE, upgrade = FALSE)'
cd template
quarto render report.qmd
Rscript ../dev/check-writeback.R   # checks header/footer/body/metadata/style-mapping/pruning of the result
```

`officequarto.crossref.auto-number` also has a dedicated end-to-end fixture, kept
separate from `template/` since `template/_quarto.yml` sets `crossref.numbered: false`
(mutually exclusive with `auto-number` by design):

```bash
cd dev/fixtures/auto-number
quarto render report.qmd
Rscript ../../check-auto-number-e2e.R
```

Editing any file under `R/` requires reinstalling the package (`devtools::install()`,
see above) before the next `quarto render` picks up the change — unlike
`template/report.qmd`, which is a plain Quarto document rendered fresh every time.

`dev/make-sample-docx.R` regenerates the sample template `template/original.docx`,
including the ACME custom styles used for style-mapping (requires the R packages
`officer` and `xml2`, only for generating the sample template, not for the hook
itself).

Building the pkgdown site locally (e.g. to preview vignette changes):

```r
pkgdown::build_site()
```
