## Native (live) figure/table numbering through knitr hooks - an opt-in alternative to the
## post-render officequarto.crossref.auto-number (see CLAUDE.md "Numbering hook" and
## dev/knitr-hooks/experiments/15-fig-caption-hooks, 16-table-hook-spike).
##
## Quarto's own numbering is static text added by a Lua filter AFTER knitr ran, so a hook can only
## influence the markdown that reaches Pandoc. The hooks here chain onto Quarto's `plot` (figures)
## and `chunk` (tables) hooks, strip the Quarto crossref id from the figure/table and build the
## caption themselves: bookmark around "<label> <number>" + live SEQ field + separator + caption
## text. Quarto therefore no longer knows the item, so `@fig-x` does not resolve for it - references
## go through oq_ref() (a REF field to the bookmark).

## Bookmark ids must be unique within the docx and must not collide with Pandoc's own (small
## integers); one counter per R session is enough since Quarto starts a fresh R process per render.
#' @noRd
oq_numbering_state <- new.env(parent = emptyenv())
oq_numbering_state$bookmark_id <- 100000L

#' @noRd
oq_next_bookmark_id <- function() {
  id <- oq_numbering_state$bookmark_id + 1L
  oq_numbering_state$bookmark_id <- id
  id
}

#' @noRd
oq_xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

#' @noRd
oq_raw_inline <- function(xml) paste0("`", xml, "`{=openxml}")

## 3-run complex field, same shape as the SEQ/REF fields the post-render code builds
## (R/table-caption-mapping.R): fldChar begin -> instrText -> fldChar end, both fldChars dirty,
## no "separate" fldChar and no cached result - Word computes the value on open.
#' @noRd
oq_wml_field <- function(instr) {
  paste0(
    '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>',
    '<w:r><w:instrText xml:space="preserve"> ', instr, ' </w:instrText></w:r>',
    '<w:r><w:fldChar w:fldCharType="end" w:dirty="true"/></w:r>'
  )
}

## The caption as Pandoc markdown with inline raw OpenXML: the bookmark wraps label + number
## ("Figure 1"), so a REF field to it yields exactly what Quarto's own `@fig-x` renders.
#' @noRd
oq_caption_markdown <- function(id, text, label, sep, seq_id) {
  bm <- oq_next_bookmark_id()
  paste0(
    oq_raw_inline(sprintf('<w:bookmarkStart w:id="%d" w:name="%s"/>', bm, oq_xml_escape(id))),
    label, "\u00a0",
    oq_raw_inline(oq_wml_field(sprintf("SEQ %s \\* Arabic", seq_id))),
    oq_raw_inline(sprintf('<w:bookmarkEnd w:id="%d"/>', bm)),
    sep, text
  )
}

#' @noRd
oq_numbering_chr <- function(options, name, default) {
  value <- options[[name]]
  if (is.null(value)) return(default)
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("officequarto: chunk option '%s' must be a single string.", name), call. = FALSE)
  }
  value
}

#' @noRd
oq_is_numbering_label <- function(label, prefix) {
  is.character(label) && length(label) == 1L && !is.na(label) && grepl(paste0("^", prefix, "-"), label)
}

## Finds the first markdown image ![caption](path){attrs} produced by Quarto's plot hook. Perl
## regex so that attribute values may contain `}` inside quotes and captions may contain
## balanced brackets.
#' @noRd
oq_match_image <- function(res) {
  pattern <- paste0(
    "!\\[((?:[^\\[\\]]|\\[[^\\]]*\\])*)\\]",   # ![caption]
    "\\(([^)]*)\\)",                           # (path)
    "(\\{(?:[^}'\"]|'(?:[^'\\\\]|\\\\.)*'|\"[^\"]*\")*\\})?"  # optional {attrs}
  )
  m <- regexec(pattern, res, perl = TRUE)
  parts <- regmatches(res, m)[[1]]
  if (length(parts) == 0L) return(NULL)
  start <- as.integer(m[[1]][1])
  list(
    full = parts[1], caption = parts[2], path = parts[3], attrs = parts[4],
    start = start, end = start + nchar(parts[1]) - 1L
  )
}

