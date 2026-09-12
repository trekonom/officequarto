## Scaffolding-Helfer fuer neue officequarto-Projekte, im Geiste von
## usethis::create_project() - siehe CLAUDE.md/README.md. Trotz dieses
## oq_-Praefix-losen Vorbilds bewusst als oq_create_project() benannt (nicht
## create_officequarto_project(), die urspruengliche Wahl) - Konsistenz mit
## der internen oq_-Namenskonvention wiegt hier hoeher als das Argument, dies
## sei die einzige tatsaechlich fuer direkte Anwender:innen-Nutzung gedachte
## Funktion des Pakets.

#' Create a new officequarto project
#'
#' @description Scaffolds a new Quarto project pre-wired for the
#'   officequarto extension: creates `path`, copies the officequarto
#'   extension bundled with this package into `path/_extensions/officequarto`
#'   (a real, standalone copy - the new project does not depend on this
#'   package's installation location afterwards, only on the package being
#'   installed when it renders), writes a `_quarto.yml` with every
#'   `officequarto` option listed at its default value (see
#'   `vignette("officequarto")`/README for what each one does), and writes one
#'   minimal starter `.qmd` so the project renders immediately.
#'
#' @param path Character. Name or path of the new project directory, same
#'   semantics as `usethis::create_project(path, ...)`: relative paths are
#'   resolved against the current working directory, and the directory is
#'   created if it doesn't already exist. Fails loudly if `path` already
#'   contains a `_quarto.yml` (no silent clobbering of an existing project).
#' @param reference_doc Character or `NULL` (default). Path to an existing
#'   `.docx` to use as the project's `reference-doc`. When supplied, it is
#'   copied into `path` under its own basename, and that basename is written
#'   into the generated `_quarto.yml`. When `NULL`, `reference-doc` is simply
#'   omitted from the generated YAML (every officequarto option is already
#'   per-field optional, so an unset reference-doc is consistent, not a
#'   special case) - add a reference document and the key later.
#' @param open Logical, default `interactive()`. If `TRUE` and the
#'   `rstudioapi` package is installed and there is an active RStudio
#'   session, opens the new project via `rstudioapi::openProject()`
#'   (best-effort, silently skipped otherwise - mirrors
#'   `usethis::create_project()`'s own UX without adding a hard dependency).
#'
#' @return Invisibly, the normalized path to the new project directory.
#' @export
#'
#' @examples
#' \dontrun{
#' oq_create_project("my-report", reference_doc = "original.docx")
#' }
oq_create_project <- function(path, reference_doc = NULL, open = interactive()) {
  if (missing(path) || !is.character(path) || length(path) != 1 || !nzchar(path)) {
    fail("path muss ein einzelner, nicht-leerer Pfad sein.")
  }
  if (!is.null(reference_doc)) {
    if (!is.character(reference_doc) || length(reference_doc) != 1 || !nzchar(reference_doc)) {
      fail("reference_doc muss ein einzelner Pfad (String) oder NULL sein.")
    }
    if (!file.exists(reference_doc)) {
      fail("reference_doc '%s' wurde nicht gefunden.", reference_doc)
    }
  }

  if (file.exists(file.path(path, "_quarto.yml"))) {
    fail("'%s' enthaelt bereits eine _quarto.yml - kein Ueberschreiben eines vorhandenen Projekts.", path)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    fail("Projektverzeichnis '%s' konnte nicht angelegt werden.", path)
  }

  ## Echte, eigenstaendige Kopie (keine Symlinks) - das neue Projekt ist
  ## danach unabhaengig vom Installationsort dieses Pakets, genau wie ein per
  ## `quarto add` abgelegtes Extension-Verzeichnis es waere. Nur zur Render-
  ## Zeit (Post-Render-Hook-Shim) wird das installierte Paket wieder
  ## gebraucht.
  extension_src <- system.file("_extensions", package = "officequarto")
  if (!nzchar(extension_src)) {
    fail("Die officequarto-Extension wurde im installierten Paket nicht gefunden (system.file('_extensions', package = 'officequarto')) - ist das Paket korrekt installiert?")
  }
  file.copy(extension_src, path, recursive = TRUE)

  ref_doc_basename <- NULL
  if (!is.null(reference_doc)) {
    ref_doc_basename <- basename(reference_doc)
    file.copy(reference_doc, file.path(path, ref_doc_basename), overwrite = TRUE)
  }

  writeLines(oq_quarto_yml_template(ref_doc_basename), file.path(path, "_quarto.yml"))

  project_name <- basename(normalizePath(path, mustWork = FALSE))
  writeLines(oq_starter_qmd_template(project_name), file.path(path, paste0(project_name, ".qmd")))

  if (isTRUE(open) && requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
    rstudioapi::openProject(path)
  }

  invisible(normalizePath(path))
}

