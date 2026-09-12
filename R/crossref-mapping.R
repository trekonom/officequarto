## Core logic for Gruppe 9 (cross-reference numbering) of the officedown
## option port: officequarto.crossref.numbered (officedown:
## reference_num). Part of the officequarto R package - used by
## oq_writeback() (R/writeback.R), not run standalone. Requires: xml2.
##
## officedown/bookdown displays cross-references as a number by default
## ("Table 1"). `numbered: false` instead displays the caption's
## descriptive text without a number (e.g. "Quarterly figures"). Like
## tab.lp/fig.lp and like pre/sep/number-bold in Gruppe 3/5, this concerns
## crossrefs that Quarto/Pandoc already resolve to static text BEFORE this
## post-render hook ever runs (w:hyperlink with w:anchor pointing at the
## caption's bookmark, verified empirically during the tab.lp research
## before Gruppe 1) - there's no live field that could be switched, only
## text that gets replaced. anchor_text (see oq_apply_captions() in
## table-caption-mapping.R) already supplies the needed bookmark-name ->
## caption-text mapping for this, collected during caption processing
## (Gruppe 3/5) - regardless of whether those are configured themselves
## (writeback.R ensures Gruppe 3/5 run "silently", without their own
## style/text changes, as soon as officequarto.crossref.numbered: false is
## set, even when officequarto.tables.caption/.plots.caption themselves
## aren't configured).

## Replaces the text of every w:hyperlink[@w:anchor] whose anchor is a key
## in anchor_text with the corresponding caption text (in-place via xml2
## reference semantics). A hyperlink can have several runs (e.g. with
## inline formatting around the reference text) - the first run gets the
## full replacement text, all further runs are removed (Pandoc's generated
## crossref hyperlinks are typically a single run; multiple runs are
## handled here defensively, not as the expected case). Returns the number
## of replaced hyperlinks.
#' @noRd
oq_apply_crossref_text <- function(document_doc, anchor_text) {
  if (length(anchor_text) == 0) return(0L)
  ns <- xml2::xml_ns(document_doc)
  hyperlinks <- xml2::xml_find_all(document_doc, "//w:hyperlink[@w:anchor]", ns)

  n <- 0L
  for (link in hyperlinks) {
    anchor <- xml2::xml_attr(link, "anchor")
    if (is.na(anchor) || !(anchor %in% names(anchor_text))) next

    runs <- xml2::xml_find_all(link, "./w:r", ns)
    if (length(runs) == 0) next

    t_node <- xml2::xml_find_first(runs[[1]], "./w:t", ns)
    if (is.na(t_node)) next

    xml2::xml_text(t_node) <- anchor_text[[anchor]]
    if (length(runs) > 1) {
      for (extra_run in runs[-1]) xml2::xml_remove(extra_run)
    }
    n <- n + 1L
  }

  n
}

## Replaces the content of every w:hyperlink[@w:anchor] whose anchor
## appears in converted_anchors (returned by oq_apply_captions()'s field
## conversion, see table-caption-mapping.R/oq_convert_caption_to_field())
## with a real, live-numbering Word REF field instead of static text - for
## officequarto.crossref.auto-number (no officedown equivalent,
## {officedown} is always field-based). Field code " REF <anchor> \h " (via
## the hyperlink switch, analogous to {officer}'s run_reference() -
## bytecode-introspected, see dev/spike-notes.md Spike P), as a 3-run field
## (fldChar begin -> instrText -> fldChar end, both with w:dirty="true", NO
## fldChar type="separate", no cached-result run - exactly the same
## pattern as the SEQ field in oq_convert_caption_to_field()).
## {officedown} confirms: clickability comes from the w:hyperlink element
## itself (already present, unchanged), not from the \h switch alone -
## only the content INSIDE the hyperlink changes.
##
## Unlike oq_apply_crossref_text() (which reuses the first run), ALL
## existing runs are removed here, since their static text content isn't
## reused in the field case - only the rPr of the first run (e.g.
## w:rStyle="Hyperlink") is carried over onto all three new field runs
## (via oq_clone_rpr_with_bold() from table-caption-mapping.R, the same
## helper function oq_convert_caption_to_field() uses for the SEQ field -
## here without number_bold, i.e. pure rPr cloning with no bold override),
## so the cross-reference still visually looks like a hyperlink even
## before Word replaces the field with the actual number on its next
## recalculation (automatic on layout/open, see above). A hyperlink with
## no runs at all (an atypical document) is left untouched, the same
## defensive handling as in oq_apply_crossref_text(). Returns the number
## of converted hyperlinks.
#' @noRd
oq_apply_crossref_fields <- function(document_doc, converted_anchors) {
  if (length(converted_anchors) == 0) return(0L)
  ns <- xml2::xml_ns(document_doc)
  hyperlinks <- xml2::xml_find_all(document_doc, "//w:hyperlink[@w:anchor]", ns)

  n <- 0L
  for (link in hyperlinks) {
    anchor <- xml2::xml_attr(link, "anchor")
    if (is.na(anchor) || !(anchor %in% converted_anchors)) next

    runs <- xml2::xml_find_all(link, "./w:r", ns)
    if (length(runs) == 0) next

    orig_rpr <- xml2::xml_find_first(runs[[1]], "./w:rPr", ns)
    apply_pr <- function(run) oq_clone_rpr_with_bold(run, orig_rpr, ns)
    for (r in runs) xml2::xml_remove(r)

    begin_run <- xml2::xml_add_child(link, "w:r")
    apply_pr(begin_run)
    begin_fld <- xml2::xml_add_child(begin_run, "w:fldChar")
    xml2::xml_attr(begin_fld, "w:fldCharType") <- "begin"
    xml2::xml_attr(begin_fld, "w:dirty") <- "true"

    instr_run <- xml2::xml_add_child(link, "w:r")
    apply_pr(instr_run)
    instr_node <- xml2::xml_add_child(instr_run, "w:instrText")
    xml2::xml_attr(instr_node, "xml:space") <- "preserve"
    xml2::xml_text(instr_node) <- sprintf(" REF %s \\h ", anchor)

    end_run <- xml2::xml_add_child(link, "w:r")
    apply_pr(end_run)
    end_fld <- xml2::xml_add_child(end_run, "w:fldChar")
    xml2::xml_attr(end_fld, "w:fldCharType") <- "end"
    xml2::xml_attr(end_fld, "w:dirty") <- "true"

    n <- n + 1L
  }

  n
}
