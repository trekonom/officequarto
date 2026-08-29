## Kernlogik fuer Gruppe 3 (Tabellen-Beschriftungen) des officedown-Options-
## Ports: officequarto-tables.caption.style/prefix/separator/number-bold.
## oq_apply_captions() (die eigentliche Formatierungslogik) ist generisch und
## wird von Gruppe 5 (Abbildungs-Beschriftungen, plot_caption_mapping.R)
## wiederverwendet - nur oq_find_table_caption_paragraphs() ist
## Tabellen-spezifisch. Wird von writeback.R per source() eingebunden, keine
## eigenstaendige Ausfuehrung. Benoetigt: xml2, oq_set_pstyle() aus
## style_mapping.R (muss vor dieser Datei gesourced sein).
##
## `tnd`/`tns` (officedown: abschnittsweise Nummerierungstiefe, z.B. "2-1")
## wurden bewusst NICHT portiert - Quarto/Pandoc nummeriert Tabellen
## ausschliesslich global/fortlaufend, es gibt keine Abschnitts-Nummerierung,
## die man anzapfen koennte; eine eigene Implementierung waere ein deutlich
## groesseres, eigenstaendiges Feature (Ueberschriften-Grenzen ablaufen,
## eigene Nummerierung fuehren) - siehe README.
##
## Hintergrund/Kernproblem (siehe dev/spike-notes.md fuer die volle
## empirische Herleitung): Quartos Tabellen-Beschriftungen im docx-Output
## sind aktuell statischer, fest eingebackener Text (kein echtes
## Word-SEQ-Feld) - "Table 1: Mein Titel" ist EIN <w:r><w:t>-Lauf.
## pre/sep/number-bold koennen deshalb nur per Text-Parsing umgesetzt werden.
## Der von Pandoc generierte Praefix-Text haengt von den
## crossref.tbl-title/title-delim-Einstellungen des Nutzers ab UND wird
## zusaetzlich von Pandocs eigener Smart-Typography-Konvertierung veraendert
## (z.B. "--" -> Halbgeviertstrich "–", nicht-brechendes Leerzeichen vor der
## Zahl), weshalb der generierte Text NICHT zuverlaessig aus der
## Konfiguration vorhergesagt/nachgebaut werden kann. Stattdessen wird an der
## Zahl selbst verankert: Ziffern sind von der Typography-Konvertierung nicht
## betroffen, und officequarto zaehlt Tabellen-Beschriftungen selbst in
## Dokumentreihenfolge mit - identisch zu Pandocs eigener Zaehlung, da nur
## Tabellen MIT Beschriftung ueberhaupt einen Beschriftungsabsatz erzeugen.

## Findet alle Tabellen-Beschriftungsabsaetze in Dokumentreihenfolge. Erkannt
## als Absatz mit pStyle "ImageCaption" (Pandocs gemeinsamer
## Beschriftungs-Style fuer Tabellen UND Abbildungen), dessen Elternelement
## zusaetzlich ein w:tbl-Kind hat (= die eigentliche Tabelle, in Pandocs
## Wrapper-Struktur ein Geschwisterelement der Beschriftung innerhalb
## derselben Zelle) - grenzt Tabellen- von Abbildungs-Beschriftungen ab, die
## kein w:tbl-Geschwister haben.
oq_find_table_caption_paragraphs <- function(document_doc, ns) {
  xml2::xml_find_all(
    document_doc,
    "//w:p[w:pPr/w:pStyle/@w:val='ImageCaption'][../w:tbl]",
    ns
  )
}

## Findet den zu einer Tabellen-Beschriftung gehoerenden Inhaltsknoten (die
## verschachtelte, echte w:tbl innerhalb derselben Wrapper-Zelle) - fuer
## oq_apply_captions()s $above-Handling (siehe dort). NA, falls keine
## verschachtelte Tabelle existiert (z.B. bei einem atypischen Dokument).
oq_table_caption_content <- function(caption_p, ns) {
  xml2::xml_find_first(xml2::xml_parent(caption_p), "./w:tbl", ns)
}

## Zerlegt den Text eines Beschriftungs-Laufs in [Text vor der Zahl] [Zahl]
## [Text nach der Zahl bis zum eigentlichen Beschriftungstext] [Rest]. Die
## erwartete Zahl wird von aussen uebergeben (officequarto zaehlt selbst,
## siehe oben) und per Wortgrenzen-Lookaround verankert (nicht per einfachem
## Teilstring-Treffer, sonst wuerde z.B. "1" faelschlich in "1990" treffen).
## matched=FALSE, wenn die erwartete Zahl nicht im erwarteten Format gefunden
## wurde (z.B. weil die Beschriftung nicht Pandocs generiertem Format
## entspricht) - der Aufrufer laesst den Text dann unveraendert statt etwas
## Falsches zu raten.
oq_split_caption_text <- function(text, expected_number) {
  pattern <- paste0(
    "^(.*?)(?<![\\p{L}\\p{N}])(", expected_number, ")(?![\\p{L}\\p{N}])([^\\p{L}\\p{N}]*)"
  )
  groups <- regmatches(text, regexec(pattern, text, perl = TRUE))[[1]]
  if (length(groups) == 0) {
    return(list(matched = FALSE))
  }
  list(
    matched = TRUE,
    title_prefix = groups[2],
    number = groups[3],
    generated_sep = groups[4],
    rest = substr(text, nchar(groups[1]) + 1, nchar(text))
  )
}

