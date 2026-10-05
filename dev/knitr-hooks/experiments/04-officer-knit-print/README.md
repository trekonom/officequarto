# 04 – knit_print von officer-Objekten
**Hypothese:** `run_pagebreak()`, `block_toc()`, `block_section(landscape)`, `run_autonum()` funktionieren (nur `rmarkdown.pandoc.to` nötig).
**Ergebnis:** bestätigt – Seitenumbruch, `TOC \…`-Feld, `w:orient="landscape"` (A4 quer, `w:sectPr` am Absatzende) und `SEQ`-Feld mit Lesezeichen sind im XML.
**Evidenz:** `run.R` → alle `YES`. Hinweis: Im Test war nur `officer`/`officedown` geladen (nicht `officequarto`) – die `knit_print`-Methoden stammen also aus officedown, nicht aus diesem Repo. Deckt sich mit `R/knit-print.R` dieses Repos.
