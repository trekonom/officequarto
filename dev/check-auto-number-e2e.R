## End-to-End-Check fuer officequarto.crossref.auto-number (Live-SEQ/REF-
## Felder statt statischem Text, siehe scripts/table-caption-mapping.R/
## oq_convert_caption_to_field() und scripts/crossref-mapping.R/
## oq_apply_crossref_fields(), dev/spike-notes.md Spike P). Erwartet, dass
## zuvor `quarto render report.qmd` in DIESEM Verzeichnis
## (dev/fixtures/auto-number/) lief - eine eigenstaendige Fixture, getrennt
## von template/, da template/_quarto.yml crossref.numbered: false setzt,
## was sich mit auto-number gegenseitig ausschliesst (siehe die
## Fail-Loud-Pruefung in writeback.R). Prueft am echten gerenderten+
## gepatchten Dokument: SEQ-Felder fuer Tabelle UND Abbildung, korrekte
## Bookmark-Namen, REF-Felder an den Querverweisstellen, und dass
## word/settings.xml unangetastet bleibt (kein w:updateFields - haelt sich
## exakt an {officedown}s eigenes, empirisch bewaehrtes Verhalten).
library(xml2)

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "report.docx"
if (!file.exists(target)) fail("%s wurde nicht erzeugt", target)
ok("%s existiert", target)

tmp <- tempfile("check_auto_number_e2e_")
dir.create(tmp)
utils::unzip(target, exdir = tmp)

document_doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns <- xml_ns(document_doc)

check_seq_field <- function(bookmark_name, expected_seq_id, label) {
  bm <- xml_find_first(document_doc, sprintf("//w:bookmarkStart[@w:name='%s']", bookmark_name), ns)
  if (is.na(bm)) fail("%s: kein w:bookmarkStart mit Namen '%s' gefunden", label, bookmark_name)
  ok("%s: Bookmark '%s' vorhanden", label, bookmark_name)

  caption_p <- xml_find_first(bm, "./parent::w:p", ns)
  if (is.na(caption_p)) fail("%s: Bookmark steht nicht in einem Absatz", label)

  instr <- xml_find_first(caption_p, ".//w:instrText", ns)
  if (is.na(instr)) fail("%s: kein w:instrText im Beschriftungsabsatz gefunden", label)
  expected_instr <- sprintf("SEQ %s \\* Arabic", expected_seq_id)
  if (!identical(xml_text(instr), expected_instr)) {
    fail("%s: erwartet instrText '%s', erhalten '%s'", label, expected_instr, xml_text(instr))
  }
  ok("%s: instrText ist '%s'", label, expected_instr)

  fld_chars <- xml_find_all(caption_p, ".//w:fldChar", ns)
  if (length(fld_chars) != 2) fail("%s: erwartet 2 w:fldChar, erhalten %d", label, length(fld_chars))
  if (!all(xml_attr(fld_chars, "dirty") == "true")) fail("%s: beide w:fldChar sollten w:dirty='true' tragen", label)
  ok("%s: beide w:fldChar tragen w:dirty='true'", label)
}

check_ref_field <- function(anchor, label) {
  link <- xml_find_first(document_doc, sprintf("//w:hyperlink[@w:anchor='%s']", anchor), ns)
  if (is.na(link)) fail("%s: kein w:hyperlink mit Anker '%s' gefunden", label, anchor)
  instr <- xml_find_first(link, ".//w:instrText", ns)
  if (is.na(instr)) fail("%s: kein w:instrText im Hyperlink gefunden", label)
  expected_instr <- sprintf(" REF %s \\h ", anchor)
  if (!identical(xml_text(instr), expected_instr)) {
    fail("%s: erwartet instrText '%s', erhalten '%s'", label, expected_instr, xml_text(instr))
  }
  ok("%s: Querverweis auf '%s' traegt ein REF-Feld statt statischem Text", label, anchor)
}

check_seq_field("tbl-x", "Table", "Tabellen-Beschriftung")
check_seq_field("fig-x", "Figure", "Abbildungs-Beschriftung")
check_ref_field("tbl-x", "Tabellen-Querverweis")
check_ref_field("fig-x", "Abbildungs-Querverweis")

settings_path <- file.path(tmp, "word", "settings.xml")
if (file.exists(settings_path)) {
  settings_text <- paste(readLines(settings_path, warn = FALSE), collapse = "\n")
  if (grepl("updateFields", settings_text, fixed = TRUE)) {
    fail("word/settings.xml sollte kein w:updateFields enthalten (haelt sich an {officedown}s eigenes Verhalten)")
  }
}
ok("word/settings.xml enthaelt kein w:updateFields")

cat("\nAlle Checks bestanden.\n")
