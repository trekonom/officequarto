suppressMessages(library(xml2))
d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
for (v in c("a", "b", "c")) {
  r <- render_docx(d, paste0("t-", v, ".qmd"))
  cat("\n== variant", v, "==\n"); cat("render ok:", r$status == 0, "\n")
  if (is.na(r$xml)) { cat(tail(r$log, 8), sep = "\n"); next }
  doc <- read_xml(r$xml); ns <- xml_ns(doc)
  caps <- xml_find_all(doc, "//w:p[contains(., 'TBL-')]", ns)
  txt <- vapply(caps, xml_text, character(1))
  prev_is_cap <- vapply(xml_find_all(doc, "//w:tbl", ns), function(t) {
    p <- xml_find_first(t, "preceding-sibling::*[1]", ns); !is.na(p) && grepl("TBL-", xml_text(p)) }, logical(1))
  cat(sprintf("  %-34s %s\n", c("caption paragraphs found", "live SEQ Table in captions", "caption BEFORE its table (all tables)",
        "bookmarks tbl-a, tbl-b", "REF hyperlinks tbl-a, tbl-b", "caption pStyle(s)", "emph run in caption a",
        "no unresolved/Quarto-numbered"),
      c(length(caps) == 2,
        all(vapply(caps, function(p) length(xml_find_all(p, ".//w:instrText[contains(., 'SEQ Table')]", ns)) > 0, logical(1))),
        length(prev_is_cap) >= 2 && all(prev_is_cap),
        all(c("tbl-a", "tbl-b") %in% xml_attr(xml_find_all(doc, "//w:bookmarkStart", ns), "name")),
        all(c("tbl-a", "tbl-b") %in% xml_attr(xml_find_all(doc, "//w:hyperlink", ns), "anchor")),
        paste(unique(xml_attr(xml_find_all(caps, "./w:pPr/w:pStyle", ns), "val")), collapse = ","),
        any(grepl("<w:i/>|<w:i ", vapply(caps, as.character, character(1)))),
        !grepl("\\?@tbl|@tbl-", xml_text(doc)))), sep = "")
  cat("  texts:", txt, sep = "\n    ")
}
