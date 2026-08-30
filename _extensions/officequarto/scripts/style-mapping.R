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

## styles.xml (xml2-Dokument) -> Named Character Vector: Anzeigename -> styleId.
## type ist der OOXML-Style-Typ ("paragraph" fuer Body/Listen/Codeblock-Styles,
## "table" fuer Tabellen-Styles, siehe table-mapping.R).
oq_style_name_to_id <- function(styles_doc, type = "paragraph") {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(styles_doc, sprintf("//w:style[@w:type='%s']", type), ns)
  ids <- xml2::xml_attr(nodes, "styleId")
  nm <- xml2::xml_text(xml2::xml_find_first(nodes, "./w:name/@w:val", ns))
  stats::setNames(ids, nm)
}

## Loest einen vom Nutzer angegebenen Anzeigenamen zu einer styleId auf.
## Bricht mit einer Liste verfuegbarer Namen ab, wenn nicht gefunden. `key` ist
## der volle Konfigurationspfad fuer die Fehlermeldung (z.B.
## "officequarto.styles.body" oder "officequarto.pandoc-styles.code-block").
oq_resolve_style_id <- function(name_to_id, display_name, key, fail_fn) {
  if (display_name %in% names(name_to_id)) {
    return(unname(name_to_id[[display_name]]))
  }
  fail_fn(
    "Style '%s' (%s) wurde im reference-doc nicht gefunden. Verfuegbare Paragraph-Styles: %s",
    display_name, key, paste(sort(names(name_to_id)), collapse = ", ")
  )
}

## Vektorisierte Variante von oq_resolve_style_id() fuer Optionen, die pro
## Verschachtelungsebene einen eigenen Style-Namen tragen koennen
## (officequarto.lists.list-bullet/list-number/list-letter als Array statt
## Skalar - Index 0 = oberste Ebene). Ein skalarer Aufruf (Vektor der Laenge 1)
## verhaelt sich identisch zu einem direkten oq_resolve_style_id()-Aufruf.
oq_resolve_style_ids <- function(name_to_id, display_names, key, fail_fn) {
  if (length(display_names) == 0) {
    fail_fn("%s: leeres Array - mindestens ein Style-Name wird benoetigt.", key)
  }
  vapply(display_names, function(nm) {
    oq_resolve_style_id(name_to_id, nm, key, fail_fn)
  }, character(1), USE.NAMES = FALSE)
}

## styles.xml (xml2-Dokument) -> Named Character Vector: styleId -> numId, nur
## fuer Styles, die selbst eine Nummerierung mitbringen (w:pPr/w:numPr in der
## Style-Definition - typischerweise per w:numStyleLink an eine eigene
## Nummerierungs-Style-Definition gekoppelt, siehe oq_apply_style_mapping).
oq_style_num_id <- function(styles_doc) {
  ns <- xml2::xml_ns(styles_doc)
  nodes <- xml2::xml_find_all(
    styles_doc, "//w:style[@w:type='paragraph'][./w:pPr/w:numPr/w:numId]", ns
  )
  ids <- xml2::xml_attr(nodes, "styleId")
  num_ids <- xml2::xml_attr(xml2::xml_find_first(nodes, "./w:pPr/w:numPr/w:numId", ns), "val")
  stats::setNames(num_ids, ids)
}

## numbering.xml (xml2-Dokument) -> Named Character Vector: numId -> numFmt (Ebene 0).
## Ebene-0-Lookup genuegt fuer JEDEN Absatz, der diesen numId referenziert,
## unabhaengig von dessen eigenem w:ilvl - verifiziert per echtem Render
## (dev/spike-notes.md, Spike O): Pandoc vergibt pro Verschachtelungsebene
## einer Liste einen eigenen numId/abstractNum, und jeder so erzeugte
## abstractNum traegt an allen 9 w:lvl-Eintraegen denselben w:numFmt. Ein
## numId mit unterschiedlichem numFmt je Ebene kommt bei Pandoc-erzeugten
## Listen nicht vor.
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

## numFmt-Werte, die Word als Buchstaben-Listen behandelt (a/b/c bzw. A/B/C) -
## eigener Bucket, getrennt von "alles andere, nicht Bullet" (= list_number:
## decimal, roman etc.). Kein officedown-Aequivalent, officequarto-eigene
## Option ohne Alias.
officequarto_letter_num_fmts <- c("lowerLetter", "upperLetter")

## Absatz -> Verschachtelungsebene (0-basiert, aus w:pPr/w:numPr/w:ilvl). Bei
## Pandoc-erzeugten Listen ist w:ilvl an jedem Listen-Absatz explizit gesetzt
## (verifiziert, Spike O) - der Default 0 bei fehlendem Element ist trotzdem
## ECMA-376-konform und eine sinnvolle Absicherung fuer andere Quellen.
oq_paragraph_ilvl <- function(p, ns) {
  ilvl_node <- xml2::xml_find_first(p, "./w:pPr/w:numPr/w:ilvl", ns)
  if (is.na(ilvl_node)) 0L else as.integer(xml2::xml_attr(ilvl_node, "val"))
}

