## Kernlogik fuer Gruppe 5 (Abbildungs-Beschriftungen) des officedown-
## Options-Ports: officequarto-plots.caption.style/prefix/separator/
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
## Erkannt als Absatz mit pStyle "ImageCaption", dessen Elternelement KEIN
## w:tbl-Kind hat - Gegenstueck zu oq_find_table_caption_paragraphs()
## (table_caption_mapping.R): eine Abbildungs-Wrapper-Zelle (siehe
## plot_mapping.R) enthaelt nur den Bild-Absatz und den Beschriftungsabsatz,
## keine verschachtelte Tabelle.
oq_find_plot_caption_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(
    document_doc,
    "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption'][not(../w:tbl)]",
    ns
  )
}
