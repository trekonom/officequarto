## Criteria table: which hook variants give live SEQ captions AND keep @fig-x working?
suppressMessages(library(xml2))
d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))

criteria <- function(r) {
  if (is.na(r$xml)) return(NULL)
  doc <- read_xml(r$xml); ns <- xml_ns(doc)
  caps <- xml_find_all(doc, "//w:p[contains(., 'CAP-A') or contains(., 'CAP-B')]", ns)
  cap_text <- vapply(caps, xml_text, character(1))
  has_seq <- vapply(caps, function(p) length(xml_find_all(p, ".//w:instrText[contains(., 'SEQ')]", ns)) > 0, logical(1))
  static_prefix <- grepl("Figure[  ]*[12]", cap_text)
  body_txt <- xml_text(doc)
  c(
    caption_text      = length(caps) == 2,
    live_SEQ_field    = length(has_seq) == 2 && all(has_seq),
    static_Figure_N   = any(static_prefix),
    double_numbering  = any(static_prefix & has_seq),
    bookmarks_a_b     = all(c("fig-a", "fig-b") %in% xml_attr(xml_find_all(doc, "//w:bookmarkStart", ns), "name")),
    ref_links_a_b     = all(c("fig-a", "fig-b") %in% xml_attr(xml_find_all(doc, "//w:hyperlink", ns), "anchor")),
    ref_is_REF_field  = length(xml_find_all(doc, "//w:hyperlink//w:instrText[contains(., 'REF')]", ns)) >= 2,
    no_unresolved_ref = !grepl("@fig-|\\?@fig|\\?\\?", body_txt)
  )
}
show <- function(label, r) {
  cat("\n==", label, "==\n")
  cat("render ok:", r$status == 0, "\n")
  cr <- criteria(r)
  if (is.null(cr)) { cat(tail(r$log, 8), sep = "\n"); return(invisible()) }
  for (n in names(cr)) cat(sprintf("  %-20s %s\n", n, if (cr[[n]]) "YES" else "no"))
}
for (v in c("v0-baseline", "v1-options", "v2-inline-field", "v3-owns-numbering", "v3b-owns-numbering-atref", "v4-officedown-hook")) {
  show(v, render_docx(d, paste0(v, ".qmd")))
}

## v5: reference result, officequarto post-render auto-number (project with the in-tree extension).
repo <- normalizePath(file.path(d, "..", "..", "..", ".."))
proj <- tempfile("oq-proj-"); dir.create(proj); proj <- normalizePath(proj)
file.copy(file.path(repo, "inst", "_extensions"), proj, recursive = TRUE)
file.copy(file.path(repo, "template", "original.docx"), proj)
writeLines(c("project:", "  type: officequarto", "format:", "  docx:", "    reference-doc: original.docx",
             "    officequarto:", "      crossref:", "        auto-number: true"), file.path(proj, "_quarto.yml"))
file.copy(file.path(d, "v0-baseline.qmd"), file.path(proj, "report.qmd"))
show("v5-officequarto-auto-number (post-render)", render_docx(proj, "report.qmd"))
