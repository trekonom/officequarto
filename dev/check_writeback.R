## End-to-End-Check fuer den officequarto-Workflow.
## Erwartet, dass zuvor `quarto render bericht.qmd` im template/-Projekt lief.
## Prueft: written-back.docx existiert, Header/Footer aus original.docx sind
## erhalten, der neu gerenderte Body-Text ist auffindbar, die aus dem Original
## zurueckgeschriebenen Metadaten (Subject/Custom-Property) sind vorhanden.
library(xml2)

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "bericht.written-back.docx"
if (!file.exists(target)) fail("%s wurde nicht erzeugt", target)
ok("%s existiert", target)

tmp <- tempfile("check_")
dir.create(tmp)
utils::unzip(target, exdir = tmp)

header_txt <- xml_text(read_xml(file.path(tmp, "word", "header1.xml")))
if (!grepl("ACME GmbH", header_txt, fixed = TRUE)) fail("Header-Text aus original.docx fehlt")
ok("Header aus original.docx ist erhalten")

footer_txt <- xml_text(read_xml(file.path(tmp, "word", "footer1.xml")))
if (!grepl("Vertraulich", footer_txt, fixed = TRUE)) fail("Footer-Text aus original.docx fehlt")
ok("Footer aus original.docx ist erhalten")

body_txt <- xml_text(read_xml(file.path(tmp, "word", "document.xml")))
if (!grepl("muss im zurückgeschriebenen Dokument auffindbar sein", body_txt, fixed = TRUE)) {
  fail("neu gerenderter Body-Inhalt fehlt")
}
ok("neu gerenderter Body-Inhalt ist vorhanden")

core_txt <- xml_text(read_xml(file.path(tmp, "docProps", "core.xml")))
if (!grepl("Quartalsberichte", core_txt, fixed = TRUE)) fail("dc:subject aus original.docx fehlt")
ok("dc:subject aus original.docx wurde zurueckgeschrieben")

custom_path <- file.path(tmp, "docProps", "custom.xml")
custom_has_property <- file.exists(custom_path) &&
  any(grepl("Vertraulichkeitsstufe", readLines(custom_path, warn = FALSE), fixed = TRUE))
if (!custom_has_property) fail("Custom-Property aus original.docx fehlt")
ok("Custom-Property aus original.docx wurde zurueckgeschrieben")

unlink(tmp, recursive = TRUE)
cat("\nAlle Checks bestanden.\n")
