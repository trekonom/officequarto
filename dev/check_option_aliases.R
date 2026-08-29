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
res <- oq_resolve_aliased(list(`list-number` = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
if (!identical(res, "Nummerierung ACME")) fail("nur canonical gesetzt: erwartet 'Nummerierung ACME', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("nur canonical gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("nur canonical Name gesetzt wird korrekt aufgeloest, keine Warnung")

## Nur officedown-Alias gesetzt
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(ol_style = "Nummerierung ACME"), "list-number", "ol_style", "officequarto.lists", warn_collect)
if (!identical(res, "Nummerierung ACME")) fail("nur Alias gesetzt: erwartet 'Nummerierung ACME', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("nur Alias gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("nur officedown-Alias gesetzt wird korrekt aufgeloest, keine Warnung")

## Beide gesetzt, gleicher Wert - keine Warnung
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(`list-number` = "X", ol_style = "X"), "list-number", "ol_style", "officequarto.lists", warn_collect)
if (!identical(res, "X")) fail("beide gleich gesetzt: erwartet 'X', erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("beide gleich gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("canonical Name und Alias mit gleichem Wert gesetzt: keine Warnung")

## Beide gesetzt, widerspruechlich - canonical gewinnt, genau 1 Warnung
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(`list-number` = "Canonical-Wert", ol_style = "Alias-Wert"), "list-number", "ol_style", "officequarto.lists", warn_collect)
if (!identical(res, "Canonical-Wert")) fail("Konflikt: canonical Name haette gewinnen sollen, erhalten '%s'", res)
if (length(warnings_seen) != 1) fail("Konflikt: erwartet genau 1 Warnung, erhalten %d", length(warnings_seen))
ok("bei widerspruechlichem canonical/Alias-Wert gewinnt canonical, es wird genau 1 Warnung ausgegeben")

## Weder canonical noch Alias gesetzt
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(), "list-number", "ol_style", "officequarto.lists", warn_collect)
if (!is.null(res)) fail("keins gesetzt: erwartet NULL, erhalten '%s'", res)
ok("weder canonical noch Alias gesetzt ergibt NULL")

## Gleiche Logik fuer die Gruppe-1-Tabellenoptionen (officequarto.tables.width
## vs. Alias tables_width) - eigener Testfall, da eine andere Gruppe/anderer
## Werttyp (numerisch statt String).
warnings_seen <- character(0)
res <- oq_resolve_aliased(list(tables_width = 0.8), "width", "tables_width", "officequarto.tables", warn_collect)
if (!identical(res, 0.8)) fail("Tabellen-Alias: erwartet 0.8, erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("Tabellen-Alias: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("officequarto.tables.width ueber den officedown-Alias 'tables_width' gesetzt wird korrekt aufgeloest")

## oq_resolve_inverted_aliased(): band-rows vs. officedowns umgekehrt gepoltes
## no_hband.

## Nur canonical Name gesetzt
warnings_seen <- character(0)
res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
if (!identical(res, TRUE)) fail("invertiert, nur canonical gesetzt: erwartet TRUE, erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("invertiert, nur canonical gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("oq_resolve_inverted_aliased(): nur canonical Name gesetzt wird korrekt aufgeloest, keine Warnung")

## Nur Alias gesetzt - Wert wird negiert
warnings_seen <- character(0)
res <- oq_resolve_inverted_aliased(list(tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
if (!identical(res, TRUE)) fail("invertiert, nur Alias gesetzt (no_hband=FALSE): erwartet TRUE (Banding an), erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("invertiert, nur Alias gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("oq_resolve_inverted_aliased(): nur Alias gesetzt wird korrekt negiert aufgeloest (no_hband=FALSE -> band-rows=TRUE), keine Warnung")

## Beide gesetzt, gleichbedeutend (unterschiedliche Rohwerte, gleiche Absicht) - keine Warnung
warnings_seen <- character(0)
res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = FALSE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
if (!identical(res, TRUE)) fail("invertiert, beide gleichbedeutend gesetzt: erwartet TRUE, erhalten '%s'", res)
if (length(warnings_seen) != 0) fail("invertiert, beide gleichbedeutend gesetzt: unerwartete Warnung(en): %s", paste(warnings_seen, collapse = "; "))
ok("oq_resolve_inverted_aliased(): canonical und (negierter) Alias mit gleicher Absicht gesetzt: keine Warnung")

## Beide gesetzt, widerspruechlich - canonical gewinnt, genau 1 Warnung
warnings_seen <- character(0)
res <- oq_resolve_inverted_aliased(list(`band-rows` = TRUE, tables_conditional_no_hband = TRUE), "band-rows", "tables_conditional_no_hband", "officequarto.tables.conditional", warn_collect)
if (!identical(res, TRUE)) fail("invertiert, Konflikt: canonical haette gewinnen sollen, erhalten '%s'", res)
if (length(warnings_seen) != 1) fail("invertiert, Konflikt: erwartet genau 1 Warnung, erhalten %d", length(warnings_seen))
ok("oq_resolve_inverted_aliased(): bei widerspruechlicher Absicht gewinnt canonical, es wird genau 1 Warnung ausgegeben")

cat("\nAlle Checks bestanden.\n")
