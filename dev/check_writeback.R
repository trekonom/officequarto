## End-to-End-Check fuer den officequarto-Workflow.
## Erwartet, dass zuvor `quarto render report.qmd` im template/-Projekt lief
## (mit der officequarto-styles-, officequarto-pandoc-styles- und
## officequarto-keep-rendered-Konfiguration aus template/_quarto.yml).
## Prueft: report.docx wurde vom Hook in-place ueberschrieben (kein separates
## written-back.docx mehr), Header/Footer aus original.docx sind erhalten, der
## neu gerenderte Body-Text ist auffindbar, die aus dem Original
## zurueckgeschriebenen Metadaten (Subject/Custom-Property) sind vorhanden,
## Body-/Bullet-/Nummerierungs-/Buchstaben-Listen-/Codeblock-Absaetze tragen
## die konfigurierten ACME-Custom-Styles statt Pandocs Standard-Styles, dass die Tabelle
## den konfigurierten Style/Layout/Breite traegt (officequarto-tables, Schema-konforme
## w:tblPr-Reihenfolge), dass word/styles.xml im
## Ergebnis exakt die Styles aus original.docx enthaelt (Pandocs
## Syntax-Highlighting-Laufstile fuer den Codeblock in report.qmd wurden trotz
## Verwendung entfernt - officequarto-pandoc-styles.code-block mappt hier nur die
## SourceCode-Absatzrolle, nicht die *Tok-Laufstile), und dass das per
## officequarto-keep-rendered behaltene Debug-Artefakt den ungepatchten
## Zustand zeigt.
library(xml2)
source("_extensions/officequarto/scripts/style_pruning.R")  # fuer oq_is_pandoc_code_style_id

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "report.docx"
if (!file.exists(target)) fail("%s wurde nicht erzeugt", target)
ok("%s existiert", target)

if (file.exists("report.written-back.docx")) {
  fail("report.written-back.docx sollte nicht mehr erzeugt werden (in-place-Ueberschreiben)")
}
ok("kein separates report.written-back.docx mehr vorhanden")

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

n_letter <- sum(pstyles == "BuchstabierungACME")
if (n_letter != 3) fail("erwartet 3 Buchstaben-Listen-Absaetze mit Style 'BuchstabierungACME', gefunden %d", n_letter)
ok("%d Buchstaben-Listen-Absaetze tragen den konfigurierten Style", n_letter)

if (any(pstyles == "Normal") || any(pstyles == "Compact") || any(pstyles == "FirstParagraph")) {
  fail("es sind noch unbenannte Pandoc-Standard-Styles im Ergebnis vorhanden: %s",
       paste(unique(pstyles), collapse = ", "))
}
ok("keine unumgemappten Pandoc-Standard-Styles (Normal/Compact/FirstParagraph) mehr vorhanden")

tbl_pr <- xml_find_first(document_doc, "//w:tbl/w:tblPr", ns)
if (is.na(tbl_pr)) fail("kein w:tbl/w:tblPr im Ergebnis-Dokument gefunden (erwartet: die Tabelle aus report.qmd)")

tbl_style <- xml_attr(xml_find_first(tbl_pr, "./w:tblStyle", ns), "val")
if (!identical(tbl_style, "TabelleACME")) {
  fail("Tabelle sollte den konfigurierten Style 'TabelleACME' tragen (officequarto-tables.style), gefunden: '%s'", tbl_style)
}
ok("Tabelle traegt den konfigurierten Style 'TabelleACME' (officequarto-tables.style)")

tbl_layout <- xml_attr(xml_find_first(tbl_pr, "./w:tblLayout", ns), "type")
if (!identical(tbl_layout, "fixed")) {
  fail("Tabelle sollte tblLayout type='fixed' tragen (officequarto-tables.layout), gefunden: '%s'", tbl_layout)
}
ok("Tabelle traegt den konfigurierten Layout 'fixed' (officequarto-tables.layout)")

tbl_w_node <- xml_find_first(tbl_pr, "./w:tblW", ns)
tbl_w_type <- xml_attr(tbl_w_node, "type")
tbl_w_val <- xml_attr(tbl_w_node, "w")
if (!identical(tbl_w_type, "pct") || !identical(tbl_w_val, "4000")) {
  fail("Tabelle sollte tblW type='pct' w='4000' tragen (officequarto-tables.width: 0.8), gefunden: type='%s' w='%s'", tbl_w_type, tbl_w_val)
}
ok("Tabelle traegt die konfigurierte Breite 0.8 (officequarto-tables.width, als tblW type='pct' w='4000')")

tbl_look <- xml_find_first(tbl_pr, "./w:tblLook", ns)
expected_look <- c(firstRow = "1", lastRow = "1", noHBand = "1", noVBand = "0")
for (attr_name in names(expected_look)) {
  actual <- xml_attr(tbl_look, attr_name)
  if (!identical(actual, expected_look[[attr_name]])) {
    fail("Tabelle: w:tblLook/@%s sollte '%s' sein (officequarto-tables.conditional), gefunden: '%s'",
         attr_name, expected_look[[attr_name]], actual)
  }
}
ok("Tabelle traegt die konfigurierten Conditional-Formatting-Flags (first-row/last-row/band-rows/band-columns via officequarto-tables.conditional, teils ueber officedown-Alias)")

