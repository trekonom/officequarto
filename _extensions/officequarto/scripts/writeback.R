## Post-Render-Hook der officequarto-Extension.
##
## Hintergrund (siehe dev/spike-notes.md): Pandoc/Quarto uebernehmen Styles,
## Header, Footer und Section-Properties des `reference-doc` bereits vollstaendig
## in jedes gerenderte .docx - ein manueller Body-Ersatz auf XML-Ebene ist dafuer
## NICHT noetig und mit den verfuegbaren Werkzeugen (officer::body_add_docx) auf
## bereits von reference-doc abgeleiteten Dokumenten sogar fehleranfaellig
## (Sections-/Header-Merge-Bug bei zwei strukturgleichen Dokumenten).
##
## Was Pandoc dagegen NICHT aus dem Original uebernimmt: die docProps-Metadaten
## (docProps/core.xml, docProps/custom.xml) - Pandoc schreibt dafuer ein neues,
## weitgehend leeres core.xml. Genau das schreibt dieser Hook zurueck: er nimmt
## das frisch gerenderte .docx (Body/Header/Footer/Styles bereits korrekt) und
## uebertraegt Subject/Keywords/Category/Custom-Properties des Originals hinein.
##
## Saemtliche Konfiguration liegt gebuendelt unter dem einen Schluessel
## `format.docx.officequarto` (keine `officequarto-`-praefigierten
## Geschwister-Schluessel mehr) - siehe README/CLAUDE.md fuer die vollstaendige
## Struktur. Wichtigste Unterabschnitte:
##
## `officequarto.styles.body` und `officequarto.lists.*` (list-bullet/
## list-number/list-letter, eigener Abschnitt, getrennt von `styles`, da es
## sich konzeptionell um eine eigene Gruppe handelt): Body- und Listen-
## Absaetze werden auf vom Nutzer benannte, echte Styles des reference-doc
## umgemappt (siehe scripts/style_mapping.R fuer die Kernlogik). Fuer
## officedown-Umsteiger:innen akzeptieren die Listen-Optionen zusaetzlich die
## alten officedown-Namen (`ol_style`/`ul_style`) als Alias zu den neuen,
## sprechenderen Namen (`list-number`/`list-bullet`) - siehe
## scripts/option_aliases.R fuer die Aufloesungslogik inkl. Konfliktregel.
## `list-letter` (Buchstaben-Listen, a/b/c bzw. A/B/C) ist eine
## officequarto-eigene Ergaenzung ohne officedown-Vorbild, daher ohne Alias.
## Alle drei Listen-Optionen akzeptieren zusaetzlich ein Array statt eines
## Skalars - ein Style pro Verschachtelungsebene (Index 0 = oberste Ebene),
## tiefer verschachtelte Absaetze clampen auf den letzten Array-Eintrag - siehe
## scripts/style_mapping.R (oq_style_for_level()/oq_paragraph_ilvl()) und
## dev/spike-notes.md Spike O.
##
## Der Hook ueberschreibt die von Quarto/Pandoc erzeugte .docx direkt an Ort
## und Stelle - es entsteht keine zweite Ausgabedatei. Wer das reine,
## ungepatchte Pandoc-Ergebnis zu Debug-Zwecken behalten will, kann das per
## `officequarto.keep-rendered: true` aktivieren (analog zu Quartos eigenem
## `keep-md`); es wird dann zusaetzlich als `<name>.quarto-rendered.docx`
## abgelegt.
##
## Zusaetzlich, optional per `officequarto.tables` konfigurierbar: Tabellen-
## Style/-Layout/-Breite werden auf jede w:tbl im Dokument angewendet (siehe
## scripts/table_mapping.R fuer die Kernlogik; Gruppe 1 des officedown-
## Options-Ports, siehe README). Wie bei den Listen-Optionen akzeptieren
## style/layout/width zusaetzlich die officedown-Aliase tables_style/
## tables_layout/tables_width (siehe scripts/option_aliases.R).
##
## Zusaetzlich, immer aktiv: Pandocs docx-Writer fuegt beim Rendern eigene
## Style-Definitionen hinzu, die im reference-doc gar nicht existieren (z.B.
## Syntax-Highlighting-Styles fuer Codebloecke, unabhaengig davon, ob welche
## vorkommen). Diese werden standardmaessig wieder entfernt, das Ergebnis-docx
## enthaelt dann ausschliesslich Styles aus dem reference-doc (siehe
## scripts/style_pruning.R fuer die Kernlogik). Per
## `officequarto.pandoc-styles.code-block` (eigener Abschnitt, unabhaengig von
## `officequarto.styles`) lassen sich Pandocs Codeblock-Styles davon ausnehmen:
## `true` behaelt sie unveraendert (volles Syntax-Highlighting), ein
## Style-Name mappt nur die SourceCode-Absatzrolle auf einen eigenen
## reference-doc-Style (Syntax-Highlighting-Farben bleiben dabei entfernt).

