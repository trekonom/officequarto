# Run the officequarto post-render write-back hook

Reads the officequarto configuration for the current render via
`quarto inspect`, then rewrites the rendered `.docx` output(s) in place:
metadata merge from `reference-doc`, paragraph/table/figure style
mapping, captions, page layout, free-form style-map, cross-reference
text/fields, and style pruning. Called by the thin hook script shipped
under `_extensions/officequarto/scripts/writeback.R` (see
`system.file("_extensions", package = "officequarto")`) - not meant to
be called directly outside of a Quarto post-render context, since it
reads its entire configuration from environment variables Quarto sets
for that hook.

## Usage

``` r
oq_writeback()
```

## Value

Invisibly, `NULL`. Called for its side effect of overwriting the
rendered `.docx` file(s) referenced by `QUARTO_PROJECT_OUTPUT_FILES`.
