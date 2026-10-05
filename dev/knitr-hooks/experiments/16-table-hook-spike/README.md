# 16 – Spike: Tabellen-Numerierung per knit_hook (Entscheidungsgate für `oq_numbering()`)
**Frage:** Lassen sich `tbl-`-Zellen per Hook mit Live-`SEQ Table`-Feld + Lesezeichen + funktionierender `REF`-Referenz versehen?
**Befund zum Markdown (Q + `probe.qmd`, `keep-md`):** Quarto's `chunk`-Hook (installiert `rmd/hooks.R`, Ende des `chunk`-Hooks) emittiert pro Tabellen-Chunk `::: {#tbl-a .cell tbl-cap='…'}` mit innerem `::: {.cell-output-display}`. Die Caption steht nur als Attribut `tbl-cap`; der Lua-Crossref-Filter macht erst später „Table 1:“ daraus. Apostrophe im Attribut sind als `\'` escaped, `"` und `}` nicht (`esc.qmd`). Eine Zelle ohne `tbl-cap` hat nur `#tbl-x` (nicht anfassen). Ein flextable-Chunk hat ebenfalls `.cell-output-display` (mit rohem `{=openxml}`-Table). Ein nackter `data.frame`-Print ist nur Konsolentext (keine Tabelle) – ohne `kable`/flextable/`knit_print`-Methode gibt es nichts zu nummerieren.
**Hook-Punkt:** gechainter `chunk`-Hook; `#tbl-x` und `tbl-cap='…'` aus dem Zellen-Opener entfernen und die eigene Caption vor `::: {.cell-output-display}` einfügen (bei `echo: true` steht sie zwischen Code und Tabelle).
**Drei Caption-Formen (`t-a/b/c.qmd`, `run.R`):**

| Variante | Form | Live-`SEQ` | Caption vor Tabelle | `REF`-Verweise | Inline-Markdown (`*emph*`) | Bemerkung |
|---|---|---|---|---|---|---|
| a | Pipe-Table-Caption `: text` nach der Tabelle | ja | ja | ja | ja | nur Pipe-Tabellen (kable) |
| b | gefencter `{=openxml}`-`<w:p>` | ja | ja | ja | **nein** (Text wörtlich `*emph*`) | beliebiger Tabellentyp, kein Markdown |
| c | Markdown-Absatz in `::: {custom-style="Table Caption"}` mit rohen Inline-Feldern | ja | ja | ja | **ja** | beliebiger Tabellentyp; Pandoc baut den Absatz (Stil `TableCaption`) |

**Entscheidung:** Gate bestanden, Variante **c** (Markdown-Caption, inline Felder, jeder Tabellentyp; keine Block-Raw-Probleme, jgm/pandoc#5094).
**Evidenz:** `Rscript run.R` (Kriterien je Variante).