log_msg <- function(fmt, ...) cat(sprintf(paste0("[officequarto] ", fmt, "\n"), ...))
fail <- function(fmt, ...) stop(sprintf(paste0("officequarto: ", fmt), ...), call. = FALSE)

## Ermittelt das Verzeichnis dieses Skripts, unabhaengig vom Arbeitsverzeichnis,
## in dem Quarto den Post-Render-Hook ausfuehrt.
get_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 1) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }
  "."
}
source(file.path(get_script_dir(), "style_mapping.R"))
source(file.path(get_script_dir(), "style_pruning.R"))
source(file.path(get_script_dir(), "option_aliases.R"))
source(file.path(get_script_dir(), "table_mapping.R"))
source(file.path(get_script_dir(), "table_caption_mapping.R"))
source(file.path(get_script_dir(), "plot_mapping.R"))
source(file.path(get_script_dir(), "plot_caption_mapping.R"))
source(file.path(get_script_dir(), "style_map.R"))
source(file.path(get_script_dir(), "page_mapping.R"))
source(file.path(get_script_dir(), "crossref_mapping.R"))

warn_msg <- function(fmt, ...) log_msg(paste0("Warnung: ", fmt), ...)

output_files <- Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES", unset = "")
output_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", unset = ".")
project_dir <- Sys.getenv("QUARTO_PROJECT_DIR", unset = ".")

if (!nzchar(output_files)) {
  log_msg("keine QUARTO_PROJECT_OUTPUT_FILES gesetzt, nichts zu tun.")
  quit(save = "no", status = 0)
}

docx_outputs <- Filter(
  function(f) grepl("\\.docx$", f, ignore.case = TRUE),
  strsplit(output_files, "\n")[[1]]
)

if (length(docx_outputs) == 0) {
  log_msg("keine .docx-Outputs in diesem Render, nichts zu tun.")
  quit(save = "no", status = 0)
}

for (pkg in c("xml2", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    fail("R-Paket '%s' wird benoetigt, ist aber nicht installiert.", pkg)
  }
}
if (!nzchar(Sys.which("quarto"))) fail("'quarto' CLI nicht im PATH gefunden.")
if (!nzchar(Sys.which("zip")) || !nzchar(Sys.which("unzip"))) {
  fail("'zip'/'unzip' werden fuer das Zurueckschreiben benoetigt, sind aber nicht im PATH.")
}

inspect_raw <- suppressWarnings(
  system2("quarto", c("inspect", shQuote(project_dir)), stdout = TRUE, stderr = FALSE)
)
inspect <- tryCatch(
  jsonlite::fromJSON(paste(inspect_raw, collapse = "\n"), simplifyVector = TRUE),
  error = function(e) NULL
)
reference_doc <- tryCatch(inspect$config$format$docx$`reference-doc`, error = function(e) NULL)

if (is.null(reference_doc) || !nzchar(reference_doc)) {
  log_msg("kein format.docx.reference-doc in der Projektkonfiguration - ueberspringe.")
  quit(save = "no", status = 0)
}

reference_doc_path <- file.path(project_dir, reference_doc)
if (!file.exists(reference_doc_path)) {
  fail("reference-doc '%s' wurde nicht gefunden.", reference_doc_path)
}

## Saemtliche Konfiguration liegt unter dem einen Schluessel
## format.docx.officequarto (siehe Kommentarblock oben) - hier einmal
## eingelesen, danach je Unterabschnitt weitergereicht.
officequarto_config <- tryCatch(inspect$config$format$docx$officequarto, error = function(e) NULL)

style_config <- officequarto_config$styles
lists_config <- officequarto_config$lists
pandoc_style_config <- officequarto_config$`pandoc-styles`
keep_rendered <- officequarto_config$`keep-rendered`
if (is.null(keep_rendered)) keep_rendered <- FALSE