## Quarto puts the crossref id into the image attributes ({#fig-a width=...}); drop only that
## token and keep width/align/alt.
#' @noRd
oq_strip_id_from_attrs <- function(attrs) {
  if (!nzchar(attrs)) return("")
  attrs <- sub("#[^ }]+ *", "", attrs)
  if (grepl("^\\{\\s*\\}$", attrs)) return("")
  sub("\\s+\\}$", "}", attrs)
}

#' @noRd
oq_has_layout <- function(options) {
  layout_keys <- c("layout", "layout-ncol", "layout-nrow", "fig.ncol", "fig.sep")
  any(vapply(layout_keys, function(k) !is.null(options[[k]]), logical(1)))
}

#' Default figure numbering hook
#'
#' Returns the default post-processor that [oq_numbering()] chains onto Quarto's `plot` hook. Use
#' it as a building block for a custom `fig_hook` (wrap it, or call it and then adjust the result).
#'
#' The returned function has the signature `function(res, options)`: `res` is the markdown Quarto's
#' own plot hook produced (`![caption](path){#fig-id ...}`), `options` the chunk options. It
#' replaces the caption with a bookmarked `Figure <SEQ field>: caption` and drops the Quarto
#' cross-reference id (so Quarto no longer numbers the figure, see [oq_ref()]). It returns `res`
#' unchanged for non-docx output, chunks whose label does not start with `fig-`, chunks without a
#' caption, and chunks with sub-figures (`fig-subcap`) or a `layout`.
#'
#' The label text, separator and caption can be set per chunk or globally (for example under
#' `knitr: opts_chunk:` in `_quarto.yml`) with the chunk options `oq.fig.label` (default
#' `"Figure"`) and `oq.sep` (default `": "`).
#'
#' @return A function `function(res, options)` returning markdown.
#' @seealso [oq_numbering()], [oq_tbl_hook()], [oq_ref()]
#' @export
oq_fig_hook <- function() {
  function(res, options) {
    if (!oq_is_docx_target()) return(res)
    label <- options[["label"]]
    if (!oq_is_numbering_label(label, "fig")) return(res)
    if (length(options[["fig.subcap"]]) > 0L || oq_has_layout(options)) return(res)

    img <- oq_match_image(res)
    if (is.null(img) || !nzchar(img$caption)) return(res)

    n_figs <- options[["fig.num"]] %||% 1L
    id <- if (n_figs > 1L) paste0(label, "-", options[["fig.cur"]] %||% 1L) else label
    caption <- oq_caption_markdown(
      id, img$caption,
      label = oq_numbering_chr(options, "oq.fig.label", "Figure"),
      sep = oq_numbering_chr(options, "oq.sep", ": "),
      seq_id = "Figure"
    )
    new_image <- paste0("![", caption, "](", img$path, ")", oq_strip_id_from_attrs(img$attrs))
    paste0(substr(res, 1L, img$start - 1L), new_image, substr(res, img$end + 1L, nchar(res)))
  }
}

## Quarto's chunk hook ends with the cell div: `::: {#tbl-a .cell tbl-cap='...'}` (an apostrophe
## in the caption is escaped as \'; `"` and `}` are not).
#' @noRd
oq_match_table_cell <- function(res) {
  pattern <- paste0(
    "^(\\s*)::: \\{#([^ }]+)",
    "((?:[^}'\"]|'(?:[^'\\\\]|\\\\.)*'|\"[^\"]*\")*)\\}"
  )
  m <- regexec(pattern, res, perl = TRUE)
  parts <- regmatches(res, m)[[1]]
  if (length(parts) == 0L) return(NULL)
  rest <- parts[4]
  cap <- regmatches(rest, regexec("tbl-cap='((?:[^'\\\\]|\\\\.)*)'", rest, perl = TRUE))[[1]]
  if (length(cap) == 0L) return(NULL)
  list(
    opener = parts[1], indent = parts[2], id = parts[3],
    caption = gsub("\\'", "'", cap[2], fixed = TRUE),
    rest = trimws(sub("\\s*tbl-cap='(?:[^'\\\\]|\\\\.)*'", "", rest, perl = TRUE))
  )
}

