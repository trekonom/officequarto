library(xml2)

W_NS <- 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'

styles_doc <- function() {
  read_xml(sprintf(
    '<w:styles %s>
       <w:style w:type="paragraph" w:styleId="Corpsdetexte"><w:name w:val="Body Text"/></w:style>
       <w:style w:type="table" w:styleId="tabletemplate"><w:name w:val="table_template"/></w:style>
     </w:styles>', W_NS))
}

test_that("oq_resolve_style_name_markers(): pstlname/tstlname display names become w:val styleIds", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:tbl><w:tblPr><w:tblStyle w:tstlname="table_template"/></w:tblPr></w:tbl><w:p><w:pPr><w:pStyle w:pstlname="Body Text"/></w:pPr></w:p></w:body></w:document>',
    W_NS))
  res <- oq_resolve_style_name_markers(doc, styles_doc())
  expect_equal(res$resolved, 2L)
  expect_length(res$unresolved, 0)

  ns <- xml_ns(doc)
  expect_identical(xml_attr(xml_find_first(doc, "//w:tblStyle", ns), "val"), "tabletemplate")
  expect_identical(xml_attr(xml_find_first(doc, "//w:pStyle", ns), "val"), "Corpsdetexte")
  expect_true(is.na(xml_attr(xml_find_first(doc, "//w:tblStyle", ns), "tstlname")))
  expect_true(is.na(xml_attr(xml_find_first(doc, "//w:pStyle", ns), "pstlname")))
})

test_that("oq_resolve_style_name_markers(): name match falls back to case-insensitive", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:pstlname="body text"/></w:pPr></w:p></w:body></w:document>', W_NS))
  res <- oq_resolve_style_name_markers(doc, styles_doc())
  expect_equal(res$resolved, 1L)
  expect_identical(xml_attr(xml_find_first(doc, "//w:pStyle", xml_ns(doc)), "val"), "Corpsdetexte")
})

test_that("oq_resolve_style_name_markers(): an unknown name is reported and the invalid element removed", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:pstlname="Nope"/></w:pPr></w:p></w:body></w:document>', W_NS))
  res <- oq_resolve_style_name_markers(doc, styles_doc())
  expect_equal(res$resolved, 0L)
  expect_identical(res$unresolved, "Nope")
  expect_length(xml_find_all(doc, "//w:pStyle", xml_ns(doc)), 0)
})

test_that("oq_resolve_style_name_markers(): a document without markers is untouched", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:val="Corpsdetexte"/></w:pPr></w:p></w:body></w:document>', W_NS))
  res <- oq_resolve_style_name_markers(doc, styles_doc())
  expect_equal(res$resolved, 0L)
  expect_identical(xml_attr(xml_find_first(doc, "//w:pStyle", xml_ns(doc)), "val"), "Corpsdetexte")
})

test_that("a resolved fp_par() pStyle is merged by oq_merge_misplaced_ppr() (marker resolution runs first)", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:t>a</w:t></w:r><w:pPr><w:pStyle w:pstlname="Body Text"/></w:pPr></w:p></w:body></w:document>', W_NS))
  oq_resolve_style_name_markers(doc, styles_doc())
  oq_merge_misplaced_ppr(doc)
  ns <- xml_ns(doc)
  expect_length(xml_find_all(doc, "//w:p/w:pPr", ns), 1)
  expect_identical(xml_attr(xml_find_first(doc, "//w:p/w:pPr/w:pStyle", ns), "val"), "Corpsdetexte")
})