code_block_config <- tryCatch(pandoc_style_config$`code-block`, error = function(e) NULL)
code_block_valid <- is.null(code_block_config) || identical(code_block_config, FALSE) ||
  isTRUE(code_block_config) || (is.character(code_block_config) && length(code_block_config) == 1 && nzchar(code_block_config))
if (!code_block_valid) {
  fail("officequarto.pandoc-styles.code-block muss entweder true oder ein Style-Name (String) sein.")
}

## table_style_val/table_layout_val/table_width_val loesen jeweils canonical
## Name vs. officedown-Alias auf (tables_style/tables_layout/tables_width) -
## einmalig hier, nicht pro Ausgabedatei, da die Konfiguration render-weit
## gleich ist.
table_config <- officequarto_config$tables
table_style_val <- if (!is.null(table_config)) {
  oq_resolve_aliased(table_config, "style", "tables_style", "officequarto.tables", warn_msg)
} else NULL
table_layout_val <- if (!is.null(table_config)) {
  oq_resolve_aliased(table_config, "layout", "tables_layout", "officequarto.tables", warn_msg)
} else NULL
table_width_val <- if (!is.null(table_config)) {
  oq_resolve_aliased(table_config, "width", "tables_width", "officequarto.tables", warn_msg)
} else NULL

if (!is.null(table_layout_val) && !(table_layout_val %in% c("autofit", "fixed"))) {
  fail("officequarto.tables.layout muss 'autofit' oder 'fixed' sein (erhalten: '%s').", table_layout_val)
}
if (!is.null(table_width_val) && (!is.numeric(table_width_val) || length(table_width_val) != 1 || table_width_val <= 0)) {
  fail("officequarto.tables.width muss eine einzelne positive Zahl sein (erhalten: '%s').", table_width_val)
}

## Gruppe 2 (officequarto.tables.conditional.*) - jedes Feld unabhaengig
## optional, canonical Name vs. officedown-Alias (band-rows/band-columns mit
## umgekehrter Polaritaet zu no_hband/no_vband), siehe table_mapping.R.
table_conditional_config <- table_config$conditional
table_conditional_options <- list(
  `first-row`    = oq_resolve_table_bool_option(table_conditional_config, "first-row", "tables_conditional_first_row", FALSE, "officequarto.tables.conditional.first-row", warn_msg, fail),
  `first-column` = oq_resolve_table_bool_option(table_conditional_config, "first-column", "tables_conditional_first_column", FALSE, "officequarto.tables.conditional.first-column", warn_msg, fail),
  `last-row`     = oq_resolve_table_bool_option(table_conditional_config, "last-row", "tables_conditional_last_row", FALSE, "officequarto.tables.conditional.last-row", warn_msg, fail),
  `last-column`  = oq_resolve_table_bool_option(table_conditional_config, "last-column", "tables_conditional_last_column", FALSE, "officequarto.tables.conditional.last-column", warn_msg, fail),
  `band-rows`    = oq_resolve_table_bool_option(table_conditional_config, "band-rows", "tables_conditional_no_hband", TRUE, "officequarto.tables.conditional.band-rows", warn_msg, fail),
  `band-columns` = oq_resolve_table_bool_option(table_conditional_config, "band-columns", "tables_conditional_no_vband", TRUE, "officequarto.tables.conditional.band-columns", warn_msg, fail)
)

