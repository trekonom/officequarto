## Scaffolding helper for new officequarto projects, in the spirit of
## usethis::create_project() - see CLAUDE.md/README.md. Despite this
## oq_-prefix-less role model, deliberately named oq_create_project() (not
## create_officequarto_project(), the original choice) - consistency with
## the internal oq_ naming convention weighs more heavily here than the
## argument that this is the package's only function actually intended for
## direct end-user use.

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
#'   copied into `path` under its own basename. When `quarto_yml` is not
#'   supplied, that basename is also written into the generated
#'   `_quarto.yml`. When `NULL`, `reference-doc` is simply omitted from the
#'   generated YAML (every officequarto option is already per-field optional,
#'   so an unset reference-doc is consistent, not a special case) - add a
#'   reference document and the key later.
#' @param quarto_yml Character or `NULL` (default). Path to an existing
#'   `_quarto.yml`-style file to use instead of the generated one. Copied
#'   verbatim to `path/_quarto.yml` - its content is not inspected or merged
#'   with `reference_doc`, so if you also supply `reference_doc`, make sure
#'   this file's own `format.docx.reference-doc` already matches (or edit it
#'   afterwards). See [oq_create_quarto_yml()] if you want a fresh,
#'   officequarto-ready `_quarto.yml` to start from.
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
oq_create_project <- function(path, reference_doc = NULL, quarto_yml = NULL, open = interactive()) {
  if (missing(path) || !is.character(path) || length(path) != 1 || !nzchar(path)) {
    fail("path must be a single, non-empty path.")
  }
  if (!is.null(reference_doc)) {
    if (!is.character(reference_doc) || length(reference_doc) != 1 || !nzchar(reference_doc)) {
      fail("reference_doc must be a single path (string) or NULL.")
    }
    if (!file.exists(reference_doc)) {
      fail("reference_doc '%s' was not found.", reference_doc)
    }
  }
  if (!is.null(quarto_yml)) {
    if (!is.character(quarto_yml) || length(quarto_yml) != 1 || !nzchar(quarto_yml)) {
      fail("quarto_yml must be a single path (string) or NULL.")
    }
    if (!file.exists(quarto_yml)) {
      fail("quarto_yml '%s' was not found.", quarto_yml)
    }
  }

  if (file.exists(file.path(path, "_quarto.yml"))) {
    fail("'%s' already contains a _quarto.yml - not overwriting an existing project.", path)
  }

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    fail("Project directory '%s' could not be created.", path)
  }

  ## A real, standalone copy (no symlinks) - the new project is afterwards
  ## independent of this package's installation location, exactly like an
  ## extension directory placed via `quarto add` would be. Only at render
  ## time (post-render-hook shim) is the installed package needed again.
  extension_src <- system.file("_extensions", package = "officequarto")
  if (!nzchar(extension_src)) {
    fail("The officequarto extension was not found in the installed package (system.file('_extensions', package = 'officequarto')) - is the package installed correctly?")
  }
  file.copy(extension_src, path, recursive = TRUE)

  ref_doc_basename <- NULL
  if (!is.null(reference_doc)) {
    ref_doc_basename <- basename(reference_doc)
    file.copy(reference_doc, file.path(path, ref_doc_basename), overwrite = TRUE)
  }

  if (!is.null(quarto_yml)) {
    ## Verbatim copy - no inspection/merging of its content (see quarto_yml's
    ## @param docs: reference_doc is not automatically injected into it).
    file.copy(quarto_yml, file.path(path, "_quarto.yml"))
  } else {
    ## oq_write_quarto_yml() (shared with oq_create_quarto_yml()) rather than
    ## duplicating the writeLines()/oq_quarto_yml_template() call directly.
    ## Unlike the exported oq_create_quarto_yml(), this path may bake in
    ## ref_doc_basename - it's writing a _quarto.yml for this one concrete
    ## project, not a reusable template (see oq_create_quarto_yml()'s own
    ## docs for why it never accepts a reference doc).
    oq_write_quarto_yml(file.path(path, "_quarto.yml"), reference_doc_basename = ref_doc_basename)
  }

  project_name <- basename(normalizePath(path, mustWork = FALSE))
  writeLines(oq_starter_qmd_template(project_name), file.path(path, paste0(project_name, ".qmd")))

  if (isTRUE(open) && requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
    rstudioapi::openProject(path)
  }

  invisible(normalizePath(path))
}

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

## Shared by oq_create_project() (which may bake in a reference-doc basename,
## since it's writing a _quarto.yml for one concrete project) and the
## exported oq_create_quarto_yml() (which never does - see its own docs on
## why a reference doc doesn't belong in a reusable template).
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

## Minimal starter report, so a freshly created project is immediately
## renderable instead of an empty shell.
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
