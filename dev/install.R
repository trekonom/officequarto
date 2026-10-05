## Regenerate NAMESPACE/man and (re)install the package, so the extension shim's
## `officequarto::oq_writeback()` picks up changes under R/ before the next `quarto render`.
## Run from the repo root: Rscript dev/install.R
devtools::document(quiet = TRUE)
devtools::install(quiet = TRUE, upgrade = FALSE)