## Gruppe 3 (officequarto.tables.caption.*) - style wird wie body/list-*/
## code-block gegen die Absatz-Styles von reference-doc aufgeloest (spaeter,
## sobald name_to_id verfuegbar ist, siehe unten); prefix/separator/
## number-bold sind reine Werte/Booleans, hier vollstaendig aufloesbar.
table_caption_config <- table_config$caption
table_caption_style_val <- if (!is.null(table_caption_config)) {
  oq_resolve_aliased(table_caption_config, "style", "tables_caption_style", "officequarto.tables.caption", warn_msg)
} else NULL
table_caption_prefix_val <- if (!is.null(table_caption_config)) {
  oq_resolve_aliased(table_caption_config, "prefix", "tables_caption_pre", "officequarto.tables.caption", warn_msg)
} else NULL
table_caption_separator_val <- if (!is.null(table_caption_config)) {
  oq_resolve_aliased(table_caption_config, "separator", "tables_caption_sep", "officequarto.tables.caption", warn_msg)
} else NULL
table_caption_bold_val <- if (!is.null(table_caption_config)) {
  oq_resolve_aliased(table_caption_config, "number-bold", "tables_caption_bold", "officequarto.tables.caption", warn_msg)
} else NULL
if (!is.null(table_caption_bold_val) && (!is.logical(table_caption_bold_val) || length(table_caption_bold_val) != 1 || is.na(table_caption_bold_val))) {
  fail("officequarto.tables.caption.number-bold muss true oder false sein (erhalten: '%s').", table_caption_bold_val)
}
## caption-above (officedown: topcaption) - nachtraeglich unter caption.above
## eingeordnet statt als eigener Top-Level-Schluessel (urspruenglicher
## Vorschlag vor Gruppe 3), da jetzt ein caption-Abschnitt existiert und alle
## Beschriftungs-Optionen dort zusammengehoeren.
table_caption_above_val <- if (!is.null(table_caption_config)) {
  oq_resolve_aliased(table_caption_config, "above", "tables_topcaption", "officequarto.tables.caption", warn_msg)
} else NULL
if (!is.null(table_caption_above_val) && (!is.logical(table_caption_above_val) || length(table_caption_above_val) != 1 || is.na(table_caption_above_val))) {
  fail("officequarto.tables.caption.above muss true oder false sein (erhalten: '%s').", table_caption_above_val)
}

## Gruppe 4 (officequarto.plots.style/align) - fig.lp bewusst nicht portiert
## (siehe plot_mapping.R), topcaption zurueckgestellt (siehe oben).
plot_config <- officequarto_config$plots
plot_style_val <- if (!is.null(plot_config)) {
  oq_resolve_aliased(plot_config, "style", "plots_style", "officequarto.plots", warn_msg)
} else NULL
plot_align_val <- if (!is.null(plot_config)) {
  oq_resolve_aliased(plot_config, "align", "plots_align", "officequarto.plots", warn_msg)
} else NULL
if (!is.null(plot_align_val) && !(plot_align_val %in% c("left", "center", "right"))) {
  fail("officequarto.plots.align muss 'left', 'center' oder 'right' sein (erhalten: '%s').", plot_align_val)
}

## Gruppe 5 (officequarto.plots.caption.*) - identisches Muster zu Gruppe 3
## (officequarto.tables.caption.*), siehe dort fuer die Begruendung.
plot_caption_config <- plot_config$caption
plot_caption_style_val <- if (!is.null(plot_caption_config)) {
  oq_resolve_aliased(plot_caption_config, "style", "plots_caption_style", "officequarto.plots.caption", warn_msg)
} else NULL
plot_caption_prefix_val <- if (!is.null(plot_caption_config)) {
  oq_resolve_aliased(plot_caption_config, "prefix", "plots_caption_pre", "officequarto.plots.caption", warn_msg)
} else NULL
plot_caption_separator_val <- if (!is.null(plot_caption_config)) {
  oq_resolve_aliased(plot_caption_config, "separator", "plots_caption_sep", "officequarto.plots.caption", warn_msg)
} else NULL
plot_caption_bold_val <- if (!is.null(plot_caption_config)) {
  oq_resolve_aliased(plot_caption_config, "number-bold", "plots_caption_bold", "officequarto.plots.caption", warn_msg)
} else NULL
if (!is.null(plot_caption_bold_val) && (!is.logical(plot_caption_bold_val) || length(plot_caption_bold_val) != 1 || is.na(plot_caption_bold_val))) {
  fail("officequarto.plots.caption.number-bold muss true oder false sein (erhalten: '%s').", plot_caption_bold_val)
}
plot_caption_above_val <- if (!is.null(plot_caption_config)) {
  oq_resolve_aliased(plot_caption_config, "above", "plots_topcaption", "officequarto.plots.caption", warn_msg)
} else NULL
if (!is.null(plot_caption_above_val) && (!is.logical(plot_caption_above_val) || length(plot_caption_above_val) != 1 || is.na(plot_caption_above_val))) {
  fail("officequarto.plots.caption.above muss true oder false sein (erhalten: '%s').", plot_caption_above_val)
}

