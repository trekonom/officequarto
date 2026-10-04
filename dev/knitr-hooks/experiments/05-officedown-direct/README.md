# 05 – officedown/flextable/ggplot2 direkt in Quarto
**Hypothese:** `tab.cap`/`tab.id` + `knit_print.data.frame` funktionieren; `knitr: opts_chunk:` im YAML ersetzt `rdocx_document(tables=…)`.
**Ergebnis:**
- `data.frame` (officedown `knit_print.data.frame`): **ja** – Caption, `SEQ`-Feld, Lesezeichen `dftab`, Präfix „Tabelle " aus `knitr: opts_chunk: tab.cap.pre` (`execute.R:365–373` mergt `opts_chunk` aus dem YAML).
- `flextable` mit `tab.cap`/`set_caption()`: **Caption fehlt** – flextable setzt in Quarto bewusst `caption <- ""` (`flextable/R/printers.R`, `knit_to_wml`, Zweig `else if (quarto)`) und überlässt die Caption Quarto: `#| tbl-cap` + `label: tbl-…` **funktioniert** (statischer Text, kein Word-Feld).
- `ggplot2` mit `fig-cap`: ja (Quarto-eigener Plot-Hook; officedown's Hook ist nicht aktiv).
**Evidenz:** `run.R`; `tblStyle=Table`, `pStyle`s `TableCaption`/`ImageCaption`. Warnung von flextable: Bilder/Hyperlinks in Tabellen erfordern `flextable::repair_docx()` im Post-Render.
