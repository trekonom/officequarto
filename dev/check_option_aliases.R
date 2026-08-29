## Unit-Check fuer oq_resolve_aliased() (canonical Name vs. officedown-Alias,
## siehe scripts/option_aliases.R). Im Gegensatz zu check_writeback.R
## eigenstaendig ausfuehrbar, ohne vorherigen `quarto render` - reine
## Funktionslogik, kein Docx-Zugriff. Wie check_writeback.R aus template/
## heraus aufzurufen (`Rscript ../dev/check_option_aliases.R`), damit der
## relative Pfad zu _extensions/ (Symlink) aufgeht.
source("_extensions/officequarto/scripts/option_aliases.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

warnings_seen <- character(0)
warn_collect <- function(fmt, ...) warnings_seen[[length(warnings_seen) + 1]] <<- sprintf(fmt, ...)

## Nur canonical Name gesetzt
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(`list-number` = "Nummerierung ACME"), "list-number", "ol_style", "officequarto-styles", warn_collect)
if (!identical(res, "Nummerierung ACME")) fail("nur canonical gesetzt: erwartet 'Nummerierung ACME', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("nur canonical gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("nur canonical Name gesetzt wird korrekt aufgeloest, keine Warnung")

## Nur officedown-Alias gesetzt
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(ol_style = "Nummerierung ACME"), "list-number", "ol_style", "officequarto-styles", warn_collect)
if (!identical(res, "Nummerierung ACME")) fail("nur Alias gesetzt: erwartet 'Nummerierung ACME', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("nur Alias gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("nur officedown-Alias gesetzt wird korrekt aufgeloest, keine Warnung")

## Beide gesetzt, gleicher Wert - keine Warnung
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(`list-number` = "X", ol_style = "X"), "list-number", "ol_style", "officequarto-styles", warn_collect)
if (!identical(res, "X")) fail("beide gleich gesetzt: erwartet 'X', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("beide gleich gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("canonical Name und Alias mit gleichem Wert gesetzt: keine Warnung")

## Beide gesetzt, widerspruechlich - canonical gewinnt, genau 1 Warnung
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(`list-number` = "Canonical-Wert", ol_style = "Alias-Wert"), "list-number", "ol_style", "officequarto-styles", warn_collect)
if (!identical(res, "Canonical-Wert")) fail("Konflikt: canonical Name haette gewinnen sollen, erhalten '%s'", res)
if (length(warnings_seen) != 1) fail("Konflikt: erwartet genau 1 Warnung, erhalten %d", length(warnings_seen))
ok("bei widerspruechlichem canonical/Alias-Wert gewinnt canonical, es wird genau 1 Warnung ausgegeben")

## Weder canonical noch Alias gesetzt
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(), "list-number", "ol_style", "officequarto-styles", warn_collect)
if (!is.null(res)) fail("keins gesetzt: erwartet NULL, erhalten '%s'", res)
ok("weder canonical noch Alias gesetzt ergibt NULL")

cat("\nAlle Checks bestanden.\n")
