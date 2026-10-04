d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
for (q in c("a-default.qmd", "b-pandoc-args.qmd")) {
  r <- render_docx(d, q)
  cat("\n==", q, "==\n")
  report("render ok", r$status == 0)
  cat(grep("PANDOC.ARGS", r$log, value = TRUE), sep = "\n")
  st <- regmatches(r$xml, gregexpr('<w:tblStyle [^>]+>', r$xml))[[1]]
  cat("tblStyle:", unique(st), "\n")
  report("valid w:val ID with tabletemplate", any(grepl('w:val="tabletemplate"', st)))
  report("invalid w:tstlname present", has(r$xml, "tstlname"))
  report("invalid w:pstlname present", has(r$xml, "pstlname"))
  if (r$status != 0) cat(tail(r$log, 10), sep = "\n")
}

cat("\n== proj/ (post-render officer round-trip) ==\n")
r <- render_docx(file.path(d, "proj"), "exp.qmd")
report("render ok", r$status == 0)
st <- regmatches(r$xml, gregexpr('<w:tblStyle [^>]+>', r$xml))[[1]]
cat("tblStyle:", unique(st), "\n")
report("valid w:val ID with tabletemplate", any(grepl('w:val="tabletemplate"', st)))
report("no tstlname left", !has(r$xml, "tstlname"))
report("no pstlname left", !has(r$xml, "pstlname"))
report("caption + SEQ field kept", has(r$xml, "STYLED-TABLE") && has(r$xml, "SEQ"))
