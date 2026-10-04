# 08 – docx mit officer im Post-Render nachbearbeiten
**Hypothese:** Projekt-`post-render`-Skript kann die fertige docx mit `officer::read_docx()` öffnen und verändern (Ersatz für `output_format$post_processor`).
**Ergebnis:** bestätigt – angehängter Absatz vorhanden, Original-Body erhalten. Ausgabepfade kommen aus `QUARTO_PROJECT_OUTPUT_FILES`.
**Evidenz:** `run.R` (nutzt `proj/_quarto.yml`, `proj/post.R`). Dies ist derselbe Mechanismus wie `inst/_extensions/officequarto/scripts/writeback.R`.
