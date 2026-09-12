## Post-render hook shim. The actual logic has lived in R/writeback.R
## (oq_writeback()) since the switch to an R package - see CLAUDE.md/README.md
## for architecture/configuration. This script deliberately stays minimal:
## Quarto invokes it via Rscript, so all that's needed here is to make sure
## the package is installed, and kick off the orchestration.
if (!requireNamespace("officequarto", quietly = TRUE)) {
  stop(
    "officequarto: R package 'officequarto' is required but not installed.\n",
    "Install e.g. via: pak::pak(\"trekonom/officequarto\")",
    call. = FALSE
  )
}
officequarto::oq_writeback()
