# Reference a numbered figure or table

Inline helper that inserts a Word `REF` field (a clickable
cross-reference) to a figure or table numbered with
[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md).
It displays what Quarto's `@fig-x` would: the label and number, for
example "Figure 1". Use it in inline R code: `` `r oq_ref("fig-x")` ``.

## Usage

``` r
oq_ref(id)
```

## Arguments

- id:

  The chunk label of the figure or table, for example `"fig-x"`.

## Value

A
[`knitr::asis_output()`](https://rdrr.io/pkg/knitr/man/asis_output.html)
string (raw OpenXML for docx, `@id` otherwise).

## Details

For output formats other than docx it returns Quarto's own notation
(`@fig-x`), which Quarto resolves natively, so the same `.qmd` renders
correctly to HTML.

## See also

[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md)
