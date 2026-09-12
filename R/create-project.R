## Scaffolding-Helfer fuer neue officequarto-Projekte, im Geiste von
## usethis::create_project() - siehe CLAUDE.md/README.md. Anders als jede
## andere Funktion in diesem Paket ist create_officequarto_project()
## tatsaechlich fuer die direkte, interaktive Nutzung durch Anwender:innen
## gedacht (nicht nur intern von oq_writeback() verwendet) - deshalb bewusst
## OHNE das interne oq_-Praefix benannt, das der Grep-Barkeit unter den ~40
## rein internen OOXML-Helfern dient, nicht der oeffentlichen API.

#' Create a new officequarto project
#'
#' @description Scaffolds a new Quarto project pre-wired for the
#'   officequarto extension: creates `path`, copies the officequarto
#'   extension bundled with this package into `path/_extensions/officequarto`
#'   (a real, standalone copy - the new project does not depend on this
#'   package's installation location afterwards, only on the package being
#'   installed when it renders), writes a minimal `_quarto.yml` (
#'   `project: type: officequarto`, plus `format.docx.reference-doc` when
#'   `reference_doc` is supplied), and writes one minimal starter `.qmd` so
#'   the project renders immediately.
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
#' create_officequarto_project("my-report", reference_doc = "original.docx")
#' }
create_officequarto_project <- function(path, reference_doc = NULL, open = interactive()) {
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
    "      keep-rendered: true"
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
    "This report was scaffolded by `create_officequarto_project()`. Replace this",
    "paragraph with your own content, and see the officequarto README for the",
    "full `officequarto` configuration reference (styles, tables, figures,",
    "captions, page layout, ...)."
  )
}
