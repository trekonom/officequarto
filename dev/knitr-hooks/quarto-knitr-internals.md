# Quarto: knitr-Integration (Phase 2)

Getestet mit Quarto 1.8.24. Zeilennummern wurden gegen die **installierte** Version geprüft
(`/Applications/quarto/share/rmd/{execute,hooks}.R`, Pfade unten relativ zu `rmd/`); die erste Fassung
zitierte quarto-cli `main` (Commit `04e3341`), dort wichen einzelne Zeilen um 1–8 ab. Die Lua-Filter
(`filters/…`) sind Pfade im quarto-cli-Repo – die installierte Version bündelt sie in `main.lua`; ihr
Verhalten ist daher experimentell belegt (Exp. 11, 14), nicht per Quelltext. Details: `claims-audit.md`.

## Versionen (lokal)
R 4.5.2 · rmarkdown 2.30 · knitr 1.51 · officedown 0.4.1 · officer 0.7.3 · flextable 0.9.11 · ggplot2 4.0.3
(Für Phase 1 gelesene Upstream-Quellen waren neuer: officedown 0.4.2.006, officer 0.7.7.004; Aussagen, auf die sich Experimente stützen, wurden gegen die installierten Versionen nachgeprüft, siehe `claims-audit.md`.)

## Korrektur an der Ausgangsannahme

Quarto **ignoriert `rmarkdown::output_format` nicht** – es *baut sich selbst eines* und ruft
`rmarkdown::render()` (`rmd/execute.R:197`). `knitr_options()` (`rmd/execute.R:290–373`) erzeugt per
`rmarkdown::knitr_options(opts_knit, opts_chunk, opts_hooks, knit_hooks)` das knitr-Bündel.
Was fehlt, ist **nur** die Möglichkeit, ein *fremdes* Format (`officedown::rdocx_document`) zu wählen –
also dessen `opts_chunk`-Defaults, `knit_hooks$plot`, `post_knit` und `post_processor`.

## Antworten

### Welche Hooks setzt Quarto, und wann?
- `opts_hooks` (`rmd/hooks.R:41–160`): `code`, `eval` (nur bei `execute: enabled: false`), `echo`, `output`,
  `fig.show`, `renderings`, `collapse`, sowie dynamisch registrierte (`hooks.R:159`).
- `knit_hooks` (`rmd/hooks.R:205`, `489`, `590–594`): `chunk`, `source`, `output`, `warning`, `message`,
  `plot` (= `knitr_plot_hook(format)`, definiert `hooks.R:602`), `error`; `crop` nur für PDF (`execute.R:350`).
- Alle Hooks sind `delegating_hook`s (`hooks.R:179`): erst knitr's `hooks_markdown()`-Default, dann
  Quarto-Nachbearbeitung (Zellen-`div`s `cell`, `cell-output-display`, …).
- Zeitpunkt: `rmarkdown::render()` (rmarkdown 2.30) übernimmt `output_format$knitr$knit_hooks/opts_hooks/
  opts_chunk/opts_knit` per `knitr::knit_hooks$set()` usw. **vor** dem Aufruf von `knitr::knit()`
  (Quelle: `deparse(rmarkdown::render)`, keine Quelldatei-Zeilen zitierbar). Setup-Chunks laufen erst
  *innerhalb* von `knit()`. **Bestätigt (Exp. 13):** zum Zeitpunkt des Setup-Chunks sind Quarto's
  `opts_hooks` (`code, collapse, echo, fig.show, output, renderings`) und sein `plot`-/`chunk`-Hook
  bereits installiert.

### Wird ein user-definierter Hook angewendet, überschrieben oder verkettet?
- Hook im Setup-Chunk (`knitr::knit_hooks$set(plot = …)`): wird nach Quarto gesetzt und **ersetzt**
  Quarto's Hook vollständig (knitr kennt kein Chaining) → bei `plot`/`chunk`/`output`/`source`
  gehen Quarto's Zellen-Divs/Crossref-Verarbeitung verloren. **Bestätigt (Exp. 3)** für einen Hook, der den alten *nicht* aufruft; ein Hook, der den vorherigen Hook aufruft (Chaining, `prototype/oq-hooks.R`), behält Caption, „Figure 1" und Crossref-Link.
