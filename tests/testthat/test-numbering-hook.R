## Pure-R tests for R/numbering-hook.R (no quarto render needed); the live render is covered by
## dev/fixtures/numbering-hook + dev/check-numbering-hook-e2e.R.

local_docx_target <- function(env = parent.frame()) {
  old <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  knitr::opts_knit$set(rmarkdown.pandoc.to = "docx")
  withr::defer(knitr::opts_knit$set(rmarkdown.pandoc.to = old), envir = env)
}

fig_md <- function(attrs = "{#fig-aD08295A6 width=50% fig-align='center'}") {
  paste0("\n::: {.cell-output-display}\n![CAP-A](fig-a-1.png)", attrs, "\n:::\n")
}

tbl_md <- function(caption = "TBL-A *emph* cap") {
  paste0(
    "\n::: {#tbl-a .cell tbl-cap='", caption, "'}\n\n::: {.cell-output-display}\n\n",
    "|   a|   b|\n|---:|---:|\n|   1|   2|\n\n:::\n:::\n"
  )
}

test_that("oq_fig_hook(): live SEQ caption, bookmark around label + number, id dropped, attrs kept", {
  local_docx_target()
  out <- oq_fig_hook()(fig_md(), list(label = "fig-a"))

  expect_match(out, "SEQ Figure \\* Arabic", fixed = TRUE)
  expect_match(out, 'w:name="fig-a"', fixed = TRUE)
  expect_match(out, "Figure ", fixed = TRUE)
  expect_match(out, "CAP-A", fixed = TRUE)
  expect_false(grepl("#fig-a", out, fixed = TRUE))
  expect_match(out, "{width=50% fig-align='center'}", fixed = TRUE)
  expect_match(out, "](fig-a-1.png)", fixed = TRUE)
  ## bookmark spans label + number: start before "Figure", end after the field
  expect_lt(regexpr("bookmarkStart", out), regexpr("Figure ", out))
  expect_lt(regexpr("fldCharType=\"end\"", out), regexpr("bookmarkEnd", out))
})

test_that("oq_fig_hook(): an id-only attribute block disappears completely", {
  local_docx_target()
  out <- oq_fig_hook()(fig_md("{#fig-aD08295A6}"), list(label = "fig-a"))
  expect_match(out, "fig-a-1.png)\n:::", fixed = TRUE)
})

test_that("oq_fig_hook(): bookmark ids are unique across calls and numbered chunks get label-i names", {
  local_docx_target()
  hook <- oq_fig_hook()
  a <- hook(fig_md(), list(label = "fig-a"))
  b <- hook(fig_md(), list(label = "fig-b"))
  ids <- c(
    regmatches(a, regexpr('bookmarkStart w:id="[0-9]+"', a)),
    regmatches(b, regexpr('bookmarkStart w:id="[0-9]+"', b))
  )
  expect_length(unique(ids), 2L)

  multi <- hook(fig_md(), list(label = "fig-m", fig.num = 3L, fig.cur = 2L))
  expect_match(multi, 'w:name="fig-m-2"', fixed = TRUE)
})

test_that("oq_fig_hook(): label text and separator come from chunk options", {
  local_docx_target()
  out <- oq_fig_hook()(fig_md(), list(label = "fig-a", oq.fig.label = "Abbildung", oq.sep = " - "))
  expect_match(out, "Abbildung ", fixed = TRUE)
  expect_match(out, " - CAP-A", fixed = TRUE)
  expect_error(
    oq_fig_hook()(fig_md(), list(label = "fig-a", oq.fig.label = 1)),
    "single string"
  )
})

test_that("oq_fig_hook(): leaves everything it does not own untouched", {
  local_docx_target()
  hook <- oq_fig_hook()
  md <- fig_md()
  expect_identical(hook(md, list(label = "plot1")), md)                       # not a fig- label
  expect_identical(hook(md, list(label = "fig-a", fig.subcap = "x")), md)     # sub-figures
  expect_identical(hook(md, list(label = "fig-a", layout = "[[1,1]]")), md)   # layout
  expect_identical(hook("![](x.png){#fig-a}", list(label = "fig-a")), "![](x.png){#fig-a}")  # no caption

  knitr::opts_knit$set(rmarkdown.pandoc.to = "html")
  expect_identical(hook(md, list(label = "fig-a")), md)                       # non-docx
})

