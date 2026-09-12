check_split <- function(text, expected_number, expected_title_prefix, expected_number_str, expected_sep, expected_rest, label) {
  res <- oq_split_caption_text(text, expected_number)
  expect_true(isTRUE(res$matched), label = label)
  expect_identical(res$title_prefix, expected_title_prefix, label = label)
  expect_identical(res$number, expected_number_str, label = label)
  expect_identical(res$generated_sep, expected_sep, label = label)
  expect_identical(res$rest, expected_rest, label = label)
}

test_that("oq_split_caption_text(): einfacher Standardfall (Pandoc-Default-Format)", {
  check_split("Table 1: My table caption", 1, "Table ", "1", ": ", "My table caption", "einfacher Standardfall (Pandoc-Default-Format)")
})

test_that("oq_split_caption_text(): typographisch konvertierter Trenner (Halbgeviertstrich, NBSP)", {
  ## Smart-Typography-konvertierter Trenner (Halbgeviertstrich statt "--")
  ## plus nicht-brechendes Leerzeichen vor der Zahl - siehe dev/spike-notes.md.
  check_split("Tabelle 1– My table caption", 1, "Tabelle ", "1", "– ", "My table caption", "typographisch konvertierter Trenner (Halbgeviertstrich, NBSP)")
})

test_that("oq_split_caption_text(): zweistellige Zahl (Grenzfall fuer Wortgrenzen-Verankerung)", {
  check_split("Table 10: Tenth table", 10, "Table ", "10", ": ", "Tenth table", "zweistellige Zahl (Grenzfall fuer Wortgrenzen-Verankerung)")
})

test_that("oq_split_caption_text(): Zahl im Beschriftungstext selbst wird nicht faelschlich getroffen", {
  ## Die gesuchte Zahl (1) darf nicht faelschlich innerhalb einer anderen Zahl
  ## im Beschriftungstext selbst (1990) getroffen werden.
  check_split("Table 1: Comparing 1990 and 2000", 1, "Table ", "1", ": ", "Comparing 1990 and 2000", "Zahl im Beschriftungstext selbst wird nicht faelschlich getroffen")
})

test_that("oq_split_caption_text(): kein Treffer erwartet (Zahl nicht im Text)", {
  ## Erwartete Zahl kommt im Text gar nicht in verankerbarer Form vor (z.B.
  ## abweichendes Format) - matched=FALSE, damit der Aufrufer den Text
  ## unveraendert laesst statt etwas Falsches zu raten.
  res_no_match <- oq_split_caption_text("Some caption without any number", 1)
  expect_false(isTRUE(res_no_match$matched))
})

test_that("Issue #3 (Regressionstest): schlichte (nicht-crossref) Beschriftung mit zufaellig passender Ziffer im Text bleibt trotz konfiguriertem prefix/separator unangetastet", {
  ## Regressionstest fuer GH-Issue #3 ("Caption digit-anchoring false positive
  ## on plain (non-crossref) captions"): eine schlichte Beschriftung ohne
  ## Crossref-ID hat KEINE Pandoc-Wrapper-Zelle (Elternelement ist w:body,
  ## nicht w:tc) und wird von Quarto ueberhaupt nicht nummeriert. Ihr eigener,
  ## vom Nutzer verfasster Text koennte zufaellig eine Ziffer enthalten, die
  ## mit officequartos intern mitgezaehlter laufender Beschriftungsnummer
  ## uebereinstimmt - das war das im Issue beschriebene Risiko eines
  ## faelschlich verankerten Splits, sobald prefix/separator/number-bold
  ## konfiguriert sind.
  ##
  ## Inzwischen bereits (als Nebeneffekt des Spike-Q-Zaehler-Fixes fuer
  ## officequarto.crossref.auto-number, siehe oq_apply_captions() in
  ## table-caption-mapping.R) strukturell ausgeschlossen: oq_apply_captions()
  ## ruft oq_split_caption_text() ueberhaupt nur auf, wenn
  ## oq_caption_anchor_name() ein echtes Bookmark auflöst - und das ist
  ## empirisch nur fuer eine echte, per Wrapper-Zelle crossref-nummerierte
  ## Beschriftung der Fall (siehe CLAUDE.md/Spike Q). Eine schlichte
  ## Beschriftung wird deshalb komplett uebersprungen, bevor ueberhaupt geparst
  ## wird - unabhaengig davon, welche Ziffern ihr Text enthaelt. Dieser Test
  ## prueft das end-to-end ueber oq_apply_captions() (nicht nur
  ## oq_split_caption_text() isoliert wie oben), da genau diese Gate-Logik in
  ## oq_apply_captions() selbst sitzt.
  doc_issue3 <- xml2::read_xml(paste0(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
    '<w:p><w:pPr><w:pStyle w:val="TableCaption"/></w:pPr><w:r><w:t xml:space="preserve">Sales grew 1 percent in 2020</w:t></w:r></w:p>',
    '<w:tbl><w:tr><w:tc><w:p/></w:tc></w:tr></w:tbl>',
    '</w:body></w:document>'
  ))
  ns_issue3 <- xml2::xml_ns(doc_issue3)
  captions_issue3 <- xml2::xml_find_all(doc_issue3, "//w:p[w:pPr/w:pStyle/@w:val='TableCaption']", ns_issue3)
  result_issue3 <- oq_apply_captions(doc_issue3, captions_issue3, list(prefix = "Tab. ", separator = ": "))
  expect_equal(result_issue3$n_text_rewritten, 0)
  text_after_issue3 <- xml2::xml_text(captions_issue3[[1]])
  expect_identical(text_after_issue3, "Sales grew 1 percent in 2020")
})
