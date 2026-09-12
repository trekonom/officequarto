## Kernlogik fuer Gruppe 1 (Tabellen-Basis: style/layout/width) und Gruppe 2
## (Tabellen-Conditional-Formatting: officequarto.tables.conditional.*) des
## officedown-Options-Ports. Teil des officequarto R-Pakets - von
## oq_writeback() (R/writeback.R) verwendet, keine eigenstaendige
## Ausfuehrung. Benoetigt: xml2 sowie
## oq_resolve_aliased()/oq_resolve_inverted_aliased() aus option-aliases.R
## (im selben Package-Namespace, keine explizite Ladereihenfolge noetig).
##
## `caption-above` (officedown: topcaption) ist bewusst NICHT Teil dieser
## Datei - es hat erst mit echten Tabellen-Beschriftungen (Gruppe 3) einen
## sichtbaren Effekt und wird zusammen mit dieser implementiert, statt jetzt
## als wirkungsloser Platzhalter zu existieren.
##
## `tab.lp` (officedown) wurde bewusst NICHT portiert: es ist ein
## bookdown-Autoren-Syntax-Konzept (Label-Praefix beim Parsen von
## \@ref(tab:xyz)), kein Rendering-Schalter, und hat in Quartos eigenem
## Crossref-System (\#tbl-xyz, von Quarto/Pandoc VOR diesem Post-Render-Hook
## aufgeloest) keine sinnvolle Entsprechung - siehe README.

## Reihenfolge der w:tblPr-Kindelemente laut OOXML-Schema (CT_TblPrBase,
## Auszug - nur die hier relevanten und ihre ueblichen Nachbarn). Wird
## gebraucht, weil xml2::xml_add_child() ohne .where einfach ans Ende haengt;
## ein neu erzeugtes w:tblLayout landet damit sonst hinter Pandocs eigenem
## w:tblLook, was nicht der Schema-Reihenfolge entspricht (Word selbst ist
## tolerant, aber eine schema-konforme Reihenfolge ist sauberer/portabler).
#' @noRd
officequarto_tblpr_order <- c(
  "tblStyle", "tblpPr", "tblOverlap", "bidiVisual", "tblStyleRowBandSize",
  "tblStyleColBandSize", "tblW", "jc", "tblCellSpacing", "tblInd",
  "tblBorders", "shd", "tblLayout", "tblCellMar", "tblLook",
  "tblCaption", "tblDescription"
)

## Fuegt ein neues, lokal "tag_local" genanntes Kind-Element in tbl_pr an der
## laut officequarto_tblpr_order korrekten Position ein (vor dem ersten
## bereits vorhandenen Geschwister-Element, das in der Reihenfolge spaeter
## kommt, sonst am Ende) und gibt den neuen Knoten zurueck.
#' @noRd
oq_add_tbl_pr_child <- function(tbl_pr, tag_local) {
  tag_pos <- match(tag_local, officequarto_tblpr_order)
  existing <- xml2::xml_children(tbl_pr)
  existing_pos <- match(xml2::xml_name(existing), officequarto_tblpr_order)
  insert_before <- which(!is.na(existing_pos) & existing_pos > tag_pos)
  where <- if (length(insert_before) > 0) min(insert_before) - 1L else length(existing)
  xml2::xml_add_child(tbl_pr, paste0("w:", tag_local), .where = where)
}

## Setzt (oder erzeugt) das w:tblStyle-Kind-Element von w:tblPr.
#' @noRd
oq_set_tbl_style <- function(tbl_pr, ns, style_id) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblStyle", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblStyle")
  }
  xml2::xml_attr(node, "w:val") <- style_id
  invisible(NULL)
}

## Setzt (oder erzeugt) das w:tblLayout-Kind-Element von w:tblPr. layout ist
## bereits der validierte OOXML-Wert ("autofit"/"fixed").
#' @noRd
oq_set_tbl_layout <- function(tbl_pr, ns, layout) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblLayout", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblLayout")
  }
  xml2::xml_attr(node, "w:type") <- layout
  invisible(NULL)
}

## Setzt (oder erzeugt) das w:tblW-Kind-Element von w:tblPr. width_fraction
## ist relativ zur Seitenbreite (0..1, wie bei officedown); OOXML erwartet bei
## w:type="pct" den Wert in Fuenfzigstel-Prozent (100% Seitenbreite = 5000).
#' @noRd
oq_set_tbl_width <- function(tbl_pr, ns, width_fraction) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblW", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblW")
  }
  xml2::xml_attr(node, "w:type") <- "pct"
  xml2::xml_attr(node, "w:w") <- as.character(round(width_fraction * 5000))
  invisible(NULL)
}

## Gruppe-2-Felder (officequarto.tables.conditional.*) -> ihr w:tblLook-
## Attribut plus ob der Wert beim Schreiben invertiert werden muss.
## band-rows/band-columns sind bewusst positiv formuliert (siehe README),
## OOXML selbst kennt aber nur die negativ gepolten noHBand/noVBand - die
## Invertierung passiert hier beim Schreiben, nicht schon bei der
## Options-Aufloesung (die haelt canonical Werte in ihrer eigenen, positiven
## Polaritaet, siehe oq_resolve_inverted_aliased() in option-aliases.R).
#' @noRd
officequarto_tbllook_attrs <- list(
  `first-row`    = list(attr = "firstRow",    invert = FALSE),
  `first-column` = list(attr = "firstColumn", invert = FALSE),
  `last-row`     = list(attr = "lastRow",     invert = FALSE),
  `last-column`  = list(attr = "lastColumn",  invert = FALSE),
  `band-rows`    = list(attr = "noHBand",     invert = TRUE),
  `band-columns` = list(attr = "noVBand",     invert = TRUE)
)

