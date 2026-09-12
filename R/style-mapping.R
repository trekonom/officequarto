## Core logic for the configurable style mapping (body/lists).
## Part of the officequarto R package - used by oq_writeback() (R/writeback.R),
## not run standalone. Requires: xml2.
##
## Background: Pandoc does NOT use a single fixed style ID for body and
## list paragraphs, but instead, depending on reference-doc/context, one of
## several role names (e.g. "FirstParagraph" for the first paragraph after
## a heading, "Compact" for tight-set lists, otherwise "Normal"). What is
## reliably distinguishable, though, is the presence of <w:numPr> (= list
## paragraph); bullet vs. numbering lives in word/numbering.xml (w:numFmt),
## not in the pStyle name. Hence: list paragraphs are detected via numPr,
## body paragraphs via an allowlist of known Pandoc roles.

#' @noRd
officequarto_body_role_styles <- c("Normal", "FirstParagraph", "Compact", "BodyText", "Body Text")

## styles.xml (xml2 document) -> named character vector: display name -> styleId.
## type is the OOXML style type ("paragraph" for body/list/code-block
## styles, "table" for table styles, see table-mapping.R).
#' @noRd
oq_style_name_to_id <- function(styles_doc, type = "paragraph") {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(styles_doc, sprintf("//w:style[@w:type='%s']", type), ns)
  ids <- xml2::xml_attr(nodes, "styleId")
  nm <- xml2::xml_text(xml2::xml_find_first(nodes, "./w:name/@w:val", ns))
  stats::setNames(ids, nm)
}

## Resolves a user-supplied display name to a styleId. Aborts with a list
## of available names if not found. `key` is the full configuration path
## for the error message (e.g. "officequarto.styles.body" or
## "officequarto.pandoc-styles.code-block").
#' @noRd
oq_resolve_style_id <- function(name_to_id, display_name, key, fail_fn) {
  if (display_name %in% names(name_to_id)) {
    return(unname(name_to_id[[display_name]]))
  }
  fail_fn(
    "Style '%s' (%s) was not found in the reference-doc. Available paragraph styles: %s",
    display_name, key, paste(sort(names(name_to_id)), collapse = ", ")
  )
}

## Vectorized variant of oq_resolve_style_id() for options that can carry
## their own style name per nesting level (officequarto.lists.list-bullet/
## list-number/list-letter as an array instead of a scalar - index 0 = top
## level). A scalar call (vector of length 1) behaves identically to a
## direct oq_resolve_style_id() call.
#' @noRd
oq_resolve_style_ids <- function(name_to_id, display_names, key, fail_fn) {
  if (length(display_names) == 0) {
    fail_fn("%s: empty array - at least one style name is required.", key)
  }
  vapply(display_names, function(nm) {
    oq_resolve_style_id(name_to_id, nm, key, fail_fn)
  }, character(1), USE.NAMES = FALSE)
}

## styles.xml (xml2 document) -> named character vector: styleId -> numId,
## only for styles that themselves carry a numbering (w:pPr/w:numPr in the
## style definition - typically coupled via w:numStyleLink to a dedicated
## numbering style definition, see oq_apply_style_mapping).
#' @noRd
oq_style_num_id <- function(styles_doc) {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(
    styles_doc, "//w:style[@w:type='paragraph'][./w:pPr/w:numPr/w:numId]", ns
  )
  ids <- xml2::xml_attr(nodes, "styleId")
  num_ids <- xml2::xml_attr(xml2::xml_find_first(nodes, "./w:pPr/w:numPr/w:numId", ns), "val")
  stats::setNames(num_ids, ids)
}

## numbering.xml (xml2 document) -> named character vector: numId -> numFmt
## (level 0). A level-0 lookup suffices for EVERY paragraph referencing
## this numId, regardless of its own w:ilvl - verified via a real render
## (dev/spike-notes.md, Spike O): Pandoc assigns a separate numId/
## abstractNum per nesting level of a list, and every abstractNum created
## this way carries the identical w:numFmt at all 9 w:lvl entries. A numId
## with a different numFmt per level does not occur for Pandoc-generated
## lists.
#' @noRd
oq_num_fmt_map <- function(numbering_doc) {
  ns <- xml2::xml_ns(numbering_doc)
  abstract_nodes <- xml2::xml_find_all(numbering_doc, "//w:abstractNum", ns)
  abstract_ids <- xml2::xml_attr(abstract_nodes, "abstractNumId")
  lvl0_fmt <- vapply(abstract_nodes, function(n) {
    lvl0 <- xml2::xml_find_first(n, ".//w:lvl[@w:ilvl='0']/w:numFmt/@w:val", ns)
    if (is.na(lvl0)) NA_character_ else xml2::xml_text(lvl0)
  }, character(1))
  fmt_by_abstract <- stats::setNames(lvl0_fmt, abstract_ids)

  num_nodes <- xml2::xml_find_all(numbering_doc, "//w:num", ns)
  num_ids <- xml2::xml_attr(num_nodes, "numId")
  abstract_refs <- xml2::xml_attr(
    xml2::xml_find_first(num_nodes, "./w:abstractNumId", ns), "val"
  )
  stats::setNames(unname(fmt_by_abstract[abstract_refs]), num_ids)
}

