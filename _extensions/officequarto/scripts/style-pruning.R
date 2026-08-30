## Entfernt aus dem gerenderten word/styles.xml alle Style-Definitionen, die
## nicht im reference-doc selbst vorhanden sind. Wird von writeback.R per
## source() eingebunden, keine eigenstaendige Ausfuehrung. Benoetigt: xml2
## (bereits von writeback.R geprueft).
##
## Hintergrund: Pandocs docx-Writer fuegt beim Rendern immer eigene
## Style-Definitionen hinzu, die im reference-doc nicht existieren - z.B.
## Syntax-Highlighting-Styles (SourceCode, KeywordTok, StringTok, ...) fuer
## Codebloecke, unabhaengig davon, ob das Dokument ueberhaupt Codebloecke
## enthaelt. Das reference-doc verliert dabei nichts (Pandoc kopiert dessen
## Styles unveraendert), es kommt nur Fremdes hinzu. officequarto entfernt das
## wieder, unbedingt (keine Konfigurationsoption) - das Ergebnis-docx soll
## ausschliesslich Styles aus dem reference-doc enthalten.
##
## Wird ein zu entfernender Style noch im gerenderten Inhalt referenziert
## (z.B. ein echter Codeblock, der Pandocs SourceCode-Style nutzt, oder -
## ohne officequarto.styles/.lists-Konfiguration - Pandocs eigene Body-/
## Listen-Rollennamen wie FirstParagraph/Compact, falls das reference-doc
## diese nicht kennt), wird die Definition trotzdem entfernt; die betroffenen
## Absaetze/Runs fallen dann auf Words Default-Formatierung zurueck. Das wird
## nicht verhindert, aber in writeback.R geloggt.
##
## Ausnahme (optional, per `officequarto.pandoc-styles.code-block: true`
## konfigurierbar): Pandocs Codeblock-Styles koennen gezielt von der
## Entfernung ausgenommen werden - siehe oq_is_pandoc_code_style_id() und
## deren Verwendung in writeback.R.

## TRUE fuer Pandocs eigene Syntax-Highlighting-Style-IDs (SourceCode + alle
## *Tok-Zeichenstile) - eine stabile, feste Namenskonvention von Pandocs
## docx-Writer (siehe dev/spike-notes.md, Spike E).
oq_is_pandoc_code_style_id <- function(id) id == "SourceCode" | grepl("Tok$", id)

## styles.xml (xml2-Dokument) -> character vector aller styleIds (alle Typen:
## paragraph/character/table/numbering).
oq_all_style_ids <- function(styles_doc) {
  ns <- xml2::xml_ns(styles_doc)
  xml2::xml_attr(xml2::xml_find_all(styles_doc, "//w:style", ns), "styleId")
}

## Ein oder mehrere geparste content-xml2-Dokumente (document.xml,
## footnotes.xml, ...) -> character vector aller tatsaechlich referenzierten
## Style-IDs (w:pStyle/w:rStyle/w:tblStyle).
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

## Entfernt aus styles_doc (in-place via xml2-Referenzsemantik) jeden
## <w:style>, dessen styleId nicht in ref_style_ids enthalten ist. Gibt eine
## Liste mit $removed (alle entfernten IDs) und $removed_but_referenced
## (davon die, die noch in referenced_ids vorkommen) zurueck, fuer Logging in
## writeback.R.
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
