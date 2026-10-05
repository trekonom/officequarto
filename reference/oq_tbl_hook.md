# Default table numbering hook

Returns the default post-processor that
[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md)
chains onto Quarto's `chunk` hook. Use it as a building block for a
custom `tbl_hook`.

## Usage

``` r
oq_tbl_hook()
```

## Value

A function `function(res, options)` returning markdown.

## Details

The returned function has the signature `function(res, options)`: `res`
is the complete cell markdown Quarto's chunk hook produced
(`::: {#tbl-id .cell tbl-cap='...'} ...`), `options` the chunk options.
It removes the Quarto cross-reference id and caption attribute from the
cell and inserts a caption paragraph (`Table <SEQ field>: caption`, in
the paragraph style `oq.tbl.style`, default `"Table Caption"`) before
the table output, so it works for `kable()`, flextable and other table
producers. The caption text may contain inline markdown. It returns
`res` unchanged for non-docx output, chunks whose label does not start
with `tbl-`, and cells without a `tbl-cap`.

Chunk options: `oq.tbl.label` (default `"Table"`), `oq.sep` (default
`": "`), `oq.tbl.style`.

## See also

[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md),
[`oq_fig_hook()`](https://trekonom.github.io/officequarto/reference/oq_fig_hook.md),
[`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md)
