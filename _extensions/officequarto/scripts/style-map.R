## Kernlogik fuer Gruppe 7 (freies Style-Mapping) des officedown-Options-
## Ports: officequarto.style-map (officedown: mapstyles). Wird von
## writeback.R per source() eingebunden, keine eigenstaendige Ausfuehrung.
## Benoetigt: xml2, oq_resolve_style_id()/oq_set_pstyle() aus
## style-mapping.R (muss vor dieser Datei gesourced sein).
##
## Anders als officequarto.styles/.tables/.plots (feste, kuratierte Rollen
## mit Pandoc-spezifischer Erkennungslogik: numPr fuer Listen, w:drawing fuer
## Abbildungen, etc.) ist dies ein generischer Escape-Hatch: eine freie
## Zuordnungstabelle Ziel-Style -> Liste von Quell-pStyle-IDs, die direkt per
## pStyle-Gleichheitsvergleich umgemappt werden - keine Detection-Logik, der
## Nutzer gibt die genauen Style-IDs an, die umgemappt werden sollen.
##
## Quell- und Ziel-Seite werden bewusst asymmetrisch behandelt (wie schon bei
## SourceCode/code-block in style-mapping.R): die Quell-Seite sind Pandocs
## eigene, stabile, technische Style-IDs (z.B. "Normal", "BlockQuote",
## "Heading1") - direkter Gleichheitsvergleich, keine Aufloesung noetig, und
## kein Fehler, wenn eine Quell-ID im konkreten Dokument gar nicht vorkommt
## (dann ist die Regel dort einfach wirkungslos). Die Ziel-Seite ist ein
## echter, in reference-doc sichtbarer Style, deshalb ueber
## oq_resolve_style_id() als Anzeigename aufgeloest (fail-loud wie ueberall
## sonst in diesem Projekt).
##
## Laeuft bewusst als LETZTER Schritt der Style-Mapping-Pipeline in
## writeback.R (nach officequarto.styles/.lists/.pandoc-styles/.tables/.plots) -
## zu diesem Zeitpunkt tragen die meisten Absaetze bereits ihre finale
## pStyle, sodass eine uebliche Regel (Pandoc-Quellnamen als Schluessel)
## automatisch nur noch unberuehrte Absaetze trifft, waehrend eine bewusst
## auf einen bereits umgemappten Zielnamen zielende Regel diesen trotzdem
## noch erreichen kann.

## Loest die Konfiguration (benannte Liste: Ziel-Style-Anzeigename -> Vektor
## von Quell-pStyle-IDs) in eine Named Character Vector Quell-pStyle-ID ->
## Ziel-styleId auf. Bricht (ueber fail_fn) ab, wenn ein Ziel-Style-Name
## nicht in reference-doc existiert, oder eine Quell-pStyle-ID mehreren
## Zielen zugeordnet wird (mehrdeutig).
oq_resolve_style_map <- function(style_map_config, name_to_id, fail_fn) {
  source_to_target <- character(0)
  for (target_name in names(style_map_config)) {
    target_id <- oq_resolve_style_id(
      name_to_id, target_name,
      sprintf("officequarto.style-map.\"%s\"", target_name), fail_fn
    )
    source_ids <- style_map_config[[target_name]]
    for (source_id in source_ids) {
      if (source_id %in% names(source_to_target)) {
        fail_fn(
          paste0(
            "officequarto.style-map: Quell-Style '%s' ist mehreren Zielen zugeordnet ",
            "('%s' und '%s') - jeder Quell-Style darf nur einem Ziel zugeordnet sein."
          ),
          source_id, source_to_target[[source_id]], target_id
        )
      }
      source_to_target[[source_id]] <- target_id
    }
  }
  source_to_target
}

## Wendet die aufgeloeste Quell-pStyle-ID -> Ziel-styleId-Zuordnung auf jeden
## Absatz eines geparsten document.xml an (in-place via
## xml2-Referenzsemantik). Absaetze ohne pStyle gelten als "Normal" (wie
## ueberall sonst in diesem Projekt). Gibt die Anzahl umgemappter Absaetze
## zurueck.
oq_apply_style_map <- function(document_doc, source_to_target) {
  if (length(source_to_target) == 0) return(0L)
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- xml2::xml_find_all(document_doc, "//w:p", ns)

  n <- 0L
  for (p in paragraphs) {
    pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
    current <- if (is.na(pstyle_node)) "Normal" else xml2::xml_attr(pstyle_node, "val")
    target <- unname(source_to_target[current])
    if (!is.na(target)) {
      oq_set_pstyle(p, ns, target)
      n <- n + 1L
    }
  }
  n
}
