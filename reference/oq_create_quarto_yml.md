# Create a standalone, reusable officequarto-ready `_quarto.yml`

Writes a `_quarto.yml` listing every `officequarto` option at its
default value (`project: type: officequarto` plus the
`format.docx.officequarto` block) - the same content
[`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)
generates internally for a brand new project, but usable standalone: as
a reusable starting point for future projects (to hand-edit once and
drop into any project you want to convert to officequarto, or to later
pass as `oq_create_project(path, quarto_yml = ...)`). Deliberately has
no `reference_doc` argument: a reference document is project-specific,
so baking one in here would work against reuse - use
[`oq_create_project()`](https://trekonom.github.io/officequarto/reference/oq_create_project.md)'s
own `reference_doc` argument to wire one up for one concrete project.

## Usage

``` r
oq_create_quarto_yml(path = "_quarto.yml", overwrite = FALSE)
```

## Arguments

- path:

  Character. Destination file path, default `"_quarto.yml"` (the current
  working directory). Fails loudly if a file already exists at `path`,
  unless `overwrite = TRUE` (no silent clobbering).

- overwrite:

  Logical, default `FALSE`. Set `TRUE` to overwrite an existing file at
  `path`.

## Value

Invisibly, the normalized path to the written file.

## Examples

``` r
if (FALSE) { # \dontrun{
oq_create_quarto_yml("_quarto.yml")
} # }
```
