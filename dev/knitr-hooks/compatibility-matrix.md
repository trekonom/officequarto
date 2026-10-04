# Kompatibilitätsmatrix: officedown → Quarto (docx)

Basis: Phasen 1–3 (`officedown-mechanisms.md`, `quarto-knitr-internals.md`, `experiments/*/README.md`).
„officequarto?" verweist auf die bestehende Abdeckung (`dev/officedown-analyse.md`, `CLAUDE.md`).

| officedown-Feature | läuft unverändert | mit Anpassung | native Quarto-Alternative | officequarto? | Empfehlung |
|---|---|---|---|---|---|
| `run_*`/`fp_par` inline (`ftext()`, `run_pagebreak()` …) | **Ja** (Exp. 4) | – | `{{< pagebreak >}}` | `R/knit-print.R` | officer-`knit_print` nutzen; Fix `oq_merge_misplaced_ppr()` nötig für `fp_par` |
| `block_toc()`, `block_section()`, `block_pour_docx()` | **Ja** (Exp. 4) | – | `toc: true`, `::: {.landscape}` (nur fester A4-Querformat-sectPr, `quarto-post/landscape.lua`) | `R/knit-print.R` | officer-Blöcke nutzen, wenn Papiergröße/Spalten frei sein sollen |
| Marker `<!---BLOCK_*--->` | **Nein** (Exp. 7, still verworfen) | per Lua-Filter/Extension nachbaubar (HTML-Kommentar → `RawBlock openxml`) | s. o. | nein | nicht portieren; stattdessen Funktionsaufruf oder `{{< >}}`-Shortcode |
| Tabellen `tab.cap`/`tab.id`/`tab.style`/… (`knit_print.data.frame`) | **Ja**, wenn `officedown` geladen (Exp. 5; SEQ-Feld, Lesezeichen) | Defaults über `knitr: opts_chunk:` im YAML; `tab.style` wirkt erst nach officer-Round-Trip im Post-Render (Exp. 10/12: sonst ungültige `w:tstlname`-Marker; nicht am `--reference-doc` gelegen) | `tbl-cap`, `label: tbl-…` (statischer Text) | Optionen `tables.*` per Post-Render (`R/table-*.R`), `crossref.auto-number` für SEQ/REF | Quarto-Crossref + officequarto `auto-number`; officedown-Pfad nur wenn Live-Felder ohne Post-Render gewünscht |
| flextable `tab.cap`/`set_caption()` | **Nein** (Exp. 5; Quarto-Zweig setzt Caption `""`) | `tbl-cap` verwenden | `tbl-cap` | wie oben | `tbl-cap` + `repair_docx()` im Post-Render bei Bildern/Links |
| Plot-Hook mit Word-Feldcaption (`fig.cap`, `fig.topcaption`, `fig.align`, `fig.style`) | **Nein** (Exp. 3: Ersetzen von `plot` bricht Quarto-Crossrefs) | Hook-**Chaining** statt Ersetzen oder Post-Render | `fig-cap`, `fig-align`, `label: fig-…` | `plots.*`, `caption.above` (`R/plot-*.R`) | Quarto-nativ + officequarto; officedown-Hook nicht übernehmen |
| `reference_num`, `\@ref(tab:x)`-Querverweise | **Nein** (`post_knit` fehlt) | – | `@tbl-x`/`@fig-x` | `crossref.numbered`, `auto-number` (REF-Felder) | Quarto-Syntax verwenden |
| `lists$ul.style/ol.style`, `mapstyles`, `page_size/margins` (Post-Processor) | **Nein** (`post_processor` fehlt) | Projekt-`post-render` (Exp. 8) | `reference-doc` | `lists.*`, `style-map`, `page.*` | bereits abgedeckt |
| Eigene knitr-Hooks / `opts_hooks` | **Ja** (Exp. 1, 2) | Quarto-eigene Namen nicht überschreiben | – | – | verwenden, nur neue Namen; vorhandene Hooks chainen |
| Rohes OpenXML (`asis_output`, `results='asis'`) | **Ja** (Exp. 6) | – | `{=openxml}` in Markdown | `R/knit-print.R` | Block nur fenced (Pandoc #5094) |
| `tnd`/`tns` (Kapitel-Nummerierung) | offen | STYLEREF-Feld im Post-Render | – | nicht portiert (`CLAUDE.md`) | separat entscheiden |
| `dml`, pptx | n. g. | – | – | – | außerhalb Scope |
