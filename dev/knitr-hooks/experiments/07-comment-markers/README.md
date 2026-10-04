# 07 – `<!---BLOCK_TOC--->` & Co.
**Hypothese:** funktionieren in Quarto nicht (Auswertung erfolgt in `officedown`'s `post_knit`, `rdocx_pre_proc.R :: block_macro`).
**Ergebnis:** bestätigt – kein TOC-Feld, keine Querformat-Section; die Marker verschwinden still als HTML-Kommentare (kein Fehler).
**Evidenz:** `run.R` → `TOC… NO`, `landscape… NO`, `markers silently dropped … YES`.
