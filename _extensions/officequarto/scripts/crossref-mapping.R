## Kernlogik fuer Gruppe 9 (Querverweis-Nummerierung) des officedown-
## Options-Ports: officequarto.crossref.numbered (officedown:
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
## wird. anchor_text (siehe oq_apply_captions() in table-caption-mapping.R)
## liefert dafuer bereits die noetige Bookmark-Name -> Beschriftungstext-
## Zuordnung, gesammelt waehrend der Beschriftungsverarbeitung (Gruppe 3/5) -
## unabhaengig davon, ob diese selbst konfiguriert sind (writeback.R stellt
## sicher, dass Gruppe 3/5 "still", ohne eigene Style-/Text-Aenderungen,
## mitlaufen, sobald officequarto.crossref.numbered: false gesetzt ist, auch
## wenn officequarto.tables.caption/.plots.caption selbst nicht konfiguriert
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

## Ersetzt den Inhalt jedes w:hyperlink[@w:anchor], dessen Anker in
## converted_anchors auftaucht (von oq_apply_captions()s Feld-Umwandlung
## zurueckgegeben, siehe table-caption-mapping.R/oq_convert_caption_to_field()),
## durch ein echtes, live nummerierendes Word-REF-Feld statt statischem Text -
## fuer officequarto.crossref.auto-number (kein officedown-Aequivalent,
## {officedown} ist immer feld-basiert). Feldcode " REF <anchor> \h " (per
## Hyperlink-Schalter, analog zu {officer}s run_reference() - bytecode-
## introspiziert, siehe dev/spike-notes.md Spike P), als 3-Lauf-Feld (fldChar
## begin -> instrText -> fldChar end, beide mit w:dirty="true", KEIN
## fldChar type="separate", kein zwischengespeicherter Ergebnis-Lauf - exakt
## dasselbe Muster wie das SEQ-Feld in oq_convert_caption_to_field()).
## {officedown} bestaetigt: die Klickbarkeit kommt vom w:hyperlink-Element
## selbst (bereits vorhanden, unveraendert), nicht vom \h-Schalter allein -
## nur der Inhalt DES Hyperlinks aendert sich.
##
## Anders als oq_apply_crossref_text() (die den ersten Lauf wiederverwendet)
## werden hier SAEMTLICHE vorhandenen Laeufe entfernt, da ihr statischer
## Text-Inhalt im Feld-Fall nicht weiterverwendet wird - nur die rPr des
## ersten Laufs (z.B. w:rStyle="Hyperlink") wird auf alle drei neuen
## Feld-Laeufe uebertragen (via oq_clone_rpr_with_bold() aus
## table-caption-mapping.R, derselben Hilfsfunktion, die
## oq_convert_caption_to_field() fuer das SEQ-Feld verwendet - hier ohne
## number_bold, also reines rPr-Klonen ohne Fett-Override), damit der
## Querverweis optisch weiterhin wie ein Hyperlink aussieht, auch bevor Word
## das Feld bei der naechsten Neuberechnung (automatisch beim Layout/Oeffnen,
## siehe oben) durch die tatsaechliche Zahl ersetzt. Ein Hyperlink ohne jeden
## Lauf (atypisches Dokument) bleibt unangetastet, dieselbe defensive
## Behandlung wie in oq_apply_crossref_text(). Gibt die Anzahl umgewandelter
## Hyperlinks zurueck.
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
