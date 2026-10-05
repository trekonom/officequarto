# 15 – Figure-Captions per knit_hook: Live-`SEQ`-Feld bei erhaltenen Crossrefs?
**Frage:** Kann ein knitr-Hook Abbildungs-Captions als echte Word-`SEQ`-Felder erzeugen, ohne dass Quarto's `@fig-x` kaputtgeht?
**Hintergrund (Q, installiertes `rmd/hooks.R :: knitr_plot_hook`, Z. 602 ff.):** Quarto's Plot-Hook liefert `![caption](pfad){#fig-a …}`; die Nummerierung („Figure 1:“) und der Crossref-Link entstehen erst später im Lua-Crossref-Filter auf dem Pandoc-AST. Ein Hook kann also nur den Markdown-Text davor beeinflussen.

| Variante | Mechanismus | Live-`SEQ` | statisches „Figure N“ | Doppelzählung | `@fig-x` funktioniert | Bemerkung |
|---|---|---|---|---|---|---|
| v0 | Quarto pur | nein | ja | – | **ja** | Referenz |
| v1 | gechainter Hook ändert nur `fig.cap`-Text | nein | ja | nein | **ja** | Text/Stil möglich, keine Felder |
| v2 | gechainter Hook hängt rohes `SEQ`-Feld an die Caption | ja | ja | **ja** | ja | Quarto fügt sein statisches Präfix trotzdem hinzu |
| v3 | gechainter Hook entfernt die `fig-`-ID und baut Caption selbst (Lesezeichen + „Figure “ + `SEQ`) | **ja** | nein | nein | **nein** (`v3b`: unaufgelöst); nur mit eigenem `REF`-Feld (`oq_ref()`) | in echtem Word geprüft: „Figure 1: CAP-A“, „Figure 2: CAP-B“, Verweise lösen zu 1 und 2 auf |
| v4 | officedown's eigener Plot-Hook (`plot_word_fig_caption`) | ja | nein | nein | **nein** (unaufgelöst) | Bild/Caption komplett von officedown gebaut, `@fig-x` tot |
| v5 | officequarto `crossref.auto-number` (Post-Render) | **ja** | nein | nein | **ja** (wird zu `REF`-Feld) | Referenzergebnis, kein Hook nötig |

**Fazit:** Ein Hook kann Live-`SEQ`-Captions erzeugen (v3, v4), aber nur, indem er Quarto's Numerierung umgeht – dadurch funktioniert `@fig-x` nicht mehr, und Verweise müssen von Hand als `REF`-Felder gesetzt werden. Hooks, die Quarto's Numerierung erhalten (v1), können keine Felder erzeugen; der Versuch, beides zu mischen (v2), zählt doppelt. Die Kombination „Live-Feld **und** `@fig-x`“ erreicht nur die Post-Render-Umwandlung (v5), weil sie *nach* Quarto's Crossref-Auflösung ansetzt.
**Evidenz:** `Rscript run.R` (Kriterientabelle je Variante; v5 baut ein Projekt mit der In-Tree-Extension und braucht das installierte Paket `officequarto`).
**Grenzen:** zwei Abbildungen, eine Seite, keine Unterabbildungen/`fig-subcap`/Layouts; v3 ist bewusst minimal (Bild-Attribute bleiben erhalten, Querverweise nur über `oq_ref()`).