## Baut den Inhalt der generierten _quarto.yml als Character-Vektor (eine
## Zeile pro Element, per writeLines() geschrieben) - bewusst als simples
## String-Template statt ueber das yaml-Paket erzeugt, um keine zusaetzliche
## Abhaengigkeit nur fuer diese eine, immer gleich geformte Datei einzufuehren.
##
## Listet ABSICHTLICH jede officequarto-Option auf, auf ihren Default-Wert
## gesetzt, statt nur ein Minimalgeruest - dient als selbst-dokumentierender
## Startpunkt (siehe README/CLAUDE.md fuer die volle Options-Referenz). Zwei
## Kategorien:
## - Boolean/Enum/Numerisch mit echtem Verhaltens-Default (was passiert, wenn
##   der Schluessel fehlt) -> genau dieser Wert (z.B. keep-rendered: false,
##   jedes tables.conditional.*: false, crossref.numbered: true).
## - String-/Style-Namen-Optionen ohne universellen Default (body,
##   list-bullet/-number/-letter, tables.style/layout/width,
##   tables.caption.style/prefix/separator, plots.*, page.size.*/margins.*) ->
##   YAML null, da nur das jeweilige reference-doc einen sinnvollen Wert kennt;
##   in R/writeback.R sind alle diese Felder ausschliesslich hinter
##   !is.null(...)-Gates aktiv, ein explizites null verhaelt sich also exakt
##   wie ein fehlender Schluessel.
## officequarto.style-map ist strukturell anders (freies, nutzerdefiniertes
## Mapping ohne feste Schluessel) und hat deshalb keine sinnvollen
## Default-Eintraege - bleibt auskommentiert als Formbeispiel, statt aktiv
## mit erfundenem Inhalt aufzutauchen.
#' @noRd
oq_quarto_yml_template <- function(reference_doc_basename) {
  lines <- c(
    "project:",
    "  type: officequarto",
    "",
    "format:",
    "  docx:"
  )
  if (!is.null(reference_doc_basename)) {
    lines <- c(lines, sprintf("    reference-doc: %s", reference_doc_basename))
  }
  c(lines,
    "    officequarto:",
    "      keep-rendered: false",
    "      styles:",
    "        body: null",
    "      lists:",
    "        list-bullet: null",
    "        list-number: null",
    "        list-letter: null",
    "      tables:",
    "        style: null",
    "        layout: null",
    "        width: null",
    "        conditional:",
    "          first-row: false",
    "          first-column: false",
    "          last-row: false",
    "          last-column: false",
    "          band-rows: false",
    "          band-columns: false",
    "        caption:",
    "          style: null",
    "          prefix: null",
    "          separator: null",
    "          number-bold: false",
    "          above: false",
    "      plots:",
    "        style: null",
    "        align: null",
    "        caption:",
    "          style: null",
    "          prefix: null",
    "          separator: null",
    "          number-bold: false",
    "          above: false",
    "      # style-map: free-form target-style -> [source pStyle IDs] mapping,",
    "      # no fixed defaults to show - add entries as needed, e.g.:",
    "      # style-map:",
    "      #   \"My Custom Style\": [Normal]",
    "      page:",
    "        size:",
    "          width: null",
    "          height: null",
    "          orientation: null",
    "        margins:",
    "          top: null",
    "          bottom: null",
    "          left: null",
    "          right: null",
    "          header: null",
    "          footer: null",
    "          gutter: null",
    "      crossref:",
    "        numbered: true",
    "        auto-number: false",
    "      pandoc-styles:",
    "        code-block: false"
  )
}

## Minimaler Start-Report, damit ein frisch erzeugtes Projekt sofort
## renderbar ist statt einer leeren Huelle.
#' @noRd
oq_starter_qmd_template <- function(title) {
  c(
    "---",
    sprintf('title: "%s"', title),
    "---",
    "",
    "## Introduction",
    "",
    "This report was scaffolded by `oq_create_project()`. Replace this",
    "paragraph with your own content, and see the officequarto README for the",
    "full `officequarto` configuration reference (styles, tables, figures,",
    "captions, page layout, ...)."
  )
}
