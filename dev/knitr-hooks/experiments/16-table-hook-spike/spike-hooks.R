## Table-numbering spike: rewrite Quarto's tbl- cell after the chunk hook ran.
source("hooks.R")
.bm <- 5000L
raw_inline <- function(xml) paste0("`", xml, "`{=openxml}")
fld <- function(instr) raw_inline(paste0('<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> ', instr, ' </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>'))
## caption inline markdown: bookmark(label + number) + sep + text
cap_inline <- function(id, text, label = "Table", sep = ": ") {
  .bm <<- .bm + 1L
  paste0(raw_inline(sprintf('<w:bookmarkStart w:id="%d" w:name="%s"/>', .bm, id)), label, " ",
         fld("SEQ Table \\* Arabic"),
         raw_inline(sprintf('<w:bookmarkEnd w:id="%d"/>', .bm)), sep, text)
}
split_cell <- function(res) {
  m <- regmatches(res, regexec("^\n*(?:[ ]*)::: \\{#(tbl-[A-Za-z0-9_-]+) ([^}]*)\\}", res, perl = TRUE))[[1]]
  if (length(m) == 0) return(NULL)
  cap <- regmatches(m[3], regexec("tbl-cap='([^']*)'", m[3]))[[1]]
  if (length(cap) == 0) return(NULL)
  list(id = m[2], cap = cap[2], open_old = m[1], rest = sub("[ ]*tbl-cap='[^']*'", "", m[3]))
}
opener <- function(parts) sprintf("::: {%s}", trimws(parts$rest))
## variant a: pipe-table caption ": text" appended after the table (pipe tables only)
hook_a <- function(res, options) {
  p <- split_cell(res); if (is.null(p)) return(res)
  res <- sub(p$open_old, opener(p), res, fixed = TRUE)
  sub("(\n(\\|[^\n]*\n)+)", paste0("\\1\n: ", gsub("\\\\", "\\\\\\\\", cap_inline(p$id, p$cap)), "\n"), res, perl = TRUE)
}
## variant b: fenced raw <w:p> before the display output
hook_b <- function(res, options) {
  p <- split_cell(res); if (is.null(p)) return(res)
  res <- sub(p$open_old, opener(p), res, fixed = TRUE)
  .bm <<- .bm + 1L
  para <- sprintf('<w:p><w:pPr><w:pStyle w:val="TableCaption"/><w:keepNext/></w:pPr><w:bookmarkStart w:id="%d" w:name="%s"/><w:r><w:t xml:space="preserve">Table </w:t></w:r><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> SEQ Table \\* Arabic </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r><w:bookmarkEnd w:id="%d"/><w:r><w:t xml:space="preserve">: %s</w:t></w:r></w:p>', .bm, p$id, .bm, p$cap)
  sub("::: {.cell-output-display}", paste0("```{=openxml}\n", para, "\n```\n\n::: {.cell-output-display}"), res, fixed = TRUE)
}
## variant c: markdown paragraph in a custom-style div (inline markdown + inline raw fields)
hook_c <- function(res, options) {
  p <- split_cell(res); if (is.null(p)) return(res)
  res <- sub(p$open_old, opener(p), res, fixed = TRUE)
  blk <- paste0('::: {custom-style="Table Caption"}\n', cap_inline(p$id, p$cap), "\n:::\n\n")
  sub("::: {.cell-output-display}", paste0(blk, "::: {.cell-output-display}"), res, fixed = TRUE)
}
oq_ref <- function(id) knitr::asis_output(paste0("`<w:hyperlink w:anchor=\"", id, "\"><w:r><w:fldChar w:fldCharType=\"begin\" w:dirty=\"true\"/></w:r><w:r><w:instrText xml:space=\"preserve\"> REF ", id, " \\h </w:instrText></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:hyperlink>`{=openxml}"))
