# Create a standalone officequarto-ready `_quarto.yml`

Writes a `_quarto.yml` listing every `officequarto` option at its
default value (`project: type: officequarto` plus the
`format.docx.officequarto` block) - the same content
[`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
generates internally for a brand new project, but usable standalone: as
a starting point to drop into an already-existing Quarto project you
want to convert to officequarto, or as a file to hand-edit before
scaffolding a project with `oq_create_project(path, quarto_yml = ...)`.

## Usage

``` r
oq_create_quarto_yml(
  path = "_quarto.yml",
  reference_doc = NULL,
  overwrite = FALSE
)
```

## Arguments

- path:

  Character. Destination file path, default `"_quarto.yml"` (the current
  working directory). Fails loudly if a file already exists at `path`,
  unless `overwrite = TRUE` (no silent clobbering).

- reference_doc:

  Character or `NULL` (default). Path to an existing `.docx` file; only
  its basename (not the full path) is written to
  `format.docx.reference-doc`. This function does not copy the file
  itself, only writes the reference - make sure the `.docx` actually
  ends up alongside the generated `_quarto.yml` before rendering (see
  [`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
  if you want the copy to happen automatically).

- overwrite:

  Logical, default `FALSE`. Set `TRUE` to overwrite an existing file at
  `path`.

## Value

Invisibly, the normalized path to the written file.

## Examples

``` r
if (FALSE) { # \dontrun{
oq_create_quarto_yml("_quarto.yml", reference_doc = "original.docx")
} # }
```
