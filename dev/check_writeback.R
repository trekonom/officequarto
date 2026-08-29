## End-to-End-Check fuer den officequarto-Workflow.
## Erwartet, dass zuvor `quarto render bericht.qmd` im template/-Projekt lief
## (mit der officequarto-styles-Konfiguration aus template/_quarto.yml).
## Prueft: written-back.docx existiert, Header/Footer aus original.docx sind
## erhalten, der neu gerenderte Body-Text ist auffindbar, die aus dem Original
## zurueckgeschriebenen Metadaten (Subject/Custom-Property) sind vorhanden,
## und Body-/Bullet-/Nummerierungs-Absaetze tragen die konfigurierten
## ACME-Custom-Styles statt Pandocs Standard-Styles.
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

document_doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns <- xml_ns(document_doc)
pstyles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", ns), "val")

n_body <- sum(pstyles == "FliesstextACME")
if (n_body < 1) fail("kein Body-Absatz traegt den konfigurierten Style 'FliesstextACME' (gefunden: %s)",
                      paste(unique(pstyles), collapse = ", "))
ok("%d Body-Absatz/-Absaetze tragen den konfigurierten Style", n_body)

n_bullet <- sum(pstyles == "AufzaehlungACME")
if (n_bullet != 3) fail("erwartet 3 Bullet-Absaetze mit Style 'AufzaehlungACME', gefunden %d", n_bullet)
ok("%d Bullet-Absaetze tragen den konfigurierten Style", n_bullet)

n_number <- sum(pstyles == "NummerierungACME")
if (n_number != 3) fail("erwartet 3 nummerierte Absaetze mit Style 'NummerierungACME', gefunden %d", n_number)
ok("%d nummerierte Absaetze tragen den konfigurierten Style", n_number)

if (any(pstyles == "Normal") || any(pstyles == "Compact") || any(pstyles == "FirstParagraph")) {
  fail("es sind noch unbenannte Pandoc-Standard-Styles im Ergebnis vorhanden: %s",
       paste(unique(pstyles), collapse = ", "))
}
ok("keine unumgemappten Pandoc-Standard-Styles (Normal/Compact/FirstParagraph) mehr vorhanden")

unlink(tmp, recursive = TRUE)
cat("\nAlle Checks bestanden.\n")
