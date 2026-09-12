check_split <- function(text, expected_number, expected_title_prefix, expected_number_str, expected_sep, expected_rest, label) {
  res <- oq_split_caption_text(text, expected_number)
  expect_true(isTRUE(res$matched), label = label)
  expect_identical(res$title_prefix, expected_title_prefix, label = label)
  expect_identical(res$number, expected_number_str, label = label)
  expect_identical(res$generated_sep, expected_sep, label = label)
  expect_identical(res$rest, expected_rest, label = label)
}

test_that("oq_split_caption_text(): simple default case (Pandoc default format)", {
  check_split("Table 1: My table caption", 1, "Table ", "1", ": ", "My table caption", "simple default case (Pandoc default format)")
})

test_that("oq_split_caption_text(): typographically converted separator (en dash, NBSP)", {
  ## Smart-typography-converted separator (en dash instead of "--") plus a
  ## non-breaking space before the number - see dev/spike-notes.md.
  check_split("Tabelle 1– My table caption", 1, "Tabelle ", "1", "– ", "My table caption", "typographically converted separator (en dash, NBSP)")
})

test_that("oq_split_caption_text(): two-digit number (edge case for word-boundary anchoring)", {
  check_split("Table 10: Tenth table", 10, "Table ", "10", ": ", "Tenth table", "two-digit number (edge case for word-boundary anchoring)")
})

test_that("oq_split_caption_text(): a number within the caption text itself is not falsely matched", {
  ## The sought number (1) must not be falsely matched inside another number
  ## within the caption text itself (1990).
  check_split("Table 1: Comparing 1990 and 2000", 1, "Table ", "1", ": ", "Comparing 1990 and 2000", "a number within the caption text itself is not falsely matched")
})

test_that("oq_split_caption_text(): no match expected (number not present in the text)", {
  ## The expected number doesn't occur in the text in anchorable form at all
  ## (e.g. a different format) - matched=FALSE, so the caller leaves the text
  ## unchanged instead of guessing something wrong.
  res_no_match <- oq_split_caption_text("Some caption without any number", 1)
  expect_false(isTRUE(res_no_match$matched))
})

test_that("Issue #3 (regression test): plain (non-crossref) caption with a digit in its text that happens to match stays untouched despite configured prefix/separator", {
  ## Regression test for GH issue #3 ("Caption digit-anchoring false positive
  ## on plain (non-crossref) captions"): a plain caption without a crossref
  ## ID has NO Pandoc wrapper cell (parent is w:body, not w:tc) and isn't
  ## numbered by Quarto at all. Its own, user-authored text could
  ## accidentally contain a digit that matches officequarto's internally
  ## tracked running caption count - that was the risk described in the
  ## issue of a falsely anchored split, once prefix/separator/number-bold
  ## are configured.
  ##
  ## Now already (as a side effect of the Spike Q counter fix for
  ## officequarto.crossref.auto-number, see oq_apply_captions() in
  ## table-caption-mapping.R) structurally excluded: oq_apply_captions()
  ## only ever calls oq_split_caption_text() when oq_caption_anchor_name()
  ## resolves a real bookmark - and that is empirically only ever true for a
  ## genuine, wrapper-cell crossref-numbered caption (see CLAUDE.md/Spike
  ## Q). A plain caption is therefore skipped entirely before any parsing is
  ## even attempted - regardless of which digits its text contains. This
  ## test checks that end-to-end via oq_apply_captions() (not just
  ## oq_split_caption_text() in isolation like above), since exactly this
  ## gate logic sits in oq_apply_captions() itself.
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
