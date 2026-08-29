## Aufloesung von Konfigurationsoptionen, die sowohl unter ihrem canonical
## (neuen, sprechenden) Namen als auch unter einem alten officedown-Alias
## gesetzt sein koennen (Namenskonvention siehe README, Abschnitt
## "Option reference"). Wird von writeback.R per source() eingebunden, keine
## eigenstaendige Ausfuehrung.

## config: benannte Liste (z.B. der Wert von format.docx.officequarto-styles).
## canonical_key/alias_key: die beiden moeglichen Schluessel in config.
## group_label: fuer die Warnmeldung (z.B. "officequarto-styles"). warn_fn:
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
