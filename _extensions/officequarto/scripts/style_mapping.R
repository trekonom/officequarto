## Kernlogik fuer das konfigurierbare Style-Mapping (Body/Listen).
## Wird von writeback.R per source() eingebunden, keine eigenstaendige
## Ausfuehrung. Benoetigt: xml2 (bereits von writeback.R geprueft).
##
## Hintergrund: Pandoc verwendet fuer Body- und Listen-Absaetze KEINE einzige
## feste Style-ID, sondern je nach reference-doc/Kontext eine von mehreren
## Rollen-Namen (z.B. "FirstParagraph" fuer den ersten Absatz nach einer
## Ueberschrift, "Compact" fuer eng gesetzte/tight Listen, sonst "Normal").
## Verlaesslich unterscheidbar ist dagegen die Praesenz von <w:numPr> (=
## Listen-Absatz); Bullet vs. Nummerierung steckt in word/numbering.xml
## (w:numFmt), nicht im pStyle-Namen. Deshalb: Listen-Absaetze werden ueber
## numPr erkannt, Body-Absaetze ueber eine Allowlist bekannter Pandoc-Rollen.

officequarto_body_role_styles <- c("Normal", "FirstParagraph", "Compact", "BodyText", "Body Text")

## styles.xml (xml2-Dokument) -> Named Character Vector: Anzeigename -> styleId
oq_style_name_to_id <- function(styles_doc) {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(styles_doc, "//w:style[@w:type='paragraph']", ns)
  ids <- xml2::xml_attr(nodes, "styleId")
  nm <- xml2::xml_text(xml2::xml_find_first(nodes, "./w:name/@w:val", ns))
  stats::setNames(ids, nm)
}

## Loest einen vom Nutzer angegebenen Anzeigenamen zu einer styleId auf.
## Bricht mit einer Liste verfuegbarer Namen ab, wenn nicht gefunden.
oq_resolve_style_id <- function(name_to_id, display_name, role, fail_fn) {
  if (display_name %in% names(name_to_id)) {
    return(unname(name_to_id[[display_name]]))
  }
  fail_fn(
    "Style '%s' (officequarto-styles.%s) wurde im reference-doc nicht gefunden. Verfuegbare Paragraph-Styles: %s",
    display_name, role, paste(sort(names(name_to_id)), collapse = ", ")
  )
}

## numbering.xml (xml2-Dokument) -> Named Character Vector: numId -> numFmt (Ebene 0)
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

## Wendet das Style-Mapping direkt auf ein geparstes document.xml an (in-place
## via xml2-Referenzsemantik). style_ids ist eine Liste mit optionalen
## Eintraegen $body/$list_bullet/$list_number (jeweils eine styleId oder NULL).
oq_apply_style_mapping <- function(document_doc, num_fmt_map, style_ids) {
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- xml2::xml_find_all(document_doc, "//w:body/w:p | //w:body//w:tbl//w:p", ns)

  n_body <- 0L
  n_list <- 0L

  for (p in paragraphs) {
    num_id_node <- xml2::xml_find_first(p, "./w:pPr/w:numPr/w:numId", ns)

    if (!is.na(num_id_node)) {
      num_id <- xml2::xml_attr(num_id_node, "val")
      fmt <- unname(num_fmt_map[num_id])
      target <- if (identical(fmt, "bullet")) style_ids$list_bullet else style_ids$list_number
      if (!is.null(target)) {
        oq_set_pstyle(p, ns, target)
        n_list <- n_list + 1L
      }
      next
    }

    if (is.null(style_ids$body)) next
    pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
    current <- if (is.na(pstyle_node)) "Normal" else xml2::xml_attr(pstyle_node, "val")
    if (current %in% officequarto_body_role_styles) {
      oq_set_pstyle(p, ns, style_ids$body)
      n_body <- n_body + 1L
    }
  }

  list(n_body = n_body, n_list = n_list)
}

## Setzt (oder erzeugt) das w:pStyle-Element eines Absatzes auf die gegebene styleId.
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
