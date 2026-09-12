library(xml2)

## Synthetic word/footnotes.xml: id=-1 (separator), id=0
## (continuationSeparator) - both without their own w:pStyle (defaulting to
## "Normal", as usual in a real Word document) - plus id=1, a "real"
## footnote with the passed-in paragraph markup.
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

test_that("oq_note_paragraph_xpath('footnote') excludes separator/continuationSeparator paragraphs", {
  doc1 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  selected <- xml_find_all(doc1, footnote_xpath, xml_ns(doc1))
  expect_length(selected, 1)
})

test_that("officequarto.styles.body is not applied to footnote paragraphs (the body-role allowlist structurally never fires there)", {
  ## oq_apply_style_mapping() against footnotes.xml: the body-role allowlist
  ## NEVER fires (neither for the pStyle-less (default "Normal") separator
  ## paragraphs nor for "FootnoteText") - even when officequarto.styles.body
  ## is configured.
  doc2 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  style_ids <- list(body = "FliesstextACME")
  result2 <- oq_apply_style_mapping(doc2, character(0), style_ids, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result2$n_body, 0)
  pstyles2 <- xml_attr(xml_find_all(doc2, "//w:p/w:pPr/w:pStyle", xml_ns(doc2)), "val")
  expect_false("FliesstextACME" %in% pstyles2)
})

test_that("oq_apply_style_mapping() detects and maps a list paragraph inside a footnote (officequarto.lists.*)", {
  ## oq_apply_style_mapping(): a list paragraph INSIDE a footnote is still
  ## detected (numPr-based, independent of pStyle context).
  doc3 <- make_footnotes_doc(paste0(
    '<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Vor der Liste</w:t></w:r></w:p>',
    '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="0"/></w:numPr></w:pPr></w:p>'
  ))
  num_fmt_map3 <- c("1" = "bullet")
  style_ids3 <- list(list_bullet = "AufzaehlungACME")
  result3 <- oq_apply_style_mapping(doc3, num_fmt_map3, style_ids3, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result3$n_list, 1)
})

test_that("oq_apply_style_mapping() detects and maps a code-block paragraph inside a footnote (officequarto.pandoc-styles.code-block)", {
  ## oq_apply_style_mapping(): a SourceCode paragraph INSIDE a footnote is
  ## still detected (a fixed style ID, direct equality check).
  doc4 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="SourceCode"/></w:pPr><w:r><w:t>code()</w:t></w:r></w:p>')
  style_ids4 <- list(code = "CodeACME")
  result4 <- oq_apply_style_mapping(doc4, character(0), style_ids4, character(0), paragraph_xpath = footnote_xpath)
  expect_equal(result4$n_code, 1)
})

test_that("officequarto.style-map redirects Pandoc's fixed FootnoteText fallback ID to a custom style", {
  ## oq_apply_style_map(): FootnoteText (Pandoc's fixed fallback ID) can be
  ## redirected via officequarto.style-map just like any other source style
  ## ID - that's the actual solution for issue #2, not a dedicated
  ## configuration option.
  doc5 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  n5 <- oq_apply_style_map(doc5, c(FootnoteText = "MeineFussnoteACME"), footnote_xpath)
  expect_equal(n5, 1)
  pstyles5 <- xml_attr(xml_find_all(doc5, "//w:p/w:pPr/w:pStyle", xml_ns(doc5)), "val")
  expect_true("MeineFussnoteACME" %in% pstyles5)
})

test_that("officequarto.style-map, thanks to oq_note_paragraph_xpath(), doesn't accidentally hit a footnote's pStyle-less separator paragraph", {
  ## oq_apply_style_map(): a rule "Normal" -> X (e.g. to hit pStyle-less body
  ## paragraphs in document.xml) must NOT accidentally also catch a
  ## footnote's pStyle-less separator paragraph.
  doc6 <- make_footnotes_doc('<w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr><w:r><w:t>Text</w:t></w:r></w:p>')
  n6 <- oq_apply_style_map(doc6, c(Normal = "FliesstextACME"), footnote_xpath)
  expect_equal(n6, 0)
})

test_that("officequarto.style-map redirects Pandoc's fixed EndnoteText fallback ID (endnote side, analogous to footnotes)", {
  ## Endnote side: the same mechanism, container="endnote" instead of
  ## "footnote" (just a spot check, not a full duplication of the cases
  ## above - the logic is container-agnostic).
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
