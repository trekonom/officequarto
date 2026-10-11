## Removal of Quarto's caption wrapper tables (pure functions, no side
## effects of its own - called from writeback.R).
##
## Quarto's docx layout wraps every crossref-captioned figure/table in a
## 1x1 "wrapper" table whose single cell holds the caption plus the
## content (see table-caption-mapping.R). The wrapper is only structural,
## but it shows up in Word as a real table. It is removed as the very last
## caption-related step: caption detection, bookmarks and the table
## options all rely on the wrapper while they run.

## Finds the wrapper tables: a w:tbl with exactly one row and one cell
## whose own direct paragraph is styled ImageCaption/TableCaption. Must be
## called BEFORE any caption style remapping (the signature is the
## pStyle); the returned node-set stays valid for oq_unwrap_caption_tables().
#' @noRd
oq_find_caption_wrappers <- function(document_doc) {
  ns <- xml2::xml_ns(document_doc)
  xml2::xml_find_all(
    document_doc,
    paste0("//w:tbl[count(./w:tr) = 1 and count(./w:tr/w:tc) = 1 and ",
           "./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val[. = 'ImageCaption' or . = 'TableCaption']]"),
    ns
  )
}

## Replaces each wrapper by the content of its cell. Drops the trailing
## empty paragraph Pandoc adds after a nested table (unless the next
## sibling of the wrapper is a table, which would otherwise merge with
## it) and sets keepNext on a leading paragraph, so caption and content
## stay on one page like they did inside the single cell. Returns the
## number of unwrapped tables.
#' @noRd
oq_unwrap_caption_tables <- function(document_doc, wrappers) {
  ns <- xml2::xml_ns(document_doc)
  n <- 0L
  for (wrapper in wrappers) {
    cell <- xml2::xml_find_first(wrapper, "./w:tr/w:tc", ns)
    if (is.na(cell)) next
    children <- xml2::xml_find_all(cell, "./*[not(self::w:tcPr)]", ns)
    if (length(children) == 0L) next

    next_is_tbl <- !is.na(xml2::xml_find_first(wrapper, "following-sibling::*[1][self::w:tbl]", ns))
    content <- Filter(function(x) !xml2::xml_name(x) %in% c("bookmarkStart", "bookmarkEnd"), children)
    last <- content[[length(content)]]
    if (xml2::xml_name(last) == "p" && length(content) > 1L && !next_is_tbl &&
        !nzchar(xml2::xml_text(last)) && is.na(xml2::xml_find_first(last, ".//w:drawing|.//w:sectPr|.//w:fldChar", ns))) {
      children <- Filter(function(x) !identical(x$node, last$node), children)
    }

    if (xml2::xml_name(children[[1]]) == "p") oq_set_keep_next(children[[1]], ns)

    for (child in children) {
      xml2::xml_add_sibling(wrapper, child, .where = "before", .copy = TRUE)
    }
    xml2::xml_remove(wrapper)
    n <- n + 1L
  }
  n
}

## Sets w:keepNext in a paragraph's w:pPr at its schema position (after
## w:pStyle, otherwise first).
#' @noRd
oq_set_keep_next <- function(p, ns) {
  ppr <- xml2::xml_find_first(p, "./w:pPr", ns)
  if (is.na(ppr)) ppr <- xml2::xml_add_child(p, "w:pPr", .where = 0)
  if (!is.na(xml2::xml_find_first(ppr, "./w:keepNext", ns))) return(invisible(NULL))
  style <- xml2::xml_find_first(ppr, "./w:pStyle", ns)
  if (is.na(style)) {
    xml2::xml_add_child(ppr, "w:keepNext", .where = 0)
  } else {
    xml2::xml_add_sibling(style, "w:keepNext", .where = "after")
  }
  invisible(NULL)
}
