w_ns <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
mk <- function(body) xml2::read_xml(sprintf('<w:document xmlns:w="%s"><w:body>%s</w:body></w:document>', w_ns, body))
cap <- function(txt, st = "ImageCaption") sprintf('<w:p><w:pPr><w:pStyle w:val="%s"/></w:pPr><w:r><w:t>%s</w:t></w:r></w:p>', st, txt)
wrap <- function(inner) sprintf('<w:tbl><w:tblPr/><w:tr><w:tc>%s</w:tc></w:tr></w:tbl>', inner)
inner_tbl <- '<w:tbl><w:tblPr/><w:tr><w:tc><w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc><w:tc><w:p/></w:tc></w:tr></w:tbl>'
body_names <- function(doc) xml2::xml_name(xml2::xml_children(xml2::xml_find_first(doc, "//w:body")))

test_that("table float is unwrapped, empty trailing paragraph dropped, keepNext set", {
  doc <- mk(paste0(wrap(paste0('<w:bookmarkStart w:id="1" w:name="tbl-a"/>', cap("Table 1: A"), inner_tbl, '<w:p/><w:bookmarkEnd w:id="1"/>')),
                   '<w:p><w:r><w:t>after</w:t></w:r></w:p>'))
  wr <- oq_find_caption_wrappers(doc)
  expect_length(wr, 1)
  expect_equal(oq_unwrap_caption_tables(doc, wr), 1L)
  expect_equal(body_names(doc), c("bookmarkStart", "p", "tbl", "bookmarkEnd", "p"))
  expect_length(xml2::xml_find_all(doc, "//w:body/w:p/w:pPr/w:keepNext", xml2::xml_ns(doc)), 0)
})

test_that("figure float is unwrapped and image paragraph gets keepNext", {
  doc <- mk(wrap(paste0('<w:p><w:pPr><w:pStyle w:val="Figure"/></w:pPr><w:r><w:drawing/></w:r></w:p>', cap("Figure 1: B"))))
  wr <- oq_find_caption_wrappers(doc)
  oq_unwrap_caption_tables(doc, wr)
  expect_equal(body_names(doc), c("p", "p"))
  ns <- xml2::xml_ns(doc)
  expect_length(xml2::xml_find_all(doc, "//w:body/w:p[1]/w:pPr[w:pStyle/following-sibling::w:keepNext]", ns), 1)
})

test_that("wrapper detection happens before restyle; handles survive remapping", {
  doc <- mk(wrap(paste0(cap("Table 1: A"), inner_tbl, '<w:p/>')))
  wr <- oq_find_caption_wrappers(doc)
  ns <- xml2::xml_ns(doc)
  ps <- xml2::xml_find_first(doc, "//w:pStyle", ns)
  xml2::xml_attr(ps, "w:val") <- "Mine"
  expect_length(oq_find_caption_wrappers(doc), 0)
  expect_equal(oq_unwrap_caption_tables(doc, wr), 1L)
  expect_equal(body_names(doc), c("p", "tbl"))
})

test_that("empty paragraph is kept when the next sibling is a table; callout-like tables untouched", {
  callout <- wrap('<w:p><w:pPr><w:pStyle w:val="Figure"/></w:pPr></w:p><w:p><w:r><w:t>Note</w:t></w:r></w:p>')
  doc <- mk(paste0(wrap(paste0(cap("Table 1: A"), inner_tbl, '<w:p/>')), inner_tbl, callout))
  wr <- oq_find_caption_wrappers(doc)
  expect_length(wr, 1)
  oq_unwrap_caption_tables(doc, wr)
  expect_equal(body_names(doc), c("p", "tbl", "p", "tbl", "tbl"))
})

test_that("no wrappers is a no-op", {
  doc <- mk(cap("x", "Normal"))
  expect_equal(oq_unwrap_caption_tables(doc, oq_find_caption_wrappers(doc)), 0L)
})