## Schreibt den (ggf. neu zusammengesetzten) Beschriftungstext in den ersten
## Lauf einer Beschriftung zurueck. number_bold: NULL (nicht konfiguriert -
## Formatierung unveraendert lassen, ein Lauf bleibt bestehen) oder
## TRUE/FALSE (expliziter Fett-Schalter fuer den Praefix+Zahl-Anteil - dafuer
## wird der Lauf in zwei Laeufe gesplittet: der erste traegt Praefix+Zahl
## plus explizites w:b, der zweite Trenner+Beschriftungstext OHNE explizites
## w:b, damit er die Formatierung des Styles erbt statt sie zu
## ueberschreiben). Etwaige weitere, bereits vorhandene Laeufe danach (z.B.
## Inline-Formatierung im vom Menschen verfassten Beschriftungstext) bleiben
## unangetastet - sie folgen strukturell korrekt nach dem neuen zweiten Lauf.
oq_write_caption_run <- function(first_run, t_node, ns, pre, number, sep, rest, number_bold) {
  if (is.null(number_bold)) {
    xml2::xml_text(t_node) <- paste0(pre, number, sep, rest)
    return(invisible(NULL))
  }

  xml2::xml_text(t_node) <- paste0(pre, number)
  rpr <- xml2::xml_find_first(first_run, "./w:rPr", ns)
  if (is.na(rpr)) {
    rpr <- xml2::xml_add_child(first_run, "w:rPr", .where = 0)
  }
  b_node <- xml2::xml_find_first(rpr, "./w:b", ns)
  if (is.na(b_node)) {
    b_node <- xml2::xml_add_child(rpr, "w:b")
  }
  xml2::xml_attr(b_node, "w:val") <- if (isTRUE(number_bold)) "1" else "0"

  second_run <- xml2::xml_add_sibling(first_run, "w:r", .where = "after")
  second_t <- xml2::xml_add_child(second_run, "w:t")
  xml2::xml_attr(second_t, "xml:space") <- "preserve"
  xml2::xml_text(second_t) <- paste0(sep, rest)

  invisible(NULL)
}

## Verschiebt eine Beschriftung an die Position vor (above=TRUE) oder nach
## (above=FALSE) ihren zugehoerigen Inhaltsknoten (verschachteltes w:tbl bei
## Tabellen, Bild-Absatz bei Abbildungen - siehe content_finder-Parameter von
## oq_apply_captions()), innerhalb derselben Pandoc-Wrapper-Zelle. Per
## copy+remove statt eines direkten "Verschiebens" - xml2 bietet kein
## natives Verschieben eines Knotens zwischen Positionen an, und
## `xml_add_sibling(..., copy = FALSE)` erzeugt trotzdem eine Kopie und
## entfernt das Original NICHT (empirisch verifiziert) - der Copy-Schritt
## muss deshalb explizit durch xml_remove() des Originals ergaenzt werden.
## Funktioniert unabhaengig von der bisherigen Position (kein Vorab-Check
## noetig, da idempotent: eine bereits korrekt positionierte Beschriftung
## landet nach copy+remove unveraendert an derselben Stelle).
oq_move_caption <- function(caption_p, content_node, above) {
  where <- if (isTRUE(above)) "before" else "after"
  xml2::xml_add_sibling(content_node, caption_p, .where = where, copy = TRUE)
  xml2::xml_remove(caption_p)
  invisible(NULL)
}

## Findet den Namen des Bookmarks (w:bookmarkStart/@name), der eine
## Beschriftung als Crossref-Ziel markiert - ein direktes Geschwister der
## Beschriftung innerhalb derselben Pandoc-Wrapper-Zelle (siehe
## oq_table_caption_content()/oq_plot_caption_content()). NA, falls keins
## gefunden wird. Fuer Gruppe 9 (officequarto-crossref.numbered, siehe
## crossref_mapping.R) - dort wird dieser Name als Schluessel benutzt, um
## einen @tbl-xyz/@fig-xyz-Querverweis auf diese Beschriftung zurueckzufuehren.
## Achtung xml2-Eigenheit: w:name wird beim LESEN unpraefigiert als "name"
## adressiert (anders als beim SCHREIBEN, wo "w:val" etc. praefigiert sein
## muss - siehe CLAUDE.md) - empirisch verifiziert.
oq_caption_anchor_name <- function(caption_p, ns) {
  bookmark <- xml2::xml_find_first(xml2::xml_parent(caption_p), "./w:bookmarkStart", ns)
  if (is.na(bookmark)) return(NA_character_)
  xml2::xml_attr(bookmark, "name")
}

