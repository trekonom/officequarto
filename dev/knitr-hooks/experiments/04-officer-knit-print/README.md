# 04 – knit_print von officer-Objekten
**Hypothese:** `run_pagebreak()`, `block_toc()`, `block_section(landscape)`, `run_autonum()` funktionieren (nur `rmarkdown.pandoc.to` nötig).
**Ergebnis:** bestätigt – Seitenumbruch, `TOC \…`-Feld, `w:orient="landscape"` (A4 quer, `w:sectPr` am Absatzende) und `SEQ`-Feld mit Lesezeichen sind im XML.
**Evidenz:** `run.R` → alle `YES`. Hinweis: Im Test sind `officedown` **und** officequarto's eigene `knit_print`-Methoden (nur wenn Paket geladen) mögliche Quelle; hier wurde `library(officedown)` geladen. Deckt sich mit `R/knit-print.R` dieses Repos.
