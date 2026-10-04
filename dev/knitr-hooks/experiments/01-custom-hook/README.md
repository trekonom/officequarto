# 01 – Eigener knitr-Hook über Chunk-Option
**Hypothese:** `knit_hooks$set(myhook=…)` im Setup-Chunk wird von Quarto nicht überschrieben (neuer Name, kein Konflikt).
**Ergebnis:** bestätigt – `before`- und `after`-Ausgabe landen in `word/document.xml`.
**Evidenz:** `Rscript run.R` → `custom hook 'before'/'after' … YES`. Quelle: Quarto setzt nur `chunk/source/output/warning/message/plot/error` (`quarto-cli/src/resources/rmd/hooks.R:205–595`).
