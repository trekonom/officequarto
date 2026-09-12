## Core logic for Gruppe 8 (page layout) of the officedown option port:
## officequarto.page.size.{width,height,orientation}/
## margins.{top,bottom,left,right,header,footer,gutter}. Part of the
## officequarto R package - used by oq_writeback() (R/writeback.R), not
## run standalone. Requires: xml2.
##
## Unlike all previous groups, this doesn't touch paragraph/table styles,
## but section properties (w:sectPr/w:pgSz/w:pgMar) - page layout is
## already fully carried over from reference-doc by Pandoc (see
## CLAUDE.md), but Pandoc's docx writer offers NO YAML override mechanism
## for it (unlike, say, its LaTeX/PDF writer with geometry options) -
## anyone wanting to change page size/margins without editing reference-doc
## itself needs a post-render patch like this one for it. Applied uniformly
## to EVERY w:sectPr in the document (most documents have exactly one; a
## document with genuinely different per-section page layouts is
## deliberately not the target scenario, matching officedown's own
## single-section assumption).
##
## Values are given in inches (as with officedown) and converted internally
## to twips (1 inch = 1440 twips, the OOXML unit expected by w:pgSz/w:pgMar).

#' @noRd
officequarto_twips_per_inch <- 1440

## Sets (or creates) the w:pgSz attributes (w:w/w:h/w:orient) of a w:sectPr.
## size_options: list with optional $width/$height (inches)/$orientation
## ("portrait"/"landscape", already validated). No automatic swapping of
## width/height for orientation: landscape - as with officedown, that's the
## user's own responsibility.
#' @noRd
oq_set_page_size <- function(sect_pr, ns, size_options) {
  node <- xml2::xml_find_first(sect_pr, "./w:pgSz", ns)
  if (is.na(node)) {
    node <- xml2::xml_add_child(sect_pr, "w:pgSz", .where = 0)
  }
  if (!is.null(size_options$width)) {
    xml2::xml_attr(node, "w:w") <- as.character(round(size_options$width * officequarto_twips_per_inch))
  }
  if (!is.null(size_options$height)) {
    xml2::xml_attr(node, "w:h") <- as.character(round(size_options$height * officequarto_twips_per_inch))
  }
  if (!is.null(size_options$orientation)) {
    xml2::xml_attr(node, "w:orient") <- size_options$orientation
  }
  invisible(NULL)
}

## Sets (or creates) the w:pgMar attributes (top/bottom/left/right/header/
## footer/gutter) of a w:sectPr. margin_options: list with each of these
## fields optional (inches).
#' @noRd
oq_set_page_margins <- function(sect_pr, ns, margin_options) {
  node <- xml2::xml_find_first(sect_pr, "./w:pgMar", ns)
  if (is.na(node)) {
    node <- xml2::xml_add_child(sect_pr, "w:pgMar")
  }
  for (field in c("top", "bottom", "left", "right", "header", "footer", "gutter")) {
    val <- margin_options[[field]]
    if (!is.null(val)) {
      xml2::xml_attr(node, paste0("w:", field)) <- as.character(round(val * officequarto_twips_per_inch))
    }
  }
  invisible(NULL)
}

## Applies page_options ($size/$margins, each optional with further
## optional sub-fields) to every w:sectPr in the document (in-place via
## xml2 reference semantics). Returns the number of sections processed.
#' @noRd
oq_apply_page_options <- function(document_doc, page_options) {
  ns <- xml2::xml_ns(document_doc)
  sections <- xml2::xml_find_all(document_doc, "//w:sectPr", ns)

  has_size <- !is.null(page_options$size) && any(!vapply(page_options$size, is.null, logical(1)))
  has_margins <- !is.null(page_options$margins) && any(!vapply(page_options$margins, is.null, logical(1)))

  for (sect_pr in sections) {
    if (has_size) oq_set_page_size(sect_pr, ns, page_options$size)
    if (has_margins) oq_set_page_margins(sect_pr, ns, page_options$margins)
  }

  length(sections)
}
