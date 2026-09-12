## Core logic for Gruppe 1 (table basics: style/layout/width) and Gruppe 2
## (table conditional formatting: officequarto.tables.conditional.*) of the
## officedown option port. Part of the officequarto R package - used by
## oq_writeback() (R/writeback.R), not run standalone. Requires: xml2 and
## oq_resolve_aliased()/oq_resolve_inverted_aliased() from option-aliases.R
## (in the same package namespace, no explicit load order needed).
##
## `caption-above` (officedown: topcaption) is deliberately NOT part of this
## file - it only has a visible effect once real table captions (Gruppe 3)
## exist and is implemented together with those, rather than existing now
## as an inert placeholder.
##
## `tab.lp` (officedown) was deliberately NOT ported: it's a
## bookdown authoring-syntax concept (label prefix when parsing
## \@ref(tab:xyz)), not a rendering switch, and has no meaningful
## equivalent in Quarto's own crossref system (\#tbl-xyz, resolved by
## Quarto/Pandoc BEFORE this post-render hook ever runs) - see README.

## Order of w:tblPr child elements per the OOXML schema (CT_TblPrBase,
## excerpt - only the ones relevant here and their usual neighbors). Needed
## because xml2::xml_add_child() without .where simply appends at the end;
## a newly created w:tblLayout would otherwise land after Pandoc's own
## w:tblLook, which doesn't match the schema order (Word itself is
## tolerant, but a schema-compliant order is cleaner/more portable).
#' @noRd
officequarto_tblpr_order <- c(
  "tblStyle", "tblpPr", "tblOverlap", "bidiVisual", "tblStyleRowBandSize",
  "tblStyleColBandSize", "tblW", "jc", "tblCellSpacing", "tblInd",
  "tblBorders", "shd", "tblLayout", "tblCellMar", "tblLook",
  "tblCaption", "tblDescription"
)

## Inserts a new child element, locally named "tag_local", into tbl_pr at the
## position that's correct per officequarto_tblpr_order (before the first
## already-existing sibling element that comes later in the order,
## otherwise at the end) and returns the new node.
#' @noRd
oq_add_tbl_pr_child <- function(tbl_pr, tag_local) {
  tag_pos <- match(tag_local, officequarto_tblpr_order)
  existing <- xml2::xml_children(tbl_pr)
  existing_pos <- match(xml2::xml_name(existing), officequarto_tblpr_order)
  insert_before <- which(!is.na(existing_pos) & existing_pos > tag_pos)
  where <- if (length(insert_before) > 0) min(insert_before) - 1L else length(existing)
  xml2::xml_add_child(tbl_pr, paste0("w:", tag_local), .where = where)
}

## Sets (or creates) the w:tblStyle child element of w:tblPr.
#' @noRd
oq_set_tbl_style <- function(tbl_pr, ns, style_id) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblStyle", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblStyle")
  }
  xml2::xml_attr(node, "w:val") <- style_id
  invisible(NULL)
}

## Sets (or creates) the w:tblLayout child element of w:tblPr. layout is
## already the validated OOXML value ("autofit"/"fixed").
#' @noRd
oq_set_tbl_layout <- function(tbl_pr, ns, layout) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblLayout", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblLayout")
  }
  xml2::xml_attr(node, "w:type") <- layout
  invisible(NULL)
}

## Sets (or creates) the w:tblW child element of w:tblPr. width_fraction
## is relative to the page width (0..1, as in officedown); OOXML expects,
## for w:type="pct", the value in fiftieths-of-a-percent (100% page width = 5000).
#' @noRd
oq_set_tbl_width <- function(tbl_pr, ns, width_fraction) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblW", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblW")
  }
  xml2::xml_attr(node, "w:type") <- "pct"
  xml2::xml_attr(node, "w:w") <- as.character(round(width_fraction * 5000))
  invisible(NULL)
}

## Gruppe 2 fields (officequarto.tables.conditional.*) -> their w:tblLook
## attribute plus whether the value must be inverted when written.
## band-rows/band-columns are deliberately phrased positively (see README),
## but OOXML itself only knows the negatively-polarized noHBand/noVBand - the
## inversion happens here when writing, not already at option resolution
## (which holds canonical values in its own, positive polarity, see
## oq_resolve_inverted_aliased() in option-aliases.R).
#' @noRd
officequarto_tbllook_attrs <- list(
  `first-row`    = list(attr = "firstRow",    invert = FALSE),
  `first-column` = list(attr = "firstColumn", invert = FALSE),
  `last-row`     = list(attr = "lastRow",     invert = FALSE),
  `last-column`  = list(attr = "lastColumn",  invert = FALSE),
  `band-rows`    = list(attr = "noHBand",     invert = TRUE),
  `band-columns` = list(attr = "noVBand",     invert = TRUE)
)

