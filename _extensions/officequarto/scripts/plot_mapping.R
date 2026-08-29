## Kernlogik fuer Gruppe 4 (Abbildungen-Basis) des officedown-Options-Ports:
## officequarto.plots.style/align. Wird von writeback.R per source()
## eingebunden, keine eigenstaendige Ausfuehrung. Benoetigt: xml2,
## oq_set_pstyle() aus style_mapping.R (muss vor dieser Datei gesourced
## sein).
##
## `fig.lp` (officedown) wurde bewusst NICHT portiert - identische
## Begruendung wie `tab.lp` (siehe table_mapping.R/README): ein
## bookdown-Autoren-Syntax-Konzept ohne Entsprechung in Quartos
## Post-Render-Architektur.
##
## `topcaption` (officedown: Beschriftung oben/unten) ist bewusst NICHT Teil
## dieser Datei - es ist eine strukturelle Absatz-Umsortierung (Beschriftung
## vor/nach der Abbildung), analog zum bewusst zurueckgestellten
## officequarto.tables.caption.above (siehe table_mapping.R), und soll
## gemeinsam fuer Tabellen UND Abbildungen implementiert werden, sobald
## Gruppe 5 (Abbildungs-Beschriftungen) steht.

## Findet alle Abbildungs-Absaetze: ein w:p mit einem w:drawing-Nachfahren -
## verlaesslicher als ueber den pStyle-Namen, da Pandoc dafuer denselben
## kontextabhaengigen Rollennamen wie fuer Body-Absaetze verwendet (z.B.
## "Compact", empirisch verifiziert) - siehe style_mapping.R, das
## w:drawing-Absaetze deshalb explizit von der Body-Rollen-Zuordnung
## ausnimmt, damit sich die beiden Features nicht um denselben Absatz
## streiten.
oq_find_plot_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(document_doc, "//w:p[.//w:drawing]", ns)
}

## Setzt (oder erzeugt) w:jc (Absatz-Ausrichtung) eines Absatzes. align ist
## bereits der validierte OOXML-Wert ("left"/"center"/"right").
oq_set_paragraph_align <- function(p, ns, align) {
  ppr <- xml2::xml_find_first(p, "./w:pPr", ns)
  if (is.na(ppr)) {
    ppr <- xml2::xml_add_child(p, "w:pPr", .where = 0)
  }
  jc_node <- xml2::xml_find_first(ppr, "./w:jc", ns)
  if (is.na(jc_node)) {
    jc_node <- xml2::xml_add_child(ppr, "w:jc")
  }
  xml2::xml_attr(jc_node, "w:val") <- align
  invisible(NULL)
}

## Wendet plot_options ($style/$align, jeweils optional) auf jeden
## Abbildungs-Absatz an (in-place via xml2-Referenzsemantik). Gibt die Anzahl
## bearbeiteter Absaetze zurueck.
oq_apply_plot_options <- function(document_doc, plot_options) {
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- oq_find_plot_paragraphs(document_doc, ns)

  for (p in paragraphs) {
    if (!is.null(plot_options$style)) oq_set_pstyle(p, ns, plot_options$style)
    if (!is.null(plot_options$align)) oq_set_paragraph_align(p, ns, plot_options$align)
  }

  length(paragraphs)
}
