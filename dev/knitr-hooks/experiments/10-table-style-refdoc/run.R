d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
r <- render_docx(d, "exp.qmd")
report("render ok", r$status == 0)
st <- regmatches(r$xml, gregexpr('w:tblStyle w:val="[^"]+"', r$xml))[[1]]
cat("tblStyle in document.xml:", unique(st), "\n")
report("requested style applied as w:val ID", any(grepl("w:val=", st)))
if (r$status != 0) cat(tail(r$log, 10), sep = "\n")
