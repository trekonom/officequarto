## End-to-end check for officequarto.crossref.auto-number (live SEQ/REF
## fields instead of static text, see scripts/table-caption-mapping.R/
## oq_convert_caption_to_field() and scripts/crossref-mapping.R/
## oq_apply_crossref_fields(), dev/spike-notes.md Spike P). Expects that
## `quarto render report.qmd` has already run in THIS directory
## (dev/fixtures/auto-number/) - a standalone fixture, kept separate from
## template/, since template/_quarto.yml sets crossref.numbered: false,
## which is mutually exclusive with auto-number (see the fail-loud check in
## writeback.R). Checks against the actual rendered+patched document: SEQ
## fields for table AND figure, correct bookmark names, REF fields at the
## cross-reference sites, and that word/settings.xml stays untouched (no
## w:updateFields - matches {officedown}'s own empirically verified
## behavior exactly).
library(xml2)

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

target <- "report.docx"
if (!file.exists(target)) fail("%s was not created", target)
ok("%s exists", target)

tmp <- tempfile("check_auto_number_e2e_")
dir.create(tmp)
utils::unzip(target, exdir = tmp)

document_doc <- read_xml(file.path(tmp, "word", "document.xml"))
ns <- xml_ns(document_doc)

check_seq_field <- function(bookmark_name, expected_seq_id, label) {
  bm <- xml_find_first(document_doc, sprintf("//w:bookmarkStart[@w:name='%s']", bookmark_name), ns)
  if (is.na(bm)) fail("%s: no w:bookmarkStart with name '%s' found", label, bookmark_name)
  ok("%s: bookmark '%s' present", label, bookmark_name)

  caption_p <- xml_find_first(bm, "./parent::w:p", ns)
  if (is.na(caption_p)) fail("%s: bookmark is not inside a paragraph", label)

  instr <- xml_find_first(caption_p, ".//w:instrText", ns)
  if (is.na(instr)) fail("%s: no w:instrText found in the caption paragraph", label)
  expected_instr <- sprintf("SEQ %s \\* Arabic", expected_seq_id)
  if (!identical(xml_text(instr), expected_instr)) {
    fail("%s: expected instrText '%s', got '%s'", label, expected_instr, xml_text(instr))
  }
  ok("%s: instrText is '%s'", label, expected_instr)

  fld_chars <- xml_find_all(caption_p, ".//w:fldChar", ns)
  if (length(fld_chars) != 2) fail("%s: expected 2 w:fldChar, got %d", label, length(fld_chars))
  if (!all(xml_attr(fld_chars, "dirty") == "true")) fail("%s: both w:fldChar should carry w:dirty='true'", label)
  ok("%s: both w:fldChar carry w:dirty='true'", label)
}

check_ref_field <- function(anchor, label) {
  link <- xml_find_first(document_doc, sprintf("//w:hyperlink[@w:anchor='%s']", anchor), ns)
  if (is.na(link)) fail("%s: no w:hyperlink with anchor '%s' found", label, anchor)
  instr <- xml_find_first(link, ".//w:instrText", ns)
  if (is.na(instr)) fail("%s: no w:instrText found in the hyperlink", label)
  expected_instr <- sprintf(" REF %s \\h ", anchor)
  if (!identical(xml_text(instr), expected_instr)) {
    fail("%s: expected instrText '%s', got '%s'", label, expected_instr, xml_text(instr))
  }
  ok("%s: cross-reference to '%s' carries a REF field instead of static text", label, anchor)
}

check_seq_field("tbl-x", "Table", "table caption")
check_seq_field("fig-x", "Figure", "figure caption")
check_ref_field("tbl-x", "table cross-reference")
check_ref_field("fig-x", "figure cross-reference")

settings_path <- file.path(tmp, "word", "settings.xml")
if (file.exists(settings_path)) {
  settings_text <- paste(readLines(settings_path, warn = FALSE), collapse = "\n")
  if (grepl("updateFields", settings_text, fixed = TRUE)) {
    fail("word/settings.xml should not contain w:updateFields (matches {officedown}'s own behavior)")
  }
}
ok("word/settings.xml contains no w:updateFields")

cat("\nAll checks passed.\n")
