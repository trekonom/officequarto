#' Create a standalone, reusable officequarto-ready `_quarto.yml`
#'
#' @description Writes a `_quarto.yml` listing every `officequarto` option at
#'   its default value (`project: type: officequarto` plus the
#'   `format.docx.officequarto` block) - the same content
#'   [oq_create_project()] generates internally for a brand new project, but
#'   usable standalone: as a reusable starting point for future projects (to
#'   hand-edit once and drop into any project you want to convert to
#'   officequarto, or to later pass as `oq_create_project(path, quarto_yml =
#'   ...)`). Deliberately has no `reference_doc` argument: a reference
#'   document is project-specific, so baking one in here would work against
#'   reuse - use [oq_create_project()]'s own `reference_doc` argument to wire
#'   one up for one concrete project.
#'
#' @param path Character. Destination file path, default `"_quarto.yml"`
#'   (the current working directory). Fails loudly if a file already exists
#'   at `path`, unless `overwrite = TRUE` (no silent clobbering).
#' @param overwrite Logical, default `FALSE`. Set `TRUE` to overwrite an
#'   existing file at `path`.
#'
#' @return Invisibly, the normalized path to the written file.
#' @export
#'
#' @examples
#' \dontrun{
#' oq_create_quarto_yml("_quarto.yml")
#' }
oq_create_quarto_yml <- function(path = "_quarto.yml", overwrite = FALSE) {
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    fail("path must be a single, non-empty path.")
  }
  oq_write_quarto_yml(path, overwrite = overwrite)
}

## Shared by oq_create_project() (create-project.R; which may bake in a
## reference-doc basename, since it's writing a _quarto.yml for one concrete
## project) and the exported oq_create_quarto_yml() above (which never does -
## see its own docs on why a reference doc doesn't belong in a reusable
## template).
#' @noRd
oq_write_quarto_yml <- function(path, reference_doc_basename = NULL, overwrite = FALSE) {
  if (file.exists(path) && !isTRUE(overwrite)) {
    fail("'%s' already exists - not overwriting an existing file (set overwrite = TRUE to replace it).", path)
  }
  writeLines(oq_quarto_yml_template(reference_doc_basename), path)
  invisible(normalizePath(path))
}

## Builds the content of the generated _quarto.yml as a character vector
## (one line per element, written via writeLines()) - deliberately a simple
## string template rather than generated via the yaml package, to avoid
## introducing an extra dependency just for this one, always identically
## shaped file.
##
## DELIBERATELY lists every officequarto option, set to its default value,
## instead of just a minimal skeleton - serves as a self-documenting
## starting point (see README/CLAUDE.md for the full option reference). Two
## categories:
## - Boolean/enum/numeric options with a real behavioral default (what
##   happens when the key is missing) -> exactly that value (e.g.
##   keep-rendered: false, every tables.conditional.*: false,
##   crossref.numbered: true).
## - String/style-name options with no universal default (body,
##   list-bullet/-number/-letter, tables.style/layout/width,
##   tables.caption.style/prefix/separator, plots.*, page.size.*/margins.*) ->
##   YAML null, since only the respective reference-doc knows a meaningful
##   value; in R/writeback.R all of these fields are only ever active behind
##   !is.null(...) gates, so an explicit null behaves exactly like a missing
##   key.
## officequarto.style-map is structurally different (a free-form,
## user-defined mapping with no fixed keys) and therefore has no meaningful
## default entries - stays commented out as a shape example, rather than
## actively showing up with made-up content.
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
