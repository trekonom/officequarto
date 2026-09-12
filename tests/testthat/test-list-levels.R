library(xml2)

test_that("oq_style_for_level() mit Laenge-1-Vektor liefert unabhaengig von der Ebene immer denselben Wert", {
  expect_identical(oq_style_for_level("A", 0L), "A")
  expect_identical(oq_style_for_level("A", 5L), "A")
})

test_that("oq_style_for_level() waehlt bei ausreichend langem Vektor exakt den Eintrag der jeweiligen Ebene", {
  styles3 <- c("L0", "L1", "L2")
  expect_identical(oq_style_for_level(styles3, 0L), "L0")
  expect_identical(oq_style_for_level(styles3, 1L), "L1")
  expect_identical(oq_style_for_level(styles3, 2L), "L2")
})

test_that("oq_style_for_level() clampt eine tiefere Verschachtelung auf den letzten konfigurierten Eintrag", {
  styles3 <- c("L0", "L1", "L2")
  expect_identical(oq_style_for_level(styles3, 5L), "L2")
})

test_that("oq_paragraph_ilvl() liest ein vorhandenes w:ilvl korrekt", {
  p_with_ilvl <- xml_find_first(
    read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="2"/></w:numPr></w:pPr></w:p></w:body></w:document>'),
    "//w:p"
  )
  expect_equal(oq_paragraph_ilvl(p_with_ilvl, xml_ns(xml_root(p_with_ilvl))), 2L)
})

test_that("oq_paragraph_ilvl() faellt bei fehlendem w:ilvl auf Ebene 0 zurueck", {
  p_without_ilvl <- xml_find_first(
    read_xml('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:numPr><w:numId w:val="1"/></w:numPr></w:pPr></w:p></w:body></w:document>'),
    "//w:p"
  )
  expect_equal(oq_paragraph_ilvl(p_without_ilvl, xml_ns(xml_root(p_without_ilvl))), 0L)
})

test_that("oq_resolve_style_ids() loest ein Array vollstaendig und reihenfolgetreu auf", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB", "Ziel C" = "ZielC")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  res <- oq_resolve_style_ids(name_to_id, c("Ziel B", "Ziel A", "Ziel C"), "test.key", fail_collect)
  expect_length(fails_seen, 0)
  expect_identical(res, c("ZielB", "ZielA", "ZielC"))
})

test_that("oq_resolve_style_ids() mit einem unbekannten Namen: genau 1 Fehler", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB", "Ziel C" = "ZielC")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  invisible(oq_resolve_style_ids(name_to_id, c("Ziel A", "Unbekannt"), "test.key", fail_collect))
  expect_length(fails_seen, 1)
})

test_that("oq_resolve_style_ids() mit leerem Array: genau 1 Fehler", {
  name_to_id <- c("Ziel A" = "ZielA", "Ziel B" = "ZielB", "Ziel C" = "ZielC")
  fails_seen <- character(0)
  fail_collect <- function(fmt, ...) fails_seen[[length(fails_seen) + 1]] <<- sprintf(fmt, ...)
  invisible(oq_resolve_style_ids(name_to_id, character(0), "test.key", fail_collect))
  expect_length(fails_seen, 1)
})

test_that("oq_apply_style_mapping() clampt eine tiefer verschachtelte Liste korrekt auf den letzten konfigurierten Style", {
  document_doc <- read_xml(paste0(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
    '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="0"/></w:numPr></w:pPr></w:p>',
    '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="1"/></w:numPr></w:pPr></w:p>',
    '<w:p><w:pPr><w:numPr><w:numId w:val="1"/><w:ilvl w:val="2"/></w:numPr></w:pPr></w:p>',
    '</w:body></w:document>'
  ))
  num_fmt_map <- c("1" = "bullet")
  style_ids <- list(list_bullet = c("BulletL0", "BulletL1"))
  result <- oq_apply_style_mapping(document_doc, num_fmt_map, style_ids, character(0))
  expect_equal(result$n_list, 3)
  expect_equal(result$n_list_clamped, 1)
  result_styles <- xml_attr(xml_find_all(document_doc, "//w:p/w:pPr/w:pStyle", xml_ns(document_doc)), "val")
  expect_identical(result_styles, c("BulletL0", "BulletL1", "BulletL1"))
})
