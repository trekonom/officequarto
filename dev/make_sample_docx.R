## Erzeugt eine Beispiel-Word-Vorlage (template/original.docx) mit eigenem
## Header/Footer und auffälligem Absatzformat, damit sich Style- und
## Round-Trip-Treue beim Spike visuell prüfen lassen.
library(officer)

doc <- read_docx()

doc <- doc |>
  body_add_par("Platzhalter-Body (wird beim Rendern ersetzt)", style = "Normal")

sect_properties <- prop_section(
  header_default = block_list(
    fpar(ftext("ACME GmbH — Quartalsbericht", fp_text(bold = TRUE, color = "#2E5B8A")))
  ),
  footer_default = block_list(
    fpar(ftext("Vertraulich — Seite ", fp_text(italic = TRUE)), run_word_field(field = "PAGE"))
  )
)

doc <- doc |> body_set_default_section(sect_properties)

doc <- doc |> set_doc_properties(
  subject = "Quartalsberichte",
  description = "Interner Bericht - vertraulich",
  values = list(Vertraulichkeitsstufe = "Intern", Dokumentennummer = "ACME-QB-001")
)

print(doc, target = "template/original.docx")
cat("Beispiel-Dokument geschrieben: template/original.docx\n")
