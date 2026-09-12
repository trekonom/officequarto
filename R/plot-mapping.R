## Core logic for Gruppe 4 (figure basics) of the officedown option port:
## officequarto.plots.style/align. Part of the officequarto R package - used
## by oq_writeback() (R/writeback.R), not run standalone. Requires: xml2,
## oq_set_pstyle() from style-mapping.R (in the same package namespace, no
## explicit load order needed).
##
## `fig.lp` (officedown) was deliberately NOT ported - identical
## reasoning as `tab.lp` (see table-mapping.R/README): a bookdown
## authoring-syntax concept with no equivalent in Quarto's post-render
## architecture.
##
## `topcaption` (officedown: caption above/below) is deliberately NOT part
## of this file - it's a structural paragraph reorder (caption before/after
## the figure), analogous to the deliberately deferred
## officequarto.tables.caption.above (see table-mapping.R), and is meant to
## be implemented jointly for tables AND figures once Gruppe 5 (figure
## captions) exists.

## Finds all figure paragraphs: a w:p with a w:drawing descendant - more
## reliable than going by the pStyle name, since Pandoc uses the same
## context-dependent role name for these as for body paragraphs (e.g.
## "Compact", empirically verified) - see style-mapping.R, which therefore
## explicitly excludes w:drawing paragraphs from the body-role assignment,
## so the two features don't fight over the same paragraph.
#' @noRd
oq_find_plot_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(document_doc, "//w:p[.//w:drawing]", ns)
}

## Sets (or creates) w:jc (paragraph alignment) of a paragraph. align is
## already the validated OOXML value ("left"/"center"/"right").
#' @noRd
oq_set_paragraph_align <- function(p, ns, align) {
  ppr <- xml2::xml_find_first(p, "./w:pPr", ns)
  if (is.na(ppr)) {
    ppr <- xml2::xml_add_child(p, "w:pPr", .where = 0)
  }
  jc_node <- xml2::xml_find_first(ppr, "./w:jc", ns)
  if (is.na(jc_node)) {
    jc_node <- xml2::xml_add_child(ppr, "w:jc")
  }
  xml2::xml_attr(jc_node, "w:val") <- align
  invisible(NULL)
}

## Applies plot_options ($style/$align, each optional) to every figure
## paragraph (in place, via xml2's reference semantics). Returns the number
## of paragraphs processed.
#' @noRd
oq_apply_plot_options <- function(document_doc, plot_options) {
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- oq_find_plot_paragraphs(document_doc, ns)

  for (p in paragraphs) {
    if (!is.null(plot_options$style)) oq_set_pstyle(p, ns, plot_options$style)
    if (!is.null(plot_options$align)) oq_set_paragraph_align(p, ns, plot_options$align)
  }

  length(paragraphs)
}