test_that("oq_tbl_hook(): caption block before the output, id and tbl-cap removed, markdown kept", {
  local_docx_target()
  out <- oq_tbl_hook()(tbl_md(), list(label = "tbl-a"))

  expect_false(grepl("#tbl-a", out, fixed = TRUE))
  expect_false(grepl("tbl-cap", out, fixed = TRUE))
  expect_match(out, "^\n::: \\{\\.cell\\}")
  expect_match(out, '::: {custom-style="Table Caption"}', fixed = TRUE)
  expect_match(out, "SEQ Table \\* Arabic", fixed = TRUE)
  expect_match(out, 'w:name="tbl-a"', fixed = TRUE)
  expect_match(out, "TBL-A *emph* cap", fixed = TRUE)
  expect_lt(regexpr("custom-style", out), regexpr("{.cell-output-display}", out, fixed = TRUE))
})

test_that("oq_tbl_hook(): escaped apostrophes in the caption are restored; style and label are options", {
  local_docx_target()
  out <- oq_tbl_hook()(
    tbl_md("It\\'s a \"quoted\" } caption"),
    list(label = "tbl-a", oq.tbl.label = "Tabelle", oq.tbl.style = "Beschriftung")
  )
  expect_match(out, "It's a \"quoted\" } caption", fixed = TRUE)
  expect_match(out, "Tabelle ", fixed = TRUE)
  expect_match(out, 'custom-style="Beschriftung"', fixed = TRUE)
})

test_that("oq_tbl_hook(): a cell without .cell-output-display gets the caption right after the opener", {
  local_docx_target()
  md <- "\n::: {#tbl-a .cell tbl-cap='C'}\nplain\n:::\n"
  out <- oq_tbl_hook()(md, list(label = "tbl-a"))
  expect_lt(regexpr("custom-style", out), regexpr("plain", out))
})

test_that("oq_tbl_hook(): leaves everything it does not own untouched", {
  local_docx_target()
  hook <- oq_tbl_hook()
  md <- tbl_md()
  expect_identical(hook(md, list(label = "other")), md)
  nocap <- "\n::: {#tbl-a .cell}\n\n::: {.cell-output-display}\nx\n:::\n:::\n"
  expect_identical(hook(nocap, list(label = "tbl-a")), nocap)
  knitr::opts_knit$set(rmarkdown.pandoc.to = "html")
  expect_identical(hook(md, list(label = "tbl-a")), md)
})

test_that("oq_numbering(): chains onto the existing hook, is idempotent, and honours custom hooks", {
  local_docx_target()
  saved <- knitr::knit_hooks$get()
  on.exit(knitr::knit_hooks$restore(saved), add = TRUE)

  knitr::knit_hooks$set(plot = function(x, options) fig_md())   # stand-in for Quarto's hook
  oq_numbering(tables = FALSE)
  once <- knitr::knit_hooks$get("plot")("p.png", list(label = "fig-a"))
  oq_numbering(tables = FALSE)                                  # second call must not stack
  twice <- knitr::knit_hooks$get("plot")("p.png", list(label = "fig-a"))
  expect_match(once, "SEQ Figure", fixed = TRUE)
  expect_equal(lengths(regmatches(twice, gregexpr("SEQ Figure", twice, fixed = TRUE))), 1L)

  oq_numbering(tables = FALSE, fig_hook = function(res, options) paste0("CUSTOM:", sub("^\n", "", res)))
  custom <- knitr::knit_hooks$get("plot")("p.png", list(label = "fig-a"))
  expect_match(custom, "^CUSTOM:")
  expect_false(grepl("SEQ Figure", custom, fixed = TRUE))       # replaces, does not add to, the default
  expect_match(custom, "CAP-A", fixed = TRUE)                   # but still sits on top of the previous hook
})

test_that("oq_numbering(): validates custom hooks", {
  expect_error(oq_numbering(fig_hook = "nope"), "fig_hook")
  expect_error(oq_numbering(tbl_hook = function(x) x), "tbl_hook")
})

test_that("oq_ref(): REF field hyperlink for docx, Quarto notation otherwise", {
  local_docx_target()
  ref <- oq_ref("fig-a")
  expect_s3_class(ref, "knit_asis")
  expect_match(ref, '<w:hyperlink w:anchor="fig-a">', fixed = TRUE)
  expect_match(ref, "REF fig-a \\h", fixed = TRUE)
  expect_match(ref, "{=openxml}", fixed = TRUE)

  knitr::opts_knit$set(rmarkdown.pandoc.to = "html")
  expect_identical(as.character(oq_ref("fig-a")), "@fig-a")

  expect_error(oq_ref(c("a", "b")), "single chunk label")
  expect_error(oq_ref(""), "single chunk label")
})
