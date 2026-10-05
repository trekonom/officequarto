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