#' Default table numbering hook
#'
#' Returns the default post-processor that [oq_numbering()] chains onto Quarto's `chunk` hook.
#' Use it as a building block for a custom `tbl_hook`.
#'
#' The returned function has the signature `function(res, options)`: `res` is the complete cell
#' markdown Quarto's chunk hook produced (`::: {#tbl-id .cell tbl-cap='...'} ...`), `options` the
#' chunk options. It removes the Quarto cross-reference id and caption attribute from the cell and
#' inserts a caption paragraph (`Table <SEQ field>: caption`, in the paragraph style
#' `oq.tbl.style`, default `"Table Caption"`) before the table output, so it works for `kable()`,
#' flextable and other table producers. The caption text may contain inline markdown. It returns
#' `res` unchanged for non-docx output, chunks whose label does not start with `tbl-`, and cells
#' without a `tbl-cap`.
#'
#' Chunk options: `oq.tbl.label` (default `"Table"`), `oq.sep` (default `": "`), `oq.tbl.style`.
#'
#' @return A function `function(res, options)` returning markdown.
#' @seealso [oq_numbering()], [oq_fig_hook()], [oq_ref()]
#' @export
oq_tbl_hook <- function() {
  function(res, options) {
    if (!oq_is_docx_target()) return(res)
    label <- options[["label"]]
    if (!oq_is_numbering_label(label, "tbl")) return(res)

    cell <- oq_match_table_cell(res)
    if (is.null(cell) || !nzchar(cell$caption)) return(res)

    caption <- oq_caption_markdown(
      cell$id, cell$caption,
      label = oq_numbering_chr(options, "oq.tbl.label", "Table"),
      sep = oq_numbering_chr(options, "oq.sep", ": "),
      seq_id = "Table"
    )
    block <- paste0(
      cell$indent, '::: {custom-style="', oq_numbering_chr(options, "oq.tbl.style", "Table Caption"), '"}\n',
      cell$indent, caption, "\n",
      cell$indent, ":::\n\n"
    )
    new_opener <- paste0(cell$indent, "::: {", cell$rest, "}")
    body <- substr(res, nchar(cell$opener) + 1L, nchar(res))
    marker <- paste0(cell$indent, "::: {.cell-output-display}")
    pos <- regexpr(marker, body, fixed = TRUE)
    if (pos[1] > 0L) {
      body <- paste0(substr(body, 1L, pos[1] - 1L), block, substr(body, pos[1], nchar(body)))
      paste0(new_opener, body)
    } else {
      paste0(new_opener, "\n\n", block, sub("^\n+", "", body))
    }
  }
}

## Chains `after` onto the currently installed knitr hook `name`: the previous hook (Quarto's) runs
## first, then `after(res, options)` post-processes its output. Replacing a hook with
## knit_hooks$set() would drop Quarto's cell/crossref handling (dev/knitr-hooks Exp. 3), hence the
## chaining. Idempotent: if the installed hook is one of ours, the inner (Quarto) hook is chained
## again instead of stacking a second layer.
#' @noRd
oq_chain_hook <- function(name, after) {
  current <- knitr::knit_hooks$get(name)
  if (is.null(current)) {
    stop(sprintf("officequarto: no knitr hook named '%s' is installed.", name), call. = FALSE)
  }
  inner <- attr(current, "oq_inner", exact = TRUE) %||% current
  chained <- local({
    force(inner)
    force(after)
    function(x, options, ...) after(inner(x, options, ...), options)
  })
  attr(chained, "oq_inner") <- inner
  knitr::knit_hooks$set(structure(list(chained), names = name))
  invisible(inner)
}

#' @noRd
oq_check_hook_arg <- function(hook, arg) {
  if (is.null(hook)) return(invisible(NULL))
  if (!is.function(hook) || length(formals(hook)) < 2L) {
    stop(sprintf(
      "officequarto: `%s` must be a function(res, options) returning markdown (see ?oq_numbering).", arg
    ), call. = FALSE)
  }
  invisible(NULL)
}