## Wendet caption_options ($style/$prefix/$separator/$number_bold/$above,
## jeweils optional) auf eine bereits gefundene Menge von
## Beschriftungsabsaetzen an (in-place via xml2-Referenzsemantik). Generisch
## fuer Tabellen- UND Abbildungs-Beschriftungen - die Formatierungslogik
## selbst ist fuer beide identisch, nur die Suche nach den Absaetzen (und,
## fuer $above, die Suche nach dem zugehoerigen Inhaltsknoten via
## content_finder) unterscheidet sich (oq_find_table_caption_paragraphs()/
## oq_table_caption_content() hier bzw. oq_find_plot_caption_paragraphs()/
## oq_plot_caption_content() in plot_caption_mapping.R fuer Gruppe 5).
## content_finder: function(caption_p, ns) -> Inhaltsknoten oder NA; nur
## noetig, wenn caption_options$above gesetzt ist. Nummeriert Beschriftungen
## selbst in Dokumentreihenfolge (1-basiert), identisch zu Pandocs Zaehlung -
## da Tabellen- und Abbildungs-Beschriftungen bei Pandoc getrennte
## Nummernkreise haben ("Table 1"/"Figure 1" unabhaengig voneinander), muss
## diese Funktion fuer Tabellen und Abbildungen JEWEILS SEPARAT mit ihrer
## eigenen, bereits gefundenen Menge aufgerufen werden. $above wird bewusst
## als LETZTER Schritt pro Beschriftung angewendet (nach Style-Remap und
## Text-Rewrite) - erst nachdem alle Aenderungen am noch angehefteten Knoten
## vorgenommen wurden, wird er per copy+remove verschoben; ein Verschieben
## VOR den anderen Schritten wuerde mit einem bereits vom Dokumentbaum
## abgetrennten Knoten weiterarbeiten.
##
## Der eigentliche Beschriftungstext (oq_split_caption_text()s $rest) wird
## IMMER ermittelt, unabhaengig davon, ob prefix/separator/number_bold
## ueberhaupt konfiguriert sind (nicht nur wenn needs_text_rewrite) - Gruppe
## 9 (officequarto-crossref.numbered: false) braucht diesen Text auch dann,
## wenn Gruppe 3/5 selbst gar nicht konfiguriert wurden, nur "still"
## mitlaufen, um die Crossref-Umschreibung zu ermoeglichen. Nur das
## tatsaechliche SCHREIBEN in den Absatz (oq_write_caption_run()) bleibt an
## needs_text_rewrite gebunden.
##
## Gibt list(n_found, n_text_rewritten, n_moved, anchor_text) zurueck -
## n_text_rewritten kann kleiner als n_found sein, wenn eine Beschriftung
## nicht im erwarteten "Praefix Zahl Trenner Text"-Format vorlag
## (oq_split_caption_text() konnte die Zahl nicht verankern) und deshalb
## unangetastet blieb; n_moved kann kleiner als n_found sein, wenn fuer eine
## Beschriftung kein zugehoeriger Inhaltsknoten gefunden wurde. anchor_text
## ist eine Named Character Vector Bookmark-Name -> Beschriftungstext (ohne
## Praefix/Zahl/Trenner), fuer Beschriftungen, bei denen sowohl ein Bookmark
## als auch ein erfolgreich geparster Text gefunden wurden.
oq_apply_captions <- function(document_doc, captions, caption_options, content_finder = NULL) {
  ns <- xml2::xml_ns(document_doc)

  n_found <- length(captions)
  n_text_rewritten <- 0L
  n_moved <- 0L
  anchor_text <- character(0)

  needs_text_rewrite <- !is.null(caption_options$prefix) ||
    !is.null(caption_options$separator) ||
    !is.null(caption_options$number_bold)

  for (i in seq_along(captions)) {
    p <- captions[[i]]

    if (!is.null(caption_options$style)) {
      oq_set_pstyle(p, ns, caption_options$style)
    }

    runs <- xml2::xml_find_all(p, "./w:r", ns)
    if (length(runs) > 0) {
      first_run <- runs[[1]]
      t_node <- xml2::xml_find_first(first_run, "./w:t", ns)
      if (!is.na(t_node)) {
        split <- oq_split_caption_text(xml2::xml_text(t_node), i)
        if (isTRUE(split$matched)) {
          anchor_name <- oq_caption_anchor_name(p, ns)
          if (!is.na(anchor_name)) {
            anchor_text[[anchor_name]] <- split$rest
          }
          if (needs_text_rewrite) {
            final_pre <- if (!is.null(caption_options$prefix)) caption_options$prefix else split$title_prefix
            final_sep <- if (!is.null(caption_options$separator)) caption_options$separator else split$generated_sep
            oq_write_caption_run(first_run, t_node, ns, final_pre, split$number, final_sep, split$rest, caption_options$number_bold)
            n_text_rewritten <- n_text_rewritten + 1L
          }
        }
      }
    }

    if (!is.null(caption_options$above) && !is.null(content_finder)) {
      content_node <- content_finder(p, ns)
      if (!is.na(content_node)) {
        oq_move_caption(p, content_node, caption_options$above)
        n_moved <- n_moved + 1L
      }
    }
  }

  list(n_found = n_found, n_text_rewritten = n_text_rewritten, n_moved = n_moved, anchor_text = anchor_text)
}
