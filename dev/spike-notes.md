# Spike-Notizen

Ergebnisse aus Phase 0 (Setup & Spike), verifiziert am 2026-08-28 mit
`quarto 1.8.24`, `Rscript 4.5.2`, `pandoc 3.10.1`.

## Spike A — `reference-doc` allein reicht für Style-Übernahme

`format: docx: reference-doc: original.docx` reicht **ohne jeden eigenen Code**, um Styles,
Header, Footer und Section-Properties (Seitenränder, Papierformat) aus einem beliebigen
Original-`.docx` zu übernehmen. Das ist natives Pandoc-Verhalten (der docx-Writer benutzt das
Referenzdokument als Vorlage für `styles.xml`, `header*.xml`, `footer*.xml` und `sectPr`).

**Überraschender Zusatzfund, der Phase 3 grundlegend verändert hat:** Ein per `reference-doc`
gerendertes `.docx` enthält Header/Footer/Section-Properties des Originals bereits *vollständig
und unverändert* — verifiziert per `unzip`-Diff zwischen `original.docx` und dem reinen
Pandoc-Ergebnis `report.docx`, noch bevor irgendein eigener Post-Render-Code lief. Das
ursprünglich geplante "Body des Originals manuell entfernen und Rendering-Body einfügen, dabei
Header/Footer erhalten" (Phase-3-Spezifikation) ist damit für den Kern-Anwendungsfall bereits
durch Pandoc selbst erledigt — ein zusätzlicher XML-Merge-Schritt bringt hier keinen Mehrwert.

Versuch, das im Konzept beschriebene manuelle Body-Ersetzen trotzdem umzusetzen
(`officer::body_add_docx()`, um den Rendering-Output in eine Kopie des Originals einzufügen),
ist an einem Bug/Grenzfall von `officer 0.7.3` gescheitert: Sobald der Body eines Dokuments
vollständig geleert wird (0 Absätze) oder zwei strukturell sehr ähnliche Dokumente (beide mit
eigenen Header/Footer/Sections, da beide von `original.docx` abstammen) gemergt werden, wirft
`print()` beim Reserialisieren einen Fehler in `process_sections_content()` (Zeilen-Mismatch
zwischen Content-Sections und Header/Footer-Dateien). Reproduzierbar mit einem Minimalbeispiel
(zwei Absätze, ein Header, ein Footer).

