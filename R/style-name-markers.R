## Resolves officer's style-name markers into real style references.
## Called unconditionally from writeback.R (a correctness fix, like
## oq_merge_misplaced_ppr() - not gated behind any officequarto.* option).
##
## Background: officer writes the Word style of a paragraph/table it builds
## (fp_par(word_style=), prop_table(style=), block_caption(style=), ...) as a
## marker attribute carrying the style's DISPLAY NAME - `<w:pStyle
## w:pstlname="Normal"/>`, `<w:tblStyle w:tstlname="Table Grid"/>` - not the
## OOXML-required `w:val` styleId. officer only swaps these for real
## `w:val` IDs when it WRITES a docx (print.rdocx() ->
## convert_custom_styles_in_wml(), officer's R/utils-xml.R), which is what
## {officedown}'s rdocx_document() post_processor triggers under R Markdown.
## Quarto has no such step, so the markers reach the final docx unresolved and
## Word ignores them (see dev/knitr-hooks/experiments/12-table-style-cause).
## This does the same name -> id swap against the rendered styles.xml, with no
## {officer} dependency, mirroring oq_style_name_to_id().
##
## Runs BEFORE oq_merge_misplaced_ppr(): a resolved fp_par() pStyle now has a
## `w:val`, so the merge picks it up like any other well-formed pStyle.
##
## A marker whose name isn't a style in styles.xml has nothing to resolve to:
## the (otherwise invalid) element is removed, so the paragraph/table falls
## back to the default style, and the name is returned so the caller can warn.
#' @noRd
oq_resolve_style_name_markers <- function(part_doc, styles_doc) {
  ns <- xml2::xml_ns(part_doc)
  specs <- list(
    list(xpath = "//w:pStyle[@w:pstlname]", element = "w:pStyle", marker = "pstlname", type = "paragraph"),
    list(xpath = "//w:tblStyle[@w:tstlname]", element = "w:tblStyle", marker = "tstlname", type = "table")
  )
  resolved <- 0L
  unresolved <- character()
  for (spec in specs) {
    nodes <- xml2::xml_find_all(part_doc, spec$xpath, ns)
    if (length(nodes) == 0) next
    name_to_id <- oq_style_name_to_id(styles_doc, spec$type)
    lookup <- stats::setNames(unname(name_to_id), tolower(names(name_to_id)))
    for (node in nodes) {
      name <- xml2::xml_attr(node, spec$marker)
      id <- if (name %in% names(name_to_id)) {
        unname(name_to_id[[name]])
      } else {
        unname(lookup[tolower(name)])
      }
      if (length(id) == 0 || is.na(id)) {
        unresolved <- c(unresolved, name)
        xml2::xml_remove(node)
      } else {
        ## xml2 cannot remove a namespaced attribute (xml_attr<- NULL is a
        ## silent no-op for "w:pstlname"), so swap in a fresh element that
        ## only carries w:val instead of editing the marker node in place.
        new_node <- xml2::xml_add_sibling(node, spec$element, .where = "before")
        xml2::xml_attr(new_node, "w:val") <- id
        xml2::xml_remove(node)
        resolved <- resolved + 1L
      }
    }
  }
  list(resolved = resolved, unresolved = unique(unresolved))
}
