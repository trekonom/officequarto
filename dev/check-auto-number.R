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

## --- Regressionstest fuer einen echten, per Render gegen ../hello-wordto
## gefundenen Bug: eine crossref-nummerierte Beschriftung OHNE Wrapper-Zelle
## (Elternelement ist w:body, nicht w:tc) neben einem voellig unabhaengigen
## Ueberschriften-Bookmark im selben Elternelement. Vor dem Fix griff
## oq_find_caption_bookmark() faelschlich dieses fremde Bookmark, entfernte es
## und baute darunter ein SEQ-Feld auf - zerstoerte damit ein echtes,
## unabhaengiges Sprungziel. Der xml_name(parent) == "tc"-Guard muss das
## verhindern: kein Bookmark-Fund, kein entferntes fremdes Bookmark, kein
## erzeugtes Feld.
doc_foreign_bm <- read_xml(paste0(
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
  '<w:bookmarkStart w:id="24" w:name="ein-unabhaengiges-kapitel"/>',
  '<w:p><w:pPr><w:pStyle w:val="ImageCaption"/></w:pPr><w:r><w:t xml:space="preserve">Figure 1: Zufaellig danebenliegende Beschriftung</w:t></w:r></w:p>',
  '<w:bookmarkEnd w:id="24"/>',
  '</w:body></w:document>'
))
ns_foreign <- xml_ns(doc_foreign_bm)
p_foreign <- xml_find_first(doc_foreign_bm, "//w:p", ns_foreign)
fr_foreign <- xml_find_first(p_foreign, "./w:r", ns_foreign)
split_foreign <- oq_split_caption_text(xml_text(xml_find_first(fr_foreign, "./w:t", ns_foreign)), 1)
if (!isTRUE(split_foreign$matched)) fail("Vorbereitung: erwartet matched=TRUE (die Zahl 1 sollte gefunden werden)")
anchor_foreign <- oq_caption_anchor_name(p_foreign, ns_foreign)
if (!is.na(anchor_foreign)) fail("oq_caption_anchor_name() sollte NA liefern, wenn das Elternelement keine Wrapper-Zelle ist (erhalten: '%s')", anchor_foreign)
converted_foreign <- oq_convert_caption_to_field(p_foreign, ns_foreign, fr_foreign, split_foreign, "Figure", list())
if (!is.na(converted_foreign)) fail("oq_convert_caption_to_field() sollte NA_character_ liefern, nicht das fremde Bookmark stehlen (erhalten: '%s')", converted_foreign)
if (length(xml_find_all(doc_foreign_bm, "//w:instrText", ns_foreign)) != 0) fail("es sollte kein Feld erzeugt worden sein")
remaining_foreign_bm <- xml_find_first(doc_foreign_bm, "//w:bookmarkStart[@w:name='ein-unabhaengiges-kapitel']", ns_foreign)
if (is.na(remaining_foreign_bm)) fail("das fremde, unabhaengige Bookmark haette NICHT entfernt werden duerfen")
ok("oq_caption_anchor_name()/oq_convert_caption_to_field() ignorieren ein fremdes Bookmark ausserhalb einer Wrapper-Zelle, statt es zu stehlen/entfernen (Regressionstest, gefunden gegen ../hello-wordto)")

