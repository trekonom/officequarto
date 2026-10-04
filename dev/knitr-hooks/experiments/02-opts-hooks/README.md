# 02 – `opts_hooks` schreibt Chunk-Optionen um
**Hypothese:** Ein `opts_hooks$set(tab.cap=…)` kann `fig.cap` setzen; Quarto's eigene opts_hooks bleiben unberührt.
**Ergebnis:** bestätigt – Caption „FROM-OPTS-HOOK: my table caption" erscheint im docx.
**Evidenz:** `run.R` → `YES`. Einschränkung: Hooks mit Quarto-eigenen Namen (`echo`, `eval`, `fig.show`, `collapse`, `code`, `output`; `hooks.R:41–160`) würden Quarto's ersetzen. Offen/ungeprüft: ob die so gesetzte Caption auch die Quarto-Crossref-Nummerierung auslöst (hier nur Text geprüft).
