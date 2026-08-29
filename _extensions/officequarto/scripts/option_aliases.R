## Aufloesung von Konfigurationsoptionen, die sowohl unter ihrem canonical
## (neuen, sprechenden) Namen als auch unter einem alten officedown-Alias
## gesetzt sein koennen (Namenskonvention siehe README, Abschnitt
## "Option reference"). Wird von writeback.R per source() eingebunden, keine
## eigenstaendige Ausfuehrung.

## config: benannte Liste (z.B. der Wert von format.docx.officequarto.tables).
## canonical_key/alias_key: die beiden moeglichen Schluessel in config.
## group_label: fuer die Warnmeldung (z.B. "officequarto.tables"). warn_fn:
## Funktion(fmt, ...), die bei einem Konflikt aufgerufen wird - wie fail_fn bei
## oq_resolve_style_id() wird auch hier eine Callback-Funktion statt eines
## direkten log_msg()-Aufrufs verwendet, damit diese Datei wie style_mapping.R
## und style_pruning.R eine reine Funktionssammlung ohne eigene Seiteneffekte
## bleibt.
##
## Sind canonical Name und Alias gleichzeitig gesetzt und widersprechen sich
## (unterschiedlicher Wert), gewinnt der canonical Name; warn_fn wird mit einer
## Meldung aufgerufen, welcher Wert verworfen wurde. Sind sie gleichzeitig
## gesetzt und identisch, gibt es keine Warnung. Ist nur einer von beiden
## gesetzt, wird dessen Wert verwendet. Ist keiner gesetzt, wird NULL
## zurueckgegeben.
oq_resolve_aliased <- function(config, canonical_key, alias_key, group_label, warn_fn) {
  canonical_val <- config[[canonical_key]]
  alias_val <- config[[alias_key]]

  if (!is.null(canonical_val) && !is.null(alias_val) && !identical(canonical_val, alias_val)) {
    warn_fn(
      paste0(
        "%s: sowohl '%s' (%s) als auch der officedown-Alias '%s' (%s) sind gesetzt und ",
        "widersprechen sich - '%s' gewinnt, der Alias-Wert wird verworfen."
      ),
      group_label, canonical_key, canonical_val, alias_key, alias_val, canonical_key
    )
  }

  if (!is.null(canonical_val)) return(canonical_val)
  alias_val
}

## Ruft oq_resolve_aliased() fuer mehrere Felder derselben Gruppe auf einmal
## auf und gibt eine benannte Liste zurueck (canonical Name -> aufgeloester
## Wert oder NULL). fields ist ein benannter Character Vector canonical Name
## -> officedown-Alias (z.B. c(width = "page_size_width", height =
## "page_size_height")). Nuetzlich fuer Gruppen mit vielen gleichartigen
## Feldern (z.B. officequarto.page.size/.margins), um die sonst noetige
## Wiederholung von oq_resolve_aliased()-Aufrufen zu vermeiden. config darf
## NULL sein (dann ist jedes Feld NULL, wie oq_resolve_aliased() das auch
## einzeln handhaben wuerde).
oq_resolve_fields <- function(config, fields, group_label, warn_fn) {
  stats::setNames(
    lapply(names(fields), function(canonical) {
      if (is.null(config)) return(NULL)
      oq_resolve_aliased(config, canonical, fields[[canonical]], group_label, warn_fn)
    }),
    names(fields)
  )
}

## Variante von oq_resolve_aliased() fuer Optionspaare mit ENTGEGENGESETZTER
## Polaritaet zwischen canonical Name und officedown-Alias (z.B.
## officequarto.tables.conditional.band-rows, positiv formuliert, vs.
## officedowns no_hband, negativ formuliert - "band-rows: true" und
## "no_hband: false" meinen dasselbe). oq_resolve_aliased() selbst eignet
## sich hierfuer nicht, da dessen Konfliktpruefung Rohwerte auf Gleichheit
## vergleicht - bei entgegengesetzter Polaritaet waere das irrefuehrend
## (unterschiedliche Rohwerte koennten trotzdem dieselbe Absicht ausdruecken
## oder umgekehrt). Der Alias-Wert wird deshalb vor dem Vergleich negiert.
oq_resolve_inverted_aliased <- function(config, canonical_key, alias_key, group_label, warn_fn) {
  canonical_val <- config[[canonical_key]]
  alias_raw <- config[[alias_key]]
  alias_val <- if (!is.null(alias_raw)) !alias_raw else NULL

  if (!is.null(canonical_val) && !is.null(alias_val) && !identical(canonical_val, alias_val)) {
    warn_fn(
      paste0(
        "%s: sowohl '%s' (%s) als auch der (umgekehrt gepolte) officedown-Alias '%s' (%s, ",
        "entspricht %s) sind gesetzt und widersprechen sich - '%s' gewinnt, der Alias-Wert wird ",
        "verworfen."
      ),
      group_label, canonical_key, canonical_val, alias_key, alias_raw, alias_val, canonical_key
    )
  }

  if (!is.null(canonical_val)) return(canonical_val)
  alias_val
}
