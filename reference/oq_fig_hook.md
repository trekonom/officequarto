# Default figure numbering hook

Returns the default post-processor that
[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md)
chains onto Quarto's `plot` hook. Use it as a building block for a
custom `fig_hook` (wrap it, or call it and then adjust the result).

## Usage

``` r
oq_fig_hook()
```

## Value

A function `function(res, options)` returning markdown.

## Details

The returned function has the signature `function(res, options)`: `res`
is the markdown Quarto's own plot hook produced
(`![caption](path){#fig-id ...}`), `options` the chunk options. It
replaces the caption with a bookmarked `Figure <SEQ field>: caption` and
drops the Quarto cross-reference id (so Quarto no longer numbers the
figure, see
[`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md)).
It returns `res` unchanged for non-docx output, chunks whose label does
not start with `fig-`, chunks without a caption, and chunks with
sub-figures (`fig-subcap`) or a `layout`.

The label text, separator and caption can be set per chunk or globally
(for example under `knitr: opts_chunk:` in `_quarto.yml`) with the chunk
options `oq.fig.label` (default `"Figure"`) and `oq.sep` (default
`": "`).

## See also

[`oq_numbering()`](https://trekonom.github.io/officequarto/reference/oq_numbering.md),
[`oq_tbl_hook()`](https://trekonom.github.io/officequarto/reference/oq_tbl_hook.md),
[`oq_ref()`](https://trekonom.github.io/officequarto/reference/oq_ref.md)
