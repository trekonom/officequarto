# 06 – Rohes OpenXML aus R-Chunks
**Hypothese:** ```` ```{=openxml} ````-Blöcke und `` `…`{=openxml} ``-Inline-Runs aus `asis_output()`/`cat(results='asis')` kommen im docx an.
**Ergebnis:** bestätigt für alle drei Wege (asis_output-Block, `cat()`-Block, Inline-Run); kein Literal `{=openxml}` bleibt stehen.
**Evidenz:** `run.R`. (Erste Fassung des Tests scheiterte an einem Fehler im Test selbst: Backticks im Inline-R-Code – behoben, siehe Git-Historie.) Regel aus `CLAUDE.md`: Blöcke mit vollständigem `<w:p>` nur als Fenced Block (Pandoc #5094).
