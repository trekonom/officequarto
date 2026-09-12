# Create a new officequarto project

Scaffolds a new Quarto project pre-wired for the officequarto extension:
creates `path`, copies the officequarto extension bundled with this
package into `path/_extensions/officequarto` (a real, standalone copy -
the new project does not depend on this package's installation location
afterwards, only on the package being installed when it renders), writes
a `_quarto.yml` with every `officequarto` option listed at its default
value (see `vignette("officequarto")`/README for what each one does),
and writes one minimal starter `.qmd` so the project renders
immediately.

## Usage

``` r
oq_create_project(path, reference_doc = NULL, open = interactive())
```

## Arguments

- path:

  Character. Name or path of the new project directory, same semantics
  as `usethis::create_project(path, ...)`: relative paths are resolved
  against the current working directory, and the directory is created if
  it doesn't already exist. Fails loudly if `path` already contains a
  `_quarto.yml` (no silent clobbering of an existing project).

- reference_doc:

  Character or `NULL` (default). Path to an existing `.docx` to use as
  the project's `reference-doc`. When supplied, it is copied into `path`
  under its own basename, and that basename is written into the
  generated `_quarto.yml`. When `NULL`, `reference-doc` is simply
  omitted from the generated YAML (every officequarto option is already
  per-field optional, so an unset reference-doc is consistent, not a
  special case) - add a reference document and the key later.

- open:

  Logical, default
  [`interactive()`](https://rdrr.io/r/base/interactive.html). If `TRUE`
  and the `rstudioapi` package is installed and there is an active
  RStudio session, opens the new project via
  [`rstudioapi::openProject()`](https://rstudio.github.io/rstudioapi/reference/projects.html)
  (best-effort, silently skipped otherwise - mirrors
  `usethis::create_project()`'s own UX without adding a hard
  dependency).

## Value

Invisibly, the normalized path to the new project directory.

## Examples

``` r
if (FALSE) { # \dontrun{
oq_create_project("my-report", reference_doc = "original.docx")
} # }
```
