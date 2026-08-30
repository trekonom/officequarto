## Unit-Check fuer oq_split_caption_text() (siehe
## scripts/table-caption-mapping.R) - das numerisch verankerte Parsing von
## Pandocs generiertem Tabellen-Beschriftungstext ("Table 1: Mein Titel").
## Eigenstaendig ausfuehrbar, ohne vorherigen `quarto render` - reine
## Funktionslogik, kein Docx-Zugriff. Wie check-option-aliases.R aus
## template/ heraus aufzurufen (`Rscript ../dev/check-caption-parsing.R`),
## damit der relative Pfad zu _extensions/ (Symlink) aufgeht.
source("_extensions/officequarto/scripts/table-caption-mapping.R")

fail <- function(...) {
  cat("FAIL:", sprintf(...), "\n")
  quit(save = "no", status = 1)
}
ok <- function(...) cat("OK:", sprintf(...), "\n")

check_split <- function(text, expected_number, expected_title_prefix, expected_number_str, expected_sep, expected_rest, label) {
  res <- oq_split_caption_text(text, expected_number)
  if (!isTRUE(res$matched)) fail("%s: erwartet einen Treffer, aber matched=FALSE", label)
  if (!identical(res$title_prefix, expected_title_prefix)) {
    fail("%s: title_prefix erwartet '%s', erhalten '%s'", label, expected_title_prefix, res$title_prefix)
  }
  if (!identical(res$number, expected_number_str)) {
    fail("%s: number erwartet '%s', erhalten '%s'", label, expected_number_str, res$number)
  }
  if (!identical(res$generated_sep, expected_sep)) {
    fail("%s: generated_sep erwartet '%s', erhalten '%s'", label, expected_sep, res$generated_sep)
  }
  if (!identical(res$rest, expected_rest)) {
    fail("%s: rest erwartet '%s', erhalten '%s'", label, expected_rest, res$rest)
  }
  ok("%s: korrekt in title_prefix='%s' number='%s' sep='%s' rest='%s' zerlegt", label, res$title_prefix, res$number, res$generated_sep, res$rest)
}

check_split("Table 1: My table caption", 1, "Table ", "1", ": ", "My table caption", "einfacher Standardfall (Pandoc-Default-Format)")

## Smart-Typography-konvertierter Trenner (Halbgeviertstrich statt "--") plus
## nicht-brechendes Leerzeichen vor der Zahl - siehe dev/spike-notes.md.
check_split("Tabelle 1– My table caption", 1, "Tabelle ", "1", "– ", "My table caption", "typographisch konvertierter Trenner (Halbgeviertstrich, NBSP)")

check_split("Table 10: Tenth table", 10, "Table ", "10", ": ", "Tenth table", "zweistellige Zahl (Grenzfall fuer Wortgrenzen-Verankerung)")

## Die gesuchte Zahl (1) darf nicht faelschlich innerhalb einer anderen Zahl
## im Beschriftungstext selbst (1990) getroffen werden.
check_split("Table 1: Comparing 1990 and 2000", 1, "Table ", "1", ": ", "Comparing 1990 and 2000", "Zahl im Beschriftungstext selbst wird nicht faelschlich getroffen")

## Erwartete Zahl kommt im Text gar nicht in verankerbarer Form vor (z.B.
## abweichendes Format) - matched=FALSE, damit der Aufrufer den Text
## unveraendert laesst statt etwas Falsches zu raten.
res_no_match <- oq_split_caption_text("Some caption without any number", 1)
if (isTRUE(res_no_match$matched)) fail("kein Treffer erwartet: matched sollte FALSE sein, ist aber TRUE")
ok("kein Treffer erwartet (Zahl nicht im Text): matched=FALSE, Text bleibt dem Aufrufer zufolge unveraendert")

cat("\nAlle Checks bestanden.\n")