- Neue, eigene Hook-Namen (`knit_hooks$set(myhook = …)`) kollidieren nicht (bestätigt, Exp. 1).
- `knitr:`-YAML-Key (`execute.R:370–371`): `knitr.opts_knit` und `knitr.opts_chunk` werden mit
  `rmarkdown:::merge_lists` über Quarto's Defaults gelegt (bestätigt, Exp. 13: beliebige Schlüssel
  kommen in `opts_chunk`/`opts_knit` an). **`knit_hooks`/`opts_hooks` im YAML werden nicht still ignoriert,
  sondern von der Schema-Validierung abgelehnt** (`property name knit_hooks is invalid` → „Render failed
  due to invalid YAML", Exp. 13 `yaml-hooks.qmd`; die erste Fassung dieses Berichts sagte „nicht gelesen").
  Hooks lassen sich also nur per R-Code setzen. (So liefert `knitr: opts_chunk: {tab.cap.style: …}` die
  officedown-Defaults aus `rdocx_document()` nach, die `officer::opts_current_table()` liest – bestätigt, Exp. 5.)
- `opts_hooks` des Nutzers: `opts_hooks$set(foo = …)` im Setup-Chunk ergänzt sich mit Quarto's (anderer Name; bestätigt, Exp. 2 und 9).
  Bei Quarto-eigenen Namen (`echo`, `eval`, `fig.show`, `collapse`, `code`, `output`) würde ersetzt (aus der Knitr-Semantik gefolgert, nicht experimentell getestet).

### `opts_knit$get("rmarkdown.pandoc.to")` / `knitr::pandoc_to()`
`execute.R:295–303`: `rmarkdown.pandoc.to = format$pandoc$to` (bei `pdf` → `latex`), `rmarkdown.pandoc.from`,
`rmarkdown.version = 3`, `rmarkdown.runtime = "static"`, `quarto.version = 1`. **Gemessen (Exp. 13, docx):**
`pandoc.to = docx`, `knitr::pandoc_to() = docx`, `pandoc.from` leer, `runtime = static`, `quarto.version = 1`
→ alle officedown/officer-`knit_print`-Methoden (`grepl("docx", …)`) greifen (Exp. 4/5).
`rmarkdown.pandoc.args` ist **gesetzt**, enthält aber nur `--to docx` (gemessen, Exp. 13; `execute.R`
`args = c("--to", format$pandoc$to)`) – **kein `--reference-doc`**, auch nicht bei
`format.docx.reference-doc`. Die erste Fassung behauptete „nicht gesetzt". Folge: officer's
Referenzdokument-Auflösung (`officer/R/knitr_utils.R`, Abschnitt `--reference-doc`) fällt auf das
Pandoc-Default-Dokument zurück. Für die wirkungslosen Tabellenstile ist das aber **nicht** die Ursache
(Exp. 12: auch mit gesetztem `--reference-doc` bleiben die `tstlname`-Marker stehen).

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
| `<!---BLOCK_TOC--->` etc. | kein Marker-Mechanismus; Ersatz: `toc: true`, `{{< pagebreak >}}` (`quarto-pre/shortcodes-handlers.lua:364`), `::: {.landscape}` (`quarto-post/landscape.lua`, fester A4-Querformat-`sectPr`) – alle drei in Exp. 14 bestätigt; `officequarto` liefert die Marker seit 0.3.0 als `markers.lua` |
| Word-`SEQ`/`REF`-Felder | in Quarto statisch (siehe `CLAUDE.md` „Live numbering“); hier über `oq_…auto-number` nachgerüstet |

## Status der ursprünglich offenen Punkte
Alle geklärt: Plot-Hook überschreiben (Exp. 3), `reference-doc` bei `knit_print.data.frame` (Exp. 10/12),
`opts_chunk` aus dem `knitr:`-YAML in `officer::opts_current_table()` (Exp. 5; Präfix „Tabelle " kommt an).
