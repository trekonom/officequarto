d <- dirname(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)))
source(file.path(d, "..", "lib.R"))
r <- render_docx(d, "exp.qmd")
report("render ok", r$status == 0)
report("toc: true -> TOC field", has(r$xml, "TOC \\"))
report("{{< pagebreak >}} -> w:br type=page", has(r$xml, "w:type=\"page\""))
report("::: {.landscape} -> w:orient=landscape", has(r$xml, "w:orient=\"landscape\""))
m <- regmatches(r$xml, gregexpr("<w:pgSz[^>]*>", r$xml))[[1]]
cat("pgSz elements:", m, sep = "\n  ")
