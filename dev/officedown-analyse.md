# officedown-Analyse: Parität von `officequarto` zu `officedown::rdocx_document()`

## 1. Versionen und Datum

| | |
|---|---|
| officedown | 0.4.1 (installierte CRAN-Version, Quelle per `formals()`/`body()` gelesen) |
| officer | installiert (Suggests von officequarto) |
| Quarto | 1.8.24 |
| R | 4.5.2 |
| Analysedatum | 2026-10-04 |
| officequarto | 0.2.0 |

Abweichung zum Arbeitsauftrag: Der Post-Render-Hook nutzt **nicht** `{officer}`, sondern `zip`/`unzip` +
`{xml2}` (`R/writeback.R`). `{officer}` ist nur `Suggests` (für `knit_print`-Methoden und
`dev/make-sample-docx.R`).

## 2. Gesamttabelle

Signatur: `rdocx_document(base_format = "rmarkdown::word_document", tables = list(), plots = list(),
lists = list(), mapstyles = list(), page_size = NULL, page_margins = NULL, reference_num = TRUE, ...)`

Legende Kategorie: A nativ, B Lua-Filter, C Post-Render, D Neuentwurf, E entfällt.
Status: umgesetzt / teilweise / offen. Alle officequarto-Namen liegen unter `format.docx.officequarto.`.
Abweichend von officedown sind **alle** officequarto-Defaults „unset = Pandoc/reference-doc-Verhalten"
(bewusste Entscheidung, siehe CLAUDE.md „Table options"); die Spalte „Default" nennt den officedown-Default.

### 2.1 Eigene Argumente von `rdocx_document()`

| officedown-Option | Default | Wirkung | Mechanismus in officedown | Kat. | officequarto-Name | Alias | Status | Gruppe / Datei |
|---|---|---|---|---|---|---|---|---|
| `tables$style` | `"Table"` | Tabellenstil | knitr-Chunk-Opt `tab.style`, ausgewertet in `knit_print.data.frame` | C | `tables.style` | `tables_style` | umgesetzt | G1, `R/table-mapping.R` |
| `tables$layout` | `"autofit"` | Tabellenlayout | wird in `rdocx_document()` **nicht** an Chunk-Optionen weitergereicht (toter Default in 0.4.1) | C | `tables.layout` | `tables_layout` | umgesetzt (Mehrwert ggü. officedown) | G1 |
| `tables$width` | `1` | relative Breite | `tab.width` | C | `tables.width` | `tables_width` | umgesetzt | G1 |
| `tables$tab.lp` | `"tab:"` | bookdown-Label-Präfix für `\@ref(tab:x)` | `post_knit_caption_references` (Pandoc-Markdown, vor Pandoc) | E | – | – | bewusst entfallen | siehe 3.2 |
| `tables$topcaption` | `TRUE` | Caption über Tabelle | `tab.topcaption` | A/C | `tables.caption.above` | `tables_topcaption` | umgesetzt | `R/table-caption-mapping.R` |
| `tables$caption$style` | `"Table Caption"` | Absatzformat Caption | `block_caption(style=)` | C | `tables.caption.style` | `tables_caption_style` | umgesetzt | G3 |
| `tables$caption$pre` | `"Table"` | Text vor Nummer | `run_autonum(pre_label=)` | C (A via `crossref.tbl-title`) | `tables.caption.prefix` | `tables_caption_pre` | umgesetzt | G3 |
| `tables$caption$sep` | `":"` | Text nach Nummer | `run_autonum(post_label=)` | C | `tables.caption.separator` | `tables_caption_sep` | umgesetzt | G3 |
| `tables$caption$tnd` | `0` | Kapitel-Tiefe der Nummer (`2-1`) | `run_autonum(tnd=)`, STYLEREF-Feld | D | – | `tables_caption_tnd` (geplant) | offen | siehe 3.1 |
| `tables$caption$tns` | `"-"` | Trenner Kapitel/Nummer | `run_autonum(tns=)` | D | – | `tables_caption_tns` (geplant) | offen | siehe 3.1 |
| `tables$caption$fp_text` | bold | Zeichenformat Label+Nummer (16 Felder) | `run_autonum(prop=)` | C | `tables.caption.number-bold` deckt nur `bold` ab | `tables_caption_bold` | **teilweise** | siehe 3.3 |
| `tables$conditional$first_row` | `TRUE` | Kopfzeile | `first_row` in `knit_print.data.frame` | C | `tables.conditional.first-row` | `…_first_row` | umgesetzt | G2 |
| `…$first_column` | `FALSE` | erste Spalte | dto. | C | `…first-column` | `…_first_column` | umgesetzt | G2 |
| `…$last_row` | `FALSE` | Summenzeile | dto. | C | `…last-row` | `…_last_row` | umgesetzt | G2 |
| `…$last_column` | `FALSE` | letzte Spalte | dto. | C | `…last-column` | `…_last_column` | umgesetzt | G2 |
| `…$no_hband` | `FALSE` | Zeilenbänderung aus | dto. | C | `…band-rows` (Polarität invertiert) | `…_no_hband` | umgesetzt | G2, `oq_resolve_inverted_aliased()` |
| `…$no_vband` | `TRUE` | Spaltenbänderung aus | dto. | C | `…band-columns` (invertiert) | `…_no_vband` | umgesetzt | G2 |
| `plots$style` | `"Figure"` | Absatzformat Bildabsatz | `plot_word_fig_caption` (`fig.style`) | C | `plots.style` | `plots_style` | umgesetzt | G4, `R/plot-mapping.R` |
| `plots$align` | `"center"` | Ausrichtung | `fig.align` | A (`fig-align`) / C | `plots.align` | `plots_align` | umgesetzt (C, siehe 4.3) | G4 |
| `plots$fig.lp` | `"fig:"` | Label-Präfix | wie `tab.lp` | E | – | – | bewusst entfallen | 3.2 |
| `plots$topcaption` | `FALSE` | Caption über Bild | `fig.topcaption` | A/C | `plots.caption.above` | `plots_topcaption` | umgesetzt | `R/plot-caption-mapping.R` |
| `plots$caption$style` | `"Image Caption"` | Absatzformat | `block_caption` | C | `plots.caption.style` | `plots_caption_style` | umgesetzt | G5 |
| `plots$caption$pre` | `"Figure "` | Präfix | `run_autonum` | C | `plots.caption.prefix` | `plots_caption_pre` | umgesetzt | G5 |
| `plots$caption$sep` | `": "` | Trenner | `run_autonum` | C | `plots.caption.separator` | `plots_caption_sep` | umgesetzt | G5 |
| `plots$caption$tnd` / `tns` | `0` / `"-"` | wie Tabellen | `run_autonum` | D | – | – | offen | 3.1 |
| `plots$caption$fp_text` | bold | wie Tabellen | `run_autonum(prop=)` | C | `plots.caption.number-bold` (nur bold) | `plots_caption_bold` | teilweise | 3.3 |
| `lists$ul.style` | `NULL` | Aufzählungsformat | `process_list_settings`: ersetzt **Nummerierungs**-Stil (`numbering.xml`, `abstractNum`) | C | `lists.list-bullet` | `ul_style` | umgesetzt, **andere Semantik** | 3.4 |
| `lists$ol.style` | `NULL` | Nummerierungsformat | dto. | C | `lists.list-number` | `ol_style` | umgesetzt, andere Semantik | 3.4 |
| – | – | (Buchstabenlisten) | kein Äquivalent | – | `lists.list-letter` | – | officequarto-Erweiterung | |
| `mapstyles` | `list()` | Stil-Umbenennung `ziel = c(quellen)` | `change_styles`: Anzeigenamen → IDs, ersetzt `pStyle`/`rStyle`/`tblStyle` | C | `style-map` | – (Abschnittsname neu) | **teilweise** | 3.5 |
| `page_size$width` | 8.27 | Seitenbreite (in) | `body_set_default_section` | C | `page.size.width` | `page_size_width` | umgesetzt | G8, `R/page-mapping.R` |
| `page_size$height` | 11.7 | Seitenhöhe | dto. | C | `page.size.height` | `page_size_height` | umgesetzt | G8 |
| `page_size$orient` | `"portrait"` | Ausrichtung | dto. | C | `page.size.orientation` | `page_size_orient` | umgesetzt | G8 |
| `page_margins$top/bottom/left/right/header/footer/gutter` | 0.984 / 0.492 / 0 | Ränder (in) | dto. | C | `page.margins.*` | `page_margins_*` | umgesetzt | G8 |
| `reference_num` | `TRUE` | Verweis zeigt Nummer (TRUE) oder Text (FALSE) | `post_knit_std_references` | C | `crossref.numbered` | `reference_num` | umgesetzt | G9, `R/crossref-mapping.R` |

### 2.2 Durchgereichte Argumente (`base_format = word_document`, `...`)

`rdocx_document()` setzt `reference_docx` auf ein eigenes Template, wenn nichts übergeben wird, und
erzwingt `number_sections = FALSE`. Alle anderen `word_document()`-Argumente werden unverändert
durchgereicht.

| word_document-Argument | Kat. | Quarto-Entsprechung | Status in officequarto |
|---|---|---|---|
| `reference_docx` | A | `format.docx.reference-doc` | umgesetzt (Kern des Projekts) |
| `toc`, `toc_depth` | A | `toc`, `toc-depth` | nativ, nichts zu tun |
| `number_sections` | A (aber siehe unten) | `number-sections` | nativ; officedown erzwingt `FALSE`, officequarto nicht (Abweichung dokumentieren) |
| `fig_width`, `fig_height` | A | `fig-width`, `fig-height` | nativ |
| `fig_caption` | E | Quarto: Captions immer aktiv | entfällt |
| `df_print` | A | `df-print` | nativ |
| `highlight` | A | `highlight-style` | nativ |
| `keep_md` | A | `keep-md` | nativ |
| `md_extensions` | A | `from: markdown+ext` | nativ |
| `pandoc_args` | A | `pandoc-args` | nativ |

## 3. Detailabschnitte Kategorie D (und Grenzfälle)

### 3.1 `caption$tnd` / `caption$tns` (kapitelbezogene Nummerierung, z. B. „Tabelle 2-1")

Konflikt: officedown schreibt ein `STYLEREF`-Feld (Überschriftsnummer) vor das `SEQ`-Feld; Quarto zählt
global. Stand heute ist die Nummer in Quarto statischer Text.

| Option | Vorteil | Nachteil |
|---|---|---|
| (a) Nur mit `crossref.auto-number: true` unterstützen: `STYLEREF <tnd> \r` + `tns` vor das SEQ-Feld, `SEQ … \s <tnd>` für Neustart pro Kapitel | echte Word-Felder, Word hält die Zählung; geringer Zusatzaufwand, da Felderzeugung existiert | Quarto-Crossref-Text und Word-Nummer stimmen nur nach Feldaktualisierung überein; setzt nummerierte Überschriften im reference-doc voraus |
| (b) Eigene Nummerierung berechnen (Kapitelgrenzen tracken) | funktioniert ohne Felder | dupliziert Quarto-Logik, fehleranfällig |
| (c) Weiterhin nicht portieren | kein Aufwand | bleibt Paritätslücke |

**Empfehlung: (a).** Name: `tables.caption.chapter-depth` (Alias `tables_caption_tnd`),
`tables.caption.chapter-separator` (Alias `tables_caption_tns`), analog `plots.caption.*`. Ohne
`auto-number` fail-loud (Konflikt mit statischem Text).

### 3.2 `tab.lp` / `fig.lp`

bookdown-Syntaxkonzept (`\@ref(tab:x)`), in Quarto durch `@tbl-x`/`@fig-x` ersetzt, vor dem Hook
bereits aufgelöst. Sichtbarer Präfix: `crossref.tbl-title`/`fig-title`. **Empfehlung: E (entfällt)**, in der
README-Tabelle mit Begründung führen (Phase 3 des Auftrags).

### 3.3 `caption$fp_text`

16 Zeichenformat-Felder für „Label+Nummer". officequarto bildet nur `bold` ab (`number-bold`).
Optionen: (a) so lassen, (b) kleine Teilmenge ergänzen (`number-italic`, `number-color`,
`number-font-size`), (c) vollständige `number-format`-Untergruppe. **Empfehlung: (a)**, auf Nachfrage (b).
Die Schriftformatierung gehört normalerweise in den Caption-Absatzstil des reference-doc.

### 3.4 `lists$ul.style` / `ol.style` (Semantikunterschied)

officedown wählt einen **Nummerierungsstil** (und ersetzt dessen `abstractNum`-Zuordnung in
`numbering.xml`), officequarto mappt auf **Absatzstile** (`List Bullet` etc.). Ergebnis ähnelt sich, ist
aber nicht identisch: officedown ändert Einzug/Symbol über die Nummerierungsdefinition, officequarto den
Absatzstil. Das Alias `ul_style`/`ol_style` ist daher nicht bedeutungsgleich. **Empfehlung:** Unterschied
in README/Vignette explizit nennen; keine Umsetzung der `numbering.xml`-Variante, außer es besteht Bedarf
(ggf. später `lists.numbering-style`).

### 3.5 `mapstyles` (Teilparität)

officedown: Quellen sind Anzeigenamen, ersetzt `pStyle`, `rStyle` **und** `tblStyle`. officequarto
(`R/style-map.R`): Quellen sind Pandoc-Style-IDs, nur `pStyle`. Lücken: Zeichen- und Tabellenstile, Quellen
als Anzeigenamen. Zeichenstile sind nützlich (z. B. `VerbatimChar`, `Hyperlink`). **Empfehlung:** `rStyle`
und `tblStyle` in `style-map` ergänzen (gleiche Eingabeform, nach Typ des Zielstils entscheiden).

## 4. Weitere Befunde

1. **Seitenlayout:** officedown wendet `page_size`/`page_margins` nur an, wenn **beide** gesetzt sind,
   und ersetzt nur die letzte Dokument-`sectPr` (`type = continuous`). officequarto: beide unabhängig,
   alle `sectPr`. Abweichung (sinnvoller) dokumentieren.
2. **Unbekannte Optionen:** Konvention des Auftrags („Warnung statt harter Fehler") ist nicht
   umgesetzt. `grep` nach „unknown"/„unbekannt" in `R/` ohne Treffer. → Lücke.
3. **Kat.-A-Prüfung `align`:** Quarto `fig-align` ist natives Pandoc-Attribut, wirkt aber über die
   Absatzeigenschaft des Bildabsatzes. Gleichwertig, daher bleibt die C-Variante nur als Alias zum
   einheitlichen Namensschema sinnvoll. Vorrangregel siehe 5.2.
4. **Defaults:** officequarto setzt bewusst **keine** officedown-Defaults aktiv (unset = unverändert).
   Das widerspricht der Konvention „Defaults identisch zu officedown" und wurde früher mit dem Nutzer
   entschieden. Hier zur erneuten Bestätigung vorgelegt.

## 5. Paritätslücken und Vorschläge

### 5.1 Offene Optionen ohne Gruppe

| Lücke | Kat. | Vorschlag |
|---|---|---|
| `caption.tnd`/`tns` (Tabellen, Abbildungen) | D | Gruppe 10, nur mit `auto-number` (3.1) |
| `caption.fp_text` (außer bold) | C | zurückstellen (3.3) |
| `mapstyles` für Zeichen-/Tabellenstile | C | Gruppe 11 (3.5) |
| Warnung bei unbekannten Optionen | C | Gruppe 12, `oq_warn_unknown_options()` |
| `lists` über Nummerierungsstil | C | zurückstellen (3.4) |

### 5.2 Vorschlag Vorrangregel (officequarto-Option vs. native Quarto-Option, Kat. A)

Betrifft: `plots.align` vs. `fig-align`, `caption.above` vs. `tbl-cap-location`/`fig-cap-location`,
`caption.prefix` vs. `crossref.tbl-title`/`fig-title`. Vorschlag: **officequarto gewinnt**, weil es
nachgelagert (post-render) arbeitet und die explizitere Angabe darstellt. Bei widersprüchlichen Werten
eine Warnung („`<native>` wurde durch `officequarto.<name>` überschrieben"). Ohne Widerspruch still. Die
native Option wird dafür über `quarto inspect` mit eingelesen.

### 5.3 Reihenfolge

1. Gruppe 12 (Warnung bei unbekannten Optionen), klein, ohne Risiko
2. Gruppe 11 (`style-map` für `rStyle`/`tblStyle`)
3. Gruppe 10 (`tnd`/`tns`), setzt `auto-number` voraus
4. README-Optionstabelle vervollständigen (Spalten gemäß Auftrag: officequarto-Name | Alias | Default |
   Kategorie | Hinweis), Kat.-E-Optionen (`tab.lp`, `fig.lp`, `fig_caption`) mit Begründung aufnehmen
5. Danach offene Issues #18 (mehrteilige Captions) und #4 (Content-Controls)

## 6. Fazit

Die meisten Optionen von `rdocx_document()` sind umgesetzt. Teilweise umgesetzt sind `caption$fp_text`
(nur bold), `mapstyles` (nur `pStyle`) und die Listenoptionen (andere Semantik). Offen sind
`caption$tnd`/`tns` (Tabellen und Abbildungen). Bewusst entfallen `tab.lp` und `fig.lp`. Die eigentliche
Paritätslücke ist klein; wichtiger sind die dokumentierten Abweichungen (Defaults, Seitenlayout,
Listenstil-Semantik, fehlende Warnung bei unbekannten Optionen).