## Sets (or creates) w:tblLook attributes of w:tblPr for the fields set in
## conditional_options (names as in officequarto_tbllook_attrs, each
## TRUE/FALSE, or NULL/missing for "not configured, leave unchanged").
#' @noRd
oq_set_tbl_look <- function(tbl_pr, ns, conditional_options) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblLook", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblLook")
  }
  for (key in names(conditional_options)) {
    val <- conditional_options[[key]]
    if (is.null(val)) next
    spec <- officequarto_tbllook_attrs[[key]]
    ooxml_val <- if (isTRUE(spec$invert)) !val else val
    xml2::xml_attr(node, paste0("w:", spec$attr)) <- if (isTRUE(ooxml_val)) "1" else "0"
  }
  invisible(NULL)
}

## Resolves a single boolean officequarto.tables.conditional field
## (canonical name vs. officedown alias, via oq_resolve_aliased() or, for
## invert=TRUE, via oq_resolve_inverted_aliased()) and validates the
## result as a single TRUE/FALSE value (fail-loud, consistent with
## layout/width in Gruppe 1). key_path is the full configuration path for
## the error message.
#' @noRd
oq_resolve_table_bool_option <- function(config, canonical_key, alias_key, invert, key_path, warn_fn, fail_fn) {
  resolved <- if (invert) {
    oq_resolve_inverted_aliased(config, canonical_key, alias_key, "officequarto.tables.conditional", warn_fn)
  } else {
    oq_resolve_aliased(config, canonical_key, alias_key, "officequarto.tables.conditional", warn_fn)
  }
  if (!is.null(resolved) && (!is.logical(resolved) || length(resolved) != 1 || is.na(resolved))) {
    fail_fn("%s must be true or false (got: '%s').", key_path, resolved)
  }
  resolved
}

## Applies table_options ($style/$layout/$width/$conditional, each
## optional) to every w:tbl in a parsed document.xml (in place, via
## xml2's reference semantics). $conditional is a named list as populated
## by oq_resolve_table_bool_option() (names from
## officequarto_tbllook_attrs). Returns the number of tables processed.
#' @noRd
oq_apply_table_options <- function(document_doc, table_options) {
  ns <- xml2::xml_ns(document_doc)
  ## Excludes Pandoc's synthetic wrapper table: for both captioned tables
  ## AND figures, Pandoc combines the caption + actual content into a 1x1
  ## wrapper table whose single cell directly contains a paragraph with
  ## pStyle "ImageCaption" (see table-caption-mapping.R) - this signature
  ## identifies the wrapper table directly and reliably, regardless of
  ## whether it wraps a real table or a figure (an earlier version instead
  ## only filtered out tables containing a nested w:tbl - that correctly
  ## recognized the table case, but not figure wrappers, which contain no
  ## nested table). Without this filter, style/layout/width/conditional
  ## would be incorrectly applied to this invisible structural table too,
  ## not just to the actual data table(s).
  tables <- xml2::xml_find_all(
    document_doc,
    "//w:tbl[not(./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val='ImageCaption')]",
    ns
  )

  for (tbl in tables) {
    tbl_pr <- xml2::xml_find_first(tbl, "./w:tblPr", ns)
    if (is.na(tbl_pr)) {
      tbl_pr <- xml2::xml_add_child(tbl, "w:tblPr", .where = 0)
    }
    if (!is.null(table_options$style)) oq_set_tbl_style(tbl_pr, ns, table_options$style)
    if (!is.null(table_options$layout)) oq_set_tbl_layout(tbl_pr, ns, table_options$layout)
    if (!is.null(table_options$width)) oq_set_tbl_width(tbl_pr, ns, table_options$width)
    has_conditional <- !is.null(table_options$conditional) &&
      any(!vapply(table_options$conditional, is.null, logical(1)))
    if (has_conditional) {
      oq_set_tbl_look(tbl_pr, ns, table_options$conditional)
    }
  }

  length(tables)
}
