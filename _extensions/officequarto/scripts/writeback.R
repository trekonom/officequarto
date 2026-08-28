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

log_msg <- function(fmt, ...) cat(sprintf(paste0("[officequarto] ", fmt, "\n"), ...))
fail <- function(fmt, ...) stop(sprintf(paste0("officequarto: ", fmt), ...), call. = FALSE)

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

  target_path <- file.path(
    dirname(rendered_path),
    paste0(tools::file_path_sans_ext(basename(rendered_path)), ".written-back.docx")
  )

  work_dir <- tempfile("officequarto_")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  system2("unzip", c("-oq", shQuote(rendered_path), "-d", shQuote(work_dir)))

  orig_dir <- file.path(work_dir, "__original__")
  dir.create(orig_dir)
  system2("unzip", c("-oq", shQuote(reference_doc_path), "docProps/core.xml", "docProps/custom.xml",
                      "-d", shQuote(orig_dir)))

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

  if (file.exists(target_path)) file.remove(target_path)
  old_wd <- setwd(work_dir)
  system2("zip", c("-rq", shQuote(target_path), "."))
  setwd(old_wd)

  log_msg("zurueckgeschrieben: %s", target_path)
}
