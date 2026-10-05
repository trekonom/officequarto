# officedown: Mechanismen (Phase 1)

Quellen: `vendor/officedown` (DESCRIPTION 0.4.2.006, Commit `b292a9d`), `vendor/officer` (0.7.7.004).
Lokal installiert (für Experimente): officedown 0.4.1, officer 0.7.3. Die gelesenen Quelltexte waren neuer;
Zeilennummern daraus sind nicht mehr zitiert. Die tragenden Aussagen wurden gegen die **installierten**
Versionen nachgeprüft (`claims-audit.md`): kein `opts_hooks` in officedown, genau ein gesetzter Hook
(`plot`), `register_s3_method` für `data.frame`/`dml` in `.onAttach`, `LIST_BLOCK_MACRO`, `post_knit`/`post_processor`
in `rdocx_document()` – alles auch in 0.4.1 vorhanden. Ergänzt `dev/officedown-analyse.md` (Optionen-Parität).

Mechanismen: **1** knitr-Hook/Chunk-Option · **2** `knit_print`-Methode · **3** Kommentar-Marker
(Markdown-Vorverarbeitung) · **4** `rmarkdown::output_format` (post_knit / post_processor / opts_chunk).

## Befund vorab

- **`opts_hooks` kommt in officedown nirgends vor** (`grep opts_hooks R/` → leer). Es gibt genau
  *einen* gesetzten knitr-Hook: `knit_hooks$plot` (`rdocx_document()`, Zeile `knit_hooks$plot <- plot_word_fig_caption`).
- Alle Chunk-Optionen (`tab.*`, `fig.*`, `first_row`, …) werden von `rdocx_document()` per
  `output_formats$knitr$opts_chunk` als **Defaults** gesetzt (`rdocx_document()`, Block `output_formats$knitr$opts_chunk`) und zur Laufzeit via
  `knitr::opts_current$get()` gelesen (`officer::opts_current_table()`, `officer/R/knitr_utils.R`, `opts_current_table()`).
  Das ist reine knitr-Funktionalität – aber die *Defaults* hängen am rmarkdown-Output-Format.
- Alle `knit_print`-Methoden entscheiden über `opts_knit$get("rmarkdown.pandoc.to")`.

## Tabelle

| Feature | Mechanismus | Datei :: Funktion | hängt an rmarkdown-Pipeline? |
|---|---|---|---|
| Plot-Caption mit Word-SEQ-Feld, `fig.cap`/`fig.id`/`fig.topcaption`/`fig.align`/`fig.style` | 1 (Plot-Hook, ersetzt knitr-Standard-Hook) | `officedown/R/hooks.R :: plot_word_fig_caption`; Registrierung `R/rdocx_document.R` (`knitr$knit_hooks$plot`) | **Ja** (Hook wird nur über `output_format$knitr` installiert) |
| Tabellen als Word-Tabelle inkl. Caption, Stil, Breite, conditional formatting | 2 (`knit_print.data.frame`) + Chunk-Optionen `tab.*` | `officedown/R/knit_print_table.R :: knit_print.data.frame`; Optionen: `officer/R/knitr_utils.R :: opts_current_table` | Registrierung per `register_s3_method` in `R/onAttach.R` (kein rmarkdown); Defaults aus `rdocx_document()` (Mechanismus 4) |
| `run_*` / `fp_par` inline (`ftext()`, `run_pagebreak()`, `run_autonum()`, …) | 2 (`knit_print.run`, `.fp_par`) → `` `<w:r>…`{=openxml} `` | `R/rdocx_knit_print.R :: knit_print.run/.fp_par` | Nein (nur `rmarkdown.pandoc.to`) |
| `block_*` (`block_toc()`, `block_section()`, `block_pour_docx()`, `fpar()`, …) | 2 (`knit_print.block`) → ```` ```{=openxml} ```` Fenced Block | `R/rdocx_knit_print.R :: knit_print.block` | Nein |
| Manuelle Varianten bei `results='asis'` | 2′ (`cat()`) | `R/rdocx_knit_print.R :: knit_print_block/knit_print_run` | Nein |
| Kommentar-Marker `<!---BLOCK_TOC--->`, `BLOCK_LANDSCAPE_START/STOP`, `BLOCK_MULTICOL_START/STOP`, `BLOCK_POUR_DOCX` (YAML-Argumente in `{…}`) | 3, ausgeführt in `post_knit` | `R/rdocx_pre_proc.R :: block_macro/LIST_BLOCK_MACRO/comment_tag_to_ooxml` | **Ja**: läuft in `output_formats$post_knit`, das die `*.knit.md` auf Platte umschreibt (`rdocx_document()`, `output_formats$post_knit`) |
| Querverweise `\@ref(tab:x)`, `\@ref(fig:x)`, `\@ref(x)` → `REF`-Feld in `w:hyperlink` | 3/4 (Regex auf Markdown, `post_knit`) | `R/rdocx_post_knit.R :: post_knit_caption_references/post_knit_std_references/as_reference_*` | **Ja** (`post_knit`) |
| Listenformate `ul.style`/`ol.style`, Absatz-Merge (`process_par_settings`), `mapstyles`, Default-Section (Seitengröße/-ränder) | 4 (Post-Processor nach Pandoc, mit `officer::read_docx`) | `R/rdocx_post_proc.R :: process_list_settings/process_par_settings`; `R/rdocx_document.R :: post_processor` | **Ja** |
| Referenz-Docx-Auflösung für Tabellenstile | Pandoc-Arg `--reference-doc` aus `opts_knit$get("rmarkdown.pandoc.args")` | `officer/R/knitr_utils.R` (Abschnitt `--reference-doc`) | **Ja** (Quarto setzt diese Option evtl. nicht → Phase 2/3) |
| DML-Grafiken (`dml`, editierbare Charts) | 2 (`knit_print.dml`) | `R/knit_print_dml.R` | Nein (nur `pandoc.to`) |
| `base_format`-Delegation (`word_document`), `bookdown_output_format='docx'` | 4 | `R/rdocx_document.R` | **Ja** |
| Caption-Rendering `to_wml(block_caption, knitting=TRUE)` (Pandoc-Markdown-Variante mit Lesezeichen) | officer-intern | `officer/R/ooxml_block_objects.R :: to_wml.block_caption` → `to_wml_block_caption_pandoc` | Nein |

## Was daraus für Quarto folgt (Hypothesen für Phase 2/3, noch nicht verifiziert)

1. Mechanismus 2 (`knit_print`) braucht nur `opts_knit$get("rmarkdown.pandoc.to")` → in Quarto zu prüfen.
   Bekannt aus diesem Repo: `R/knit-print.R` portiert `run`/`fp_par`/`block` bereits und funktioniert.
2. `knit_print.data.frame` und `officer::opts_current_table()` laufen ohne rmarkdown, aber
   `get_reference_rdocx()` (Tabellenstil-Auflösung) und die `tab.*`-Defaults hängen am Output-Format.
3. Mechanismus 3 und 4 (`post_knit`, `post_processor`, `opts_chunk`-Bündel) existieren in Quarto nicht
   in dieser Form; Ersatz: Pre-/Post-Render-Skripte, Lua-Filter, eigener `knitr:`-YAML-Block.
4. Der Plot-Hook überschreibt knitr's `plot`-Hook; Quarto setzt eigene Hooks → Konflikt in Phase 3, Exp. 3.