## Gruppe 7 (officequarto.style-map, officedown: mapstyles) - freies
## Style-Mapping, siehe style_map.R. Nur grobe Formvalidierung hier (benannte
## Liste); die eigentliche Aufloesung (Ziel-Style gegen reference-doc) passiert
## pro Ausgabedatei weiter unten, da sie name_to_id braucht.
style_map_config <- officequarto_config$`style-map`
if (!is.null(style_map_config) && (!is.list(style_map_config) || is.null(names(style_map_config)) || any(!nzchar(names(style_map_config))))) {
  fail("officequarto.style-map muss eine benannte Liste sein (Ziel-Style-Name -> Liste von Quell-pStyle-IDs).")
}

## Gruppe 8 (officequarto.page.size/.margins) - Werte in Zoll, siehe
## page_mapping.R fuer die Twips-Umrechnung und die Begruendung, warum diese
## Gruppe (anders als alle anderen) Section Properties statt Styles betrifft.
page_config <- officequarto_config$page

page_size_fields <- c(width = "page_size_width", height = "page_size_height", orientation = "page_size_orient")
page_size_vals <- oq_resolve_fields(page_config$size, page_size_fields, "officequarto.page.size", warn_msg)
for (f in c("width", "height")) {
  v <- page_size_vals[[f]]
  if (!is.null(v) && (!is.numeric(v) || length(v) != 1 || v <= 0)) {
    fail("officequarto.page.size.%s muss eine einzelne positive Zahl sein (erhalten: '%s').", f, v)
  }
}
if (!is.null(page_size_vals$orientation) && !(page_size_vals$orientation %in% c("portrait", "landscape"))) {
  fail("officequarto.page.size.orientation muss 'portrait' oder 'landscape' sein (erhalten: '%s').", page_size_vals$orientation)
}

page_margin_fields <- c(
  top = "page_margins_top", bottom = "page_margins_bottom",
  left = "page_margins_left", right = "page_margins_right",
  header = "page_margins_header", footer = "page_margins_footer",
  gutter = "page_margins_gutter"
)
page_margin_vals <- oq_resolve_fields(page_config$margins, page_margin_fields, "officequarto.page.margins", warn_msg)
for (f in names(page_margin_fields)) {
  v <- page_margin_vals[[f]]
  if (!is.null(v) && (!is.numeric(v) || length(v) != 1 || v < 0)) {
    fail("officequarto.page.margins.%s muss eine einzelne, nicht-negative Zahl sein (erhalten: '%s').", f, v)
  }
}

## Gruppe 9 (officequarto.crossref.numbered, officedown: reference_num) -
## siehe crossref_mapping.R. Pandocs eigener Default entspricht bereits
## "numbered" (Querverweise zeigen die Nummer) - nur explizites `false`
## loest ueberhaupt eine Verarbeitung aus (siehe unten, wo dies zusaetzlich
## dazu fuehrt, dass die Beschriftungs-Erkennung/-Textzerlegung aus Gruppe
## 3/5 "still" mitlaeuft, auch wenn officequarto.tables.caption/
## plots.caption selbst nicht konfiguriert sind).
crossref_config <- officequarto_config$crossref
crossref_numbered_val <- if (!is.null(crossref_config)) {
  oq_resolve_aliased(crossref_config, "numbered", "reference_num", "officequarto.crossref", warn_msg)
} else NULL
if (!is.null(crossref_numbered_val) && (!is.logical(crossref_numbered_val) || length(crossref_numbered_val) != 1 || is.na(crossref_numbered_val))) {
  fail("officequarto.crossref.numbered muss true oder false sein (erhalten: '%s').", crossref_numbered_val)
}
crossref_rewrite_needed <- isFALSE(crossref_numbered_val)

## Uebertraegt dc:subject, cp:keywords, cp:category aus core_from in core_to und
## gibt den (ggf. veraenderten) core_to xml2-Doc zurueck.
merge_core_properties <- function(core_to, core_from) {
  ns_from <- xml2::xml_ns(core_from)
  root_to <- xml2::xml_root(core_to)
  for (field in c("dc:subject", "cp:keywords", "dc:description", "cp:category")) {
    src_node <- xml2::xml_find_first(core_from, paste0("//", field), ns_from)
    if (is.na(src_node) || !nzchar(trimws(xml2::xml_text(src_node)))) next
    dst_node <- xml2::xml_find_first(root_to, paste0("//", field), xml2::xml_ns(root_to))
    if (is.na(dst_node)) {
      dst_node <- xml2::xml_add_child(root_to, field)
    }
    xml2::xml_text(dst_node) <- xml2::xml_text(src_node)
  }
  core_to
}

