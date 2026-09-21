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
#' @param starter_qmd Character or `NULL` (default). Path to an existing
#'   `.qmd` file to use as the project's starter document instead of the
#'   generated one. When supplied, it is copied into `path` as
#'   `<project_name>.qmd`. When `NULL`, a minimal generated starter `.qmd`
#'   (see `oq_starter_qmd_template()`) is written instead.
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
oq_create_project <- function(path, reference_doc = NULL, quarto_yml = NULL,
                               starter_qmd = NULL, open = interactive()) {
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
  if (!is.null(starter_qmd)) {
    if (!is.character(starter_qmd) || length(starter_qmd) != 1 || !nzchar(starter_qmd)) {
      fail("starter_qmd must be a single path (string) or NULL.")
    }
    if (!file.exists(starter_qmd)) {
      fail("starter_qmd '%s' was not found.", starter_qmd)
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
  qmd_path <- file.path(path, paste0(project_name, ".qmd"))
  if (!is.null(starter_qmd)) {
    ## Verbatim copy, renamed to <project_name>.qmd - same "opaque single
    ## file, no inspection" treatment as quarto_yml.
    file.copy(starter_qmd, qmd_path)
  } else {
    writeLines(oq_starter_qmd_template(project_name), qmd_path)
  }

  if (isTRUE(open) && requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()) {
    rstudioapi::openProject(path)
  }

  invisible(normalizePath(path))
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