## --- Regressionstest fuer einen zweiten, verwandten echten Bug (ebenfalls
## per Realrender gegen ../hello-wordto gefunden): eine schlichte
## (Nicht-Crossref-)Beschriftung, die VOR einer crossref-nummerierten
## Beschriftung DERSELBEN Art im Dokument steht. Quarto nummeriert die
## schlichte Beschriftung ueberhaupt nicht mit - die urspruengliche
## Implementierung zaehlte aber JEDE gefundene Beschriftung (auch schlichte)
## in EINEM gemeinsamen Zaehler, sodass die crossref-nummerierte Beschriftung
## einen um 1 zu hohen erwarteten Zahlenwert bekam, oq_split_caption_text()
## faelschlich nicht matchte und die Beschriftung stillschweigend
## unangetastet blieb - bei JEDEM Feature (prefix/separator/number-bold,
## crossref.numbered: false, crossref.auto-number). Der Zaehler darf nur fuer
## tatsaechlich bookmark-markierte (= von Quarto wirklich nummerierte)
## Beschriftungen hochgezaehlt werden.
doc_mixed <- read_xml(paste0(
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
  '<w:p><w:pPr><w:pStyle w:val="TableCaption"/></w:pPr><w:r><w:t xml:space="preserve">Table 1 Caption</w:t></w:r></w:p>',
  '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
  '<w:tbl><w:tr><w:tc>',
  '<w:bookmarkStart w:id="48" w:name="tbl-crossref-check"/>',
  '<w:p><w:pPr><w:pStyle w:val="ImageCaption"/></w:pPr><w:r><w:t xml:space="preserve">Table 1: A crossref-numbered table</w:t></w:r></w:p>',
  '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
  '<w:bookmarkEnd w:id="48"/>',
  '</w:tc></w:tr></w:tbl>',
  '</w:body></w:document>'
))
ns_mixed <- xml_ns(doc_mixed)
mixed_captions <- xml_find_all(doc_mixed, "//w:p[w:pPr/w:pStyle/@w:val='TableCaption' or w:pPr/w:pStyle/@w:val='ImageCaption']", ns_mixed)
if (length(mixed_captions) != 2) fail("Vorbereitung: erwartet 2 gefundene Beschriftungen, erhalten %d", length(mixed_captions))
mixed_result <- oq_apply_captions(doc_mixed, mixed_captions, list(auto_number = TRUE), seq_id = "Table")
if (mixed_result$n_field_converted != 1) {
  fail("gemischte Beschriftungen: erwartet genau 1 in ein Feld umgewandelte Beschriftung (die crossref-nummerierte), erhalten %d", mixed_result$n_field_converted)
}
plain_text_after <- xml_text(mixed_captions[[1]])
if (!identical(plain_text_after, "Table 1 Caption")) fail("die schlichte Beschriftung haette unveraendert bleiben sollen, ist aber '%s'", plain_text_after)
if (length(xml_find_all(doc_mixed, "//w:bookmarkStart[@w:name='tbl-crossref-check']", ns_mixed)) != 1) {
  fail("die crossref-nummerierte Beschriftung haette korrekt in ein SEQ-Feld umgewandelt werden sollen")
}
ok("oq_apply_captions() zaehlt eine vorausgehende schlichte Beschriftung nicht mit - die nachfolgende crossref-nummerierte Beschriftung wird trotzdem korrekt erkannt (Regressionstest, gefunden gegen ../hello-wordto)")

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

## --- Fallback auf Text-Rewrite: auto_number=TRUE, die Beschriftung IST
## bookmarkiert (anchor_name loest auf, nimmt also am Zaehler/Parsing teil -
## siehe oben), aber oq_find_caption_bookmark() findet kein passendes
## w:bookmarkEnd zur @id (z.B. weil es fehlt) - oq_convert_caption_to_field()
## liefert NA_character_. oq_apply_captions() darf die Beschriftung dann
## NICHT unangetastet lassen, sondern muss auf denselben statischen
## Text-Rewrite zurueckfallen wie ohne auto_number (Regressionstest fuer den
## Review-Fund: vorher blieb die Beschriftung in diesem Fall stillschweigend
## Pandocs Rohtext).
doc_fallback <- read_xml(paste0(
  '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc>',
  '<w:bookmarkStart w:id="7" w:name="tbl-x"/>',
  '<w:p><w:pPr><w:pStyle w:val="ImageCaption"/></w:pPr><w:r><w:t xml:space="preserve">Table 1: Ohne Bookmark</w:t></w:r></w:p>',
  '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
  ## Kein w:bookmarkEnd mit @id="7" - oq_find_caption_bookmark() findet also
  ## kein passendes Ende und liefert NULL.
  '</w:tc></w:tr></w:tbl></w:body></w:document>'
))
ns_fallback <- xml_ns(doc_fallback)
fallback_captions <- xml_find_all(doc_fallback, "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption']", ns_fallback)
fallback_result <- oq_apply_captions(
  doc_fallback, fallback_captions,
  list(auto_number = TRUE, prefix = "Tab. ", separator = ": "),
  seq_id = "Table"
)
if (fallback_result$n_field_converted != 0) fail("erwartet 0 Feld-Umwandlungen ohne Bookmark, erhalten %d", fallback_result$n_field_converted)
if (fallback_result$n_text_rewritten != 1) fail("erwartet 1 Text-Rewrite als Fallback, erhalten %d", fallback_result$n_text_rewritten)
if (length(xml_find_all(doc_fallback, "//w:instrText", ns_fallback)) != 0) fail("Fallback sollte kein SEQ-Feld erzeugen")
fallback_text <- xml_text(fallback_captions[[1]])
if (!identical(fallback_text, "Tab. 1: Ohne Bookmark")) fail("erwartet 'Tab. 1: Ohne Bookmark' nach Fallback-Rewrite, erhalten '%s'", fallback_text)
ok("oq_apply_captions() faellt bei fehlgeschlagener Feld-Umwandlung (kein Bookmark) auf statischen Text-Rewrite zurueck, statt die Beschriftung unangetastet zu lassen (Review-Fund)")

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
