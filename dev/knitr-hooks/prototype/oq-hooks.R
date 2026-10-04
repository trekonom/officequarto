# Prototype: safe knitr hook helpers for Quarto (source() in a setup chunk).
# Quarto's hooks are delegating hooks; knitr_hooks$set() REPLACES them (experiment 03).
# chain_hook() keeps the previous hook and lets us pre-/post-process around it.
chain_hook <- function(name, before = NULL, after = NULL) {
  old <- knitr::knit_hooks$get(name)
  if (is.null(old)) stop("no existing knitr hook named '", name, "'")
  new <- function(x, options, ...) {
    if (!is.null(before)) options <- before(options) %||% options
    res <- old(x, options, ...)
    if (!is.null(after)) res <- after(res, options) %||% res
    res
  }
  knitr::knit_hooks$set(structure(list(new), names = name))
  invisible(old)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# Example: chained plot hook that appends a Word-style marker paragraph option
# (fig.style) without losing Quarto's figure div / crossref handling.
chain_hook("plot", after = function(res, options) {
  if (!is.null(options$fig.note)) paste0(res, "\n\nPLOT-HOOK-NOTE: ", options$fig.note, "\n\n") else res
})