for (rel_path in docx_outputs) {
  rendered_path <- file.path(output_dir, rel_path)
  if (!file.exists(rendered_path)) {
    log_msg("gerendertes Dokument '%s' nicht gefunden, ueberspringe.", rendered_path)
    next
  }

  work_dir <- tempfile("officequarto_")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  system2("unzip", c("-oq", shQuote(rendered_path), "-d", shQuote(work_dir)))

  orig_dir <- file.path(work_dir, "__original__")
  dir.create(orig_dir)
  system2("unzip", c("-oq", shQuote(reference_doc_path), "docProps/core.xml", "docProps/custom.xml",
                      "word/styles.xml", "-d", shQuote(orig_dir)))

  core_to_path <- file.path(work_dir, "docProps", "core.xml")
  core_from_path <- file.path(orig_dir, "docProps", "core.xml")
  if (file.exists(core_to_path) && file.exists(core_from_path)) {
    core_to <- xml2::read_xml(core_to_path)
    core_from <- xml2::read_xml(core_from_path)
    core_to <- merge_core_properties(core_to, core_from)
    xml2::write_xml(core_to, core_to_path)
  }

  custom_from_path <- file.path(orig_dir, "docProps", "custom.xml")
  if (file.exists(custom_from_path)) {
    file.copy(custom_from_path, file.path(work_dir, "docProps", "custom.xml"), overwrite = TRUE)
  }

  if (!is.null(style_config) || !is.null(lists_config) || !is.null(code_block_config) || !is.null(table_config) || !is.null(plot_config) || !is.null(style_map_config) || !is.null(page_config) || crossref_rewrite_needed) {
    styles_path <- file.path(work_dir, "word", "styles.xml")
    document_path <- file.path(work_dir, "word", "document.xml")
    numbering_path <- file.path(work_dir, "word", "numbering.xml")

    styles_doc <- xml2::read_xml(styles_path)
    document_doc <- xml2::read_xml(document_path)
    ## name_to_id wird sowohl von der Absatz-Style-Zuordnung unten als auch
    ## von der Tabellen-Beschriftungs-Style-Zuordnung (Gruppe 3) gebraucht,
    ## deshalb hier zentral einmal berechnet statt in beiden Bloecken.
    name_to_id <- oq_style_name_to_id(styles_doc)

    if (!is.null(style_config) || !is.null(lists_config) || !is.null(code_block_config)) {
      style_num_id <- oq_style_num_id(styles_doc)

      style_ids <- list()
      if (!is.null(style_config$body)) {
        style_ids$body <- oq_resolve_style_id(name_to_id, style_config$body, "officequarto.styles.body", fail)
      }
      ## list-bullet/list-number/list-letter akzeptieren einen Skalar (ein
      ## Style fuer jede Verschachtelungsebene, unveraendertes Verhalten) oder
      ## ein Array (ein Style pro Ebene, Index 0 = oberste Ebene) - beide
      ## Formen kommen aus quarto inspects JSON als Character-Vektor an
      ## (Laenge 1 bzw. Laenge n), oq_resolve_aliased()s identical()-basierter
      ## Konfliktcheck funktioniert dafuer unveraendert. oq_resolve_style_ids()
      ## loest jeden Eintrag einzeln, fail-loud, unter Beibehaltung der
      ## Reihenfolge auf.
      list_bullet_val <- oq_resolve_aliased(lists_config, "list-bullet", "ul_style", "officequarto.lists", warn_msg)
      if (!is.null(list_bullet_val)) {
        style_ids$list_bullet <- oq_resolve_style_ids(name_to_id, list_bullet_val, "officequarto.lists.list-bullet", fail)
      }
      list_number_val <- oq_resolve_aliased(lists_config, "list-number", "ol_style", "officequarto.lists", warn_msg)
      if (!is.null(list_number_val)) {
        style_ids$list_number <- oq_resolve_style_ids(name_to_id, list_number_val, "officequarto.lists.list-number", fail)
      }
      if (!is.null(lists_config$`list-letter`)) {
        style_ids$list_letter <- oq_resolve_style_ids(name_to_id, lists_config$`list-letter`, "officequarto.lists.list-letter", fail)
      }
      if (is.character(code_block_config) && nzchar(code_block_config)) {
        style_ids$code <- oq_resolve_style_id(name_to_id, code_block_config, "officequarto.pandoc-styles.code-block", fail)
      }

      num_fmt_map <- if (file.exists(numbering_path)) {
        oq_num_fmt_map(xml2::read_xml(numbering_path))
      } else {
        character(0)
      }

      result <- oq_apply_style_mapping(document_doc, num_fmt_map, style_ids, style_num_id)
      log_msg("Style-Mapping angewendet: %d Body-Absaetze, %d Listen-Absaetze, %d Codeblock-Absaetze.",
               result$n_body, result$n_list, result$n_code)
      if (result$n_list_clamped > 0) {
        log_msg("Davon %d Listen-Absatz/-Absaetze durch Clamping auf den tiefsten konfigurierten Listen-Style abgebildet (Verschachtelung tiefer als konfiguriert).",
                 result$n_list_clamped)
      }
    }

    if (!is.null(table_config)) {
      table_options <- list(layout = table_layout_val, width = table_width_val, conditional = table_conditional_options)
      if (!is.null(table_style_val)) {
        table_style_name_to_id <- oq_style_name_to_id(styles_doc, type = "table")
        table_options$style <- oq_resolve_style_id(table_style_name_to_id, table_style_val, "officequarto.tables.style", fail)
      }
      n_tables <- oq_apply_table_options(document_doc, table_options)
      log_msg("Tabellen-Optionen angewendet: %d Tabelle(n).", n_tables)
    }

    ## Crossref_rewrite_needed (Gruppe 9) laesst diesen Block auch dann
    ## mitlaufen, wenn officequarto.tables.caption selbst nicht konfiguriert
    ## ist - caption_options bleibt dann leer (keine Style-/Text-Aenderung),
    ## aber oq_apply_captions() liefert trotzdem das fuer Gruppe 9 benoetigte
    ## anchor_text (siehe table_caption_mapping.R).
    crossref_anchor_text <- character(0)
    if (!is.null(table_caption_config) || crossref_rewrite_needed) {
      caption_options <- list(prefix = table_caption_prefix_val, separator = table_caption_separator_val, number_bold = table_caption_bold_val, above = table_caption_above_val)
      if (!is.null(table_caption_style_val)) {
        caption_options$style <- oq_resolve_style_id(name_to_id, table_caption_style_val, "officequarto.tables.caption.style", fail)
      }
      caption_result <- oq_apply_captions(document_doc, oq_find_table_caption_paragraphs(document_doc, xml2::xml_ns(document_doc)), caption_options, oq_table_caption_content)
      log_msg("Tabellen-Beschriftungen: %d gefunden, %d Text umformatiert, %d verschoben.",
               caption_result$n_found, caption_result$n_text_rewritten, caption_result$n_moved)
      crossref_anchor_text <- c(crossref_anchor_text, caption_result$anchor_text)
    }

    if (!is.null(plot_config)) {
      plot_options <- list(align = plot_align_val)
      if (!is.null(plot_style_val)) {
        plot_options$style <- oq_resolve_style_id(name_to_id, plot_style_val, "officequarto.plots.style", fail)
      }
      n_plots <- oq_apply_plot_options(document_doc, plot_options)
      log_msg("Abbildungs-Optionen angewendet: %d Abbildung(en).", n_plots)
    }

    if (!is.null(plot_caption_config) || crossref_rewrite_needed) {
      plot_caption_options <- list(prefix = plot_caption_prefix_val, separator = plot_caption_separator_val, number_bold = plot_caption_bold_val, above = plot_caption_above_val)
      if (!is.null(plot_caption_style_val)) {
        plot_caption_options$style <- oq_resolve_style_id(name_to_id, plot_caption_style_val, "officequarto.plots.caption.style", fail)
      }
      plot_caption_result <- oq_apply_captions(document_doc, oq_find_plot_caption_paragraphs(document_doc, xml2::xml_ns(document_doc)), plot_caption_options, oq_plot_caption_content)
      log_msg("Abbildungs-Beschriftungen: %d gefunden, %d Text umformatiert, %d verschoben.",
               plot_caption_result$n_found, plot_caption_result$n_text_rewritten, plot_caption_result$n_moved)
      crossref_anchor_text <- c(crossref_anchor_text, plot_caption_result$anchor_text)
    }

    if (crossref_rewrite_needed) {
      n_crossref <- oq_apply_crossref_text(document_doc, crossref_anchor_text)
      log_msg("Querverweise auf Beschriftungstext umgestellt (officequarto.crossref.numbered: false): %d.", n_crossref)
    }

    ## Bewusst als letzter Schritt (siehe style_map.R): trifft dadurch
    ## standardmaessig nur noch von den obigen Schritten unberuehrte
    ## Absaetze, kann bei Bedarf aber auch gezielt bereits umgemappte
    ## Ziel-Styles noch einmal ueberschreiben.
    if (!is.null(style_map_config)) {
      source_to_target <- oq_resolve_style_map(style_map_config, name_to_id, fail)
      n_mapped <- oq_apply_style_map(document_doc, source_to_target)
      log_msg("Freies Style-Mapping (officequarto.style-map) angewendet: %d Absaetze.", n_mapped)
    }

    if (!is.null(page_config)) {
      n_sections <- oq_apply_page_options(document_doc, list(size = page_size_vals, margins = page_margin_vals))
      log_msg("Seitenlayout (officequarto.page) angewendet: %d Section(s).", n_sections)
    }

    xml2::write_xml(document_doc, document_path)
  }

  ref_styles_path <- file.path(orig_dir, "word", "styles.xml")
  if (file.exists(ref_styles_path)) {
    ref_style_ids <- oq_all_style_ids(xml2::read_xml(ref_styles_path))

    content_paths <- file.path(
      work_dir, "word",
      c("document.xml", "footnotes.xml", "endnotes.xml", "comments.xml")
    )
    content_docs <- lapply(content_paths[file.exists(content_paths)], xml2::read_xml)
    referenced_ids <- oq_referenced_style_ids(content_docs)

    rendered_styles_path <- file.path(work_dir, "word", "styles.xml")
    rendered_styles_doc <- xml2::read_xml(rendered_styles_path)

    keep_style_ids <- ref_style_ids
    if (isTRUE(code_block_config)) {
      rendered_ids_all <- oq_all_style_ids(rendered_styles_doc)
      code_style_ids <- rendered_ids_all[oq_is_pandoc_code_style_id(rendered_ids_all)]
      keep_style_ids <- union(keep_style_ids, code_style_ids)
      if (length(code_style_ids) > 0) {
        log_msg("Pandocs Codeblock-Styles behalten (officequarto.pandoc-styles.code-block: true): %s",
                 paste(code_style_ids, collapse = ", "))
      }
    }

    prune_result <- oq_prune_foreign_styles(rendered_styles_doc, keep_style_ids, referenced_ids)
    xml2::write_xml(rendered_styles_doc, rendered_styles_path)

    log_msg("Styles bereinigt: %d entfernt, %d behalten.",
             length(prune_result$removed), length(keep_style_ids))
    if (length(prune_result$removed_but_referenced) > 0) {
      log_msg(paste0(
        "Warnung: folgende entfernte Styles werden im Dokument noch referenziert und fallen auf ",
        "Words Standard-Formatierung zurueck: %s (im reference-doc ergaenzen, ueber ",
        "officequarto.styles/officequarto.lists auf einen vorhandenen Style umleiten, oder fuer ",
        "Codeblock-Styles officequarto.pandoc-styles.code-block setzen)."
      ), paste(prune_result$removed_but_referenced, collapse = ", "))
    }
  }

  if (isTRUE(keep_rendered)) {
    debug_path <- file.path(
      dirname(rendered_path),
      paste0(tools::file_path_sans_ext(basename(rendered_path)), ".quarto-rendered.docx")
    )
    file.copy(rendered_path, debug_path, overwrite = TRUE)
    log_msg("reines Quarto/Pandoc-Ergebnis behalten (officequarto.keep-rendered): %s", debug_path)
  }

  ## In eine temporaere Datei zippen und erst danach ueber rendered_path
  ## kopieren, statt direkt in rendered_path hinein zu zippen - schlaegt das
  ## Zippen fehl, bleibt so die bisherige (gueltige) Ausgabedatei unangetastet
  ## statt beschaedigt/leer zurueckzubleiben.
  tmp_zip <- tempfile("officequarto_out_", fileext = ".docx")
  old_wd <- setwd(work_dir)
  system2("zip", c("-rq", shQuote(tmp_zip), "."))
  setwd(old_wd)
  file.copy(tmp_zip, rendered_path, overwrite = TRUE)
  file.remove(tmp_zip)

  log_msg("aktualisiert: %s", rendered_path)
}
