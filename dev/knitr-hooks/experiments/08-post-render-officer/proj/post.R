# Post-render hook: re-open every rendered .docx with officer and append a paragraph.
files <- strsplit(Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES"), "\n")[[1]]
for (f in files[grepl("\\.docx$", files)]) {
  x <- officer::read_docx(f)
  x <- officer::body_add_par(x, "OFFICER-POSTRENDER-MARKER")
  print(x, target = f)
}
