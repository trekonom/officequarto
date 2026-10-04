## End-to-end check for the BLOCK_* comment markers contributed by the
## extension (inst/_extensions/officequarto/scripts/markers.lua). Expects that
## `quarto render report.qmd` has already run in dev/fixtures/block-markers/:
##   cd dev/fixtures/block-markers && quarto render report.qmd
##   Rscript ../../check-block-markers-e2e.R
library(xml2)

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "report.docx"
if (!file.exists(target)) fail("%s was not created", target)
tmp <- tempfile("check_block_markers_e2e_")
dir.create(tmp)
utils::unzip(target, exdir = tmp)
doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns <- xml_ns(doc)

n_toc <- length(xml_find_all(doc, "//w:instrText[contains(., 'TOC ')]", ns))
if (n_toc != 1) fail("expected 1 TOC field, found %d", n_toc)
ok("one TOC field")

n_br <- length(xml_find_all(doc, "//w:br[@w:type='page']", ns))
if (n_br != 1) fail("expected 1 page break, found %d", n_br)
ok("one page break")

## Section-ending paragraphs: <w:p><w:pPr><w:sectPr>. Body-final sectPr is a direct w:body child.
para_sects <- xml_find_all(doc, "//w:body/w:p/w:pPr/w:sectPr", ns)
if (length(para_sects) != 4) fail("expected 4 section-ending paragraphs, found %d", length(para_sects))
ok("4 section-ending paragraphs (2 portrait + 2 landscape)")

sz <- lapply(para_sects, function(s) {
  p <- xml_find_first(s, "./w:pgSz", ns)
  c(w = xml_attr(p, "w"), h = xml_attr(p, "h"), orient = xml_attr(p, "orient"))
})
orients <- vapply(sz, function(x) if (is.na(x[["orient"]])) "portrait" else x[["orient"]], character(1))
if (!identical(orients, c("portrait", "landscape", "portrait", "landscape"))) {
  fail("unexpected section order: %s", paste(orients, collapse = ", "))
}
ok("section order portrait, landscape, portrait, landscape")
if (!identical(unname(sz[[2]][c("w", "h")]), c("16838", "11906"))) fail("default landscape size wrong")
ok("default landscape size is A4 (16838 x 11906)")
if (!identical(unname(sz[[4]][c("w", "h")]), c("15840", "12240"))) fail("custom landscape size wrong")
ok("custom landscape size applied (15840 x 12240)")

txt <- paste(readLines(file.path(tmp, "word", "document.xml"), warn = FALSE), collapse = "")
if (grepl("BLOCK_", txt, fixed = TRUE)) fail("a BLOCK_ marker was left in the document")
ok("no BLOCK_ marker text left (unknown marker stays inert)")

cat("All block-marker checks passed.\n")
