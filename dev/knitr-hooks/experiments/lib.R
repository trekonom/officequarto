# Shared helpers for the knitr-hooks experiments.
# render_docx(): copies an experiment directory to a temp dir (so no artefacts land in the repo),
# renders one .qmd with the quarto CLI and returns the word/document.xml text plus quarto's stderr.
render_docx <- function(dir, qmd, extra_args = character()) {
  tmp <- tempfile("oqexp-")
  dir.create(tmp)
  tmp <- normalizePath(tmp)  # macOS: /var -> /private/var, else quarto refuses cleanup
  file.copy(list.files(dir, full.names = TRUE), tmp, recursive = TRUE)
  out <- system2("quarto", c("render", shQuote(file.path(tmp, qmd)), "--to", "docx", extra_args),
                 stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status") %||% 0L
  docx <- file.path(tmp, sub("\\.qmd$", ".docx", qmd))
  xml <- NA_character_
  if (file.exists(docx)) {
    x <- tempfile(); dir.create(x)
    utils::unzip(docx, exdir = x)
    xml <- paste(readLines(file.path(x, "word", "document.xml"), warn = FALSE), collapse = "\n")
  }
  list(xml = xml, log = out, status = status, tmp = tmp, docx = docx)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
has <- function(xml, pattern, fixed = TRUE) !is.na(xml) && grepl(pattern, xml, fixed = fixed)
report <- function(label, ok) cat(sprintf("%-60s %s\n", label, if (isTRUE(ok)) "YES" else "NO"))
