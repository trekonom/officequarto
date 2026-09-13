## Fixes up a structural defect that officer inline syntax (R/knit-print.R,
## officer::fp_par() specifically) can leave behind in Pandoc's rendered
## document.xml/footnotes.xml/endnotes.xml. Called unconditionally from
## writeback.R - not gated behind any officequarto.* option, since it's not
## a configurable feature but a correctness fix, needed regardless of
## whether any officequarto option is configured at all (see writeback.R).
##
## Background: knit_print.fp_par() splices officer::to_wml(fp_par(...))'s
## <w:pPr>...</w:pPr> output inline, wherever the `` `r fp_par(...)` ``
## expression sits in the paragraph's text - there is no other way to inject
## paragraph-level properties from an inline R expression. But CT_P (the
## OOXML schema type for w:p) allows at most one w:pPr, and only as the
## paragraph's first child. Left as a second, misplaced w:pPr, real Word
## refuses to open the resulting docx outright (confirmed against actual
## Word, not just XML well-formedness/python-docx, which don't validate this
## and stayed silent). {officedown} has the identical problem, from the
## identical mechanism, and fixes it the identical way: merge the misplaced
## w:pPr's children into the paragraph's real first w:pPr (or promote it to
## be the first child, if the paragraph doesn't have one yet), then drop the
## misplaced one (officedown::process_par_settings(), R/rdocx_post_proc.R).
##
## Deliberately does NOT merge a w:pStyle that lacks a w:val attribute -
## unlike officedown, which merges w:pStyle unconditionally. officer's own
## to_wml.fp_par() (ppr_wml() in officer's R/ooxml.R) has a genuine upstream
## bug: it writes `<w:pStyle w:pstlname="...">`, not the OOXML-required
## `w:val` attribute (verified against the installed officer 0.7.3 source).
## Merging THAT in would silently discard the paragraph's real, correctly
## resolved style for a dead attribute Word ignores, for no benefit -
## fp_par()'s word_style argument can't work through this path regardless of
## whether it's merged. This check is deliberately scoped to "missing w:val"
## rather than "is named pStyle", because Pandoc's OWN caption-wrapper-cell
## paragraphs (see table-caption-mapping.R) independently, natively produce
## the identical two-pPr shape - one generic wrapper-cell-alignment pPr,
## then a second, separate one carrying the real (well-formed, w:val-bearing)
## `pStyle="ImageCaption"` - discovered when report.qmd's own end-to-end
## fixture regressed (table/figure caption detection relies on finding that
## real pStyle, wherever it ends up). A blanket pStyle exclusion broke that
## pre-existing, previously-harmless quirk; excluding only the malformed
## officer shape fixes officer's case without touching Pandoc's own.

#' @noRd
oq_merge_misplaced_ppr <- function(document_doc) {
  ns <- xml2::xml_ns(document_doc)
  ## preceding-sibling::* (any preceding element, regardless of name), not
  ## position() > 1 (which {officedown}'s own process_par_settings() uses):
  ## position() on a w:pPr[...] step counts position among w:pPr siblings
  ## specifically, so it misses a paragraph that has exactly one (misplaced,
  ## non-first-child) w:pPr and no other - a real, verified gap in
  ## officedown's own version, not just a theoretical one (occurs whenever
  ## Pandoc emits a paragraph with no w:pPr of its own at all, e.g. no
  ## explicit pStyle override, and fp_par() is the paragraph's only pPr).
  misplaced <- xml2::xml_find_all(document_doc, "//w:p/w:pPr[preceding-sibling::*]", ns)

  for (pr in misplaced) {
    par <- xml2::xml_parent(pr)
    pr1 <- xml2::xml_child(par, 1)

    if (!is.na(pr1) && identical(xml2::xml_name(pr1), "pPr")) {
      for (child in xml2::xml_children(pr)) {
        if (identical(xml2::xml_name(child), "pStyle") && is.na(xml2::xml_attr(child, "val"))) next
        existing <- xml2::xml_find_first(pr1, sprintf("./w:%s", xml2::xml_name(child)), ns)
        if (!is.na(existing)) {
          xml2::xml_replace(existing, child)
        } else {
          xml2::xml_add_child(pr1, child)
        }
      }
      xml2::xml_remove(pr)
    } else {
      ## xml2 offers no native "move" (xml_add_child()/xml_add_sibling()
      ## always copy, even with copy = FALSE - see oq_move_caption() in
      ## table-caption-mapping.R), hence copy to position 0 (= new first
      ## child, matching this codebase's .where convention elsewhere, e.g.
      ## style-mapping.R/plot-mapping.R) then remove the original.
      xml2::xml_add_child(par, pr, .where = 0)
      xml2::xml_remove(pr)
    }
  }

  length(misplaced)
}
