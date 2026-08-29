## Unit-Check fuer oq_apply_crossref_text() (siehe scripts/crossref_mapping.R,
## Gruppe 9 / officequarto.crossref.numbered). Eigenstaendig ausfuehrbar,
## ohne vorherigen `quarto render` - reine Funktionslogik anhand kleiner
## xml2-Testdokumente. Wie check_option_aliases.R aus template/ heraus
## aufzurufen (`Rscript ../dev/check_crossref.R`), damit der relative Pfad
## zu _extensions/ (Symlink) aufgeht.
library(xml2)
source("_extensions/officequarto/scripts/crossref_mapping.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

## Einfacher Fall: passender Anker wird ersetzt
doc <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n <- oq_apply_crossref_text(doc, c(`tbl-x` = "Meine Tabelle"))
if (n != 1) fail("einfacher Fall: erwartet 1 ersetzt, erhalten %d", n)
result_text <- xml_text(xml_find_first(doc, "//w:hyperlink", xml_ns(doc)))
if (!identical(result_text, "Meine Tabelle")) fail("einfacher Fall: erwartet 'Meine Tabelle', erhalten '%s'", result_text)
ok("passender Anker wird korrekt durch den Beschriftungstext ersetzt")

## Anker ohne Eintrag in anchor_text bleibt unangetastet
doc2 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-unbekannt"><w:r><w:t>Table 2</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n2 <- oq_apply_crossref_text(doc2, c(`tbl-x` = "Meine Tabelle"))
if (n2 != 0) fail("unbekannter Anker: erwartet 0 ersetzt, erhalten %d", n2)
result_text2 <- xml_text(xml_find_first(doc2, "//w:hyperlink", xml_ns(doc2)))
if (!identical(result_text2, "Table 2")) fail("unbekannter Anker: Text haette unveraendert bleiben sollen, ist aber '%s'", result_text2)
ok("Hyperlink mit unbekanntem Anker bleibt unangetastet")

## Leere anchor_text -> No-op (frueher Ausstieg)
doc3 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n3 <- oq_apply_crossref_text(doc3, character(0))
if (n3 != 0) fail("leere anchor_text: erwartet 0 ersetzt, erhalten %d", n3)
ok("leere anchor_text ist ein No-op")

## Mehrere Laeufe im Hyperlink: erster Lauf erhaelt den Text, weitere werden entfernt
doc4 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table</w:t></w:r><w:r><w:t xml:space="preserve"> 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n4 <- oq_apply_crossref_text(doc4, c(`tbl-x` = "Meine Tabelle"))
if (n4 != 1) fail("mehrere Laeufe: erwartet 1 ersetzt, erhalten %d", n4)
runs4 <- xml_find_all(doc4, "//w:hyperlink/w:r", xml_ns(doc4))
if (length(runs4) != 1) fail("mehrere Laeufe: erwartet genau 1 verbleibenden Lauf, erhalten %d", length(runs4))
if (!identical(xml_text(runs4[[1]]), "Meine Tabelle")) fail("mehrere Laeufe: erwartet 'Meine Tabelle' im verbleibenden Lauf, erhalten '%s'", xml_text(runs4[[1]]))
ok("Hyperlink mit mehreren Laeufen: erster Lauf traegt den Ersatztext, weitere Laeufe werden entfernt")

cat("\nAlle Checks bestanden.\n")
