## Kernlogik fuer Gruppe 5 (Abbildungs-Beschriftungen) des officedown-
## Options-Ports: officequarto.plots.caption.style/prefix/separator/
## number-bold. Die eigentliche Text-Umformatierungslogik ist identisch zu
## Gruppe 3 (Tabellen-Beschriftungen) und lebt deshalb gemeinsam in
## table_caption_mapping.R (oq_apply_captions()/oq_split_caption_text()/
## oq_write_caption_run()) - diese Datei traegt nur die
## Abbildungs-spezifische Erkennung bei. Wird von writeback.R per source()
## eingebunden, keine eigenstaendige Ausfuehrung. Benoetigt: xml2 sowie
## oq_apply_captions() aus table_caption_mapping.R (muss vor dieser Datei
## gesourced sein).
##
## `tnd`/`tns` wurden aus identischem Grund wie bei Gruppe 3 NICHT portiert
## (siehe table_caption_mapping.R/README): Quarto/Pandoc nummeriert
## Abbildungen ausschliesslich global/fortlaufend.

## Findet alle Abbildungs-Beschriftungsabsaetze in Dokumentreihenfolge.
## Erkannt als Absatz mit pStyle "ImageCaption" (Pandocs Style fuer
## Abbildungs-Beschriftungen - im Gegensatz zu Tabellen nutzt Pandoc hierfuer
## immer "ImageCaption", ob mit oder ohne Quarto-Crossref-ID, siehe
## oq_find_table_caption_paragraphs()), dessen UNMITTELBAR VORANGEHENDES
## Geschwisterelement einen Bild-Absatz (w:drawing) enthaelt - Pandocs
## Standardposition ist in beiden Faellen (Wrapper-Zelle bei Crossref-IDs,
## schlichte Geschwister im Dokumentkoerper sonst) "Beschriftung nach der
## Abbildung". Positionsnaehe statt der frueheren "Elternelement hat kein
## w:tbl-Kind"-Pruefung (siehe oq_find_table_caption_paragraphs() fuer den
## dadurch entstandenen realen Bug, wenn Abbildungs- und Tabellen-
## Beschriftungen im selben Dokumentkoerper als Geschwister neben
## unabhaengigen Tabellen liegen).
oq_find_plot_caption_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(
    document_doc,
    "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption'][preceding-sibling::*[1][.//w:drawing]]",
    ns
  )
}

## Findet den zu einer Abbildungs-Beschriftung gehoerenden Inhaltsknoten (den
## unmittelbar vorangehenden Bild-Absatz, siehe
## oq_find_plot_caption_paragraphs()) - fuer oq_apply_captions()s
## $above-Handling (siehe table_caption_mapping.R). NA, falls kein
## unmittelbar vorangehender Bild-Absatz existiert.
oq_plot_caption_content <- function(caption_p, ns) {
  xml2::xml_find_first(caption_p, "./preceding-sibling::*[1][.//w:drawing]", ns)
}
