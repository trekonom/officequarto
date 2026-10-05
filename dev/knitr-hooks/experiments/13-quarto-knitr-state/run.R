d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
for (q in c("state.qmd", "yaml.qmd", "yaml-hooks.qmd")) {
  r <- render_docx(d, q)
  cat("\n==", q, "==\n")
  report("render ok", r$status == 0)
  p <- file.path(r$tmp, "probe.txt")
  if (file.exists(p)) cat(readLines(p), sep = "\n") else cat("(no probe.txt)\n")
  if (r$status != 0) cat(grep("ERROR|invalid|property name", r$log, value = TRUE), sep = "\n")
}
