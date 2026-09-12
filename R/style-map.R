## Core logic for Gruppe 7 (free-form style mapping) of the officedown
## option port: officequarto.style-map (officedown: mapstyles). Part of the
## officequarto R package - used by oq_writeback() (R/writeback.R), not run
## standalone. Requires: xml2,
## oq_resolve_style_id()/oq_set_pstyle() from style-mapping.R (in the same
## package namespace, no explicit load order needed).
##
## Unlike officequarto.styles/.tables/.plots (fixed, curated roles with
## Pandoc-specific detection logic: numPr for lists, w:drawing for figures,
## etc.), this is a generic escape hatch: a free-form mapping table target
## style -> list of source pStyle IDs, remapped directly via pStyle equality
## comparison - no detection logic, the user specifies the exact style IDs
## to be remapped.

## Source and target sides are deliberately handled asymmetrically (as
## already done for SourceCode/code-block in style-mapping.R): the source
## side is Pandoc's own, stable, technical style IDs (e.g. "Normal",
## "BlockQuote", "Heading1") - direct equality comparison, no resolution
## needed, and no error if a source ID doesn't occur in the actual document
## at all (then the rule is simply a no-op there). The target side is a
## real style visible in reference-doc, so it's resolved via
## oq_resolve_style_id() as a display name (fail-loud like everywhere else
## in this project).
##
## Deliberately runs as the LAST step of the style-mapping pipeline in
## writeback.R (after officequarto.styles/.lists/.pandoc-styles/.tables/.plots) -
## by that point most paragraphs already carry their final pStyle, so a
## typical rule (keyed on Pandoc source names) automatically only touches
## paragraphs left untouched so far, while a rule deliberately targeting an
## already-remapped target name can still reach it anyway.

## Resolves the configuration (named list: target style display name ->
## vector of source pStyle IDs) into a named character vector source
## pStyle ID -> target styleId. Aborts (via fail_fn) if a target style name
## doesn't exist in reference-doc, or if a source pStyle ID is assigned to
## more than one target (ambiguous).
#' @noRd
oq_resolve_style_map <- function(style_map_config, name_to_id, fail_fn) {
  source_to_target <- character(0)
  for (target_name in names(style_map_config)) {
    target_id <- oq_resolve_style_id(
      name_to_id, target_name,
      sprintf("officequarto.style-map.\"%s\"", target_name), fail_fn
    )
    source_ids <- style_map_config[[target_name]]
    for (source_id in source_ids) {
      if (source_id %in% names(source_to_target)) {
        fail_fn(
          paste0(
            "officequarto.style-map: source style '%s' is assigned to more than one ",
            "target ('%s' and '%s') - each source style may only be assigned to one target."
          ),
          source_id, source_to_target[[source_id]], target_id
        )
      }
      source_to_target[[source_id]] <- target_id
    }
  }
  source_to_target
}

## Applies the resolved source-pStyle-ID -> target-styleId mapping to
## every paragraph of a parsed document.xml (or, via paragraph_xpath,
## footnotes.xml/endnotes.xml - see oq_note_paragraph_xpath() in
## style-mapping.R, Issue #2 "Footnote/endnote paragraph styling")
## (in-place via xml2 reference semantics). The paragraph_xpath default
## "//w:p" is already root-agnostic (no w:body anchor), but for
## footnotes.xml/endnotes.xml, without the separator/continuationSeparator
## exclusions, it would incorrectly apply to their pStyle-less (= "Normal")
## paragraph - hence the parameter instead of simply reusing the default.
## Paragraphs without a pStyle count as "Normal" (as everywhere else in
## this project). Returns the number of remapped paragraphs.
#' @noRd
oq_apply_style_map <- function(document_doc, source_to_target, paragraph_xpath = "//w:p") {
  if (length(source_to_target) == 0) return(0L)
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- xml2::xml_find_all(document_doc, paragraph_xpath, ns)

  n <- 0L
  for (p in paragraphs) {
    pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
    current <- if (is.na(pstyle_node)) "Normal" else xml2::xml_attr(pstyle_node, "val")
    target <- unname(source_to_target[current])
    if (!is.na(target)) {
      oq_set_pstyle(p, ns, target)
      n <- n + 1L
    }
  }
  n
}