## Waehlt aus einem Vektor konfigurierter Styles (Index 0 = oberste Ebene) den
## fuer die gegebene Verschachtelungsebene passenden Eintrag. Ist die Liste
## kuerzer als die tatsaechliche Verschachtelung, wird auf den letzten
## (tiefsten konfigurierten) Eintrag geklemmt (Clamping) - analog zu Words
## eigener eingebauter Konvention (z.B. "List Bullet 3" als tiefste benannte
## Ebene, tiefer verschachtelte Absaetze nutzen visuell weiterhin diese). Ein
## Vektor der Laenge 1 ("skalare" Konfiguration) liefert immer denselben Wert,
## unabhaengig von der Ebene - kein separater Skalar-Codepfad noetig.
oq_style_for_level <- function(styles, ilvl) {
  idx <- min(ilvl + 1L, length(styles))
  styles[[idx]]
}

## Wendet das Style-Mapping direkt auf ein geparstes document.xml an (in-place
## via xml2-Referenzsemantik). style_ids ist eine Liste mit optionalen
## Eintraegen $body/$code (jeweils eine styleId oder NULL) und
## $list_bullet/$list_number/$list_letter (jeweils ein Character-Vektor von
## styleIds, ein Eintrag pro Verschachtelungsebene - Laenge 1 = derselbe Style
## auf jeder Ebene, kuerzere Vektoren als die tatsaechliche Verschachtelung
## clampen auf den letzten Eintrag, siehe oq_style_for_level - oder NULL).
## style_num_id (siehe oq_style_num_id) sagt, welche Ziel-Styles selbst eine
## Nummerierung mitbringen.
oq_apply_style_mapping <- function(document_doc, num_fmt_map, style_ids, style_num_id) {
  ns <- xml2::xml_ns(document_doc)
  paragraphs <- xml2::xml_find_all(document_doc, "//w:body/w:p | //w:body//w:tbl//w:p", ns)

  n_body <- 0L
  n_list <- 0L
  n_code <- 0L
  n_list_clamped <- 0L

  for (p in paragraphs) {
    num_id_node <- xml2::xml_find_first(p, "./w:pPr/w:numPr/w:numId", ns)

    if (!is.na(num_id_node)) {
      num_id <- xml2::xml_attr(num_id_node, "val")
      ilvl <- oq_paragraph_ilvl(p, ns)
      fmt <- unname(num_fmt_map[num_id])
      styles_vec <- if (identical(fmt, "bullet")) {
        style_ids$list_bullet
      } else if (fmt %in% officequarto_letter_num_fmts) {
        style_ids$list_letter
      } else {
        style_ids$list_number
      }
      target <- if (!is.null(styles_vec)) oq_style_for_level(styles_vec, ilvl) else NULL
      if (!is.null(target)) {
        if (ilvl + 1L > length(styles_vec)) n_list_clamped <- n_list_clamped + 1L
        oq_set_pstyle(p, ns, target)
        ## Eine direkte w:numPr am Absatz (von Pandoc gesetzt, zeigt auf
        ## Pandocs eigene generische Bullet-/Decimal-Nummerierung) hat in Word
        ## IMMER Vorrang vor der im Ziel-Style selbst hinterlegten
        ## Nummerierung. Bringt der Ziel-Style eine eigene Nummerierung mit,
        ## muss die Absatz-Override deshalb entfernt werden, sonst bleibt
        ## Pandocs Nummerierung optisch sichtbar, obwohl der pStyle korrekt
        ## umgemappt wurde.
        if (target %in% names(style_num_id)) {
          xml2::xml_remove(xml2::xml_parent(num_id_node))
        }
        n_list <- n_list + 1L
      }
      next
    }

    pstyle_node <- xml2::xml_find_first(p, "./w:pPr/w:pStyle", ns)
    current <- if (is.na(pstyle_node)) "Normal" else xml2::xml_attr(pstyle_node, "val")

    ## SourceCode ist - anders als Normal/FirstParagraph/Compact - eine
    ## stabile, feste Pandoc-Style-ID (kein Kontext-abhaengiger Rollenname),
    ## daher genuegt ein direkter Gleichheitscheck statt einer Allowlist.
    if (identical(current, "SourceCode") && !is.null(style_ids$code)) {
      oq_set_pstyle(p, ns, style_ids$code)
      n_code <- n_code + 1L
      next
    }

    ## Abbildungs-Absaetze (enthalten ein w:drawing) tragen bei Pandoc
    ## denselben kontextabhaengigen Rollennamen wie echte Body-Absaetze (z.B.
    ## "Compact", verifiziert empirisch) - waeren also sonst faelschlich vom
    ## Body-Role-Mapping erfasst. Werden hier ausgenommen und stattdessen
    ## dediziert von oq_apply_plot_options() (plot-mapping.R,
    ## officequarto.plots.style) behandelt.
    if (!is.na(xml2::xml_find_first(p, ".//w:drawing", ns))) next

    if (is.null(style_ids$body)) next
    if (current %in% officequarto_body_role_styles) {
      oq_set_pstyle(p, ns, style_ids$body)
      n_body <- n_body + 1L
    }
  }

  list(n_body = n_body, n_list = n_list, n_code = n_code, n_list_clamped = n_list_clamped)
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
