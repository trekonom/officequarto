suppressMessages(library(xml2))
d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
for (v in c("v-a-baseline", "v-b-filters", "v-c-pre-quarto")) {
  r <- render_docx(d, paste0(v, ".qmd"))
  cat("\n==", v, "==\nrender ok:", r$status == 0, "\n")
  cat(grep("refs.lua|WARN|Unable|unresolved|crossref", r$log, value = TRUE, ignore.case = TRUE), sep = "\n")
  if (is.na(r$xml)) { cat(tail(r$log, 8), sep = "\n"); next }
  doc <- read_xml(r$xml); ns <- xml_ns(doc)
  for (key in c("Plain:", "Bracketed:", "Multi:", "Suffix:", "Prefix:", "Unknown:")) {
    p <- xml_find_first(doc, sprintf("//w:p[starts-with(normalize-space(.), '%s')]", key), ns)
    if (is.na(p)) { cat(sprintf("  %-11s (paragraph not found)\n", key)); next }
    refs <- xml_attr(xml_find_all(p, ".//w:hyperlink[.//w:instrText[contains(., 'REF')]]", ns), "anchor")
    txt <- paste(xml_text(xml_find_all(p, ".//w:t", ns)), collapse = "")
    cat(sprintf("  %-11s REF->[%s]  text: '%s'\n", key, paste(refs, collapse = ","), txt))
  }
}

## stage 2: delivery through the extension, mixed native + hook items, auto-number on
repo <- normalizePath(file.path(d, "..", "..", "..", ".."))
proj <- normalizePath(tempfile("oq-qn-")); dir.create(proj)
file.copy(file.path(repo, "inst", "_extensions"), proj, recursive = TRUE)
file.copy(file.path(d, "refs.lua"), file.path(proj, "_extensions", "officequarto", "scripts", "refs.lua"))
ext <- file.path(proj, "_extensions", "officequarto", "_extension.yml")
writeLines(sub("          - scripts/markers.lua", "          - scripts/markers.lua\n          - scripts/refs.lua", readLines(ext)), ext)
file.copy(file.path(repo, "template", c("original.docx", "plot.png")), proj)
file.copy(file.path(d, "mixed.qmd"), proj)
writeLines(c("project:", "  type: officequarto", "format:", "  docx:", "    reference-doc: original.docx",
             "    officequarto:", "      crossref:", "        auto-number: true"), file.path(proj, "_quarto.yml"))
r <- render_docx(proj, "mixed.qmd")
cat("\n== extension-delivered filter, mixed items, auto-number on ==\nrender ok:", r$status == 0, "\n")
cat(grep("refs.lua|WARN|Unable|cross-references|captions:", r$log, value = TRUE, ignore.case = TRUE), sep = "\n")
if (!is.na(r$xml)) {
  doc <- read_xml(r$xml); ns <- xml_ns(doc)
  for (key in c("Single:", "Mixed cite:")) {
    p <- xml_find_first(doc, sprintf("//w:p[starts-with(normalize-space(.), '%s')]", key), ns)
    refs <- xml_attr(xml_find_all(p, ".//w:hyperlink[.//w:instrText[contains(., 'REF')]]", ns), "anchor")
    cat(sprintf("  %-12s REF->[%s]  text: '%s'\n", key, paste(refs, collapse = ","),
        paste(xml_text(xml_find_all(p, ".//w:t", ns)), collapse = "")))
  }
  for (key in c("HOOK-FIG-A", "NATIVE-FIG", "NATIVE-TBL")) {
    p <- xml_find_first(doc, sprintf("//w:p[contains(., '%s')]", key), ns)
    cat(sprintf("  caption %-11s SEQ fields: %d  text: '%s'\n", key,
        length(xml_find_all(p, ".//w:instrText[contains(., 'SEQ')]", ns)),
        paste(xml_text(xml_find_all(p, ".//w:t", ns)), collapse = "")))
  }
  cat("  page break (markers.lua still active):", grepl("w:type=\"page\"", r$xml, fixed = TRUE), "\n")
  cat("  bookmark names:", paste(xml_attr(xml_find_all(doc, "//w:bookmarkStart", ns), "name"), collapse = ", "), "\n")
}

if (nzchar(Sys.getenv("OQ_COPY"))) file.copy(r$docx, Sys.getenv("OQ_COPY"), overwrite = TRUE)

## stage 3: the same mixed document WITHOUT auto-number - native items keep Quarto's static numbers
writeLines(c("project:", "  type: officequarto", "format:", "  docx:", "    reference-doc: original.docx"),
           file.path(proj, "_quarto.yml"))
r3 <- render_docx(proj, "mixed.qmd")
cat("\n== mixed items, auto-number OFF ==\nrender ok:", r3$status == 0, "\n")
if (!is.na(r3$xml)) {
  doc3 <- read_xml(r3$xml); ns3 <- xml_ns(doc3)
  for (key in c("HOOK-FIG-A", "NATIVE-FIG")) {
    p <- xml_find_first(doc3, sprintf("//w:p[contains(., '%s')]", key), ns3)
    cat(sprintf("  caption %-11s SEQ field: %-5s static text: '%s'\n", key,
        length(xml_find_all(p, ".//w:instrText[contains(., 'SEQ')]", ns3)) > 0,
        paste(xml_text(xml_find_all(p, ".//w:t", ns3)), collapse = "")))
  }
}
