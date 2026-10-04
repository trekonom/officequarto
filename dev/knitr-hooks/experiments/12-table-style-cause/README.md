# 12 – Ursache des unwirksamen `tab.style` (Folge von Exp. 10)
**Hypothese A (aus Exp. 10, widerlegt):** Es liegt an fehlendem `--reference-doc` in `rmarkdown.pandoc.args`.
Test: `b-pandoc-args.qmd` setzt `opts_knit$rmarkdown.pandoc.args = c("--reference-doc","ref.docx")` (verifiziert in der Log-Zeile `PANDOC.ARGS`) → unverändert `w:tstlname="table_template"`.
**Hypothese B (bestätigt):** officer schreibt Stilnamen als Marker (`w:tstlname`/`w:pstlname`) und ersetzt sie erst beim **Schreiben** eines docx durch `w:val`-IDs (`officer/R/docx_write.R` → `convert_custom_styles_in_wml`, `utils-xml.R:334`, ausgelöst durch `print.rdocx`). Unter rmarkdown erledigt das officedown's `post_processor` (`read_docx(output_file) … print(x, target = output_file)`, `rdocx_document.R`). Quarto hat diesen Schritt nicht.
**Fix in Quarto:** Post-Render-Round-Trip (`proj/post.R`: `print(officer::read_docx(f), target = f)`) → `<w:tblStyle w:val="tabletemplate"/>`, keine `tstlname`/`pstlname` mehr, Caption + `SEQ` bleiben (`proj/` in `run.R`).
**Randbefunde:**
- `tab.style` erwartet den **Anzeigenamen** (`table_template`), nicht die Style-ID (`tabletemplate`); mit der ID bricht der Round-Trip mit „Some styles can not be found in the document" ab. (Exp. 10 hatte zunächst die ID benutzt; das Ergebnis dort – Marker bleiben stehen – gilt unabhängig davon.)
- Dieselbe Ursache erklärt die in `CLAUDE.md` dokumentierten `w:pstlname`-Reste bei `fp_par()`.
**Konsequenz für officequarto:** Mögliche Härtung (nicht umgesetzt): im `oq_writeback()` verbliebene `w:pstlname`/`w:tstlname` anhand von `styles.xml` (Name→ID) nach `w:val` umschreiben – ohne officer-Abhängigkeit, analog zu `oq_style_name_to_id()`.
