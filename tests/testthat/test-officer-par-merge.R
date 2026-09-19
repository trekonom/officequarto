library(xml2)

W_NS <- 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'

test_that("oq_merge_misplaced_ppr(): a misplaced pPr is merged into the paragraph's real first pPr and removed", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:val="Corpsdetexte"/></w:pPr><w:r><w:t>a</w:t></w:r><w:pPr><w:jc w:val="center"/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:pBdr></w:pPr><w:r><w:t>b</w:t></w:r></w:p></w:body></w:document>',
    W_NS
  ))
  n <- oq_merge_misplaced_ppr(doc)
  expect_equal(n, 1)

  ns <- xml_ns(doc)
  ppr_nodes <- xml_find_all(doc, "//w:p/w:pPr", ns)
  expect_length(ppr_nodes, 1)
  expect_identical(xml_attr(xml_find_first(ppr_nodes, "./w:pStyle", ns), "val"), "Corpsdetexte")
  expect_identical(xml_attr(xml_find_first(ppr_nodes, "./w:jc", ns), "val"), "center")
  expect_false(is.na(xml_find_first(ppr_nodes, "./w:pBdr", ns)))
})

test_that("oq_merge_misplaced_ppr(): a malformed pStyle (no w:val, officer's fp_par() bug) is never merged in", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:val="Corpsdetexte"/></w:pPr><w:r><w:t>a</w:t></w:r><w:pPr><w:pStyle w:pstlname="Normal"/><w:jc w:val="center"/></w:pPr></w:p></w:body></w:document>',
    W_NS
  ))
  oq_merge_misplaced_ppr(doc)

  ns <- xml_ns(doc)
  pstyle <- xml_find_first(doc, "//w:p/w:pPr/w:pStyle", ns)
  expect_identical(xml_attr(pstyle, "val"), "Corpsdetexte")
})

test_that("oq_merge_misplaced_ppr(): a well-formed pStyle (real w:val) in the misplaced pPr IS merged in", {
  ## Mirrors Pandoc's own native caption-wrapper-cell paragraphs (see
  ## table-caption-mapping.R): a first pPr with no pStyle, a second,
  ## misplaced pPr carrying the real pStyle - unrelated to officer's fp_par()
  ## bug, and must not be treated the same way (regression test: an earlier
  ## version of this function excluded ALL pStyle merging by name alone,
  ## which broke table/figure caption detection - see report.qmd/
  ## dev/check-writeback.R).
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>a</w:t></w:r><w:pPr><w:jc w:val="left"/><w:pStyle w:val="ImageCaption"/></w:pPr></w:p></w:body></w:document>',
    W_NS
  ))
  oq_merge_misplaced_ppr(doc)

  ns <- xml_ns(doc)
  ppr_nodes <- xml_find_all(doc, "//w:p/w:pPr", ns)
  expect_length(ppr_nodes, 1)
  expect_identical(xml_attr(xml_find_first(ppr_nodes, "./w:pStyle", ns), "val"), "ImageCaption")
  expect_identical(xml_attr(xml_find_first(ppr_nodes, "./w:jc", ns), "val"), "left")
})

test_that("oq_merge_misplaced_ppr(): a matching child in the real pPr is replaced, not duplicated", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:jc w:val="left"/></w:pPr><w:r><w:t>a</w:t></w:r><w:pPr><w:jc w:val="right"/></w:pPr></w:p></w:body></w:document>',
    W_NS
  ))
  oq_merge_misplaced_ppr(doc)

  ns <- xml_ns(doc)
  jc_nodes <- xml_find_all(doc, "//w:p/w:pPr/w:jc", ns)
  expect_length(jc_nodes, 1)
  expect_identical(xml_attr(jc_nodes[[1]], "val"), "right")
})

test_that("oq_merge_misplaced_ppr(): a paragraph with no pPr at all gets the misplaced one promoted to first child", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:r><w:t>a</w:t></w:r><w:pPr><w:jc w:val="center"/></w:pPr></w:p></w:body></w:document>',
    W_NS
  ))
  n <- oq_merge_misplaced_ppr(doc)
  expect_equal(n, 1)

  ns <- xml_ns(doc)
  p <- xml_find_first(doc, "//w:p", ns)
  expect_identical(xml_name(xml_child(p, 1)), "pPr")
  expect_identical(xml_attr(xml_find_first(p, "./w:pPr/w:jc", ns), "val"), "center")
})

test_that("oq_merge_misplaced_ppr(): a paragraph with a correctly-placed single pPr is a no-op", {
  doc <- read_xml(sprintf(
    '<w:document %s><w:body><w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>',
    W_NS
  ))
  n <- oq_merge_misplaced_ppr(doc)
  expect_equal(n, 0)
})
