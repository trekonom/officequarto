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

## officer bietet keine High-Level-API zum Definieren neuer Paragraph-/
## Tabellen-Styles, daher werden 15 ACME-Custom-Paragraph-Styles (die
## urspruenglichen neun, plus je zwei weitere Verschachtelungsebenen fuer
## Aufzaehlung/Nummerierung/Buchstabierung - officequarto.lists.* als Array
## statt Skalar, siehe style-mapping.R) plus ein ACME-Custom-Tabellen-Style
## direkt in word/styles.xml nachgetragen - gleiche unzip/xml2/zip-Technik wie
## in scripts/writeback.R. Jeder Style hat eine deutlich abweichende
## Formatierung, damit ein erfolgreiches Mapping auch visuell erkennbar ist.
library(xml2)

custom_styles <- c(
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="FliesstextACME">
     <w:name w:val="Fließtext ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:i/><w:color w:val="1F4E79"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="AufzaehlungACME">
     <w:name w:val="Aufzählung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:color w:val="A6192E"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="AufzaehlungACME2">
     <w:name w:val="Aufzählung ACME 2"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:i/><w:color w:val="D32F2F"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="AufzaehlungACME3">
     <w:name w:val="Aufzählung ACME 3"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:b/><w:i/><w:color w:val="F06292"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="NummerierungACME">
     <w:name w:val="Nummerierung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:b/><w:color w:val="2E7D32"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="NummerierungACME2">
     <w:name w:val="Nummerierung ACME 2"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:i/><w:color w:val="66BB6A"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="NummerierungACME3">
     <w:name w:val="Nummerierung ACME 3"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:b/><w:i/><w:color w:val="A5D6A7"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="CodeACME">
     <w:name w:val="Code ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:color w:val="6A1B9A"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="BuchstabierungACME">
     <w:name w:val="Buchstabierung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:u w:val="single"/><w:color w:val="E65100"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="BuchstabierungACME2">
     <w:name w:val="Buchstabierung ACME 2"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:u w:val="double"/><w:color w:val="FB8C00"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="BuchstabierungACME3">
     <w:name w:val="Buchstabierung ACME 3"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:u w:val="wave"/><w:color w:val="FFB74D"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="BeschriftungACME">
     <w:name w:val="Beschriftung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:i/><w:color w:val="00695C"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="AbbildungACME">
     <w:name w:val="Abbildung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:pPr><w:pBdr><w:top w:val="single" w:sz="8" w:space="4" w:color="4A148C"/><w:bottom w:val="single" w:sz="8" w:space="4" w:color="4A148C"/></w:pBdr></w:pPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="AbbildungsbeschriftungACME">
     <w:name w:val="Abbildungsbeschriftung ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:i/><w:color w:val="AD1457"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="paragraph" w:customStyle="1" w:styleId="TitelACME">
     <w:name w:val="Titel ACME"/>
     <w:basedOn w:val="Normal"/>
     <w:qFormat/>
     <w:rPr><w:b/><w:sz w:val="48"/><w:color w:val="1A237E"/></w:rPr>
   </w:style>',
  '<w:style xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
     w:type="table" w:customStyle="1" w:styleId="TabelleACME">
     <w:name w:val="Tabelle ACME"/>
     <w:basedOn w:val="TableauNormal"/>
     <w:tblPr>
       <w:tblBorders>
         <w:top w:val="single" w:sz="8" w:space="0" w:color="A6192E"/>
         <w:left w:val="single" w:sz="8" w:space="0" w:color="A6192E"/>
         <w:bottom w:val="single" w:sz="8" w:space="0" w:color="A6192E"/>
         <w:right w:val="single" w:sz="8" w:space="0" w:color="A6192E"/>
         <w:insideH w:val="single" w:sz="4" w:space="0" w:color="A6192E"/>
         <w:insideV w:val="single" w:sz="4" w:space="0" w:color="A6192E"/>
       </w:tblBorders>
     </w:tblPr>
   </w:style>'
)

target_path <- normalizePath("template/original.docx")
work_dir <- tempfile("make_sample_docx_")
dir.create(work_dir)
system2("unzip", c("-oq", shQuote(target_path), "-d", shQuote(work_dir)))

styles_path <- file.path(work_dir, "word", "styles.xml")
styles_doc <- read_xml(styles_path)
root <- xml_root(styles_doc)
for (style_xml in custom_styles) {
  xml_add_child(root, read_xml(style_xml))
}
write_xml(styles_doc, styles_path)

invisible(file.remove(target_path))
old_wd <- setwd(work_dir)
system2("zip", c("-rq", shQuote(target_path), "."))
setwd(old_wd)
unlink(work_dir, recursive = TRUE)

cat("Beispiel-Dokument geschrieben: template/original.docx (inkl. 15 ACME-Paragraph-Styles - neun Basis-Styles plus je zwei weitere Verschachtelungsebenen fuer Aufzaehlung/Nummerierung/Buchstabierung - und einem ACME-Tabellen-Style)\n")
