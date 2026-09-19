# Using officer syntax inline

Unlike every `officequarto.*` option documented in
[`vignette("options")`](https://trekonom.github.io/officequarto/articles/options.md),
this is a plain R-session feature, not a `_quarto.yml` setting: it lets
you use {officer}’s run/paragraph/block constructors
([`ftext()`](https://davidgohel.github.io/officer/reference/ftext.html),
[`fp_par()`](https://davidgohel.github.io/officer/reference/fp_par.html),
[`run_word_field()`](https://davidgohel.github.io/officer/reference/run_word_field.html),
[`block_pour_docx()`](https://davidgohel.github.io/officer/reference/block_pour_docx.html),
…) directly as inline R expressions in a `.qmd`, the same way
{officedown} lets you in an `.Rmd`. For example (shown here without
backticks to avoid this vignette itself trying to evaluate it):

> The \`r ftext(“officequarto”, fp_text(bold = TRUE, color =
> “#C32900”))\` package can be installed from CRAN or GitHub.

Without this, returning an {officer} object from an inline R expression
errors — there’s no `knit_print` method registered for {officer}’s S3
classes anywhere (not in {officer} itself, and {officedown}’s own
`knit_print.run`/`knit_print.fp_par`/`knit_print.block` methods are only
registered when {officedown} itself is loaded). `officequarto` registers
the equivalent three methods itself, so you get this without needing
{officedown} at all.

To use it, add both packages to your `.qmd`’s setup chunk — loading
`officequarto` is what registers the methods for the current R session,
so it must happen before any inline expression that returns an {officer}
object:

``` r

library(officequarto)
library(officer)
```

- [`ftext()`](https://davidgohel.github.io/officer/reference/ftext.html),
  [`run_word_field()`](https://davidgohel.github.io/officer/reference/run_word_field.html),
  [`run_reference()`](https://davidgohel.github.io/officer/reference/run_reference.html),
  [`run_autonum()`](https://davidgohel.github.io/officer/reference/run_autonum.html),
  [`run_bookmark()`](https://davidgohel.github.io/officer/reference/run_bookmark.html),
  and other {officer} **run**-level constructors, and
  [`fp_par()`](https://davidgohel.github.io/officer/reference/fp_par.html)
  (paragraph properties): use directly inline (`ftext(...)`,
  `fp_par(text.align = "center")`, wrapped the same way as the example
  above). These render to a `<w:r>`/`<w:pPr>` XML fragment spliced into
  the surrounding paragraph.
- {officer} **block**-level constructors
  ([`block_pour_docx()`](https://davidgohel.github.io/officer/reference/block_pour_docx.html),
  [`block_section()`](https://davidgohel.github.io/officer/reference/block_section.html),
  [`fpar()`](https://davidgohel.github.io/officer/reference/fpar.html),
  [`block_list()`](https://davidgohel.github.io/officer/reference/block_list.html),
  [`block_toc()`](https://davidgohel.github.io/officer/reference/block_toc.html),
  [`block_caption()`](https://davidgohel.github.io/officer/reference/block_caption.html),
  …), which render to one or more complete `<w:p>` elements, work the
  same way, returned directly from a chunk. As in {officedown}, this
  relies on `knit_print` dispatch, which isn’t triggered by a call
  inside a `for` loop — that case isn’t covered here.

This works because officequarto’s `knit_print` methods use the exact
same mechanism as {officedown}’s: wrapping `officer::to_wml(x)` as
Pandoc raw OOXML (`` `...`{=openxml} `` for runs/paragraph-properties, a
fenced ```` ```{=openxml} ```` block for full blocks — the split
matters, since a raw inline block-level fragment gets nested inside
Pandoc’s own paragraph and corrupts the docx). The resulting XML is
spliced directly into `word/document.xml` by Pandoc itself during
rendering, before this hook ever runs — `officequarto`’s own post-render
style-mapping/ pruning logic treats it like any other run or paragraph,
with no special-casing needed.
