# Audit der Aussagen in `dev/knitr-hooks/`

Stand: 2026-10-05. Geprüft gegen die Versionen, auf denen die Experimente liefen:
Quarto 1.8.24 (`/Applications/quarto/share/rmd/*.R`), R 4.5.2, knitr 1.51, rmarkdown 2.30,
officedown 0.4.1, officer 0.7.3, flextable 0.9.11. Die zuerst gelesenen Upstream-Quellen (quarto-cli `main`,
officedown 0.4.2.006, officer 0.7.7.004) wurden nicht erneut geklont; `vendor/` ist gelöscht.
Alle `experiments/*/run.R` und `prototype/run.R` wurden erneut ausgeführt: Ergebnisse wie dokumentiert.

Beleg-Arten: **E** = Experiment mit XML-Prüfung · **Q** = installierter Quelltext/Namespace gelesen ·
**U** = nur Upstream-HEAD gelesen, nicht gegen die installierte Version geprüft.
Status: ✔ bestätigt · ✎ korrigiert · ◐ bestätigt mit Einschränkung.

| # | Aussage | Beleg | Status |
|---|---|---|---|
| 1 | Quarto baut ein eigenes rmarkdown-Format und ruft `rmarkdown::render()` | Q `execute.R:197`, `290–373` | ✔ |
| 2 | Quarto's Hooks (`chunk, source, output, warning, message, plot, error`) und `opts_hooks` (`code, eval*, echo, output, fig.show, renderings, collapse`) | Q `hooks.R:41–145, 205, 489, 590–594, 602` (Zeilen korrigiert, vorher 1–8 daneben) | ✎ Zeilen |
| 3 | Zum Zeitpunkt des Setup-Chunks sind Quarto's Hooks bereits installiert | E Exp. 13 (`opts_hooks` = `code,collapse,echo,fig.show,output,renderings`; plot-/chunk-Hook sind Quarto's) | ✔ (vorher nur gefolgert) |
| 4 | `rmarkdown::render` setzt Hooks vor `knit()` (mit „Zeilen 258–262/327“) | Nur Funktionsbeschreibung belegbar; die Zeilen waren Indizes in `deparse(render)` | ✎ Zeilenangaben entfernt |
| 5 | Ersetzen von `plot`/`chunk` zerstört Crossrefs | E Exp. 3 – **nur** für Hooks, die den alten nicht aufrufen | ◐ präzisiert |
| 6 | Chaining erhält Crossrefs | E prototype (nur Text angehängt) und Exp. 15 v1 (Caption-Text geändert): ja. Exp. 15 v2–v4: sobald der Hook Quarto's Numerierung ersetzt oder ergänzt, geht `@fig-x` verloren bzw. wird doppelt gezählt | ◐ gilt nur, wenn die Caption nur als Text verändert wird |
| 7 | Eigene Hook-Namen / `opts_hooks` kollidieren nicht | E Exp. 1, 2, 9 | ✔ |
| 8 | `knitr:`-YAML: `opts_knit`/`opts_chunk` werden gemergt | E Exp. 5, 13 | ✔ |
| 9 | `knitr:`-YAML: `knit_hooks`/`opts_hooks` „werden nicht gelesen“ | E Exp. 13: **Schema-Validierung bricht den Render ab** (`property name knit_hooks is invalid`) | ✎ falsch formuliert |
| 10 | `rmarkdown.pandoc.to` = `docx` | E Exp. 13 (`docx`, `pandoc_to()` = `docx`, `pandoc.from` leer, `runtime` = `static`, `quarto.version` = 1) | ✔ (vorher nie gemessen) |
| 11 | `rmarkdown.pandoc.args` ist nicht gesetzt | E Exp. 12/13: Wert ist `--to docx` | ✎ falsch; nur `--reference-doc` fehlt |
| 12 | Fehlendes `--reference-doc` erklärt wirkungsloses `tab.style` | E Exp. 12 widerlegt (Marker bleiben auch mit gesetztem Argument) | ✎ Ursache: officer schreibt kein docx (`print.rdocx`) |
| 13 | `{=openxml}` aus R-Chunks (asis_output, `cat`, Inline) kommt an | E Exp. 6 | ✔ |
| 14 | `{{< pagebreak >}}`, `toc: true`, `::: {.landscape}` als native Alternativen | E Exp. 14 (vorher nur aus Quarto-Quelle gefolgert) | ✔ (Landscape fix A4) |
| 15 | officedown setzt genau einen Hook (`plot`), nirgends `opts_hooks` | Q Namespace von 0.4.1 | ✔ |
| 16 | Tabellen-`knit_print` per `register_s3_method` in `.onAttach`; `LIST_BLOCK_MACRO`; `post_knit`/`post_processor` | Q 0.4.1 | ✔ |
| 17 | officer ersetzt `pstlname`/`tstlname` erst beim Schreiben (`print.rdocx` → `convert_custom_styles_in_wml`) | Q 0.7.3 + E Exp. 12 | ✔ |
| 18 | flextable setzt in Quarto die Caption auf `""` (`knit_to_wml`, `quarto`-Zweig) | Q 0.9.11 + E Exp. 5 | ✔ |
| 19 | Exp. 4: Methoden stammen ggf. aus officequarto | im Test war nur officedown geladen | ✎ Formulierung |
| 20 | Zeilenangaben in `officedown-mechanisms.md` (Z. 219–250 …) | U (0.4.2.006) | ✎ durch Funktionsbezüge ersetzt |
| 21 | Lua-Filter-Pfade (`filters/quarto-post/…`) | U: installierte Version bündelt Filter in `main.lua`; Verhalten per E belegt | ◐ Pfade sind Repo-Pfade |
| 22 | `BLOCK_*`-Marker werden still verworfen | E Exp. 7 | ✔ |
| 23 | `opts_hooks`-gesetzte `fig.cap` löst Quarto-Nummerierung aus | E Exp. 9 | ✔ |
| 24 | Landscape-Größen-Override am STOP-Marker | E Exp. 11, `dev/fixtures/block-markers` | ✔ |
| 25 | Quarto's Plot-Hook emittiert `![cap](pfad){#fig-x …}`, Numerierung folgt erst im Lua-Filter | Q installiertes `hooks.R:602 ff.` + E Exp. 15 (v3-Regex greift) | ✔ |
| 26 | Ein knit_hook kann Live-`SEQ`-Figure-Captions erzeugen, ohne `@fig-x` zu verlieren | E Exp. 15 v2–v4 | ✎ **nein**; nur mit handgesetzten `REF`-Feldern (v3) |
| 27 | Ein Lua-Filter kann `@fig-a` für Hook-Items in `REF`-Felder umsetzen, bevor Quarto's Crossref-Filter läuft | E Exp. 17 (Standard-`filters:` und `at: pre-quarto`; über die Extension geliefert; in Word „Figure 1“) | ✔ |
| 28 | Hook-Items und native Items lassen sich mischen | E Exp. 17: nur mit `auto-number` (gemeinsame `SEQ`-Folge); ohne doppelte Nummern | ◐ Einschränkung |

Offen (kein Beleg, bewusst nicht behauptet): Verhalten bei Quarto-Versionen ≠ 1.8.24; Unterabbildungen/Layouts/`fig-subcap` bei Hook-Varianten.
