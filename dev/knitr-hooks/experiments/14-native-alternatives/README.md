# 14 – Native Quarto-Alternativen (Audit)
**Hypothese (aus der Matrix):** `toc: true`, `{{< pagebreak >}}` und `::: {.landscape}` liefern TOC-Feld, Seitenumbruch und Querformat-Section im docx.
**Ergebnis:** alle drei bestätigt; die Landscape-Section hat festes A4-Querformat (`w:w=16838 w:h=11906`), die Hochformat-Sections tragen kein eigenes `w:pgSz`.
**Evidenz:** `Rscript run.R`.