## numFmt values that Word treats as letter lists (a/b/c or A/B/C) - its
## own bucket, separate from "everything else, not bullet" (= list_number:
## decimal, roman, etc.). No officedown equivalent, officequarto's own
## option with no alias.
#' @noRd
officequarto_letter_num_fmts <- c("lowerLetter", "upperLetter")

## Paragraph -> nesting level (0-based, from w:pPr/w:numPr/w:ilvl). For
## Pandoc-generated lists, w:ilvl is explicitly set on every list paragraph
## (verified, Spike O) - the default of 0 when the element is missing is
## nonetheless ECMA-376-compliant and a sensible safeguard for other
## sources.
#' @noRd
oq_paragraph_ilvl <- function(p, ns) {
  ilvl_node <- xml2::xml_find_first(p, "./w:pPr/w:numPr/w:ilvl", ns)
  if (is.na(ilvl_node)) 0L else as.integer(xml2::xml_attr(ilvl_node, "val"))
}

## Picks, from a vector of configured styles (index 0 = top level), the
## entry matching the given nesting level. If the list is shorter than the
## actual nesting, it clamps to the last (deepest configured) entry -
## mirroring Word's own built-in convention (e.g. "List Bullet 3" as the
## deepest named level, more deeply nested paragraphs visually keep reusing
## it). A vector of length 1 ("scalar" configuration) always returns the
## same value regardless of level - no separate scalar code path needed.
#' @noRd
oq_style_for_level <- function(styles, ilvl) {
  idx <- min(ilvl + 1L, length(styles))
  styles[[idx]]
}

## XPath paragraph selector for word/footnotes.xml or word/endnotes.xml
## (root w:footnotes/w:endnotes, no w:body - paragraphs hang either
## directly, or, for a table inside a footnote/endnote, nested under
## w:footnote/w:endnote). Excludes the two infrastructure entries Word
## itself always creates with w:type="separator"/"continuationSeparator"
## (IDs -1/0, plain separator-line markers with no body role of their
## own) - their paragraph carries NO w:pStyle of its own in practice, so
## it falls back to "Normal" by default, and would otherwise be falsely
## caught both by the body-role mapping (officequarto.styles.body) and by
## a generic officequarto.style-map rule like "X": [Normal] - not just a
## defensive safeguard, but a necessity. `container` is "footnote" or
## "endnote". Used both by oq_apply_style_mapping() here and by
## oq_apply_style_map() (style-map.R) as paragraph_xpath (see writeback.R,
## Issue #2 "Footnote/endnote paragraph styling").
#' @noRd
oq_note_paragraph_xpath <- function(container) {
  excl <- "not(@w:type='separator' or @w:type='continuationSeparator')"
  sprintf("//w:%1$s[%2$s]/w:p | //w:%1$s[%2$s]//w:tbl//w:p", container, excl)
}

