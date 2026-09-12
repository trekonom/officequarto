library(xml2)

## Synthetisches word/footnotes.xml: id=-1 (separator), id=0
## (continuationSeparator) - beide ohne eigenes w:pStyle (Default "Normal",
## wie in einem echten Word-Dokument ueblich) - plus id=1, eine "echte"
## Fussnote mit dem uebergebenen Absatz-Markup.
make_footnotes_doc <- function(real_footnote_p) {
  read_xml(paste0(
    '<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>',
    '<w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>',
    '<w:footnote w:id="1">', real_footnote_p, '</w:footnote>',
    '</w:footnotes>'
  ))
}

footnote_xpath <- oq_note_paragraph_xpath("footnote")

test_that("oq_note_paragraph_xpath('footnote') schliesst separator/continuationSeparator-Absaetze aus", {
  doc1 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  selected <- xml_find_all(doc1, footnote_xpath, xml_ns(doc1))
  expect_length(selected, 1)
})

test_that("officequarto.styles.body wird auf Fussnoten-Absaetze nicht angewendet (Body-Role-Allowlist greift dort strukturell nie)", {
  ## oq_apply_style_mapping() gegen footnotes.xml: Body-Role-Allowlist greift
  ## NIE (weder fuer die pStyle-losen (Default "Normal") separator-Absaetze
  ## noch fuer "FootnoteText") - selbst wenn officequarto.styles.body
  ## konfiguriert ist.
  doc2 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  style_ids <- list(body = "FliesstextACME")
  result2 <- oq_apply_style_mapping(doc2, character(0), style_ids, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result2$n_body, 0)
  pstyles2 <- xml_attr(xml_find_all(doc2, "//w:p/w:pPr/w:pStyle", xml_ns(doc2)), "val")
  expect_false("FliesstextACME" %in% pstyles2)
})

test_that("oq_apply_style_mapping() erkennt und mappt einen Listen-Absatz innerhalb einer Fussnote (officequarto.lists.*)", {
  ## oq_apply_style_mapping(): Listen-Absatz INNERHALB einer Fussnote wird
  ## trotzdem erkannt (numPr-basiert, unabhaengig vom pStyle-Kontext).
  doc3 <- make_footnotes_doc(paste0(
    '<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Vor der Liste</w:t></w:r></w:p>',
    '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="0"/></w:numPr></w:pPr></w:p>'
  ))
  num_fmt_map3 <- c("1" = "bullet")
  style_ids3 <- list(list_bullet = "AufzaehlungACME")
  result3 <- oq_apply_style_mapping(doc3, num_fmt_map3, style_ids3, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result3$n_list, 1)
})

test_that("oq_apply_style_mapping() erkennt und mappt einen Codeblock-Absatz innerhalb einer Fussnote (officequarto.pandoc-styles.code-block)", {
  ## oq_apply_style_mapping(): SourceCode-Absatz innerhalb einer Fussnote wird
  ## trotzdem erkannt (feste Style-ID, direkter Gleichheitscheck).
  doc4 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="SourceCode"/></w:pPr><w:r><w:t>code()</w:t></w:r></w:p>')
  style_ids4 <- list(code = "CodeACME")
  result4 <- oq_apply_style_mapping(doc4, character(0), style_ids4, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result4$n_code, 1)
})

test_that("officequarto.style-map leitet Pandocs feste FootnoteText-Fallback-ID auf einen eigenen Style um", {
  ## oq_apply_style_map(): FootnoteText (Pandocs feste Fallback-ID) laesst
  ## sich wie jede andere Quell-Style-ID ueber officequarto.style-map
  ## umleiten - das ist der eigentliche Loesungsweg fuer Issue #2, keine
  ## eigene Konfigurationsoption.
  doc5 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  n5 <- oq_apply_style_map(doc5, c(FootnoteText = "MeineFussnoteACME"), footnote_xpath)
  expect_equal(n5, 1)
  pstyles5 <- xml_attr(xml_find_all(doc5, "//w:p/w:pPr/w:pStyle", xml_ns(doc5)), "val")
  expect_true("MeineFussnoteACME" %in% pstyles5)
})

test_that("officequarto.style-map trifft dank oq_note_paragraph_xpath() nicht versehentlich den pStyle-losen separator-Absatz einer Fussnote", {
  ## oq_apply_style_map(): eine Regel "Normal" -> X (z.B. um pStyle-lose
  ## Body-Absaetze in document.xml zu treffen) darf NICHT versehentlich den
  ## pStyle-losen separator-Absatz einer Fussnote miterfassen.
  doc6 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  n6 <- oq_apply_style_map(doc6, c(Normal = "FliesstextACME"), footnote_xpath)
  expect_equal(n6, 0)
})

test_that("officequarto.style-map leitet Pandocs feste EndnoteText-Fallback-ID um (Endnote-Seite, analog zu Fussnoten)", {
  ## Endnote-Seite: derselbe Mechanismus, container="endnote" statt
  ## "footnote" (nur ein Stichprobentest, keine vollstaendige Duplikation der
  ## obigen Faelle - die Logik ist container-agnostisch).
  endnote_xpath <- oq_note_paragraph_xpath("endnote")
  endnote_doc <- read_xml(paste0(
    '<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    '<w:endnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:endnote>',
    '<w:endnote w:id="1"><w:p><w:pPr><w:pStyle w:val="EndnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p></w:endnote>',
    '</w:endnotes>'
  ))
  n_en <- oq_apply_style_map(endnote_doc, c(EndnoteText = "MeineEndnoteACME"), endnote_xpath)
  expect_equal(n_en, 1)
})
