# 10 – officedown-Tabellenstil gegen echtes `reference-doc`
**Hypothese:** `tab.style: "tabletemplate"` (existiert in `ref.docx`) wird angewendet.
**Ergebnis:** **widerlegt.** Das XML enthält `<w:tblStyle w:tstlname="tabletemplate"/>` und `<w:pStyle w:pstlname="Normal"/>` – Stil*namen* in nicht-standardkonformen Attributen statt `w:val`-IDs; Word ignoriert sie, der Stil wird nicht angewendet. Caption und `SEQ`-Feld sind korrekt.
**Ursache:** siehe Exp. 12 – *nicht* das fehlende `--reference-doc` (Hypothese hier widerlegt), sondern das fehlende officer-Schreiben (`print.rdocx`) nach dem Render. Ursprüngliche Vermutung war: `officer` löst Namen→IDs nur gegen `base_document` auf; `get_reference_rdocx()` liest `--reference-doc` aus `rmarkdown.pandoc.args`, das Quarto nicht setzt (`execute.R:295–303`), also wird gegen das Pandoc-Default-Dokument aufgelöst.
**Konsequenz:** In Quarto Tabellenstile über officequarto (`tables.style`, Post-Render gegen das echte `reference-doc`) setzen, nicht über `tab.style`. Deckt sich mit dem bekannten `pstlname`-Fehler (`CLAUDE.md`, `R/officer-par-merge.R`).
**Evidenz:** `Rscript run.R` → `requested style … NO`.
