## End-to-end check for oq_numbering()/oq_ref() (R/numbering-hook.R): live SEQ captions and REF
## references created by knitr hooks while knitting, see dev/knitr-hooks/experiments/15-16.
## Expects the fixture to have been rendered already:
##   cd dev/fixtures/numbering-hook
##   quarto render                       # report.docx + custom.docx
##   (cd with-auto-number && quarto render)   # report.qmd again + mixed.qmd, officequarto.crossref.auto-number: true
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

  ## Quarto notation (@fig-a, [@fig-b], [@fig-a; @tbl-a], [-@tbl-b], [siehe @fig-b, S. 3]) is turned into
  ## REF fields by the extension's refs.lua filter: oq_ref() contributes one link per id, the
  ## notation paragraph the rest (fig-a: 2, fig-b: 2, tbl-a: 1, tbl-b: 1).
  expected_links <- c("fig-a" = 3, "fig-b" = 3, "tbl-a" = 2, "tbl-b" = 2)
  for (id in names(expected_links)) {
    links <- xml_find_all(doc, sprintf("//w:hyperlink[@w:anchor='%s'][.//w:instrText[contains(., 'REF')]]", id), ns)
    if (length(links) != expected_links[[id]]) {
      fail("%s: expected %d REF links to '%s' (oq_ref + Quarto notation), found %d", label, expected_links[[id]], id, length(links))
    }
  }
  ok("%s: Quarto notation @fig-a/[@fig-b]/[@fig-a; @tbl-a]/[-@tbl-b]/[siehe @fig-b, S. 3] resolved to REF fields", label)
  notation <- xml_find_first(doc, "//w:p[starts-with(normalize-space(.), 'Quarto-Notation')]", ns)
  if (!grepl("S. 3", par_text(notation, ns), fixed = TRUE)) fail("%s: the suffix 'S. 3' of the citation was lost", label)
  if (!grepl("siehe", par_text(notation, ns), fixed = TRUE)) fail("%s: the prefix 'siehe' of the citation was lost", label)
  ok("%s: citation prefix and suffix kept", label)

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

## mixed document (with-auto-number/mixed.qmd): hook-numbered and native items, auto-number on
mixed <- read_docx_xml(file.path("with-auto-number", "mixed.docx"))
mns <- xml_ns(mixed)
seq_figs <- xml_find_all(mixed, "//w:p[.//w:instrText[contains(., 'SEQ Figure')]]", mns)
if (length(seq_figs) != 2) fail("mixed: expected 2 figure captions with a SEQ Figure field (hook + native via auto-number), found %d", length(seq_figs))
if (!any(grepl("HOOK-FIG", vapply(seq_figs, par_text, character(1), ns = mns)))) fail("mixed: hook figure caption missing")
if (!any(grepl("NATIVE-FIG", vapply(seq_figs, par_text, character(1), ns = mns)))) fail("mixed: native figure caption was not converted by auto-number")
ok("mixed: hook-numbered and native figure share the SEQ Figure sequence (2 live captions)")
single <- xml_find_first(mixed, "//w:p[starts-with(normalize-space(.), 'Einzeln')]", mns)
links <- xml_attr(xml_find_all(single, ".//w:hyperlink[.//w:instrText[contains(., 'REF')]]", mns), "anchor")
if (!identical(sort(links), sort(c("fig-hook", "fig-nat", "tbl-nat")))) fail("mixed: single references resolved to [%s]", paste(links, collapse = ","))
ok("mixed: @fig-hook (refs.lua) and @fig-nat/@tbl-nat (auto-number) are all REF fields")
gem <- xml_find_first(mixed, "//w:p[starts-with(normalize-space(.), 'Gemischt')]", mns)
links <- xml_attr(xml_find_all(gem, ".//w:hyperlink[.//w:instrText[contains(., 'REF')]]", mns), "anchor")
if (!identical(sort(links), sort(c("fig-hook", "fig-nat")))) fail("mixed: [@fig-hook; @fig-nat] resolved to [%s]", paste(links, collapse = ","))
if (grepl("?@", paste(xml_text(xml_find_all(mixed, "//w:t", mns)), collapse = " "), fixed = TRUE)) fail("mixed: unresolved '?@' reference")
ok("mixed: the mixed citation [@fig-hook; @fig-nat] is fully resolved")

cat("All numbering-hook checks passed.\n")
