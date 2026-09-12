library(xml2)

test_that("oq_resolve_style_map(): a target with multiple sources resolves correctly", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_style_map(list(`Ziel A` = c("Normal", "Compact")), name_to_id, fail_collect)
  expect_length(fails_seen, 0)
  expect_identical(unname(res["Normal"]), "ZielA")
  expect_identical(unname(res["Compact"]), "ZielA")
})

test_that("oq_resolve_style_map(): multiple targets with disjoint sources resolve correctly", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_style_map(list(`Ziel A` = c("Normal"), `Ziel B` = c("Heading1")), name_to_id, fail_collect)
  expect_length(fails_seen, 0)
  expect_identical(unname(res["Normal"]), "ZielA")
  expect_identical(unname(res["Heading1"]), "ZielB")
})

test_that("oq_resolve_style_map(): the same source assigned to two targets yields exactly 1 error", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  invisible(oq_resolve_style_map(list(`Ziel A` = c("Normal"), `Ziel B` = c("Normal")), name_to_id, fail_collect))
  expect_length(fails_seen, 1)
})

test_that("oq_resolve_style_map(): an unknown target style name yields exactly 1 error", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  invisible(oq_resolve_style_map(list(`Unbekanntes Ziel` = c("Normal")), name_to_id, fail_collect))
  expect_length(fails_seen, 1)
})

test_that("oq_apply_style_map() with an empty mapping is a no-op", {
  doc <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr></w:p></w:body></w:document>')
  n <- oq_apply_style_map(doc, character(0))
  expect_equal(n, 0)
})

test_that("oq_apply_style_map() remaps the matching paragraph and leaves the rest untouched", {
  doc2 <- read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr></w:p><w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr></w:p></w:body></w:document>')
  n2 <- oq_apply_style_map(doc2, c(Title = "TitelACME"))
  expect_equal(n2, 1)
  result_styles <- xml_attr(xml_find_all(doc2, "//w:p/w:pPr/w:pStyle", xml_ns(doc2)), "val")
  expect_identical(sort(result_styles), sort(c("Normal", "TitelACME")))
})
