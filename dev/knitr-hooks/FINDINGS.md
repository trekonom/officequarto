# Findings: knitr-Hooks in Quarto nach dem Vorbild von officedown

**Stand:** Quarto 1.8.24, R 4.5.2, knitr 1.51, rmarkdown 2.30, officedown 0.4.1, officer 0.7.3, flextable 0.9.11.
Details: `officedown-mechanisms.md`, `quarto-knitr-internals.md`, `experiments/`, `compatibility-matrix.md`, `prototype/`.

## Zusammenfassung
- Quarto ruft intern `rmarkdown::render()` mit einem selbst gebauten Format auf; ein fremdes Format
  (`rdocx_document`) kann nicht gewählt werden. Damit entfallen `post_knit` und `post_processor`.
- `knit_print`-Methoden (officer, officedown-Tabellen) und rohes OpenXML laufen unverändert.
- Eigene Hooks funktionieren, **Ersetzen** von `plot`/`chunk` zerstört Quarto's Crossrefs (Exp. 3);
  **Chaining** (`prototype/oq-hooks.R`) funktioniert.
- `<!---BLOCK_*--->`-Marker brauchen einen Lua-Filter (`prototype/markers.lua`) – funktioniert.
- flextable übergibt Captions in Quarto an Quarto (`tbl-cap`), statt Word-Feld.

## Empfehlung
Quarto-native Crossrefs plus officequarto (`auto-number` für Live-Felder) nutzen; officer-Objekte
inline; Marker nur bei Bedarf per Lua-Filter. officedown's Plot-Hook nicht übernehmen.

## Geklärte Fragen (Exp. 9–11)
- `fig.cap` aus `opts_hooks` löst Quarto-Nummerierung und Crossref aus (Exp. 9).
- **officedown-`tab.style` wirkt in Quarto nicht**: `knit_print.data.frame` schreibt `w:tstlname`/`w:pstlname` statt `w:val`-IDs (Exp. 10). Ursache (Exp. 12): officer ersetzt Stil-Marker erst beim Schreiben eines docx; ein Post-Render-`print(read_docx(f), target = f)` behebt es. `tab.style` nimmt den Anzeigenamen. Alternativ Tabellenstile über `officequarto.tables.style`.
- Größen-Override der Landscape-Section funktioniert (Exp. 11).

## Offen
- Umgesetzt in PR #21: `oq_writeback()` schreibt verbliebene `pstlname`/`tstlname` selbst nach `w:val` um (`R/style-name-markers.R`, ohne officer). `tab.style` und `fp_par(word_style=)` wirken damit in officequarto-Projekten ohne eigenen Round-Trip.
- Landscape mit Kopf-/Fußzeilen und freien Rändern; Spalten-Sections (`BLOCK_MULTICOL_*`) nicht umgesetzt.
