## Kernlogik fuer Gruppe 8 (Seitenlayout) des officedown-Options-Ports:
## officequarto.page.size.{width,height,orientation}/
## margins.{top,bottom,left,right,header,footer,gutter}. Teil des
## officequarto R-Pakets - von oq_writeback() (R/writeback.R) verwendet,
## keine eigenstaendige Ausfuehrung. Benoetigt: xml2.
##
## Anders als alle bisherigen Gruppen betrifft dies nicht Absatz-/
## Tabellen-Styles, sondern Section Properties (w:sectPr/w:pgSz/w:pgMar) -
## Seiten-Layout wird von Pandoc bereits vollstaendig aus reference-doc
## uebernommen (siehe CLAUDE.md), Pandocs docx-Writer bietet dafuer aber
## KEINE YAML-Override-Moeglichkeit (anders als z.B. sein LaTeX/PDF-Writer
## mit geometry-Optionen) - wer Seitenformat/Raender aendern will, ohne
## reference-doc selbst zu bearbeiten, braucht dafuer einen Post-Render-Patch
## wie hier. Wird auf JEDE w:sectPr im Dokument einheitlich angewendet (die
## meisten Dokumente haben genau eine; ein Dokument mit echt
## unterschiedlichen Seiten-Layouts pro Abschnitt ist bewusst nicht das
## Zielszenario, analog zu officedowns eigener Ein-Abschnitt-Annahme).
##
## Werte werden in Zoll (Inches) angegeben (wie bei officedown) und intern
## in Twips umgerechnet (1 Zoll = 1440 Twips, die von w:pgSz/w:pgMar
## erwartete OOXML-Einheit).

#' @noRd
officequarto_twips_per_inch <- 1440

## Setzt (oder erzeugt) w:pgSz-Attribute (w:w/w:h/w:orient) einer w:sectPr.
## size_options: Liste mit optionalen $width/$height (Zoll)/$orientation
## ("portrait"/"landscape", bereits validiert). Kein automatisches
## Vertauschen von Breite/Hoehe bei orientation: landscape - wie bei
## officedown liegt das in der Verantwortung des Nutzers.
#' @noRd
oq_set_page_size <- function(sect_pr, ns, size_options) {
  node <- xml2::xml_find_first(sect_pr, "./w:pgSz", ns)
  if (is.na(node)) {
    node <- xml2::xml_add_child(sect_pr, "w:pgSz", .where = 0)
  }
  if (!is.null(size_options$width)) {
    xml2::xml_attr(node, "w:w") <- as.character(round(size_options$width * officequarto_twips_per_inch))
  }
  if (!is.null(size_options$height)) {
    xml2::xml_attr(node, "w:h") <- as.character(round(size_options$height * officequarto_twips_per_inch))
  }
  if (!is.null(size_options$orientation)) {
    xml2::xml_attr(node, "w:orient") <- size_options$orientation
  }
  invisible(NULL)
}

## Setzt (oder erzeugt) w:pgMar-Attribute (top/bottom/left/right/header/
## footer/gutter) einer w:sectPr. margin_options: Liste mit den jeweils
## optionalen Feldern (Zoll).
#' @noRd
oq_set_page_margins <- function(sect_pr, ns, margin_options) {
  node <- xml2::xml_find_first(sect_pr, "./w:pgMar", ns)
  if (is.na(node)) {
    node <- xml2::xml_add_child(sect_pr, "w:pgMar")
  }
  for (field in c("top", "bottom", "left", "right", "header", "footer", "gutter")) {
    val <- margin_options[[field]]
    if (!is.null(val)) {
      xml2::xml_attr(node, paste0("w:", field)) <- as.character(round(val * officequarto_twips_per_inch))
    }
  }
  invisible(NULL)
}

## Wendet page_options ($size/$margins, jeweils optional mit weiteren
## optionalen Unterfeldern) auf jede w:sectPr im Dokument an (in-place via
## xml2-Referenzsemantik). Gibt die Anzahl bearbeiteter Sections zurueck.
#' @noRd
oq_apply_page_options <- function(document_doc, page_options) {
  ns <- xml2::xml_ns(document_doc)
  sections <- xml2::xml_find_all(document_doc, "//w:sectPr", ns)

  has_size <- !is.null(page_options$size) && any(!vapply(page_options$size, is.null, logical(1)))
  has_margins <- !is.null(page_options$margins) && any(!vapply(page_options$margins, is.null, logical(1)))

  for (sect_pr in sections) {
    if (has_size) oq_set_page_size(sect_pr, ns, page_options$size)
    if (has_margins) oq_set_page_margins(sect_pr, ns, page_options$margins)
  }

  length(sections)
}
