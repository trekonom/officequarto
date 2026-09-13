## Registers officequarto's knit_print methods (R/knit-print.R) against knitr's
## knit_print generic conditionally, at package load time - not via roxygen @export,
## since knitr (like officer) is Suggests-only here and this must not force either to
## load just to install/check officequarto. Standard CRAN-safe pattern for registering
## an S3 method for a generic that lives in a Suggested package (cf. vctrs::s3_register()).

#' @noRd
oq_s3_register <- function(generic, class, method) {
  pieces <- strsplit(generic, "::")[[1]]
  package <- pieces[[1]]
  generic_name <- pieces[[2]]

  setHook(
    packageEvent(package, "onLoad"),
    function(...) {
      registerS3method(generic_name, class, method, envir = asNamespace(package))
    }
  )

  if (isNamespaceLoaded(package)) {
    registerS3method(generic_name, class, method, envir = asNamespace(package))
  }

  invisible()
}

.onLoad <- function(libname, pkgname) {
  oq_s3_register("knitr::knit_print", "run", knit_print.run)
  oq_s3_register("knitr::knit_print", "fp_par", knit_print.fp_par)
  oq_s3_register("knitr::knit_print", "block", knit_print.block)
}
