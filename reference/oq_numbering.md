# Native Word numbering for R-chunk figures and tables

Call once in the setup chunk of a `.qmd` (after
[`library(officequarto)`](https://trekonom.github.io/officequarto/)) to
give figures and tables produced by R chunks real Word captions:
`Figure <SEQ field>: caption` and `Table <SEQ field>: caption`, each
wrapped in a bookmark named after the chunk label. Word computes the
numbers itself (and renumbers when you insert or move items). This is an
opt-in alternative to the post-render option
`officequarto.crossref.auto-number`, which converts Quarto's static
captions after the fact.

## Usage

``` r
oq_numbering(figures = TRUE, tables = TRUE, fig_hook = NULL, tbl_hook = NULL)
```

## Arguments

- figures, tables:

  Logical; install the figure (`plot` hook) and/or table (`chunk` hook)
  numbering. Default `TRUE`.

- fig_hook, tbl_hook:

  Optional custom hooks, `function(res, options)`, that **replace** the
  built-in post-processing (see
  [`oq_fig_hook()`](https://trekonom.github.io/officequarto/reference/oq_fig_hook.md),
  [`oq_tbl_hook()`](https://trekonom.github.io/officequarto/reference/oq_tbl_hook.md)).
  They are still chained onto Quarto's hook, so `res` is the markdown
  Quarto produced for the figure (`plot` hook: the
  `![caption](path){#fig-id ...}` image) or for the whole cell (`chunk`
  hook); return the markdown to use instead. Wrap the default to extend
  it: `function(res, options) oq_fig_hook()(res, options)`.

  Calling `oq_numbering()` again re-configures instead of stacking
  hooks.

## Value

Invisibly `NULL`; called for its side effect of installing knitr hooks.

## Details

The hooks chain onto Quarto's own `plot` (figures) and `chunk` (tables)
hooks, so cell structure, sizes and alignment are kept. For the numbered
items Quarto's cross-reference id is removed, which has consequences:

- Quarto's own cross-reference resolution no longer knows them. In an
  officequarto project (`project: type: officequarto`) the extension's
  `refs.lua` filter turns Quarto notation (`@fig-x`, `[@fig-x]`,
  `[@fig-x; @tbl-y]`, ...) into `REF` fields showing "Figure 1". Without
  the extension, reference them with
  [`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md),
  e.g. `` `r oq_ref("fig-x")` ``.

- Only figures and tables created by R chunks are handled (chunk label
  starting `fig-` / `tbl-` plus a `fig-cap` / `tbl-cap`). Markdown
  images and tables, sub-figures (`fig-subcap`) and `layout` chunks are
  left to Quarto.

- There is no list of figures/tables, and nothing happens for non-docx
  output.

Label text and separator are chunk options and can be set globally in
`_quarto.yml`:

    knitr:
      opts_chunk:
        oq.fig.label: "Abbildung"
        oq.tbl.label: "Tabelle"
        oq.sep: ": "

## See also

[`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md),
[`oq_fig_hook()`](https://trekonom.github.io/officequarto/reference/oq_fig_hook.md),
[`oq_tbl_hook()`](https://trekonom.github.io/officequarto/reference/oq_tbl_hook.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# in the setup chunk of a .qmd
library(officequarto)
oq_numbering()

# custom figure hook: default behaviour, then add a note below the figure
oq_numbering(fig_hook = function(res, options) {
  paste0(oq_fig_hook()(res, options), "\n\nSource: ", options$source %||% "n/a")
})
} # }
```