## Applies the style mapping directly to a parsed document.xml (or, via
## paragraph_xpath, footnotes.xml/endnotes.xml - see
## oq_note_paragraph_xpath() above) (in-place via xml2 reference
## semantics). style_ids is a list with optional entries $body/$code
## (each a styleId or NULL) and $list_bullet/$list_number/$list_letter
## (each a character vector of styleIds, one entry per nesting level -
## length 1 = the same style at every level, vectors shorter than the
## actual nesting clamp to the last entry, see oq_style_for_level - or
## NULL). style_num_id (see oq_style_num_id) says which target styles
## themselves carry a numbering.
##
## For footnotes/endnotes (paragraph_xpath = oq_note_paragraph_xpath(...))
## the body-role allowlist (style_ids$body) structurally NEVER fires:
## Pandoc never renders footnote text under one of its context-dependent
## body role names (Normal/FirstParagraph/Compact/...), but instead either
## under the reference-doc's own already-correctly-reused (possibly
## localized) style ID, or - if reference-doc doesn't define one of its
## own - under the fixed, never-defined Pandoc/Word fallback ID
## "FootnoteText"/"EndnoteText" (see README "Footnotes and endnotes"). The
## list/SourceCode detection, on the other hand, applies unchanged if a
## footnote/endnote itself contains a list or a code block - which is why
## it's safe to run this function unchanged against footnotes.xml/
## endnotes.xml as well.
#' @noRd
oq_apply_style_mapping <- function(document_doc, num_fmt_map, style_ids, style_num_id,
                                    paragraph_xpath = "//w:body/w:p | //w:body//w:tbl//w:p") {
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- xml2::xml_find_all(document_doc, paragraph_xpath, ns)

  n_body <- 0L
  n_list <- 0L
  n_code <- 0L
  n_list_clamped <- 0L

  for (p in paragraphs) {
    num_id_node <- xml2::xml_find_first(p, "./w:pPr/w:numPr/w:numId", ns)

    if (!is.na(num_id_node)) {
      num_id <- xml2::xml_attr(num_id_node, "val")
      ilvl <- oq_paragraph_ilvl(p, ns)
      fmt <- unname(num_fmt_map[num_id])
      styles_vec <- if (identical(fmt, "bullet")) {
        style_ids$list_bullet
      } else if (fmt %in% officequarto_letter_num_fmts) {
        style_ids$list_letter
      } else {
        style_ids$list_number
      }
      target <- if (!is.null(styles_vec)) oq_style_for_level(styles_vec, ilvl) else NULL
      if (!is.null(target)) {
        if (ilvl + 1L > length(styles_vec)) n_list_clamped <- n_list_clamped + 1L
        oq_set_pstyle(p, ns, target)
        ## A direct w:numPr on the paragraph (set by Pandoc, pointing at
        ## Pandoc's own generic bullet/decimal numbering) ALWAYS takes
        ## precedence in Word over the numbering defined in the target
        ## style itself. If the target style brings its own numbering, the
        ## paragraph-level override must therefore be removed, or else
        ## Pandoc's numbering remains visually present even though the
        ## pStyle was correctly remapped.
        if (target %in% names(style_num_id)) {
          xml2::xml_remove(xml2::xml_parent(num_id_node))
        }
        n_list <- n_list + 1L
      }
      next
    }

    pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
    current <- if (is.na(pstyle_node)) "Normal" else xml2::xml_attr(pstyle_node, "val")

    ## SourceCode is - unlike Normal/FirstParagraph/Compact - a stable,
    ## fixed Pandoc style ID (not a context-dependent role name), so a
    ## direct equality check suffices instead of an allowlist.
    if (identical(current, "SourceCode") && !is.null(style_ids$code)) {
      oq_set_pstyle(p, ns, style_ids$code)
      n_code <- n_code + 1L
      next
    }

    ## Figure paragraphs (containing a w:drawing) carry, under Pandoc, the
    ## same context-dependent role name as real body paragraphs (e.g.
    ## "Compact", verified empirically) - so they would otherwise be
    ## falsely caught by the body-role mapping. Excluded here and handled
    ## instead, dedicated, by oq_apply_plot_options() (plot-mapping.R,
    ## officequarto.plots.style).
    if (!is.na(xml2::xml_find_first(p, ".//w:drawing", ns))) next

    if (is.null(style_ids$body)) next
    if (current %in% officequarto_body_role_styles) {
      oq_set_pstyle(p, ns, style_ids$body)
      n_body <- n_body + 1L
    }
  }

  list(n_body = n_body, n_list = n_list, n_code = n_code, n_list_clamped = n_list_clamped)
}

## Sets (or creates) a paragraph's w:pStyle element to the given styleId.
#' @noRd
oq_set_pstyle <- function(p, ns, style_id) {
  pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
  if (!is.na(pstyle_node)) {
    xml2::xml_attr(pstyle_node, "w:val") <- style_id
    return(invisible(NULL))
  }
  ppr_node <- xml2::xml_find_first(p, "./w:pPr", ns)
  if (is.na(ppr_node)) {
    ppr_node <- xml2::xml_add_child(p, "w:pPr", .where = 0)
  }
  new_style <- xml2::xml_add_child(ppr_node, "w:pStyle", .where = 0)
  xml2::xml_attr(new_style, "w:val") <- style_id
  invisible(NULL)
}