**Konsequenz für Phase 3:** Der Post-Render-Hook baut nicht mehr selbst den Body zusammen,
sondern arbeitet mit dem bereits korrekten Pandoc-Ergebnis weiter (siehe Abschnitt "Was der Hook
tatsächlich noch beiträgt" unten).

## Was der Hook tatsächlich noch beiträgt

Was Pandoc **nicht** aus dem Original übernimmt: `docProps/core.xml` (Titel, Subject, Keywords,
Description, Category) und `docProps/custom.xml` (frei definierte Custom-Properties, z. B.
Vertraulichkeitsstufe, Dokumentennummer). Pandoc schreibt dafür ein neues, weitgehend leeres
`core.xml` auf Basis der `.qmd`-Metadaten. Genau das übernimmt `scripts/writeback.R`: Es arbeitet
mit einer Kopie des bereits korrekten gerenderten `.docx` in einem temporären Verzeichnis,
überträgt `dc:subject`/`cp:keywords`/`dc:description`/`cp:category` sowie `docProps/custom.xml`
aus dem Original hinein und überschreibt damit die von Quarto erzeugte `.docx` direkt an Ort und
Stelle (keine zweite Ausgabedatei; optional per `officequarto-keep-rendered: true` lässt sich das
ungepatchte Pandoc-Ergebnis zusätzlich als `<name>.quarto-rendered.docx` behalten).

**Bekannte Grenze:** Wenn das gerenderte Pandoc-Dokument den Part `docProps/custom.xml` selbst
noch nicht kennt (in `[Content_Types].xml`/`_rels/.rels` registriert), würde ein reines
Überschreiben dieser Datei einen nicht referenzierten Part erzeugen. Im getesteten Fall (Original
als `reference-doc`) ist der Part durch Pandoc bereits korrekt registriert; für exotischere
Ausgangsdokumente ist das nicht garantiert und bleibt dokumentierte Einschränkung des Prototyps.

## Spike B — `contributes: project:` in `_extension.yml`

Funktioniert wie erwartet, **ist aber kein Zero-Config-Mechanismus**: `quarto add` installiert
nur die Extension-Dateien. Der Post-Render-Hook wird erst aktiv, wenn das Nutzerprojekt in seiner
eigenen `_quarto.yml` `project: { type: officequarto }` setzt. Verifiziert per Gegenprobe: mit
`project: type: default` (kein `officequarto`) läuft `writeback.R` nachweislich **nicht** —
`report.written-back.docx` wird nicht erzeugt. Mit `project: type: officequarto` läuft der Hook
zuverlässig bei jedem `quarto render`.

## Spike C — Umgebungsvariablen im Post-Render-Skript

Zuverlässig verfügbar (per `Sys.getenv()` bestätigt):

- `QUARTO_PROJECT_OUTPUT_FILES` — newline-separierte Liste der Output-Dateien, **relativ** zu
  `QUARTO_PROJECT_OUTPUT_DIR` (im Test: `report.docx`)
- `QUARTO_PROJECT_OUTPUT_DIR` — absoluter Pfad (im Test: `.../template`)
- `QUARTO_PROJECT_RENDER_ALL` — `"1"` bei Full-Render
- `QUARTO_PROJECT_DIR` — absoluter Projekt-Root, wird u. a. genutzt, um `original.docx` und die
  Projektkonfiguration zu finden

Den Pfad des `reference-doc` selbst liefert keine Env-Variable — dafür wird `quarto inspect
<project_dir>` aufgerufen und `config.format.docx["reference-doc"]` aus dem JSON gelesen. Das ist
robuster als eigenes YAML-Parsing von `_quarto.yml`, weil `quarto inspect` bereits Merges/
Defaults auflöst.

## Spike D — Style-Mapping (Body/Listen), verifiziert am 2026-08-28

Ausgangsannahme aus der Recherche (officedown/Pandoc-Interna) war, Pandoc verwende feste
Style-IDs `Normal` (Body) und `ListParagraph` (Listen). Das war **unvollständig**: Am echten
gerenderten Dokument zeigte sich, dass Pandoc je nach Kontext unterschiedliche Style-Namen wählt,
die im `reference-doc` existieren:

- Body-Absätze direkt nach einer Überschrift → `FirstParagraph`
- Listen-Absätze aus "tight" Markdown-Listen (keine Leerzeile zwischen Einträgen, der
  Normalfall) → `Compact` — **sowohl für Bullet- als auch für nummerierte Listen**
- `Normal`/`ListParagraph` kommen nur in anderen Konstellationen vor (z. B. "loose" Listen,
  Body-Absätze ohne vorausgehende Überschrift)

Verifiziert per `unzip`+Python-Regex-Diff am realen `report.docx`: alle 9 Absätze trugen explizite
`pStyle`-Werte aus `{Title, Titre2, FirstParagraph, Compact}`, `ListParagraph` kam gar nicht vor.
**Konsequenz:** Listen-Absätze werden nicht am Style-Namen erkannt, sondern an der Präsenz von
`<w:numPr>` (zuverlässig, unabhängig vom gewählten Style-Namen); Body-Absätze werden über eine
Allowlist bekannter Rollennamen erkannt (`Normal`, `FirstParagraph`, `Compact`, `BodyText`,
`Body Text`) — siehe `scripts/style-mapping.R`.

Ebenfalls verifiziert: `word/numbering.xml` löst `numId` → `abstractNumId` → `w:numFmt` (Ebene 0)
zuverlässig auf; im Test hatte die Bullet-Liste `numFmt="bullet"`, die nummerierte Liste
`numFmt="decimal"` — mit unterschiedlichen `numId`s (1001 vs. 1002), aber identischem `pStyle`
(`Compact`) auf Absatzebene. Ohne den `numFmt`-Umweg wäre Bullet/Nummerierung nicht unterscheidbar
gewesen.

Außerdem bestätigt: `word/styles.xml` im gerenderten Output enthält alle Style-Definitionen des
`reference-doc` unverändert (inkl. selbst ergänzter Custom-Styles) plus von Pandoc zusätzlich
benötigte Styles (z. B. Syntax-Highlighting-Token-Styles) — keine zweite Extraktion aus dem
`reference-doc` nötig, `work_dir/word/styles.xml` reicht. Und: `quarto inspect` liefert einen neu
hinzugefügten verschachtelten Key `format.docx.officequarto-styles` genauso zuverlässig wie
`reference-doc` (per Gegenprobe mit einem Testwert bestätigt).

## Spike E — Style-Pruning, verifiziert am 2026-08-29

Auf den ersten Blick harmlos formulierter Befund in Spike D ("plus von Pandoc zusätzlich benötigte
Styles, z. B. Syntax-Highlighting-Token-Styles") stellte sich als groesser heraus als gedacht:
`original.docx` definiert 27 Styles; das rohe Pandoc-Ergebnis (`report.quarto-rendered.docx`, vor
jeglichem officequarto-Post-Processing) enthaelt 59 — 32 zusaetzliche, ausschliesslich
Syntax-Highlighting-Styles (`SourceCode`, `KeywordTok`, `StringTok`, ...), obwohl `report.qmd` zum
Testzeitpunkt gar keinen Codeblock enthielt. Verifiziert per Style-ID-Diff (`w:styleId` in
`word/styles.xml`): alle 27 Original-Styles sind unveraendert vorhanden, die 32 Extras kommen
ausschliesslich von Pandoc hinzu — nichts geht verloren. Laut Nutzer zeigt {officedown} dasselbe
Verhalten; es ist also eine generelle Eigenschaft von Pandocs docx-Writer, nicht spezifisch fuer
den `reference-doc`-Mechanismus.

Auf expliziten Wunsch entfernt `writeback.R` diese Extras seitdem wieder (per Default): `word/
styles.xml` des reference-doc wird zusaetzlich zu `core.xml`/`custom.xml` aus dem Original
extrahiert, und jeder `<w:style>` im gerenderten `word/styles.xml`, dessen `styleId` dort nicht
vorkommt, wird entfernt (`scripts/style-pruning.R`).

Getestet auch der Grenzfall "Style wird noch verwendet": Ein Testabsatz mit echtem Codeblock in
`report.qmd` sorgt dafuer, dass `SourceCode`/`KeywordTok`/... tatsaechlich per `w:pStyle`/`w:rStyle`
referenziert werden. Bewusste Entscheidung (vom Nutzer bestaetigt): auch dann wird der Style
entfernt statt behalten — der betroffene Absatz/Run faellt auf Words Default-Formatierung zurueck,
`writeback.R` loggt dafuer eine Warnung mit der Liste der betroffenen Style-IDs. Verifiziert: das
resultierende `document.xml`/`styles.xml` bleibt wohlgeformtes XML (kein Crash, keine defekte
Datei), der `pStyle`-Wert `SourceCode` existiert im Absatz weiter, obwohl die Style-Definition
fehlt — genau das von Word tolerierte Verhalten (stiller Fallback auf Default-Formatierung, kein
Reparatur-Dialog).

Gegenprobe an einem echten externen Projekt (`../hello-wordto`, UU-Word-Template mit 476 Styles,
`hello-wordto.qmd` ohne jeglichen Code): rohes Pandoc-Ergebnis hatte 508 Styles (476 + dieselben 32
Extras), nach Pruning wieder exakt 476 — identisch mit dem Template. Bestaetigt, dass das
Verhalten nicht spezifisch fuer die kleine ACME-Testvorlage ist, sondern generell fuer beliebige
reference-docs greift, auch sehr grosse.

## Spike F — Code-Block-Ausnahme (`officequarto-pandoc-styles.code-block`), verifiziert am 2026-08-29

Vor dem ersten Commit von Spike E kam der Wunsch nach einer Opt-in-Ausnahme fuer genau diesen
Codeblock-Fall: entweder Pandocs eigene Codeblock-Formatierung vollstaendig behalten, oder die
Codeblock-Absaetze auf einen eigenen reference-doc-Style ummappen (analog zu `body`/`list-bullet`/
`list-number`), waehrend der Default (kein Codeblock-Konfig) unveraendert bleibt.

`SourceCode` erwies sich (anders als `Normal`/`FirstParagraph`/`Compact` in Spike D) als stabile,
kontextunabhaengige Pandoc-Style-ID fuer den Codeblock-Absatz selbst — ein einfacher
Gleichheitscheck in `oq_apply_style_mapping` genuegt, keine Allowlist noetig. Fuer
`code-block: true` reicht es, die Menge der "zu behaltenden" Style-IDs vor dem Pruning-Aufruf um
alle `SourceCode`/`*Tok`-IDs zu erweitern (`oq_is_pandoc_code_style_id()`) — `oq_prune_foreign_styles`
selbst brauchte dafuer keine Aenderung, da es ohnehin nur eine beliebige "keep set"-Menge entgegennimmt.

Nachtraeglicher Wunsch (noch vor dem ersten Commit dieser Funktion): `code-block` nicht verschachtelt
unter `officequarto-styles`, sondern in einem eigenen, gleichrangigen Abschnitt
`officequarto-pandoc-styles` (Begruendung: es geht um von Pandoc hinzugefuegte Styles, nicht um das
Ummappen eigener reference-doc-Styles — inhaltlich ein anderer Konfigurationsbereich). Dabei musste
die Gate-Bedingung fuer den Style-Mapping-Block in `writeback.R` von `!is.null(style_config)` auf
`!is.null(style_config) || !is.null(code_block_config)` erweitert werden, sonst haette
`code-block` ohne gleichzeitig gesetztes `officequarto-styles` (body/list-bullet/list-number) gar
nicht gegriffen — verifiziert per Testfall mit *nur* `officequarto-pandoc-styles.code-block`
gesetzt (kein `officequarto-styles` in der Config): Codeblock-Absatz wird trotzdem korrekt auf den
konfigurierten Style umgemappt, Body-Absaetze bleiben unangetastet bei Pandocs Rollennamen. Auch
`oq_resolve_style_id()` musste angepasst werden: der volle Konfigurationspfad fuer Fehlermeldungen
wird jetzt vom Aufrufer uebergeben (`"officequarto-styles.body"` vs.
`"officequarto-pandoc-styles.code-block"`), statt den Praefix `officequarto-styles.` hart zu
kodieren.

Verifiziert (`template/_quarto.yml` nutzt jetzt dauerhaft `officequarto-pandoc-styles:
{code-block: "Code ACME"}` als String-Mapping-Testfall, ein vierter ACME-Custom-Style in
`dev/make-sample-docx.R`):
- `code-block` unset (Default): unveraendert wie Spike E (32 entfernt, inkl. `SourceCode`).
- `code-block: "Code ACME"`: `SourceCode`-Absatz wird auf `CodeACME` umgemappt (kein
  `SourceCode`-Verweis mehr, keine Warnung dafuer), die `*Tok`-Laufstile im Codeblock bleiben aber
  weiterhin referenziert-aber-entfernt (Warnung wie gehabt) — bewusst getrennte Zustaendigkeit
  Block-Style vs. Syntax-Highlighting-Farben.
- `code-block: true` (manuell in einem Scratch-Projekt getestet, nicht Teil der dauerhaften
  Testvorlage): 0 entfernt, alle 32 `SourceCode`/`*Tok`-Styles bleiben unveraendert erhalten, keine
  Warnung, volle Syntax-Highlighting-Farbgebung im Ergebnis.
- Ungueltiger Wert (z. B. eine Zahl): bricht sofort mit klarer Fehlermeldung ab, noch vor der
  Pro-Datei-Schleife.

## Spike G — `list-letter` (Buchstaben-Listen), verifiziert am 2026-08-29

Frage vor der Implementierung: erzeugt Pandocs docx-Writer fuer Buchstaben-Listen (`a.`/`b.`/`c.`
bzw. `A.`/`B.`/`C.` in der Markdown-Quelle) ueberhaupt einen von `bullet`/`decimal` unterscheidbaren
`w:numFmt`-Wert, oder faellt das unter Pandocs generische Nummerierung wie alles andere auch?

Empirisch per direktem `pandoc test.md -o test.docx --standalone` (Test-Markdown mit je einer
Buchstaben-, Zahlen- und Grossbuchstaben-Liste) geprueft, unabhaengig von officequarto:
`word/numbering.xml` enthaelt danach `w:numFmt`-Werte `bullet`, `decimal` **und** `lowerLetter`
(fuer `a.`/`b.`/`c.`) als eigene, unterscheidbare Werte — Grossbuchstaben-Marker (`A.`/`B.`) waeren
analog `upperLetter` (nicht separat mitgetestet, aber laut OOXML-Spezifikation das erwartete
Gegenstueck zu `lowerLetter`). Buchstaben-Listen sind damit genauso zuverlaessig ueber
`word/numbering.xml` erkennbar wie Bullet- vs. Zahlen-Listen in Spike D — keine Sonderbehandlung
noetig, nur ein zusaetzlicher Zweig in der bestehenden `numFmt`-Fallunterscheidung.

Umgesetzt als eigener Bucket `list-letter` (`officequarto_letter_num_fmts <- c("lowerLetter",
"upperLetter")` in `style-mapping.R`), getrennt von `list-number` (das weiterhin `decimal`,
roemische Ziffern etc. abdeckt) — beide Faelle in einer Option zusammengefasst statt separater
Optionen fuer Klein-/Grossbuchstaben, analog dazu, wie `list-number` bereits `decimal` und
roemische Ziffern in einem Bucket zusammenfasst. Hat kein officedown-Vorbild (officedown kennt nur
`ol.style`/`ul.style`), daher als officequarto-eigene Option ohne Alias eingefuehrt — kein
Konflikt mit der [[officedown-Alias-Konvention]] (siehe `option-aliases.R`), da es schlicht keinen
zu mappenden officedown-Namen gibt.

Verifiziert am funktionierenden Testprojekt (fuenfter ACME-Custom-Style `BuchstabierungACME` in
`dev/make-sample-docx.R`, dritte Liste `a./b./c.` in `template/report.qmd`,
`officequarto-styles.list-letter: "Buchstabierung ACME"` in `template/_quarto.yml`): 3
Buchstaben-Listen-Absaetze werden korrekt auf `BuchstabierungACME` umgemappt, `list-number`
(separat auf `NummerierungACME` gemappt) bleibt bei weiterhin nur 3 Absaetzen unveraendert — keine
Vermischung der beiden Buckets.

## Spike H — Tabellen-Basisoptionen (Gruppe 1) und `tab.lp`-Verzicht, verifiziert am 2026-08-29

Zwei offene Fragen vor der Implementierung von `officequarto-tables` (Gruppe 1 des
officedown-Options-Ports: `style`/`layout`/`width`, officedown-Vorbild: `tables = list(style=,
layout=, width=, topcaption=, tab.lp=)`):

**1. Braucht officequarto ein `tab.lp`/`fig.lp`-Aequivalent?** Recherchiert (Quartos eigene
Crossref-Dokumentation, `quarto.org/docs/authoring/cross-reference-options.html` und
`.../cross-references.html`, sowie eine Quarto-Maintainer-Diskussion zu Docx-Crossrefs,
`github.com/orgs/quarto-dev/discussions/8503`) statt angenommen: Nein. `tab.lp` ist in
officedown/bookdown ein reines **Autoren-Syntax-Konzept** — der Praefix, an dem bookdowns
`\@ref(tab:xyz)`-Parser erkennt, dass ein Label sich auf eine Tabelle bezieht — kein
Rendering-Schalter. Quartos eigenes Aequivalent (`#tbl-xyz`/`#fig-xyz`) ist eine fixe,
nicht-konfigurierbare Quarto-Autoren-Konvention, die schon beim Parsen der `.qmd` aufgeloest wird —
lange bevor `writeback.R` (das nur das fertig gerenderte docx sieht) ueberhaupt laeuft. Kein
Ansatzpunkt in der Post-Render-Architektur. Das sichtbare Praefix-Textproblem ("Tabelle" statt
"Table") ist ausserdem bereits nativ durch Quartos eigene `crossref.tbl-title`/`fig-title`
YAML-Optionen geloest — keine officequarto-Option dafuer noetig. Randbefund fuer eine spaetere
Gruppe 3 (Tabellen-/Abbildungs-Beschriftungen): Quartos Docx-Crossref-Captions sind aktuell
statischer, fest eingebackener Text statt echter Word-`SEQ`-Felder (offene Quarto-Luecke) — der
Post-Render-XML-Zugriff von officequarto waere ein plausibler Ort, um das spaeter nachzuruesten.

**2. `style` gegen welche Styles aufloesen?** `officequarto-tables.style` referenziert
Tabellen-Styles (`w:type="table"`), nicht Absatz-Styles wie `body`/`list-*` — `oq_style_name_to_id()`
in `style-mapping.R` wurde daher um einen `type`-Parameter erweitert (`"paragraph"`
Default, `"table"` fuer diesen Fall), statt eine zweite fast identische Funktion anzulegen. Beim
Pruefen der Test-Vorlage zeigte sich: `original.docx` (von `officer::read_docx()` erzeugt) enthaelt
bereits vier eingebaute Tabellen-Styles, darunter den Basis-Style mit der ID `TableauNormal` (nicht
`TableNormal` wie im generischen OOXML-Beispiel — officer-Basisvorlage ist franzoesisch benannt).
Der neue ACME-Tabellen-Style (`TabelleACME`) baut deshalb auf `TableauNormal` auf, nicht auf einen
angenommenen `TableNormal`.

**Zusaetzlicher Implementierungsfund (nicht vorab recherchiert, beim ersten Testrender entdeckt):**
ein per `xml2::xml_add_child(tbl_pr, "w:tblLayout")` ohne `.where` neu erzeugtes Element landet
einfach als letztes Kind von `w:tblPr` — bei einer von Pandoc bereits mit `w:tblStyle`, `w:tblW`,
`w:tblLook` vorbelegten `w:tblPr` also *hinter* `w:tblLook`, obwohel `w:tblLayout` laut
OOXML-Schema (`CT_TblPrBase`) *vor* `w:tblLook` stehen muss. Word selbst toleriert das
(rendert trotzdem korrekt), aber nicht schema-konform. Behoben durch `oq_add_tbl_pr_child()`
(`table-mapping.R`), das die Zielposition anhand einer festen `officequarto_tblpr_order`-Sequenz
bestimmt statt blind anzuhaengen — verifiziert per `check-writeback.R`-Assertion auf die konkrete
resultierende Kindelement-Reihenfolge (`tblStyle, tblW, tblLayout, tblLook`).

## Spike I — Tabellen-Beschriftungen (Gruppe 3), verifiziert am 2026-08-29

Vor der Implementierung von `officequarto-tables.caption` empirisch geprueft, wie Quarto/Pandoc
Tabellen-Beschriftungen im docx-Output tatsaechlich erzeugen (Testrender: `#tbl-example`-Tabelle
mit Beschriftung, unabhaengig von officequarto, direkt per `quarto render`):

**Struktur:** eine beschriftete Tabelle wird von Pandoc in eine synthetische 1x1-"Wrapper"-Tabelle
eingebettet, deren einzige Zelle den Beschriftungsabsatz (`pStyle="ImageCaption"`) gefolgt von der
eigentlichen, verschachtelten Tabelle enthaelt (plus `w:bookmarkStart`/`w:bookmarkEnd` fuer den
Crossref-Anker). `ImageCaption` ist dabei ein einziger, fester Pandoc-Style, gemeinsam genutzt von
Tabellen- UND Abbildungs-Beschriftungen — keine eigene "TableCaption"-Style-ID.

**Wichtiger Fund, der die Gruppe-1/2-Implementierung nachtraeglich betraf:** `oq_apply_table_options()`s
urspruengliche `//w:tbl`-Selektion traf durch diese Wrapper-Struktur unbeabsichtigt BEIDE Tabellen
(die unsichtbare Wrapper-Tabelle UND die echte Datentabelle) — verifiziert am eigenen
Testrender ("Tabellen-Optionen angewendet: 2 Tabelle(n)." statt der erwarteten 1, sobald die
Test-Tabelle eine Beschriftung bekam). Behoben durch `[not(.//w:tbl)]` in der XPath-Selektion
(schliesst jede `w:tbl` aus, die selbst eine verschachtelte `w:tbl` enthaelt) — dieselbe Korrektur
war auch in `check-writeback.R`s eigener Tabellen-Lookup-XPath noetig.

**Kernproblem fuer pre/sep/number-bold:** die Beschriftung ist vollstaendig statischer,
eingebackener Text — "Table 1: My table caption" als EIN `<w:r><w:t>`-Lauf, kein echtes
Word-SEQ-Feld (bestaetigt bereits durch die `tab.lp`-Recherche vor Gruppe 1, siehe oben; hier am
konkreten XML nochmals verifiziert). Versucht: den generierten Praefix aus
`crossref.tbl-title`/`title-delim` vorherzusagen, um ihn beim Ersetzen gezielt abzuschneiden.
Empirisch verworfen: ein Testrender mit `crossref: {tbl-title: "Tabelle", title-delim: "--"}`
erzeugte den Text `"Tabelle\xa01– My table caption"` — Pandocs Smart-Typography-Konvertierung
wandelt `"--"` in einen echten Halbgeviertstrich ("–") um und setzt ein nicht-brechendes
Leerzeichen vor die Zahl; der tatsaechlich gerenderte Text weicht damit vom konfigurierten
Rohwert ab, eine Vorhersage aus der Config waere unzuverlaessig.

**Loesung:** an der Zahl selbst verankern statt am umgebenden Text — Ziffern sind von der
Typography-Konvertierung nicht betroffen. `officequarto` zaehlt Tabellen-Beschriftungen selbst in
Dokumentreihenfolge (identisch zu Pandocs eigener Zaehlung, da nur beschriftete Tabellen ueberhaupt
einen Beschriftungsabsatz erzeugen) und sucht die erwartete Zahl per Wortgrenzen-Lookaround-Regex
(`(?<![\p{L}\p{N}])N(?![\p{L}\p{N}])`), nicht per einfachem Teilstring-Treffer — verifiziert u.a.
gegen den Grenzfall, dass die gesuchte Zahl zufaellig auch als Teil einer anderen Zahl im
eigentlichen Beschriftungstext vorkommt (z.B. "1" in "1990"), siehe `dev/check-caption-parsing.R`.

## Spike J — Abbildungen-Basisoptionen (Gruppe 4), verifiziert am 2026-08-29

Vor der Implementierung von `officequarto-plots` empirisch geprueft (Testrender: `#fig-example`-
Abbildung mit Beschriftung, unabhaengig von officequarto, direkt per `quarto render`), wie Pandoc
eine Abbildung im docx-Output strukturiert.

**Fund 1 — Abbildungs-Absaetze tragen denselben Rollennamen wie Body-Absaetze:** der Absatz, der
das `w:drawing` traegt, hat `pStyle="Compact"` - denselben kontextabhaengigen Pandoc-Rollennamen,
den `officequarto_body_role_styles` (Spike D) bereits als "Body-Text" behandelt. Ohne Gegenmassnahme
haette `officequarto-styles.body` (falls konfiguriert) also faelschlich auch Abbildungs-Absaetze
umgemappt. Behoben durch eine explizite Ausnahme in `oq_apply_style_mapping()`
(`style-mapping.R`): Absaetze mit einem `w:drawing`-Nachfahren werden von der Body-Rollen-Pruefung
ausgenommen und stattdessen dediziert von `oq_apply_plot_options()` (`plot-mapping.R`) behandelt -
Abbildungs-Absaetze werden ueber die Praesenz von `w:drawing` erkannt, nicht ueber den Style-Namen
(analoges Prinzip wie Listen-Absaetze ueber `w:numPr`, nicht ueber den Style-Namen, Spike D).

**Fund 2 — auch Abbildungen werden in Pandocs 1x1-Wrapper-Tabelle eingebettet:** identische
Struktur wie bei beschrifteten Tabellen (Spike I), nur mit Bild- statt Tabellen-Inhalt in der
Zelle. Das bedeutete einen zweiten echten Bug, der erst beim eigenen Testrender dieser Gruppe
auffiel: `oq_apply_table_options()`s Filter aus Gruppe 3 (`[not(.//w:tbl)]`, schliesst Tabellen mit
verschachtelter Tabelle aus) erkannte zwar korrekt den Tabellen-Wrapper-Fall, NICHT aber den
Abbildungs-Wrapper-Fall (dessen Zelle keine verschachtelte Tabelle enthaelt, nur Bild- und
Beschriftungsabsatz) - Log zeigte faelschlich "Tabellen-Optionen angewendet: 2 Tabelle(n)." statt
der erwarteten 1, sobald die Test-Abbildung eine Beschriftung bekam. Behoben durch ein praeziseres,
direktes Erkennungsmerkmal statt der indirekten Ableitung ueber verschachtelte Tabellen:
`//w:tbl[not(./w:tr/w:tc/w:p/w:pPr/w:pStyle/@w:val='ImageCaption')]` - schliesst jede Tabelle aus,
deren eigene direkte Zelle einen `ImageCaption`-Absatz enthaelt, unabhaengig davon, ob diese
Zelle eine Tabelle oder eine Abbildung umschliesst. Setzt voraus, dass
`oq_apply_table_options()` VOR `oq_apply_table_captions()` laeuft (aktuelle Reihenfolge in
`writeback.R`) - danach waere `ImageCaption` ggf. schon auf einen Nutzer-Style umgemappt und das
Merkmal wuerde nicht mehr greifen.

## Spike K — Querverweis-Nummerierung (Gruppe 9), verifiziert am 2026-08-29

Vor der Implementierung von `officequarto-crossref.numbered` zwei Dinge empirisch geprueft statt
angenommen.

**1. `w:anchor`/`w:name` beim Lesen unpraefigiert.** Die bestehende Dokumentation (siehe
`CLAUDE.md`) haelt bereits fest, dass xml2-Attribut-SCHREIBZUGRIFFE auf OOXML-Knoten den
Namespace-Praefix brauchen (`xml_attr(node, "w:val") <- x`, nicht `"val"`). Fuer den umgekehrten
Fall - LESEN - war das noch nicht explizit verifiziert; Gruppe 9 braucht `w:anchor` (an
`w:hyperlink`) und `w:name` (an `w:bookmarkStart`) zuverlaessig lesbar. Per kleinem xml2-Testskript
bestaetigt: Lesen funktioniert nur UNPRAEFIGIERT (`xml_attr(node, "anchor")`/`xml_attr(node,
"name")`) - der praefigierte Versuch (`"w:anchor"`) liefert `NA`. Passt zum bereits bekannten
Verhalten von `styleId` (auch dort unpraefigiert gelesen) - also eine generelle xml2-Asymmetrie
zwischen Lesen und Schreiben, nicht ein Einzelfall.

**2. Struktur von Pandocs generierten Crossref-Hyperlinks.** Bereits bei der `tab.lp`-Recherche vor
Gruppe 1 miterfasst (Testrender einer `@tbl-example`-Referenz): `<w:hyperlink w:anchor="tbl-example">`
mit einem einzelnen `<w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>Table 1</w:t></w:r>` -
identisch aufgebaut zu den Beschriftungen selbst (statischer, fest eingebackener Text, kein
Word-Feld). Das bedeutet: der Ersatztext fuer `numbered: false` kann nicht aus einem lebendigen
Feld kommen, sondern muss - wie bei pre/sep/number-bold in Gruppe 3/5 - per Text-Ersetzung erfolgen.

**Design-Konsequenz:** anstatt Beschriftungen fuer Gruppe 9 ein zweites Mal zu suchen und zu
parsen, wurde `oq_apply_captions()` (Gruppe 3/5, `table-caption-mapping.R`) so erweitert, dass sie
IMMER (nicht nur wenn `needs_text_rewrite`) den Beschriftungstext per `oq_split_caption_text()`
ermittelt und zusammen mit dem zugehoerigen Bookmark-Namen (`oq_caption_anchor_name()`, findet
`w:bookmarkStart` als Geschwister der Beschriftung in derselben Wrapper-Zelle) in einer
`anchor_text`-Rueckgabe sammelt - unabhaengig davon, ob `officequarto-tables.caption`/
`-plots.caption` selbst konfiguriert sind. `writeback.R` erweitert dafuer das Gate, ab dem der
Beschriftungs-Verarbeitungsblock ueberhaupt laeuft, um `crossref_rewrite_needed` (true nur bei
explizitem `numbered: false`) - Gruppe 9 allein reicht damit aus, um die Beschriftungserkennung
"still" anzustossen, auch ohne jede eigene Gruppe-3/5-Konfiguration.

Verifiziert am funktionierenden Testprojekt: `report.qmd` erhielt einen Satz mit
`@tbl-kennzahlen`/`@fig-umsatz`-Referenzen; nach dem Rendern mit `officequarto-crossref: {reference_num:
false}` (officedown-Alias) zeigen beide Hyperlinks korrekt den reinen Beschriftungstext
("Quartalskennzahlen"/"Umsatzentwicklung") statt "Table 1"/"Figure 1" - und zwar unveraendert vom
gleichzeitig konfigurierten `prefix`/`separator` der Beschriftungen selbst (die nur den
Beschriftungsabsatz betreffen, nicht den in `anchor_text` gesammelten reinen `rest`-Text).

## Spike L — Beschriftungen ohne Crossref-ID (`TableCaption` vs. `ImageCaption`), verifiziert am 2026-08-29

Fehlerbericht des Nutzers gegen `../hello-wordto` (ein echtes externes Konsumenten-Projekt, kein
Dev-Symlink-Setup): `officequarto-tables.caption.style` wurde dort trotz Konfiguration NICHT auf
die Tabellen-Beschriftung angewendet. `hello-wordto.qmd` nutzt schlichte Pandoc-Beschriftungen
ohne Crossref-ID (`: Table 1 Caption` bzw. `![Figure 1 ...](img){fig-alt=...}`, kein `{#tbl-...}`/
`{#fig-...}`) — anders als `template/report.qmd` in diesem Repo, das ausschliesslich
Crossref-verwaltete Beschriftungen (`{#tbl-kennzahlen}`/`{#fig-umsatz}`) testete. Root-Cause-Analyse
per direktem Vergleich des rohen (`officequarto-keep-rendered`) gegen den fertig gepatchten
Pandoc-Output ergab zwei bis dahin unbekannte, empirisch verifizierte Tatsachen:

**1. Zwei strukturell verschiedene Pandoc-Repraesentationen fuer Beschriftungen**, abhaengig davon,
ob eine Crossref-ID vergeben wurde:

- *Mit* `{#tbl-...}`/`{#fig-...}` (der bisher einzige getestete Fall): Beschriftung+Inhalt werden
  in eine synthetische 1×1-Wrapper-Tabelle gepackt, beide Beschriftungsarten teilen sich den
  Pandoc-Style `ImageCaption` (bereits dokumentiert, siehe Gruppe 3 oben).
- *Ohne* Crossref-ID (schlichte Markdown-Beschriftung): KEINE Wrapper-Tabelle — Beschriftungs-
  Absatz und Inhalt (`w:tbl` bzw. Bild-Absatz) stehen als schlichte Geschwister direkt im
  Dokumentkoerper (`w:body`). UND: Tabellen-Beschriftungen nutzen hier einen ANDEREN, bisher
  unbekannten Style — `TableCaption`, nicht `ImageCaption` — waehrend Abbildungs-Beschriftungen
  weiterhin `ImageCaption` nutzen (Bild-Absatz selbst traegt zusaetzlich `CaptionedFigure`). Die
  reale Tabelle bekommt in diesem Fall zusaetzlich ein eigenes `<w:tblCaption w:val="..." />` in
  ihrer `w:tblPr` spendiert (ein Accessibility-Attribut, von officequarto nicht angefasst).

  Ausserdem: schlichte (Crossref-lose) Beschriftungen werden von Quarto ueberhaupt NICHT
  nummeriert — der Beschriftungstext ist reiner, unveraenderter Nutzertext ohne generiertes
  "Table N:"/"Figure N:"-Praefix. `oq_split_caption_text()`s Ziffern-Verankerung kann deshalb in
  seltenen Faellen (Beschriftungstext enthaelt zufaellig genau die von officequarto intern
  mitgezaehlte laufende Nummer als eigenstaendige Ziffer) einen Treffer liefern, obwohl semantisch
  gar keine generierte Nummer vorliegt — bleibt als dokumentierte Grenzfall-Einschraenkung
  bestehen (kein Bugfix noetig fuer den gemeldeten Fehler, aber im Hinterkopf zu behalten).

**2. Die bisherige Erkennungsheuristik (`[../w:tbl]` bzw. `[not(../w:tbl)]` — "Elternelement hat
irgendein `w:tbl`-Kind") war nur im Wrapper-Fall zufaellig korrekt.** Im Nicht-Wrapper-Fall ist das
Elternelement `w:body` selbst, und `w:body` enthaelt so gut wie immer IRGENDEINE Tabelle
irgendwo im Dokument — die Pruefung schlug dadurch auf JEDE `ImageCaption`-Beschriftung im ganzen
Dokument an, unabhaengig von tatsaechlicher struktureller Naehe. Ergebnis in `hello-wordto`: die 3
Abbildungs-Beschriftungen (Style `ImageCaption`, Geschwister von `w:body`, das anderswo eine
Tabelle enthaelt) wurden faelschlich vom TABELLEN-Beschriftungs-Finder eingesammelt (Log zeigte "3
gefunden" statt der erwarteten 1), waehrend die echte Tabellen-Beschriftung (Style `TableCaption`)
von KEINEM der beiden Finder erkannt wurde (Style-Mismatch) — Tabellen- und Abbildungs-
Beschriftungen wurden also nicht nur uebersehen, sondern teilweise regelrecht vertauscht.

**Fix**: beide Finder (`oq_find_table_caption_paragraphs()`/`oq_find_plot_caption_paragraphs()`,
`table-caption-mapping.R`/`plot-caption-mapping.R`) sowie die zugehoerigen Inhaltsknoten-Finder
(`oq_table_caption_content()`/`oq_plot_caption_content()`, fuer `$above`) wurden von der
"Elternelement hat ein `w:tbl`-Kind"-Heuristik auf direkte Positionsnaehe umgestellt: eine
Tabellen-Beschriftung ist ein Absatz mit Style `TableCaption` ODER `ImageCaption`, dessen
UNMITTELBAR folgendes Geschwisterelement eine `w:tbl` ist; eine Abbildungs-Beschriftung ist ein
Absatz mit Style `ImageCaption`, dessen UNMITTELBAR vorangehendes Geschwisterelement einen
Bild-Absatz (`w:drawing`) enthaelt. Das gilt nachweislich einheitlich fuer beide Pandoc-
Repraesentationen (verifiziert: Pandocs Default-Reihenfolge ist in BEIDEN Faellen "Beschriftung vor
der Tabelle" / "Beschriftung nach der Abbildung") und ist zugleich praeziser als die alte Heuristik
selbst im bereits funktionierenden Wrapper-Fall.

Regressionsabdeckung: `template/report.qmd` bekam einen zweiten, Crossref-losen Tabellen- und
Abbildungs-Testfall ("Beschriftung ohne Crossref-ID"-Abschnitt, Beschriftungstexte bewusst OHNE
Ziffern, um Punkt 1 oben nicht versehentlich mitzutesten); `check-writeback.R` prueft, dass beide
ebenfalls den konfigurierten Style bekommen. Gegen `../hello-wordto` (der urspruengliche
Fehlerbericht) End-to-End nachgerendert und verifiziert: Tabellen- UND alle drei Abbildungs-
Beschriftungen tragen jetzt korrekt den konfigurierten `"caption"`-Style (`Bijschrift` als
resolvter Style-ID im dortigen, niederlaendisch lokalisierten `reference-doc`).

## Spike M — `officequarto.style-map`-Quell-IDs fuer eingebaute Word-Rollen sind reference-doc-abhaengig, verifiziert am 2026-08-29

Nutzerbericht gegen `../hello-wordto`: `officequarto.style-map: {"Quote": [BlockQuote]}` sollte
Absaetze einer nativen Markdown-Zitat-Auszeichnung (`> ...`) auf den Style `"Quote"` umleiten -
funktioniert aber nicht (0 Absaetze umgemappt), obwohl derselbe Mechanismus fuer explizit per
`custom-style="Quote"` ausgezeichnete Absaetze korrekt greift (die laufen gar nicht ueber
`style-map` - Pandocs `custom-style`-Handling loest den Zielstyle direkt selbst auf).

**Root Cause** (verifiziert per `officequarto.keep-rendered: true` + Rohdokument-Inspektion): der
native `> `-Blockquote bekommt in `../hello-wordto`s Rendering tatsaechlich `pStyle="Bloktekst"`
zugewiesen, nicht `"BlockQuote"`. Der Grund: `Bloktekst` ist die (niederlaendisch lokalisierte)
`styleId` des in diesem `reference-doc` bereits vorhandenen eingebauten Word-Styles mit
Anzeigenamen `"Block Text"` - Pandocs docx-Writer erkennt fuer bestimmte Element-Typen mit einem
eingebauten Word-Rollen-Aequivalent (Blockquote ist einer davon), dass `reference-doc` diese Rolle
bereits definiert, und referenziert dann DEREN echte `styleId` weiter, statt seine eigene generische
`"BlockQuote"`-ID zu verwenden. `officequarto`s eigenes `original.docx`-Testtemplate definiert
dagegen gar keinen eingebauten Blockquote-aequivalenten Style, weshalb Pandoc dort mangels
Alternative auf seine generische `"BlockQuote"`-ID zurueckfaellt - weshalb das README/CLAUDE.md-
Beispiel (`"Zitat ACME": [BlockQuote]`) dort "zufaellig" funktionieren wuerde, aber nie tatsaechlich
end-to-end gegen echten Blockquote-Content in `template/report.qmd` getestet wurde (nur als
Illustration in der Doku, nicht in `check-style-map.R`, das ausschliesslich synthetische XML-
Testfaelle mit frei erfundenen IDs verwendet, oder in `check-writeback.R`, das nur den `Title`-Fall
prueft).

**Konsequenz**: die bisherige Doku-Aussage, `style-map`-Quell-IDs seien "Pandocs eigene, stabile,
technische Style-IDs" (uneingeschraenkt portabel), stimmt so nur fuer Pandoc-eigene, generische
Rollen ohne eingebautes Word-Aequivalent (`Normal`, `FirstParagraph`, `Compact`, `SourceCode`,
`ImageCaption`/`TableCaption` - siehe Spike L). Fuer Rollen mit einem echten eingebauten Word-
Gegenstueck (mindestens `Blockquote` bestaetigt; vermutlich auch weitere wie Ueberschriften-Ebenen)
haengt die tatsaechlich von Pandoc vergebene `pStyle`-ID vom jeweiligen `reference-doc` ab -
identisch zum bereits bekannten Lokalisierungsphaenomen bei Caption-Styles. Keine Code-Aenderung
noetig (der `style-map`-Mechanismus selbst - Gleichheitsvergleich der `pStyle`-ID - funktioniert
exakt wie entworfen); dies ist eine Doku-Luecke, kein Bug. README/CLAUDE.md um einen entsprechenden
Hinweis ergaenzt: vor dem Einsatz von `style-map` fuer eingebaute-Rollen-Content den tatsaechlich
gerenderten `pStyle` per `officequarto.keep-rendered: true` nachschlagen, statt eine feste ID wie
`BlockQuote` anzunehmen.

## Spike O — `numId`/`ilvl`-Vergabe bei verschachtelten Listen, verifiziert am 2026-08-30

Vorarbeit fuer die Listen-Style-pro-Verschachtelungsebene-Funktion
(`officequarto.lists.list-bullet`/`list-number`/`list-letter` als Array statt Skalar). Zwei Fragen
vorab per echtem Render geklaert (Scratch-`.qmd` mit 3-stufig verschachtelter Bullet-Liste,
3-stufig verschachtelter Nummern-Liste, und einer `a.`-Buchstaben-Liste mit `i.`-Roemisch-Zahlen-
Unterliste, gegen `original.docx` gerendert, `word/numbering.xml`/`word/document.xml` des
ungepatchten Pandoc-Ergebnisses inspiziert):

- **`w:ilvl` ist bei JEDEM Listen-Absatz explizit gesetzt**, auch auf der obersten Ebene
  (`w:ilvl="0"` steht immer da) — die urspruengliche Annahme "fehlt `w:ilvl` implizit Ebene 0"
  ist fuer Pandoc-erzeugte Listen gar nicht relevant, da Pandoc es nie wegLaesst. Trotzdem bleibt
  ein Default-auf-0-Fallback in `oq_paragraph_ilvl()` sinnvoll (defensiv, ECMA-376-konform, falls
  ein Absatz je aus anderer Quelle stammt).
- **Pandoc vergibt pro Verschachtelungsebene einen komplett eigenen `numId` (und damit auch einen
  eigenen `abstractNum`)** — z. B. die 3-stufige Bullet-Liste bekam `numId` 1001/1002/1003 fuer
  Ebene 0/1/2, jeweils mit eigenem `abstractNum`. Es wird NIE ein einzelner `numId` ueber mehrere
  Ebenen hinweg wiederverwendet.
- **Jeder so erzeugte `abstractNum` definiert an ALLEN 9 `w:lvl`-Eintraegen denselben `w:numFmt`**
  (z. B. `abstractNum` 991 fuer die verschachtelte Bullet-Ebene: `bullet` an Ebene 0 bis 8
  identisch; ebenso bei Nummern- und Buchstaben-Listen). Auch der Uebergang von einer
  `lowerLetter`-Liste zu einer verschachtelten `lowerRoman`-Unterliste (`a.` → `i.`) erzeugt
  zwei voellig getrennte `numId`/`abstractNum`-Paare (1007/99711 rein `lowerLetter`, 1008/99511
  rein `lowerRoman`) statt eines gemeinsamen `abstractNum` mit gemischten Formaten pro Ebene.

**Konsequenz:** Die beim Planen befuerchtete Bucket-Fehlklassifizierung (ein Absatz wird anhand von
Ebene 0 des `numId` eingeordnet, obwohl seine eigene Ebene ein anderes `numFmt` hat) ist bei
Pandoc-erzeugten Listen **strukturell unerreichbar** — jeder `numId` traegt exakt ein `numFmt` ueber
alle Ebenen hinweg, Ebene-0-Lookup ist also fuer jeden Absatz, der diesen `numId` referenziert,
bereits korrekt. `oq_num_fmt_map()` bleibt deshalb unveraendert (Ebene-0-Lookup); es gibt keinen
`oq_num_fmt_for()`. Was tatsaechlich noetig ist und umgesetzt wird: `w:ilvl` pro Absatz lesen, um
die richtige **Style**-Ebene aus einem konfigurierten Array (`list-bullet: [...]`) auszuwaehlen -
das eigentliche vom Nutzer gemeldete Problem, unabhaengig von der (hier ausgeschlossenen)
Bucket-Frage.

## Spike P — Bookmark-Struktur um crossref-nummerierte Beschriftungen, verifiziert am 2026-08-30

Vorarbeit fuer eine geplante Funktion "echte" Word-Auto-Nummerierung (live `SEQ`/`REF`-Felder statt
statisch gebackenem Text fuer Tabellen-/Abbildungs-Beschriftungen und Querverweise, analog zu
{officedown}s per `officer` erzeugten Feldern). Vor der Implementierung per echtem Render (`quarto
render report.qmd`, ungepatchtes `report.quarto-rendered.docx` inspiziert) geprueft, was
`oq_caption_anchor_name()`s bisherige Kommentierung ("ein leeres Bookmark-Paar als Geschwister der
Beschriftung, zwischen Beschriftung und Tabelle") tatsaechlich in der Roh-XML bedeutet:

**Ergebnis: Die bisherige Beschreibung ist falsch/unvollstaendig.** Das Bookmark ist kein
eng benachbartes leeres Paar zwischen Beschriftungs-Absatz und Tabelle, sondern umschliesst den
**gesamten Zellinhalt** (Beschriftung UND echte Tabelle bzw. Abbildung UND Beschriftung):

- **Tabellen** (`{#tbl-kennzahlen}`): `<w:tc><w:tcPr/>` → `<w:bookmarkStart w:id="23"
  w:name="tbl-kennzahlen"/>` → Beschriftungs-Absatz (`pStyle="ImageCaption"`, Text `"Table 1:
  Quartalskennzahlen"`) → die komplette echte, verschachtelte `<w:tbl>` → `<w:bookmarkEnd
  w:id="23"/>` → ein leerer `<w:p/>` → `</w:tc>`. Das Bookmark umspannt also
  Beschriftung UND die gesamte Tabelle, nicht nur eine Luecke dazwischen.
- **Abbildungen** (`{#fig-umsatz}`): umgekehrte Reihenfolge (Bild vor Beschriftung, wie an anderer
  Stelle dokumentiert), aber gleiches Prinzip: `<w:bookmarkStart w:name="fig-umsatz"/>` →
  Bild-Absatz → Beschriftungs-Absatz (`"Figure 1: Umsatzentwicklung"`) → `<w:bookmarkEnd/>`.
- `w:bookmarkStart`/`w:bookmarkEnd` sind reine Positions-Marker (kein Container-Element), koennen
  daher beliebig weit auseinanderliegende Geschwister-Positionen markieren — genau das passiert
  hier, keine Pandoc-Anomalie, sondern Pandocs uebliche Technik fuer Section-/Heading-Bookmarks
  (dieselbe Technik ist an denselben Ebenen fuer jede Ueberschrift im Dokument zu beobachten, z. B.
  `w:name="kennzahlen"` umspannt den gesamten Abschnitt "Kennzahlen").
- **Bestaetigt** (kleiner, aber wichtiger Nebenfund): `w:bookmarkStart/@id` wird wie `@name`/
  `@anchor`/`@styleId` beim LESEN unpraefixiert gelesen (`xml_attr(node, "id")`, nicht `"w:id"`) -
  per `Rscript`-Probe direkt verifiziert, exakt dieselbe xml2-Asymmetrie wie an anderer Stelle
  dokumentiert.

**Konsequenz fuer die geplante SEQ/REF-Feld-Funktion:** `oq_find_caption_bookmark()` darf NICHT
annehmen, `w:bookmarkEnd` sei der naechste Sibling nach `w:bookmarkStart` oder liege in der Naehe
des Beschriftungs-Absatzes - es muss ueber die gesamte Zelle nach einem `w:bookmarkEnd` mit
passender `@id` gesucht werden (XPath `@w:id`-Praedikat, wie andernorts in diesem Codebase ueblich).
Funktional ist das kein Problem fuer den Plan: das existierende (grosszuegig umspannende) Bookmark
wird ohnehin entfernt und durch ein neues, eng um die SEQ-Feld-Ziffer gelegtes Paar mit demselben
Namen ersetzt (praeziser als das Original, nicht weniger praezise) - nur die *Lokalisierung* des
zu entfernenden Original-Paars muss diese tatsaechliche Struktur beruecksichtigen, nicht die
urspruenglich angenommene enge Paarung.

**Cross-Check gegen `../hello-wordto`s echtes UU-Template (2026-08-30):** Da `hello-wordto.qmd`
bislang keine crossref-nummerierten Tabellen/Abbildungen enthielt (nur einfache Beschriftungen ohne
`{#tbl-...}`/`{#fig-...}`-ID), wurde ein kleiner, dauerhaft im Dokument verbleibender Testfall
("Example of a crossref-numbered table and figure", Abschnitt "Additional officequarto test
cases") ergaenzt, um die obige Struktur auch gegen das komplexere Realwelt-Template zu pruefen
(dieselbe Vorsicht, die bereits Spike L/M dort echte, in der kleinen ACME-Vorlage nicht sichtbare
Bugs gefunden hat). Ergebnis: **identische Struktur** wie oben - `w:bookmarkStart` vor dem
Beschriftungs-/Bild-Absatz, `w:bookmarkEnd` erst nach dem gesamten Zellinhalt, exakt dieselbe
Reihenfolge Tabelle (Beschriftung→Tabelle) vs. Abbildung (Bild→Beschriftung). Keine Abweichung
diesmal - die Struktur ist stabil ueber beide getesteten reference-docs hinweg.

## Offene Fragen aus Abschnitt 3 des Konzepts — Status

| Frage | Status |
|---|---|
| `contributes: project:` funktioniert? | Ja, mit der oben genannten Aktivierungspflicht |
| `reference-doc` reicht für Style-Übernahme? | Ja, inkl. Header/Footer/Section-Properties — mehr als ursprünglich angenommen |
| Zuverlässige Env-Variablen? | `QUARTO_PROJECT_OUTPUT_FILES`/`_OUTPUT_DIR`/`_DIR`, siehe oben |
| Eigener Projekttyp nötig? | `type:` ja, aber `type: default` reicht — die Extension muss keinen eigenen Custom-Type definieren |
| Content-Zuordnung beim Zurückschreiben? | MVP schreibt Metadaten zurück, nicht den Body (der ist durch `reference-doc` bereits korrekt) — Body-Bookmark-Zuordnung bleibt zukünftige Ausbaustufe |
| R-Verfügbarkeit prüfen? | `writeback.R` prüft `xml2`/`jsonlite`, `quarto`-CLI, `zip`/`unzip` per `requireNamespace`/`Sys.which` und bricht mit verständlicher Meldung ab; ein fehlendes `Rscript` selbst kann das Skript naturgemäß nicht abfangen (siehe README) |
