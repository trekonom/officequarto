## End-to-end check for oq_numbering()/oq_ref() (R/numbering-hook.R): live SEQ captions and REF
## references created by knitr hooks while knitting, see dev/knitr-hooks/experiments/15-16.
## Expects the fixture to have been rendered already:
##   cd dev/fixtures/numbering-hook
##   quarto render                       # report.docx + custom.docx
##   (cd with-auto-number && quarto render)   # same qmd, officequarto.crossref.auto-number: true
##   Rscript ../../check-numbering-hook-e2e.R
## Needs the package installed (Rscript dev/install.R) so the render uses the current code.
library(xml2)

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

read_docx_xml <- function(path) {
  if (!file.exists(path)) fail("%s was not created", path)
  tmp <- tempfile("check_numbering_e2e_")
  dir.create(tmp)
  utils::unzip(path, exdir = tmp)
  read_xml(file.path(tmp, "word", "document.xml"))
}

par_text <- function(p, ns) paste(xml_text(xml_find_all(p, ".//w:t", ns)), collapse = "")
nbsp <- " "

check_report <- function(path, label) {
  doc <- read_docx_xml(path)
  ns <- xml_ns(doc)

  instr <- xml_text(xml_find_all(doc, "//w:instrText", ns))
  n_fig <- sum(grepl("SEQ Figure", instr, fixed = TRUE))
  n_tbl <- sum(grepl("SEQ Table", instr, fixed = TRUE))
  if (n_fig != 2) fail("%s: expected 2 SEQ Figure fields, found %d", label, n_fig)
  if (n_tbl != 2) fail("%s: expected 2 SEQ Table fields, found %d", label, n_tbl)
  ok("%s: 2 SEQ Figure + 2 SEQ Table fields (no duplicates)", label)

  bm <- xml_find_all(doc, "//w:bookmarkStart", ns)
  names <- xml_attr(bm, "name")
  ids <- xml_attr(bm, "id")
  for (id in c("fig-a", "fig-b", "tbl-a", "tbl-b")) {
    if (sum(names == id) != 1) fail("%s: expected exactly one bookmark '%s'", label, id)
  }
  if (anyDuplicated(ids)) fail("%s: duplicate w:bookmarkStart ids: %s", label, paste(ids[duplicated(ids)], collapse = ", "))
  ok("%s: bookmarks fig-a/fig-b/tbl-a/tbl-b present, all bookmark ids unique", label)

  cap_a <- xml_find_first(doc, "//w:p[contains(., 'FIG-A-CAP')]", ns)
  if (is.na(cap_a)) fail("%s: figure caption paragraph not found", label)
  txt_a <- par_text(cap_a, ns)
  if (!startsWith(txt_a, paste0("Abbildung", nbsp))) fail("%s: figure caption should start with 'Abbildung<nbsp>' (oq.fig.label), got '%s'", label, txt_a)
  if (!grepl(": FIG-A-CAP", txt_a, fixed = TRUE)) fail("%s: figure caption separator/text wrong: '%s'", label, txt_a)
  ok("%s: figure caption '%s' (label from knitr: opts_chunk)", label, txt_a)

  cap_t <- xml_find_first(doc, "//w:p[contains(., 'TBL-A-CAP')]", ns)
  if (is.na(cap_t)) fail("%s: table caption paragraph not found", label)
  if (!startsWith(par_text(cap_t, ns), paste0("Tabelle", nbsp))) fail("%s: table caption should start with 'Tabelle<nbsp>'", label)
  nxt <- xml_find_first(cap_t, "following-sibling::*[1]", ns)
  if (is.na(nxt) || xml_name(nxt) != "tbl") fail("%s: the table caption is not directly followed by its w:tbl", label)
  ok("%s: table caption directly precedes its table", label)
  if (is.na(xml_find_first(cap_t, ".//w:i", ns))) fail("%s: inline markdown (*emphasis*) lost in the table caption", label)
  ok("%s: inline markdown in the table caption became an italic run", label)

  ## references: one REF field per oq_ref(), inside a hyperlink to the bookmark
  for (id in c("fig-a", "fig-b", "tbl-a", "tbl-b")) {
    link <- xml_find_first(doc, sprintf("//w:hyperlink[@w:anchor='%s']", id), ns)
    if (is.na(link)) fail("%s: no hyperlink to '%s'", label, id)
    if (is.na(xml_find_first(link, sprintf(".//w:instrText[contains(., 'REF %s')]", id), ns))) fail("%s: hyperlink to '%s' holds no REF field", label, id)
  }
  ok("%s: oq_ref() produced a REF-field hyperlink for each of the 4 items", label)

  all_text <- paste(xml_text(xml_find_all(doc, "//w:t", ns)), collapse = " ")
  if (grepl("(Figure|Table)[  ][0-9]", all_text)) fail("%s: Quarto's static numbering is still present", label)
  if (grepl("?@", all_text, fixed = TRUE)) fail("%s: unresolved Quarto reference ('?@...') in the text", label)
  ok("%s: no static 'Figure N'/'Table N' text and no unresolved references", label)
}

check_report("report.docx", "report")

## custom hook (fig_hook = ...): replaces the default post-processing but is still chained on Quarto's hook
custom <- read_docx_xml("custom.docx")
cns <- xml_ns(custom)
note <- xml_find_first(custom, "//w:p[contains(., 'CUSTOM-NOTE for fig-c')]", cns)
if (is.na(note)) fail("custom: the custom hook's output ('CUSTOM-NOTE for fig-c') is missing")
n_seq <- sum(grepl("SEQ Figure", xml_text(xml_find_all(custom, "//w:instrText", cns)), fixed = TRUE))
if (n_seq != 1) fail("custom: the wrapped default hook should still add exactly 1 SEQ Figure field, found %d", n_seq)
ok("custom: custom fig_hook ran (note present) on top of the default numbering")

## same document with officequarto.crossref.auto-number: true - the hook-owned captions must be left alone
check_report(file.path("with-auto-number", "report.docx"), "with auto-number")

cat("All numbering-hook checks passed.\n")
