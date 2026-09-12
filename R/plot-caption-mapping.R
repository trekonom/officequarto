## Core logic for Gruppe 5 (figure captions) of the officedown option port:
## officequarto.plots.caption.style/prefix/separator/number-bold. The actual
## text-reformatting logic is identical to Gruppe 3 (table captions) and
## therefore lives jointly in table-caption-mapping.R
## (oq_apply_captions()/oq_split_caption_text()/oq_write_caption_run()) -
## this file only contributes the figure-specific detection. Part of the
## officequarto R package - used by oq_writeback() (R/writeback.R), not run
## standalone. Requires: xml2 and oq_apply_captions() from
## table-caption-mapping.R (in the same package namespace, no explicit load
## order needed).
##
## `tnd`/`tns` were NOT ported, for the identical reason as in Gruppe 3
## (see table-caption-mapping.R/README): Quarto/Pandoc numbers figures
## exclusively globally/sequentially.

## Finds all figure caption paragraphs in document order. Recognized as a
## paragraph with pStyle "ImageCaption" (Pandoc's style for figure
## captions - unlike tables, Pandoc always uses "ImageCaption" for this,
## with or without a Quarto crossref ID, see
## oq_find_table_caption_paragraphs()) whose IMMEDIATELY PRECEDING sibling
## element contains an image paragraph (w:drawing) - Pandoc's default
## position in both cases (wrapper cell for crossref IDs, plain siblings in
## the document body otherwise) is "caption after the figure". Positional
## adjacency instead of the earlier "parent element has no w:tbl child"
## check (see oq_find_table_caption_paragraphs() for the real bug this
## caused when figure and table captions sit as siblings in the same
## document body next to unrelated tables).
#' @noRd
oq_find_plot_caption_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(
    document_doc,
    "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption'][preceding-sibling::*[1][.//w:drawing]]",
    ns
  )
}

## Finds the content node belonging to a figure caption (the immediately
## preceding image paragraph, see oq_find_plot_caption_paragraphs()) - for
## oq_apply_captions()'s $above handling (see table-caption-mapping.R). NA
## if no immediately preceding image paragraph exists.
#' @noRd
oq_plot_caption_content <- function(caption_p, ns) {
  xml2::xml_find_first(caption_p, "./preceding-sibling::*[1][.//w:drawing]", ns)
}