#' Native Word numbering for R-chunk figures and tables
#'
#' Call once in the setup chunk of a `.qmd` (after `library(officequarto)`) to give figures and
#' tables produced by R chunks real Word captions: `Figure <SEQ field>: caption` and
#' `Table <SEQ field>: caption`, each wrapped in a bookmark named after the chunk label. Word
#' computes the numbers itself (and renumbers when you insert or move items). This is an opt-in
#' alternative to the post-render option `officequarto.crossref.auto-number`, which converts
#' Quarto's static captions after the fact.
#'
#' The hooks chain onto Quarto's own `plot` (figures) and `chunk` (tables) hooks, so cell
#' structure, sizes and alignment are kept. For the numbered items Quarto's cross-reference id is
#' removed, which has consequences:
#' * `@fig-x` / `@tbl-x` no longer resolve for them. Reference them with [oq_ref()], e.g.
#'   `` `r oq_ref("fig-x")` ``, which inserts a `REF` field showing "Figure 1".
#' * Only figures and tables created by R chunks are handled (chunk label starting `fig-` /
#'   `tbl-` plus a `fig-cap` / `tbl-cap`). Markdown images and tables, sub-figures
#'   (`fig-subcap`) and `layout` chunks are left to Quarto.
#' * There is no list of figures/tables, and nothing happens for non-docx output.
#'
#' Label text and separator are chunk options and can be set globally in `_quarto.yml`:
#' ```yaml
#' knitr:
#'   opts_chunk:
#'     oq.fig.label: "Abbildung"
#'     oq.tbl.label: "Tabelle"
#'     oq.sep: ": "
#' ```
#'
#' @param figures,tables Logical; install the figure (`plot` hook) and/or table (`chunk` hook)
#'   numbering. Default `TRUE`.
#' @param fig_hook,tbl_hook Optional custom hooks, `function(res, options)`, that **replace** the
#'   built-in post-processing (see [oq_fig_hook()], [oq_tbl_hook()]). They are still chained onto
#'   Quarto's hook, so `res` is the markdown Quarto produced for the figure (`plot` hook: the
#'   `![caption](path){#fig-id ...}` image) or for the whole cell (`chunk` hook); return the
#'   markdown to use instead. Wrap the default to extend it:
#'   `function(res, options) oq_fig_hook()(res, options)`.
#'
#' Calling `oq_numbering()` again re-configures instead of stacking hooks.
#'
#' @return Invisibly `NULL`; called for its side effect of installing knitr hooks.
#' @seealso [oq_ref()], [oq_fig_hook()], [oq_tbl_hook()]
#' @examples
#' \dontrun{
#' # in the setup chunk of a .qmd
#' library(officequarto)
#' oq_numbering()
#'
#' # custom figure hook: default behaviour, then add a note below the figure
#' oq_numbering(fig_hook = function(res, options) {
#'   paste0(oq_fig_hook()(res, options), "\n\nSource: ", options$source %||% "n/a")
#' })
#' }
#' @export
oq_numbering <- function(figures = TRUE, tables = TRUE, fig_hook = NULL, tbl_hook = NULL) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("officequarto: package 'knitr' is required for oq_numbering().", call. = FALSE)
  }
  oq_check_hook_arg(fig_hook, "fig_hook")
  oq_check_hook_arg(tbl_hook, "tbl_hook")
  if (isTRUE(figures)) oq_chain_hook("plot", fig_hook %||% oq_fig_hook())
  if (isTRUE(tables)) oq_chain_hook("chunk", tbl_hook %||% oq_tbl_hook())
  invisible(NULL)
}

#' Reference a numbered figure or table
#'
#' Inline helper that inserts a Word `REF` field (a clickable cross-reference) to a figure or
#' table numbered with [oq_numbering()]. It displays what Quarto's `@fig-x` would: the label and
#' number, for example "Figure 1". Use it in inline R code: `` `r oq_ref("fig-x")` ``.
#'
#' For output formats other than docx it returns Quarto's own notation (`@fig-x`), which Quarto
#' resolves natively, so the same `.qmd` renders correctly to HTML.
#'
#' @param id The chunk label of the figure or table, for example `"fig-x"`.
#' @return A [knitr::asis_output()] string (raw OpenXML for docx, `@id` otherwise).
#' @seealso [oq_numbering()]
#' @export
oq_ref <- function(id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id)) {
    stop("officequarto: `id` must be a single chunk label such as \"fig-x\".", call. = FALSE)
  }
  if (!oq_is_docx_target()) return(knitr::asis_output(paste0("@", id)))
  id_xml <- oq_xml_escape(id)
  knitr::asis_output(oq_raw_inline(paste0(
    '<w:hyperlink w:anchor="', id_xml, '">', oq_wml_field(sprintf("REF %s \\h", id_xml)), "</w:hyperlink>"
  )))
}

#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