tbl_pr_children <- xml_name(xml_children(tbl_pr))
tbl_pr_order <- match(tbl_pr_children, c("tblStyle", "tblW", "tblLayout", "tblLook"))
if (is.unsorted(tbl_pr_order, na.rm = TRUE)) {
  fail("w:tblPr-Kindelemente sind nicht in Schema-Reihenfolge: %s", paste(tbl_pr_children, collapse = ", "))
}
ok("w:tblPr-Kindelemente stehen in Schema-Reihenfolge: %s", paste(tbl_pr_children, collapse = ", "))

rendered_styles_doc <- read_xml(file.path(tmp, "word", "styles.xml"))
rendered_style_ids <- xml_attr(xml_find_all(rendered_styles_doc, "//w:style", ns), "styleId")

orig_tmp <- tempfile("check_orig_")
dir.create(orig_tmp)
utils::unzip("original.docx", exdir = orig_tmp)
orig_styles_doc <- read_xml(file.path(orig_tmp, "word", "styles.xml"))
orig_style_ids <- xml_attr(xml_find_all(orig_styles_doc, "//w:style", xml_ns(orig_styles_doc)), "styleId")
unlink(orig_tmp, recursive = TRUE)

if (!setequal(rendered_style_ids, orig_style_ids)) {
  fail("word/styles.xml von %s sollte exakt die Styles aus original.docx enthalten (nur: %s, fehlt: %s)",
       target,
       paste(setdiff(rendered_style_ids, orig_style_ids), collapse = ", "),
       paste(setdiff(orig_style_ids, rendered_style_ids), collapse = ", "))
}
ok("word/styles.xml enthaelt exakt die %d Styles aus original.docx (keine Pandoc-Extras)", length(orig_style_ids))

if (any(oq_is_pandoc_code_style_id(rendered_style_ids))) {
  fail("Pandocs Syntax-Highlighting-Styles (*Tok/SourceCode) haetten entfernt werden muessen")
}
ok("Pandocs Syntax-Highlighting-Styles (*Tok/SourceCode) wurden entfernt")

code_pstyles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", ns), "val")
if (!("CodeACME" %in% code_pstyles)) {
  fail("Codeblock-Absatz sollte auf den konfigurierten Style 'CodeACME' umgemappt sein (officequarto-pandoc-styles.code-block), gefunden: %s",
       paste(unique(code_pstyles), collapse = ", "))
}
if ("SourceCode" %in% code_pstyles) {
  fail("Codeblock-Absatz sollte nicht mehr 'SourceCode' referenzieren (haette auf 'CodeACME' umgemappt werden muessen)")
}
ok("Codeblock-Absatz traegt den konfigurierten Style 'CodeACME' (officequarto-pandoc-styles.code-block)")

code_rstyles <- xml_attr(xml_find_all(document_doc, "//w:r/w:rPr/w:rStyle", ns), "val")
if (!any(oq_is_pandoc_code_style_id(code_rstyles))) {
  fail("erwartet, dass der Codeblock noch *Tok-Laufstile referenziert (Syntax-Highlighting-Warnpfad-Testfall)")
}
ok("Codeblock referenziert weiterhin entfernte *Tok-Laufstile (Syntax-Highlighting faellt auf Standard-Formatierung zurueck, wie vorgesehen - nur die Block-Rolle wird umgemappt)")

unlink(tmp, recursive = TRUE)

debug_target <- "report.quarto-rendered.docx"
if (!file.exists(debug_target)) {
  fail("%s wurde nicht erzeugt (officequarto-keep-rendered: true in _quarto.yml erwartet)", debug_target)
}
ok("%s existiert (officequarto-keep-rendered)", debug_target)

debug_tmp <- tempfile("check_debug_")
dir.create(debug_tmp)
utils::unzip(debug_target, exdir = debug_tmp)

debug_custom_path <- file.path(debug_tmp, "docProps", "custom.xml")
debug_has_property <- file.exists(debug_custom_path) &&
  any(grepl("Vertraulichkeitsstufe", readLines(debug_custom_path, warn = FALSE), fixed = TRUE))
if (debug_has_property) {
  fail("%s sollte die ungepatchte Pandoc-Ausgabe sein, traegt aber schon die zurueckgeschriebene Custom-Property", debug_target)
}
ok("%s zeigt den ungepatchten Zustand (keine zurueckgeschriebene Custom-Property)", debug_target)

debug_document_doc <- read_xml(file.path(debug_tmp, "word", "document.xml"))
debug_pstyles <- xml_attr(xml_find_all(debug_document_doc, "//w:p/w:pPr/w:pStyle", xml_ns(debug_document_doc)), "val")
if (!any(debug_pstyles %in% c("Normal", "Compact", "FirstParagraph"))) {
  fail("%s sollte noch Pandocs Standard-Styles tragen (gefunden: %s)",
       debug_target, paste(unique(debug_pstyles), collapse = ", "))
}
ok("%s zeigt noch Pandocs Standard-Styles (kein Style-Mapping angewendet)", debug_target)

unlink(debug_tmp, recursive = TRUE)
cat("\nAlle Checks bestanden.\n")
