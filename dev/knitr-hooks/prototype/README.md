# Prototype (Phase 5)

| Datei | Zweck |
|---|---|
| `oq-hooks.R` | `chain_hook(name, before, after)`: ersetzt einen knitr-Hook, **ruft aber den vorherigen (Quarto-)Hook weiter auf**. Beispiel: `plot`-Hook mit Chunk-Option `fig.note`. |
| `markers.lua` | Pandoc-Lua-Filter (docx): `<!---BLOCK_TOC--->`, `BLOCK_PAGEBREAK`, `BLOCK_LANDSCAPE_START/STOP` (optional `{"w":…,"h":…}` in Twips am STOP-Marker) → `openxml`. |
| `demo.qmd` | zeigt alles zusammen (`filters: [markers.lua]`, `source("oq-hooks.R")`). |
| `run.R` | rendert die Demo und prüft das XML (alle Checks `YES`). |

Word-Feld-Captions (`SEQ`/`REF`) sind **nicht** Teil des Prototyps: dafür existiert bereits
`officequarto.crossref.auto-number` (Post-Render, siehe `CLAUDE.md`). Ein Hook-basierter Weg
bräuchte einen Ersatz für Quarto's Crossref-Auflösung und wäre fragiler (Exp. 3).

Grenzen: Landscape-Section-Semantik wie in Quarto's `landscape.lua` (Section-Ende-Absatz, keine
Ränder/Kopfzeilen-Übernahme); Markdown-Marker müssen auf eigener Zeile stehen; `chain_hook` verändert
nur Hooks, die bereits existieren (Setup-Chunk nach Quarto's Hooks).
