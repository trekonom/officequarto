# Quarto: knitr-Integration (Phase 2)

Quelle: `vendor/quarto-cli` (Commit `04e3341`, 2026-10-02); installiert: Quarto 1.8.24.
Pfade relativ zu `src/resources/`. Aussagen mit **[verifizieren]** werden in Phase 3 experimentell bestätigt.

## Versionen (lokal)
R 4.5.2 · rmarkdown 2.30 · knitr 1.51 · officedown 0.4.1 · officer 0.7.3 · flextable 0.9.11 · ggplot2 4.0.3
(vendorte Quellen: officedown 0.4.2.006, officer 0.7.7.004 – neuer als installiert).

## Korrektur an der Ausgangsannahme

Quarto **ignoriert `rmarkdown::output_format` nicht** – es *baut sich selbst eines* und ruft
`rmarkdown::render()` (`rmd/execute.R:197`). `knitr_options()` (`rmd/execute.R:290–374`) erzeugt per
`rmarkdown::knitr_options(opts_knit, opts_chunk, opts_hooks, knit_hooks)` das knitr-Bündel.
Was fehlt, ist **nur** die Möglichkeit, ein *fremdes* Format (`officedown::rdocx_document`) zu wählen –
also dessen `opts_chunk`-Defaults, `knit_hooks$plot`, `post_knit` und `post_processor`.

## Antworten

### Welche Hooks setzt Quarto, und wann?
- `opts_hooks` (`rmd/hooks.R:41–160`): `code`, `eval` (nur bei `execute: enabled: false`), `echo`, `output`,
  `fig.show`, `renderings`, `collapse`, sowie dynamisch registrierte (`hooks.R:159`).
- `knit_hooks` (`rmd/hooks.R:205`, `490`, `591–595`): `chunk`, `source`, `output`, `warning`, `message`,
  `plot` (= `knitr_plot_hook(format)`, `hooks.R:603`), `error`; `crop` nur für PDF (`execute.R:350`).
- Alle Hooks sind `delegating_hook`s (`hooks.R:179`): erst knitr's `hooks_markdown()`-Default, dann
  Quarto-Nachbearbeitung (Zellen-`div`s `cell`, `cell-output-display`, …).
- Zeitpunkt: `rmarkdown::render` setzt `output_format$knitr$knit_hooks/opts_hooks/opts_chunk` per
  `knitr::knit_hooks$set()` etc. (rmarkdown 2.30, `render()` Zeilen 258–262) **vor** `knitr::knit()`
  (Z. 327). Setup-Chunks laufen erst *innerhalb* von `knit()`.

### Wird ein user-definierter Hook angewendet, überschrieben oder verkettet?
- Hook im Setup-Chunk (`knitr::knit_hooks$set(plot = …)`): wird nach Quarto gesetzt und **ersetzt**
  Quarto's Hook vollständig (knitr kennt kein Chaining) → bei `plot`/`chunk`/`output`/`source`
  gehen Quarto's Zellen-Divs/Crossref-Verarbeitung verloren **[verifizieren, Exp. 3]**.
- Neue, eigene Hook-Namen (`knit_hooks$set(myhook = …)`) kollidieren nicht **[Exp. 1]**.
- `knitr:`-YAML-Key (`execute.R:365–373`): `knitr.opts_knit` und `knitr.opts_chunk` werden mit
  `rmarkdown:::merge_lists` über Quarto's Defaults gelegt. **`knit_hooks`/`opts_hooks` aus YAML werden nicht
  gelesen** – nur `opts_knit`/`opts_chunk` (so liefert `knitr: opts_chunk: {tab.cap.style: …}` die
  officedown-Defaults aus `rdocx_document()` nach, die `officer::opts_current_table()` liest).
- `opts_hooks` des Nutzers: `opts_hooks$set(foo = …)` im Setup-Chunk ergänzt sich mit Quarto's (anderer Name) **[Exp. 2]**.
  Bei Quarto-eigenen Namen (`echo`, `eval`, `fig.show`, `collapse`, `code`, `output`) wird ersetzt.

### `opts_knit$get("rmarkdown.pandoc.to")` / `knitr::pandoc_to()`
`execute.R:295–303`: `rmarkdown.pandoc.to = format$pandoc$to` (bei `pdf` → `latex`), `rmarkdown.pandoc.from`,
`rmarkdown.version = 3`, `rmarkdown.runtime = "static"`, `quarto.version = 1`. Für `format: docx` ist der
Wert `docx` → alle officedown/officer-`knit_print`-Methoden (`grepl("docx", …)`) greifen **[Exp. 4/5]**.
Nicht gesetzt: `rmarkdown.pandoc.args` → `officer::get_reference_docx`-Logik (`officer/R/knitr_utils.R:84`)
findet kein `--reference-doc` (für die Stilauflösung in Exp. 12 aber *nicht* ausschlaggebend; entscheidend ist das fehlende Schreiben durch officer) (Tabellenstil-Auflösung
gegen *falsches* Dokument möglich) **[Exp. 5]**.

### Werden ```` ```{=openxml} ````-Blöcke durchgereicht?
Ja, soweit sie als Markdown beim Pandoc ankommen: Quarto's eigene Lua-Filter erzeugen selbst
`RawBlock("openxml", …)` (`filters/quarto-post/docx.lua`, `filters/rmarkdown/pagebreak.lua:54`,
`filters/quarto-post/landscape.lua:8`). Aus R-Chunks nur mit `results: asis`/`knit_print`+`asis_output`
**[Exp. 6]**. Bekannte Falle (aus diesem Repo, `R/knit-print.R`): Inline-Raw mit komplettem `<w:p>` →
Pandoc-Bug #5094; Blöcke müssen als Fenced Block ausgegeben werden.

### Äquivalente zu `pre_processor` / `post_processor` / `post_knit`
| officedown | Quarto-Äquivalent |
|---|---|
| `post_knit` (Markdown-Umschreiben, Marker) | **keins** für `.knit.md`. Ersatz: Pandoc-Lua-Filter (Quarto-Extension `filters:`), oder `knit_print`/Hooks vorab. Eigenes `post_knit` ist nicht injizierbar (nur `execute.R:114` `post_knit` intern) |
| `post_processor` (officer auf fertiger .docx) | Projekt-`post-render:` (`resources/schema/project.yml:48`) – genau der Mechanismus von `writeback.R` hier |
| `pre_processor` | Projekt-`pre-render:` (`project.yml:44`) |
| `<!---BLOCK_TOC--->` etc. | kein Marker-Mechanismus; Ersatz: `toc: true`, `{{< pagebreak >}}` (`quarto-pre/shortcodes-handlers.lua:364`), `::: {.landscape}` (`quarto-post/landscape.lua`, fester A4-Querformat-`sectPr`) |
| Word-`SEQ`/`REF`-Felder | in Quarto statisch (siehe `CLAUDE.md` „Live numbering“); hier über `oq_…auto-number` nachgerüstet |

## Offene Punkte für Phase 3
Exp. 3 (Plot-Hook überschreiben), Exp. 5 (`reference-doc` bei `knit_print.data.frame`), und ob `opts_chunk`
aus dem `knitr:`-YAML in `officer::opts_current_table()` ankommt.
