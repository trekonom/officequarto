library(xml2)

test_that("oq_apply_crossref_text(): a matching anchor is correctly replaced by the caption text", {
  doc <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
  n <- oq_apply_crossref_text(doc, c(`tbl-x` = "Meine Tabelle"))
  expect_equal(n, 1)
  result_text <- xml_text(xml_find_first(doc, "//w:hyperlink", xml_ns(doc)))
  expect_identical(result_text, "Meine Tabelle")
})

test_that("oq_apply_crossref_text(): a hyperlink with an unknown anchor stays untouched", {
  doc2 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-unbekannt"><w:r><w:t>Table 2</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
  n2 <- oq_apply_crossref_text(doc2, c(`tbl-x` = "Meine Tabelle"))
  expect_equal(n2, 0)
  result_text2 <- xml_text(xml_find_first(doc2, "//w:hyperlink", xml_ns(doc2)))
  expect_identical(result_text2, "Table 2")
})

test_that("oq_apply_crossref_text(): an empty anchor_text is a no-op", {
  doc3 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
  n3 <- oq_apply_crossref_text(doc3, character(0))
  expect_equal(n3, 0)
})

test_that("oq_apply_crossref_text(): a hyperlink with multiple runs - the first carries the replacement text, the rest are removed", {
  doc4 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="tbl-x"><w:r><w:t>Table</w:t></w:r><w:r><w:t xml:space="preserve"> 1</w:t></w:r></w:hyperlink></w:p></w:body></w:document>')
  n4 <- oq_apply_crossref_text(doc4, c(`tbl-x` = "Meine Tabelle"))
  expect_equal(n4, 1)
  runs4 <- xml_find_all(doc4, "//w:hyperlink/w:r", xml_ns(doc4))
  expect_length(runs4, 1)
  expect_identical(xml_text(runs4[[1]]), "Meine Tabelle")
})
