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
## Zusaetzlich, optional per `format.docx.officequarto-styles` konfigurierbar:
## Body- und Listen-Absaetze werden auf vom Nutzer benannte, echte Styles des
## reference-doc umgemappt (siehe scripts/style_mapping.R fuer die Kernlogik).
##
## Der Hook ueberschreibt die von Quarto/Pandoc erzeugte .docx direkt an Ort
## und Stelle - es entsteht keine zweite Ausgabedatei. Wer das reine,
## ungepatchte Pandoc-Ergebnis zu Debug-Zwecken behalten will, kann das per
## `format.docx.officequarto-keep-rendered: true` aktivieren (analog zu
## Quartos eigenem `keep-md`); es wird dann zusaetzlich als
## `<name>.quarto-rendered.docx` abgelegt.
##
## Zusaetzlich, immer aktiv: Pandocs docx-Writer fuegt beim Rendern eigene
## Style-Definitionen hinzu, die im reference-doc gar nicht existieren (z.B.
## Syntax-Highlighting-Styles fuer Codebloecke, unabhaengig davon, ob welche
## vorkommen). Diese werden standardmaessig wieder entfernt, das Ergebnis-docx
## enthaelt dann ausschliesslich Styles aus dem reference-doc (siehe
## scripts/style_pruning.R fuer die Kernlogik). Per `format.docx.
## officequarto-pandoc-styles.code-block` (eigener Abschnitt, unabhaengig von
## officequarto-styles) lassen sich Pandocs Codeblock-Styles davon ausnehmen:
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

style_config <- tryCatch(inspect$config$format$docx$`officequarto-styles`, error = function(e) NULL)
pandoc_style_config <- tryCatch(inspect$config$format$docx$`officequarto-pandoc-styles`, error = function(e) NULL)
keep_rendered <- tryCatch(inspect$config$format$docx$`officequarto-keep-rendered`, error = function(e) NULL)
if (is.null(keep_rendered)) keep_rendered <- FALSE

code_block_config <- tryCatch(pandoc_style_config$`code-block`, error = function(e) NULL)
code_block_valid <- is.null(code_block_config) || identical(code_block_config, FALSE) ||
  isTRUE(code_block_config) || (is.character(code_block_config) && length(code_block_config) == 1 && nzchar(code_block_config))
if (!code_block_valid) {
  fail("officequarto-pandoc-styles.code-block muss entweder true oder ein Style-Name (String) sein.")
}

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

  if (!is.null(style_config) || !is.null(code_block_config)) {
    styles_path <- file.path(work_dir, "word", "styles.xml")
    document_path <- file.path(work_dir, "word", "document.xml")
    numbering_path <- file.path(work_dir, "word", "numbering.xml")

    styles_doc <- xml2::read_xml(styles_path)
    name_to_id <- oq_style_name_to_id(styles_doc)
    style_num_id <- oq_style_num_id(styles_doc)

    style_ids <- list()
    if (!is.null(style_config$body)) {
      style_ids$body <- oq_resolve_style_id(name_to_id, style_config$body, "officequarto-styles.body", fail)
    }
    if (!is.null(style_config$`list-bullet`)) {
      style_ids$list_bullet <- oq_resolve_style_id(name_to_id, style_config$`list-bullet`, "officequarto-styles.list-bullet", fail)
    }
    if (!is.null(style_config$`list-number`)) {
      style_ids$list_number <- oq_resolve_style_id(name_to_id, style_config$`list-number`, "officequarto-styles.list-number", fail)
    }
    if (is.character(code_block_config) && nzchar(code_block_config)) {
      style_ids$code <- oq_resolve_style_id(name_to_id, code_block_config, "officequarto-pandoc-styles.code-block", fail)
    }

    num_fmt_map <- if (file.exists(numbering_path)) {
      oq_num_fmt_map(xml2::read_xml(numbering_path))
    } else {
      character(0)
    }

    document_doc <- xml2::read_xml(document_path)
    result <- oq_apply_style_mapping(document_doc, num_fmt_map, style_ids, style_num_id)
    xml2::write_xml(document_doc, document_path)
    log_msg("Style-Mapping angewendet: %d Body-Absaetze, %d Listen-Absaetze, %d Codeblock-Absaetze.",
             result$n_body, result$n_list, result$n_code)
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
        log_msg("Pandocs Codeblock-Styles behalten (officequarto-pandoc-styles.code-block: true): %s",
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
        "officequarto-styles auf einen vorhandenen Style umleiten, oder fuer Codeblock-Styles ",
        "officequarto-pandoc-styles.code-block setzen)."
      ), paste(prune_result$removed_but_referenced, collapse = ", "))
    }
  }

  if (isTRUE(keep_rendered)) {
    debug_path <- file.path(
      dirname(rendered_path),
      paste0(tools::file_path_sans_ext(basename(rendered_path)), ".quarto-rendered.docx")
    )
    file.copy(rendered_path, debug_path, overwrite = TRUE)
    log_msg("reines Quarto/Pandoc-Ergebnis behalten (officequarto-keep-rendered): %s", debug_path)
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
