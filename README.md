# officequarto

Prototyp einer Quarto-Extension, die ein beliebiges vorhandenes Word-Dokument als
Ziel-/Vorlagenformat für Quarto nutzbar macht (Styles, Layout, Kopf-/Fußzeilen werden übernommen)
und nach `quarto render` automatisch eine Kopie dieses Dokuments mit den daraus übernommenen
Metadaten zurückschreibt — der Grundgedanke von [{officedown}](https://github.com/ardata-fr/officedown),
aber als installierbare Quarto-Extension statt als R-Paket.

## Nutzung in 3 Schritten

1. **Extension in ein Quarto-Projekt installieren** (ein Projekt mit `_quarto.yml` ist zwingend —
   siehe [Einschränkungen](#bekannte-einschränkungen)):

   ```bash
   quarto add <owner>/officequarto
   ```

2. **Hook aktivieren und Original-Dokument referenzieren** — in der `_quarto.yml` des Projekts:

   ```yaml
   project:
     type: officequarto   # aktiviert den Zurückschreiben-Hook - Pflichtschritt, siehe unten!

   format:
     docx:
       reference-doc: original.docx   # euer beliebiges vorhandenes Word-Dokument
   ```

   > **Wichtig:** `quarto add` allein installiert nur die Extension-Dateien. Ohne
   > `project: type: officequarto` in eurer eigenen `_quarto.yml` läuft der Hook **nicht** — das
   > ist kein Zero-Config-Mechanismus (siehe [`dev/spike-notes.md`](dev/spike-notes.md)).

3. **Rendern:**

   ```bash
   quarto render
   ```

   Neben dem normalen Pandoc-Ergebnis (`*.docx`) entsteht automatisch `*.written-back.docx` —
   euer Original mit reingerenderten Inhalten und zurückgeschriebenen Dokument-Metadaten.

Ein vollständiges Beispiel liegt in [`template/`](template/): `original.docx` (Beispielvorlage mit
eigenem Header/Footer/Custom-Properties) + `bericht.qmd` + `_quarto.yml`.

## Architektur

```
_extensions/officequarto/
├── _extension.yml       contributes: project: { project: { type: default,
│                                                  post-render: [scripts/writeback.R] } }
└── scripts/writeback.R  Post-Render-Hook

template/                 Beispielprojekt (quarto use template)
├── _quarto.yml            project: type: officequarto
├── original.docx          Beispiel-Vorlage
└── bericht.qmd             format: docx: reference-doc: original.docx
```

Ablauf bei `quarto render`:

1. Pandoc/Quarto rendern die `.qmd` mit `original.docx` als `reference-doc`. **Das allein reicht
   bereits**, um Styles, Header, Footer und Section-Properties des Originals zu übernehmen — das
   ist natives Pandoc-Verhalten, kein eigener Code nötig.
2. Der Post-Render-Hook `scripts/writeback.R` läuft automatisch danach: Er ermittelt über
   `quarto inspect` den Pfad des `reference-doc`, nimmt eine Kopie des frisch gerenderten `.docx`
   und überträgt daraus `docProps/core.xml` (Subject, Keywords, Description, Category) und
   `docProps/custom.xml` (frei definierte Custom-Properties) des Originals hinein — Metadaten, die
   Pandoc beim Rendern sonst durch neue, leere Werte ersetzt. Das Ergebnis wird als
   `<name>.written-back.docx` gespeichert; Original und reines Pandoc-Ergebnis bleiben unverändert
   erhalten.

Warum kein manueller Body-Ersatz mehr? Das war der ursprüngliche Plan (Body des Originals
entfernen, gerenderten Inhalt einfügen). Ein Spike hat gezeigt, dass `reference-doc` das für den
Body bereits vollständig erledigt — ein zusätzlicher XML-Merge-Schritt mit `officer` brachte
keinen Mehrwert und stieß zudem auf einen Grenzfall-Bug in `officer 0.7.3` beim Zusammenführen
zweier strukturell sehr ähnlicher Dokumente. Details in
[`dev/spike-notes.md`](dev/spike-notes.md).

## Voraussetzungen

- `quarto` (getestet mit 1.8.24) und `pandoc` (getestet mit 3.10.1) im `PATH`
- `Rscript` im `PATH` — der Post-Render-Hook ist ein R-Skript. Fehlt `Rscript` selbst, bricht
  Quarto mit einer eigenen Fehlermeldung ab, bevor unser Skript überhaupt starten kann; das lässt
  sich aus dem Skript heraus nicht abfangen.
- R-Pakete `xml2` und `jsonlite` (`install.packages(c("xml2", "jsonlite"))`) — der Hook prüft
  beim Start, ob beide verfügbar sind, und bricht sonst mit einer verständlichen Meldung ab.
- Die Kommandozeilenwerkzeuge `zip`/`unzip` im `PATH` (auf macOS/Linux standardmäßig vorhanden)

## Bekannte Einschränkungen

- **Funktioniert nur innerhalb eines Quarto-Projekts** (`_quarto.yml` vorhanden). Pre-/Post-Render-
  Skripte sind laut offizieller Quarto-Dokumentation ein reines Projekt-Feature und greifen nicht
  bei `quarto render einzeldatei.qmd` ohne Projekt (siehe
  [quarto-dev/quarto-cli#13032](https://github.com/quarto-dev/quarto-cli/issues/13032)).
- Der Prototyp schreibt **Dokument-Metadaten** zurück (Subject/Keywords/Description/Category/
  Custom-Properties), nicht den Body — der ist bereits durch `reference-doc` korrekt. Ein
  bookmark-genaues, partielles Einfügen von Inhalt in einen größeren, fest bestehenden Body des
  Originals (echte {officedown}/Content-Control-Parität) ist eine mögliche spätere Ausbaustufe,
  aber bewusst außerhalb dieses Prototyp-Scopes.
- Keine volle {officedown}-Feature-Parität (Querverweise, `flextable`-Sonderbehandlung,
  Inhaltsverzeichnis-Feldaktualisierung, Kommentare, Tracked Changes).
- Round-Trip-Treue ist grundsätzlich begrenzt: Wenn ein `docProps/custom.xml` im gerenderten
  Pandoc-Ergebnis noch nicht als Part registriert ist, wird das beim Überschreiben nicht
  automatisch nachgetragen (siehe `dev/spike-notes.md`).

## Entwicklung / Tests

```bash
cd template
quarto render bericht.qmd
Rscript ../dev/check_writeback.R   # prueft Header/Footer/Body/Metadaten des Ergebnisses
```

`dev/make_sample_docx.R` erzeugt die Beispiel-Vorlage `template/original.docx` neu (benötigt das
R-Paket `officer`, nur für die Testvorlagen-Erzeugung, nicht für den Hook selbst).
