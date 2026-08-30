## Unit-Check fuer die Live-Auto-Nummerierung (officequarto.crossref.auto-number,
## siehe scripts/table-caption-mapping.R/oq_convert_caption_to_field() und
## scripts/crossref-mapping.R/oq_apply_crossref_fields(), sowie
## dev/spike-notes.md Spike P fuer die empirische Herleitung der
## Bookmark-Struktur). Eigenstaendig ausfuehrbar, ohne vorherigen `quarto
## render` - reine Funktionslogik anhand kleiner xml2-Testdokumente. Wie
## check-crossref.R/check-style-map.R aus template/ heraus aufzurufen
## (`Rscript ../dev/check-auto-number.R`), damit der relative Pfad zu
## _extensions/ (Symlink) aufgeht.
library(xml2)
source("_extensions/officequarto/scripts/table-caption-mapping.R")
source("_extensions/officequarto/scripts/crossref-mapping.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

## Baut eine synthetische Wrapper-Zelle nach der in Spike P verifizierten
## Struktur nach: w:bookmarkStart VOR der Beschriftung, ein Platzhalter-Inhalt
## (steht fuer die echte Tabelle/Abbildung), w:bookmarkEnd erst DANACH - das
## Bookmark umspannt also grosszuegig, nicht eng anliegend, und die
## bookmarkEnd-Suche muss deshalb per @id erfolgen, nicht per Adjazenz.
build_doc <- function(caption_text = "Table 1: Meine Tabelle") {
  read_xml(paste0(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc>',
    '<w:bookmarkStart w:id="7" w:name="tbl-x"/>',
    '<w:p><w:pPr><w:pStyle w:val="ImageCaption"/></w:pPr><w:r><w:t xml:space="preserve">', caption_text, '</w:t></w:r></w:p>',
    '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
    '<w:bookmarkEnd w:id="7"/>',
    '</w:tc></w:tr></w:tbl></w:body></w:document>'
  ))
}

get_caption_p <- function(doc) xml_find_first(doc, "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption']", xml_ns(doc))

## --- SEQ-Feld-Konstruktion: Grundform ---
doc <- build_doc()
ns <- xml_ns(doc)
p <- get_caption_p(doc)
first_run <- xml_find_first(p, "./w:r", ns)
split <- oq_split_caption_text(xml_text(xml_find_first(first_run, "./w:t", ns)), 1)
if (!isTRUE(split$matched)) fail("Vorbereitung: oq_split_caption_text() sollte matchen")

converted <- oq_convert_caption_to_field(p, ns, first_run, split, "Table", list())
if (is.na(converted) || converted != "tbl-x") fail("erwartet Rueckgabe 'tbl-x', erhalten '%s'", converted)

p_runs <- xml_find_all(p, "./w:r | ./w:bookmarkStart | ./w:bookmarkEnd", ns)
if (length(p_runs) != 7) fail("erwartet 7 Kindknoten im Beschriftungsabsatz (Praefix, bookmarkStart, 3 Feld-Laeufe, bookmarkEnd, Rest), erhalten %d", length(p_runs))
if (!identical(xml_name(p_runs[[2]]), "bookmarkStart") || !identical(xml_name(p_runs[[6]]), "bookmarkEnd")) {
  fail("bookmarkStart/bookmarkEnd stehen nicht an der erwarteten Position")
}
instr_text <- xml_text(xml_find_first(p, ".//w:instrText", ns))
if (!identical(instr_text, "SEQ Table \\* Arabic")) fail("erwartet instrText 'SEQ Table \\\\* Arabic', erhalten '%s'", instr_text)
fld_chars <- xml_find_all(p, ".//w:fldChar", ns)
if (length(fld_chars) != 2) fail("erwartet genau 2 w:fldChar (begin/end), erhalten %d", length(fld_chars))
if (!all(xml_attr(fld_chars, "dirty") == "true")) fail("beide w:fldChar sollten w:dirty=\"true\" tragen")
if (!identical(xml_attr(fld_chars[[1]], "fldCharType"), "begin") || !identical(xml_attr(fld_chars[[2]], "fldCharType"), "end")) {
  fail("erwartet fldCharType begin dann end")
}
## alte, grosszuegig umspannende Bookmark-Paar-Knoten muessen aus der Zelle
## verschwunden sein (nur das neue, eng anliegende Paar bleibt, jetzt innerhalb
## des Beschriftungsabsatzes)
remaining_bookmarks <- xml_find_all(doc, "//w:bookmarkStart | //w:bookmarkEnd", ns)
if (length(remaining_bookmarks) != 2) fail("erwartet genau 2 Bookmark-Knoten im gesamten Dokument (nur das neue Paar), erhalten %d", length(remaining_bookmarks))
ok("SEQ-Feld wird korrekt aufgebaut (7 Knoten, instrText, 2 dirty fldChars, altes umspannendes Bookmark-Paar entfernt)")

## --- Bookmark-Name/-ID werden vom Original uebernommen ---
bm_start <- xml_find_first(doc, "//w:bookmarkStart", ns)
if (!identical(xml_attr(bm_start, "name"), "tbl-x")) fail("erwartet Bookmark-Name 'tbl-x', erhalten '%s'", xml_attr(bm_start, "name"))
if (!identical(xml_attr(bm_start, "id"), "7")) fail("erwartet wiederverwendete Bookmark-ID '7', erhalten '%s'", xml_attr(bm_start, "id"))
ok("Bookmark-Name und -ID werden vom entfernten Original uebernommen (repositioniert, nicht neu erfunden)")

## --- Abbildungs-Variante: seq_id = "Figure" ---
doc_fig <- build_doc("Figure 1: Mein Diagramm")
ns_fig <- xml_ns(doc_fig)
p_fig <- get_caption_p(doc_fig)
first_run_fig <- xml_find_first(p_fig, "./w:r", ns_fig)
split_fig <- oq_split_caption_text(xml_text(xml_find_first(first_run_fig, "./w:t", ns_fig)), 1)
invisible(oq_convert_caption_to_field(p_fig, ns_fig, first_run_fig, split_fig, "Figure", list()))
instr_fig <- xml_text(xml_find_first(p_fig, ".//w:instrText", ns_fig))
if (!identical(instr_fig, "SEQ Figure \\* Arabic")) fail("Abbildungs-Variante: erwartet 'SEQ Figure \\\\* Arabic', erhalten '%s'", instr_fig)
ok("Abbildungs-Variante verwendet 'SEQ Figure \\\\* Arabic'")

## --- number_bold: TRUE/FALSE/unset ---
test_bold <- function(number_bold, label) {
  d <- build_doc()
  n <- xml_ns(d)
  cp <- get_caption_p(d)
  fr <- xml_find_first(cp, "./w:r", n)
  sp <- oq_split_caption_text(xml_text(xml_find_first(fr, "./w:t", n)), 1)
  oq_convert_caption_to_field(cp, n, fr, sp, "Table", list(number_bold = number_bold))
  ## Praefix-Lauf + 3 Feld-Laeufe = die ersten 4 w:r-Kinder; der letzte w:r ist
  ## der Trenner+Rest-Lauf und darf NIE eine rPr bekommen (erbt vom Style).
  all_runs <- xml_find_all(cp, "./w:r", n)
  if (length(all_runs) != 5) fail("%s: erwartet 5 w:r-Kinder, erhalten %d", label, length(all_runs))
  prefix_and_field_runs <- all_runs[1:4]
  trailing_run <- all_runs[[5]]
  if (!is.na(xml_find_first(trailing_run, "./w:rPr", n))) fail("%s: der abschliessende Trenner+Rest-Lauf sollte keine rPr haben", label)
  if (is.null(number_bold)) {
    for (r in prefix_and_field_runs) {
      if (!is.na(xml_find_first(r, "./w:rPr/w:b", n))) fail("%s: bei number_bold=NULL sollte kein w:b vorkommen", label)
    }
  } else {
    expected <- if (isTRUE(number_bold)) "1" else "0"
    for (r in prefix_and_field_runs) {
      b <- xml_find_first(r, "./w:rPr/w:b", n)
      if (is.na(b)) fail("%s: erwartet w:b auf Praefix-/Feld-Lauf", label)
      if (!identical(xml_attr(b, "val"), expected)) fail("%s: erwartet w:b/@val='%s', erhalten '%s'", label, expected, xml_attr(b, "val"))
    }
  }
}
test_bold(TRUE, "number_bold=TRUE")
test_bold(FALSE, "number_bold=FALSE")
test_bold(NULL, "number_bold=NULL")
ok("number_bold wird korrekt auf Praefix- und alle 3 Feld-Laeufe angewendet (TRUE/FALSE/unset), niemals auf den Trenner+Rest-Lauf")

## --- Plain (nicht-crossref) Beschriftung: matched=FALSE -> No-op ---
doc_plain <- build_doc("Eine Beschriftung ganz ohne Zahl")
ns_plain <- xml_ns(doc_plain)
p_plain <- get_caption_p(doc_plain)
fr_plain <- xml_find_first(p_plain, "./w:r", ns_plain)
split_plain <- oq_split_caption_text(xml_text(xml_find_first(fr_plain, "./w:t", ns_plain)), 1)
if (isTRUE(split_plain$matched)) fail("Vorbereitung: erwartet matched=FALSE fuer eine Beschriftung ohne Zahl")
result <- oq_apply_captions(doc_plain, list(p_plain), list(auto_number = TRUE), seq_id = "Table")
if (result$n_field_converted != 0) fail("plain caption: erwartet 0 umgewandelte Felder, erhalten %d", result$n_field_converted)
if (length(xml_find_all(doc_plain, "//w:instrText", ns_plain)) != 0) fail("plain caption: es sollte kein SEQ-Feld erzeugt worden sein")
ok("oq_apply_captions() mit auto_number=TRUE laesst eine nicht-crossref-nummerierte Beschriftung (matched=FALSE) unangetastet")

## --- Beschriftung ohne Bookmark: oq_convert_caption_to_field() liefert NA ---
doc_no_bm <- read_xml(paste0(
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
  '<w:p><w:pPr><w:pStyle w:val="TableCaption"/></w:pPr><w:r><w:t xml:space="preserve">Table 1: Ohne Bookmark</w:t></w:r></w:p>',
  '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
  '</w:body></w:document>'
))
ns_no_bm <- xml_ns(doc_no_bm)
p_no_bm <- xml_find_first(doc_no_bm, "//w:p", ns_no_bm)
fr_no_bm <- xml_find_first(p_no_bm, "./w:r", ns_no_bm)
split_no_bm <- oq_split_caption_text(xml_text(xml_find_first(fr_no_bm, "./w:t", ns_no_bm)), 1)
converted_no_bm <- oq_convert_caption_to_field(p_no_bm, ns_no_bm, fr_no_bm, split_no_bm, "Table", list())
if (!is.na(converted_no_bm)) fail("erwartet NA_character_, wenn kein Bookmark existiert, erhalten '%s'", converted_no_bm)
if (length(xml_find_all(doc_no_bm, "//w:instrText", ns_no_bm)) != 0) fail("ohne Bookmark sollte kein Feld erzeugt worden sein")
ok("oq_convert_caption_to_field() no-opt (NA_character_), wenn kein Bookmark gefunden wird")

## --- REF-Feld: Grundform + Hyperlink-Style-Erhalt ---
ref_doc <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
ref_ns <- xml_ns(ref_doc)
n_ref <- oq_apply_crossref_fields(ref_doc, c("tbl-x"))
if (n_ref != 1) fail("REF-Feld: erwartet 1 umgewandelt, erhalten %d", n_ref)
ref_runs <- xml_find_all(ref_doc, "//w:hyperlink/w:r", ref_ns)
if (length(ref_runs) != 3) fail("REF-Feld: erwartet genau 3 Laeufe, erhalten %d", length(ref_runs))
for (r in ref_runs) {
  style <- xml_attr(xml_find_first(r, "./w:rPr/w:rStyle", ref_ns), "val")
  if (!identical(style, "Hyperlink")) fail("REF-Feld: erwartet w:rStyle='Hyperlink' auf jedem Feld-Lauf, erhalten '%s'", style)
}
instr_ref <- xml_text(xml_find_first(ref_doc, "//w:instrText", ref_ns))
if (!identical(instr_ref, " REF tbl-x \\h ")) fail("REF-Feld: erwartet instrText ' REF tbl-x \\\\h ', erhalten '%s'", instr_ref)
ref_flds <- xml_find_all(ref_doc, "//w:fldChar", ref_ns)
if (!all(xml_attr(ref_flds, "dirty") == "true")) fail("REF-Feld: beide w:fldChar sollten w:dirty=\"true\" tragen")
ok("oq_apply_crossref_fields() baut ein REF-Feld mit erhaltenem Hyperlink-rStyle auf allen 3 Laeufen auf")

## --- REF-Feld: unbekannter Anker bleibt unangetastet ---
ref_doc2 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-unbekannt"><w:r><w:t>Table 2</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n_ref2 <- oq_apply_crossref_fields(ref_doc2, c("tbl-x"))
if (n_ref2 != 0) fail("REF-Feld unbekannter Anker: erwartet 0 umgewandelt, erhalten %d", n_ref2)
if (xml_text(xml_find_first(ref_doc2, "//w:hyperlink", xml_ns(ref_doc2))) != "Table 2") fail("REF-Feld unbekannter Anker: Text haette unveraendert bleiben sollen")
ok("oq_apply_crossref_fields() laesst einen Hyperlink mit unbekanntem Anker unangetastet")

## --- REF-Feld: leere converted_anchors -> No-op ---
ref_doc3 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
n_ref3 <- oq_apply_crossref_fields(ref_doc3, character(0))
if (n_ref3 != 0) fail("REF-Feld leere converted_anchors: erwartet 0, erhalten %d", n_ref3)
ok("oq_apply_crossref_fields() mit leeren converted_anchors ist ein No-op")

cat("\nAlle Checks bestanden.\n")