## Setzt (oder erzeugt) w:tblLook-Attribute von w:tblPr fuer die in
## conditional_options gesetzten Felder (Namen wie in
## officequarto_tbllook_attrs, jeweils TRUE/FALSE oder NULL/fehlend fuer
## "nicht konfiguriert, unveraendert lassen").
#' @noRd
oq_set_tbl_look <- function(tbl_pr, ns, conditional_options) {
  node <- xml2::xml_find_first(tbl_pr, "./w:tblLook", ns)
  if (is.na(node)) {
    node <- oq_add_tbl_pr_child(tbl_pr, "tblLook")
  }
  for (key in names(conditional_options)) {
    val <- conditional_options[[key]]
    if (is.null(val)) next
    spec <- officequarto_tbllook_attrs[[key]]
    ooxml_val <- if (isTRUE(spec$invert)) !val else val
    xml2::xml_attr(node, paste0("w:", spec$attr)) <- if (isTRUE(ooxml_val)) "1" else "0"
  }
  invisible(NULL)
}

## Loest ein einzelnes boolesches officequarto.tables.conditional-Feld auf
## (canonical Name vs. officedown-Alias, ueber oq_resolve_aliased() bzw. bei
## invert=TRUE ueber oq_resolve_inverted_aliased()) und validiert das
## Ergebnis als einzelnen TRUE/FALSE-Wert (fail-loud, Konsistenz mit
## layout/width in Gruppe 1). key_path ist der volle Konfigurationspfad fuer
## die Fehlermeldung.
#' @noRd
oq_resolve_table_bool_option <- function(config, canonical_key, alias_key, invert, key_path, warn_fn, fail_fn) {
  resolved <- if (invert) {
    oq_resolve_inverted_aliased(config, canonical_key, alias_key, "officequarto.tables.conditional", warn_fn)
  } else {
    oq_resolve_aliased(config, canonical_key, alias_key, "officequarto.tables.conditional", warn_fn)
  }
  if (!is.null(resolved) && (!is.logical(resolved) || length(resolved) != 1 || is.na(resolved))) {
    fail_fn("%s muss true oder false sein (erhalten: '%s').", key_path, resolved)
  }
  resolved
}

## Wendet table_options ($style/$layout/$width/$conditional, jeweils
## optional) auf jede w:tbl in einem geparsten document.xml an (in-place via
## xml2-Referenzsemantik). $conditional ist eine benannte Liste wie von
## oq_resolve_table_bool_option() befuellt (Namen aus
## officequarto_tbllook_attrs). Gibt die Anzahl der bearbeiteten Tabellen
## zurueck.
#' @noRd
oq_apply_table_options <- function(document_doc, table_options) {
  ns <- xml2::xml_ns(document_doc)
  ## Schliesst Pandocs synthetische Wrapper-Tabelle aus: bei beschrifteten
  ## Tabellen UND Abbildungen fasst Pandoc Beschriftung + eigentlichen Inhalt
  ## in einer 1x1-Huelltabelle zusammen, deren einzige Zelle direkt einen
  ## Absatz mit pStyle "ImageCaption" enthaelt (siehe
  ## table-caption-mapping.R) - dieses Merkmal identifiziert die
  ## Wrapper-Tabelle direkt und zuverlaessig, unabhaengig davon, ob sie eine
  ## echte Tabelle oder eine Abbildung umschliesst (eine fruehere Version
  ## filterte stattdessen nur Tabellen mit einer verschachtelten w:tbl heraus
  ## - das erkannte zwar den Tabellen-Fall, nicht aber Abbildungs-Wrapper, die
  ## keine verschachtelte Tabelle enthalten). Ohne den Filter wuerden
  ## style/layout/width/conditional faelschlich auch auf diese unsichtbare
  ## Struktur-Tabelle angewendet, nicht nur auf die eigentliche(n)
  ## Datentabelle(n).
  tables <- xml2::xml_find_all(
    document_doc,
    "//w:tbl[not(./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val='ImageCaption')]",
    ns
  )

  for (tbl in tables) {
    tbl_pr <- xml2::xml_find_first(tbl, "./w:tblPr", ns)
    if (is.na(tbl_pr)) {
      tbl_pr <- xml2::xml_add_child(tbl, "w:tblPr", .where = 0)
    }
    if (!is.null(table_options$style)) oq_set_tbl_style(tbl_pr, ns, table_options$style)
    if (!is.null(table_options$layout)) oq_set_tbl_layout(tbl_pr, ns, table_options$layout)
    if (!is.null(table_options$width)) oq_set_tbl_width(tbl_pr, ns, table_options$width)
    has_conditional <- !is.null(table_options$conditional) &&
      any(!vapply(table_options$conditional, is.null, logical(1)))
    if (has_conditional) {
      oq_set_tbl_look(tbl_pr, ns, table_options$conditional)
    }
  }

  length(tables)
}
