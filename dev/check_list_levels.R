## Unit-Check fuer die Listen-Style-pro-Verschachtelungsebene-Funktion (siehe
## scripts/style_mapping.R, officequarto.lists.list-bullet/list-number/
## list-letter als Array statt Skalar, dev/spike-notes.md Spike O). Eigenstaendig
## ausfuehrbar, ohne vorherigen `quarto render` - reine Funktionslogik, nur mit
## kleinen synthetischen xml2-Dokumenten. Wie check_style_map.R/
## check_option_aliases.R aus template/ heraus aufzurufen
## (`Rscript ../dev/check_list_levels.R`), damit der relative Pfad zu
## _extensions/ (Symlink) aufgeht.
library(xml2)
source("_extensions/officequarto/scripts/style_mapping.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

## oq_style_for_level(): skalar (Laenge 1) liefert immer denselben Wert
if (!identical(oq_style_for_level("A", 0L), "A")) fail("Skalar Ebene 0: erwartet 'A'")
if (!identical(oq_style_for_level("A", 5L), "A")) fail("Skalar Ebene 5: erwartet weiterhin 'A'")
ok("oq_style_for_level() mit Laenge-1-Vektor liefert unabhaengig von der Ebene immer denselben Wert")

## oq_style_for_level(): Vektor der Laenge 3, exakter Treffer pro Ebene
styles3 <- c("L0", "L1", "L2")
if (!identical(oq_style_for_level(styles3, 0L), "L0")) fail("Ebene 0: erwartet 'L0'")
if (!identical(oq_style_for_level(styles3, 1L), "L1")) fail("Ebene 1: erwartet 'L1'")
if (!identical(oq_style_for_level(styles3, 2L), "L2")) fail("Ebene 2: erwartet 'L2'")
ok("oq_style_for_level() waehlt bei ausreichend langem Vektor exakt den Eintrag der jeweiligen Ebene")

## oq_style_for_level(): Ueberlaufende Ebene clampt auf den letzten Eintrag
if (!identical(oq_style_for_level(styles3, 5L), "L2")) fail("Ebene 5 (Ueberlauf): erwartet Clamping auf 'L2'")
ok("oq_style_for_level() clampt eine tiefere Verschachtelung auf den letzten konfigurierten Eintrag")

## oq_paragraph_ilvl(): w:ilvl vorhanden
p_with_ilvl <- xml_find_first(
  read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="2"/></w:numPr></w:pPr></w:p></w:body></w:document>'),
  "//w:p"
)
if (oq_paragraph_ilvl(p_with_ilvl, xml_ns(xml_root(p_with_ilvl))) != 2L) fail("w:ilvl vorhanden: erwartet 2")
ok("oq_paragraph_ilvl() liest ein vorhandenes w:ilvl korrekt")

## oq_paragraph_ilvl(): w:ilvl fehlt -> Default 0
p_without_ilvl <- xml_find_first(
  read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:numPr><w:numId w:val="1"/></w:numPr></w:pPr></w:p></w:body></w:document>'),
  "//w:p"
)
if (oq_paragraph_ilvl(p_without_ilvl, xml_ns(xml_root(p_without_ilvl))) != 0L) fail("w:ilvl fehlt: erwartet Default 0")
ok("oq_paragraph_ilvl() faellt bei fehlendem w:ilvl auf Ebene 0 zurueck")

## oq_resolve_style_ids(): alle Namen bekannt, Reihenfolge bleibt erhalten
name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB", "Ziel C" = "ZielC")
fails_seen <- character(0)
fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
res <- oq_resolve_style_ids(name_to_id, c("Ziel B", "Ziel A", "Ziel C"), "test.key", fail_collect)
if (length(fails_seen) != 0) fail("alle Namen bekannt: unerwartete Fehler: %s", paste(fails_seen, collapse = "; "))
if (!identical(res, c("ZielB", "ZielA", "ZielC"))) fail("alle Namen bekannt: falsche Reihenfolge/Werte: %s", paste(res, collapse = ", "))
ok("oq_resolve_style_ids() loest ein Array vollstaendig und reihenfolgetreu auf")

## oq_resolve_style_ids(): ein unbekannter Name -> genau 1 Fehler
fails_seen <- character(0)
invisible(oq_resolve_style_ids(name_to_id, c("Ziel A", "Unbekannt"), "test.key", fail_collect))
if (length(fails_seen) != 1) fail("unbekannter Name: erwartet genau 1 Fehler, erhalten %d", length(fails_seen))
ok("oq_resolve_style_ids() mit einem unbekannten Namen: genau 1 Fehler ('%s')", fails_seen[[1]])

## oq_resolve_style_ids(): leeres Array -> genau 1 Fehler
fails_seen <- character(0)
invisible(oq_resolve_style_ids(name_to_id, character(0), "test.key", fail_collect))
if (length(fails_seen) != 1) fail("leeres Array: erwartet genau 1 Fehler, erhalten %d", length(fails_seen))
ok("oq_resolve_style_ids() mit leerem Array: genau 1 Fehler ('%s')", fails_seen[[1]])

## oq_apply_style_mapping(): Clamping in der Praxis - 3 Bullet-Absaetze auf
## Ebene 0/1/2, nur 2 konfigurierte Styles -> Ebene 2 clampt auf den zweiten
## (letzten) Style.
document_doc <- read_xml(paste0(
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
  '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="0"/></w:numPr></w:pPr></w:p>',
  '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="1"/></w:numPr></w:pPr></w:p>',
  '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="2"/></w:numPr></w:pPr></w:p>',
  '</w:body></w:document>'
))
num_fmt_map <- c("1" = "bullet")
style_ids <- list(list_bullet = c("BulletL0", "BulletL1"))
result <- oq_apply_style_mapping(document_doc, num_fmt_map, style_ids, character(0))
if (result$n_list != 3) fail("Clamping-Test: erwartet 3 Listen-Absaetze, erhalten %d", result$n_list)
if (result$n_list_clamped != 1) fail("Clamping-Test: erwartet 1 geclampten Absatz, erhalten %d", result$n_list_clamped)
result_styles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", xml_ns(document_doc)), "val")
if (!identical(result_styles, c("BulletL0", "BulletL1", "BulletL1"))) {
  fail("Clamping-Test: erwartete Styles BulletL0/BulletL1/BulletL1 (Ebene 2 clampt), erhalten: %s",
       paste(result_styles, collapse = ", "))
}
ok("oq_apply_style_mapping() clampt eine tiefer verschachtelte Liste korrekt auf den letzten konfigurierten Style (n_list=%d, n_list_clamped=%d)",
   result$n_list, result$n_list_clamped)

cat("\nAlle Checks bestanden.\n")
