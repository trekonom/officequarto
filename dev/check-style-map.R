## Unit-Check fuer oq_resolve_style_map()/oq_apply_style_map() (siehe
## scripts/style-map.R, Gruppe 7 / officequarto.style-map). Eigenstaendig
## ausfuehrbar, ohne vorherigen `quarto render` - reine Funktionslogik, kein
## Docx-Zugriff (bis auf ein minimales xml2-Dokument fuer
## oq_apply_style_map()). Wie check-option-aliases.R aus template/ heraus
## aufzurufen (`Rscript ../dev/check-style-map.R`), damit der relative Pfad
## zu _extensions/ (Symlink) aufgeht.
library(xml2)
source("_extensions/officequarto/scripts/style-mapping.R")  # fuer oq_resolve_style_id()/oq_set_pstyle()
source("_extensions/officequarto/scripts/style-map.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB")
fails_seen <- character(0)
fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)

## Einfacher Fall: ein Ziel, mehrere Quellen
fails_seen <- character(0)
res <- oq_resolve_style_map(list(`Ziel A` = c("Normal", "Compact")), name_to_id, fail_collect)
if (length(fails_seen) != 0) fail("einfacher Fall: unerwartete Fehler: %s", paste(fails_seen, collapse = "; "))
if (!identical(unname(res["Normal"]), "ZielA") || !identical(unname(res["Compact"]), "ZielA")) {
  fail("einfacher Fall: erwartet Normal/Compact -> ZielA, erhalten: %s", paste(names(res), res, sep = "=", collapse = ", "))
}
ok("ein Ziel mit mehreren Quellen wird korrekt aufgeloest")

## Mehrere Ziele, disjunkte Quellen
fails_seen <- character(0)
res <- oq_resolve_style_map(list(`Ziel A` = c("Normal"), `Ziel B` = c("Heading1")), name_to_id, fail_collect)
if (length(fails_seen) != 0) fail("mehrere Ziele: unerwartete Fehler: %s", paste(fails_seen, collapse = "; "))
if (!identical(unname(res["Normal"]), "ZielA") || !identical(unname(res["Heading1"]), "ZielB")) {
  fail("mehrere Ziele: falsch aufgeloest: %s", paste(names(res), res, sep = "=", collapse = ", "))
}
ok("mehrere Ziele mit disjunkten Quellen werden korrekt aufgeloest")

## Konflikt: dieselbe Quelle zwei Zielen zugeordnet
fails_seen <- character(0)
invisible(oq_resolve_style_map(list(`Ziel A` = c("Normal"), `Ziel B` = c("Normal")), name_to_id, fail_collect))
if (length(fails_seen) != 1) fail("Konflikt: erwartet genau 1 Fehler, erhalten %d", length(fails_seen))
ok("dieselbe Quelle zwei Zielen zugeordnet: genau 1 Fehler ('%s')", fails_seen[[1]])

## Ziel-Style existiert nicht in reference-doc
fails_seen <- character(0)
invisible(oq_resolve_style_map(list(`Unbekanntes Ziel` = c("Normal")), name_to_id, fail_collect))
if (length(fails_seen) != 1) fail("unbekanntes Ziel: erwartet genau 1 Fehler, erhalten %d", length(fails_seen))
ok("unbekannter Ziel-Style-Name: genau 1 Fehler ('%s')", fails_seen[[1]])

## oq_apply_style_map(): leere Zuordnung -> No-op
doc <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr></w:p></w:body></w:document>')
n <- oq_apply_style_map(doc, character(0))
if (n != 0) fail("leere Zuordnung: erwartet 0 umgemappte Absaetze, erhalten %d", n)
ok("oq_apply_style_map() mit leerer Zuordnung ist ein No-op")

## oq_apply_style_map(): tatsaechliche Anwendung
doc2 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr></w:p><w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr></w:p></w:body></w:document>')
n2 <- oq_apply_style_map(doc2, c(Title = "TitelACME"))
if (n2 != 1) fail("Anwendung: erwartet 1 umgemappten Absatz, erhalten %d", n2)
result_styles <- xml_attr(xml_find_all(doc2, "//w:p/w:pPr/w:pStyle", xml_ns(doc2)), "val")
if (!identical(sort(result_styles), sort(c("Normal", "TitelACME")))) {
  fail("Anwendung: erwartet Styles Normal+TitelACME, erhalten: %s", paste(result_styles, collapse = ", "))
}
ok("oq_apply_style_map() mappt den passenden Absatz um und laesst den Rest unangetastet")

cat("\nAlle Checks bestanden.\n")
