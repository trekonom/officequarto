## Kernlogik fuer Gruppe 9 (Querverweis-Nummerierung) des officedown-
## Options-Ports: officequarto-crossref.numbered (officedown:
## reference_num). Wird von writeback.R per source() eingebunden, keine
## eigenstaendige Ausfuehrung. Benoetigt: xml2.
##
## officedown/bookdown zeigt Querverweise standardmaessig als Nummer
## ("Table 1"). `numbered: false` zeigt stattdessen den Beschriftungstext
## ohne Nummer (z.B. "Quartalskennzahlen"). Wie tab.lp/fig.lp und wie
## pre/sep/number-bold in Gruppe 3/5 betrifft dies bereits von Quarto/Pandoc
## VOR diesem Post-Render-Hook zu statischem Text aufgeloeste Crossrefs
## (w:hyperlink mit w:anchor auf den Beschriftungs-Bookmark, empirisch
## verifiziert bei der tab.lp-Recherche vor Gruppe 1) - es gibt kein
## lebendiges Feld, das umgeschaltet werden koennte, nur Text, der ersetzt
## wird. anchor_text (siehe oq_apply_captions() in table_caption_mapping.R)
## liefert dafuer bereits die noetige Bookmark-Name -> Beschriftungstext-
## Zuordnung, gesammelt waehrend der Beschriftungsverarbeitung (Gruppe 3/5) -
## unabhaengig davon, ob diese selbst konfiguriert sind (writeback.R stellt
## sicher, dass Gruppe 3/5 "still", ohne eigene Style-/Text-Aenderungen,
## mitlaufen, sobald officequarto-crossref.numbered: false gesetzt ist, auch
## wenn officequarto-tables.caption/-plots.caption selbst nicht konfiguriert
## wurden).

## Ersetzt den Text jedes w:hyperlink[@w:anchor], dessen Anker ein
## Schluessel in anchor_text ist, durch den zugehoerigen Beschriftungstext
## (in-place via xml2-Referenzsemantik). Ein Hyperlink kann mehrere Laeufe
## haben (z.B. bei Inline-Formatierung um den Verweistext) - der erste Lauf
## erhaelt den vollen Ersatztext, alle weiteren werden entfernt (Pandocs
## generierte Crossref-Hyperlinks sind typischerweise ein einzelner Lauf;
## mehrere Laeufe werden hier defensiv behandelt, nicht als erwarteter
## Regelfall). Gibt die Anzahl ersetzter Hyperlinks zurueck.
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
