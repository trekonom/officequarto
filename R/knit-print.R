## knit_print methods letting officer's run/paragraph/block constructors (ftext(),
## fp_par(), run_word_field(), block_pour_docx(), ...) be used directly as inline R
## expressions in an officequarto .qmd, e.g. `` `r officer::ftext("x", ft)` ``.
## Registered dynamically in zzz.R (not @export'd: knitr owns the knit_print generic
## and is Suggests-only here, same as officer itself - see DESCRIPTION).
##
## Mirrors {officedown}'s R/rdocx_knit_print.R exactly, including the inline-vs-fenced
## split: officer's "run"/"fp_par" objects render to a <w:r>/<w:pPr> fragment, safe to
## splice inline inside an existing paragraph via a single-backtick raw span; "block"
## objects (block_pour_docx(), block_section(), fpar(), block_list(), ...) render to
## one or more complete <w:p> elements, which corrupts the docx if emitted inline
## (Pandoc nests the raw <w:p> inside its own auto-generated one - jgm/pandoc#5094) and
## must instead go out as a fenced ```{=openxml}``` block.

#' @noRd
oq_is_docx_target <- function() {
  pandoc_to <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  isTRUE(!is.null(pandoc_to) && grepl("docx", pandoc_to))
}

#' @noRd
oq_require_officer <- function() {
  if (!requireNamespace("officer", quietly = TRUE)) {
    stop(
      "Package 'officer' is required to use officer's run/paragraph/block ",
      "constructors (ftext(), fp_par(), block_pour_docx(), ...) inline in a ",
      ".qmd document. Install it with install.packages(\"officer\").",
      call. = FALSE
    )
  }
}

#' @noRd
knit_print.run <- function(x, ...) {
  oq_require_officer()
  if (oq_is_docx_target()) {
    knitr::knit_print(knitr::asis_output(
      paste0("`", officer::to_wml(x), "`{=openxml}")
    ))
  } else {
    knitr::knit_print(knitr::asis_output(""))
  }
}

#' @noRd
knit_print.fp_par <- function(x, ...) {
  oq_require_officer()
  if (oq_is_docx_target()) {
    knitr::knit_print(knitr::asis_output(
      paste0("`", officer::to_wml(x), "`{=openxml}")
    ))
  } else {
    knitr::knit_print(knitr::asis_output(""))
  }
}

#' @noRd
knit_print.block <- function(x, ...) {
  oq_require_officer()
  if (oq_is_docx_target()) {
    knitr::knit_print(knitr::asis_output(
      paste("```{=openxml}", officer::to_wml(x), "```", sep = "\n")
    ))
  } else {
    knitr::knit_print(knitr::asis_output(""))
  }
}
