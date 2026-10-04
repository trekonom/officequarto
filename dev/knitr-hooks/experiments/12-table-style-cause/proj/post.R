# officer rewrites custom style tags (w:tstlname/w:pstlname) to real style IDs when it WRITES a docx
# (print.rdocx -> convert_custom_styles_in_wml). A read/print round-trip is enough.
files <- strsplit(Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES"), "\n")[[1]]
for (f in files[grepl("\\.docx$", files)]) print(officer::read_docx(f), target = f)
