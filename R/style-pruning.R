## Removes all style definitions from the rendered word/styles.xml that
## aren't present in the reference-doc itself. Part of the officequarto
## R package - used by oq_writeback() (R/writeback.R), not run
## standalone. Requires: xml2.
##
## Background: Pandoc's docx writer always adds its own style definitions
## when rendering, ones that don't exist in the reference-doc - e.g.
## syntax-highlighting styles (SourceCode, KeywordTok, StringTok, ...) for
## code blocks, regardless of whether the document contains any code blocks
## at all. The reference-doc loses nothing in the process (Pandoc copies its
## styles unchanged), only foreign styles are added on top. officequarto
## removes those again, unconditionally (no configuration option) - the
## resulting docx is meant to contain only styles from the reference-doc.
##
## If a to-be-removed style is still referenced in the rendered content
## (e.g. a real code block using Pandoc's SourceCode style, or - without
## officequarto.styles/.lists configuration - one of Pandoc's own body/
## list role names like FirstParagraph/Compact, if the reference-doc doesn't
## know them), the definition is still removed; the affected paragraphs/runs
## then fall back to Word's default formatting. This isn't prevented, but it
## is logged in writeback.R.
##
## Exception (optional, configurable via `officequarto.pandoc-styles.code-block:
## true`): Pandoc's code-block styles can be deliberately exempted from
## removal - see oq_is_pandoc_code_style_id() and its use in writeback.R.

## TRUE for Pandoc's own syntax-highlighting style IDs (SourceCode + all
## *Tok character styles) - a stable, fixed naming convention of Pandoc's
## docx writer (see dev/spike-notes.md, Spike E).
#' @noRd
oq_is_pandoc_code_style_id <- function(id) id == "SourceCode" | grepl("Tok$", id)

## styles.xml (xml2 document) -> character vector of all styleIds (all
## types: paragraph/character/table/numbering).
#' @noRd
oq_all_style_ids <- function(styles_doc) {
  ns <- xml2::xml_ns(styles_doc)
  xml2::xml_attr(xml2::xml_find_all(styles_doc, "//w:style", ns), "styleId")
}

## One or more parsed content xml2 documents (document.xml,
## footnotes.xml, ...) -> character vector of all style IDs actually
## referenced (w:pStyle/w:rStyle/w:tblStyle).
#' @noRd
oq_referenced_style_ids <- function(docs) {
  ids <- character(0)
  for (doc in docs) {
    ns <- xml2::xml_ns(doc)
    nodes <- xml2::xml_find_all(
      doc, "//w:pStyle/@w:val | //w:rStyle/@w:val | //w:tblStyle/@w:val", ns
    )
    ids <- c(ids, xml2::xml_text(nodes))
  }
  unique(ids)
}

## Removes every <w:style> from styles_doc (in-place via xml2 reference
## semantics) whose styleId isn't contained in ref_style_ids. Returns a
## list with $removed (all removed IDs) and $removed_but_referenced (the
## subset of those still occurring in referenced_ids), for logging in
## writeback.R.
#' @noRd
oq_prune_foreign_styles <- function(styles_doc, ref_style_ids, referenced_ids) {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(styles_doc, "//w:style", ns)

  removed <- character(0)
  removed_but_referenced <- character(0)

  for (node in nodes) {
    id <- xml2::xml_attr(node, "styleId")
    if (!(id %in% ref_style_ids)) {
      removed <- c(removed, id)
      if (id %in% referenced_ids) {
        removed_but_referenced <- c(removed_but_referenced, id)
      }
      xml2::xml_remove(node)
    }
  }

  list(removed = removed, removed_but_referenced = removed_but_referenced)
}
