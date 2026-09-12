## Post-render hook shim. Die eigentliche Logik lebt seit der Umstellung auf
## ein R-Paket in R/writeback.R (oq_writeback()) - siehe CLAUDE.md/README.md
## fuer Architektur/Konfiguration. Dieses Skript bleibt bewusst minimal:
## Quarto ruft es per Rscript aus, also muss hier nur sichergestellt werden,
## dass das Paket installiert ist, und die Orchestrierung angestossen werden.
if (!requireNamespace("officequarto", quietly = TRUE)) {
  stop(
    "officequarto: R package 'officequarto' is required but not installed.\n",
    "Install e.g. via: pak::pak(\"trekonom/officequarto\")",
    call. = FALSE
  )
}
officequarto::oq_writeback()
