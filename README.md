# homepage-kit

Eine Vorlage für die Website eines kleinen Betriebs, die du per Chat pflegst. Du schreibst deinem OpenClaw auf Telegram, was sich ändern soll. Der Agent ändert die Website auf deinem Mac, du siehst das Ergebnis sofort in einer privaten Vorschau, und auf Zuruf veröffentlicht er sie auf deinem Server.

Die Vorlage ist für keine Branche festgelegt. Sie zeigt Platzhaltertexte eines erfundenen Betriebs, und der Agent ersetzt Inhalt und Gestaltung im ersten Gespräch durch deine eigenen.

## So hängt es zusammen

```
Telegram ──> OpenClaw ──> dieses Repo auf dem Mac
                              │
                              ├─ Vorschau: Dienst auf dem Mac, über Tailscale auf Handy und Laptop erreichbar
                              │
                              └─ »Veröffentlichen« ──> VPS mit eigener Domain und HTTPS
```

- **Vorschau.** macOS startet einen Dev-Server beim Hochfahren und nach jedem Absturz neu. Tailscale macht ihn unter einer HTTPS-Adresse erreichbar, die nur deine eigenen Geräte öffnen können.
- **Wächter.** OpenClaw prüft die Vorschau alle fünf Minuten und startet sie bei Bedarf neu.
- **Skill.** OpenClaw bekommt einen Skill für diese Website. Seinen Namen und die Stichworte, bei denen er anspringt, legst du selbst fest.
- **Website.** Statische Seiten mit Astro, auf Deutsch und Englisch, mit Impressum und Datenschutzerklärung. Keine Cookies, keine fremden Dienste.

## Voraussetzungen

Ein Mac, der durchläuft, zum Beispiel ein Mac mini, mit:

- [Homebrew](https://brew.sh) und Node.js ab 22.23: `brew install node git`
- [Tailscale](https://tailscale.com/download), angemeldet. Im Adminbereich unter DNS müssen MagicDNS und HTTPS-Zertifikate aktiv sein.
- OpenClaw, eingerichtet mit Telegram

Tailscale und OpenClaw sind beide optional. Ohne Tailscale läuft die Vorschau nur auf dem Mac, ohne OpenClaw arbeitest du mit Claude Code oder Codex direkt im Repo. Die Regeln für alle Agenten stehen in `AGENTS.md`.

## Einrichten

1. Öffne [realS3BI/homepage-kit](https://github.com/realS3BI/homepage-kit), klick auf **Use this template** und lege ein eigenes, privates Repo an.
2. Klone es nach `~/Developer`. Die Ordner Dokumente und Schreibtisch synchronisiert iCloud, dort fällt die Vorschau früher oder später aus.

   ```sh
   mkdir -p ~/Developer && cd ~/Developer
   git clone https://github.com/realS3BI/homepage-kit.git
   cd homepage-kit
   ```

   Hast du in Schritt 1 ein eigenes Repo angelegt, klonst du stattdessen dessen Adresse.

3. Starte das Setup:

   ```sh
   npm run setup
   ```

Das Setup stellt vier Fragen und trägt die Antworten in `kit.env` ein:

| Frage | Bedeutung |
| --- | --- |
| Kurzname der Website | Steht im Namen der macOS-Dienste und des Wächters, zum Beispiel `homepage` |
| Name des Skills | Damit rufst du den Agenten im Chat auf. Aus `website` wird `/website` |
| Stichworte | Wörter, bei denen der Skill auch ohne Schrägstrich-Befehl anspringt, zum Beispiel „Firmenwebsite, unsere Homepage“ |
| Port der Vorschau | Jede Website auf demselben Mac braucht einen eigenen |

Danach installiert es die Abhängigkeiten, richtet den Vorschau-Dienst ein, gibt ihn über Tailscale frei und installiert Skill und Wächter in OpenClaw. Am Ende zeigt es die Adresse der Vorschau.

Du kannst das Setup jederzeit erneut ausführen, auch um Skill-Namen, Stichworte oder Port zu ändern. Was unter den alten Namen lief, räumt es vorher weg.

Du kannst das auch OpenClaw überlassen. Ein Agent übergibt die Antworten als Optionen:

> Klone https://github.com/realS3BI/homepage-kit nach ~/Developer und führe im Repo `npm run setup -- --slug homepage --skill website --triggers "Firmenwebsite, unsere Homepage"` aus. Schick mir danach die Adresse der Vorschau.

## Loslegen

Schreib deinem OpenClaw, hier mit dem Skill-Namen `website`:

> /website Leg los

Der Agent bittet zuerst um Beispiele und Material und stellt dann Fragen zum Betrieb, immer nur wenige auf einmal. Die Antworten hält er in `BRIEF.md` fest. Danach baut er die erste Fassung und schickt dir die Adresse der Vorschau.

### Beispiele und Material

Zeig dem Agenten, wie die Website aussehen soll. Schick ihm im Chat:

- Links und Bildschirmfotos von Websites, die dir gefallen
- Logo, Fotos und vorhandene Texte

Der Agent legt alles im Ordner `beispiele/` ab, sieht es sich an und notiert in `BRIEF.md`, was er daraus für Aufbau, Farben, Schrift und Tonfall mitnimmt. Von fremden Websites übernimmt er die Richtung, er kopiert sie nicht. Dein eigenes Material verwendet er direkt.

Das geht jederzeit, nicht nur am Anfang. Ein Bildschirmfoto mit „so soll der Kopfbereich aussehen“ genügt.

### Im Alltag

> /website Am Freitag haben wir ab jetzt bis 14 Uhr offen
>
> /website Wir haben von 3. bis 14. August Betriebsurlaub
>
> /website Hier ist unser neues Teamfoto
>
> /website Mach die letzte Änderung rückgängig

Jede Änderung wird ein eigener Git-Commit, deshalb lässt sich jede einzeln zurücknehmen.

## Veröffentlichen

Solange Beispielinhalt oder Platzhalter mit `TODO` auf der Website stehen, verweigert der Befehl die Veröffentlichung. Das betrifft vor allem Impressum und Datenschutzerklärung. Lass beide vor dem ersten Veröffentlichen rechtlich prüfen.

### Auf einem kleinen VPS

Du brauchst einen Server mit Ubuntu oder Debian, auf den du dich per SSH-Schlüssel anmelden kannst, und eine Domain, deren A-Record auf die IP des Servers zeigt. Die kleinste Größe jedes Anbieters reicht, weil der Server nur fertige Dateien ausliefert.

1. Trag Domain und Server in `kit.env` ein:

   ```sh
   SITE_DOMAIN=musterbetrieb.at
   DOMAIN_ALIASES=www.musterbetrieb.at
   DEPLOY_HOST=root@203.0.113.10
   ```

2. Bereite den Server einmalig vor. Der Befehl installiert Docker und legt den Zielordner an.

   ```sh
   npm run deploy:setup
   ```

3. Veröffentliche:

   ```sh
   npm run deploy
   ```

Der Befehl baut die Website auf dem Mac, kopiert die Dateien auf den Server und startet dort Caddy. Caddy holt und erneuert das HTTPS-Zertifikat selbst. Im Chat genügt später `/website Veröffentlichen`.

### Mit Coolify oder einer anderen Plattform

Das `Dockerfile` baut ein Image, das die Website auf Port 80 ausliefert. Verbinde das Repo mit der Plattform, wähle Dockerfile als Build-Methode und trag die Domain dort ein. `SITE_DOMAIN` in `kit.env` muss trotzdem stimmen, daraus entstehen die Adressen für Suchmaschinen.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `npm run setup` | Fragt Namen und Port ab, richtet Vorschau, Tailscale-Freigabe, Skill und Wächter ein |
| `npm run status` | Zeigt den Zustand aller Teile und die offenen Platzhalter |
| `npm run check` | Prüft Typen, baut die Website und listet Platzhalter |
| `npm run preview:check` | Prüft die Vorschau und startet sie bei Bedarf neu |
| `npm run preview:logs` | Zeigt die letzten Zeilen des Vorschau-Logs |
| `npm run share` | Gibt die Vorschau über Tailscale frei |
| `npm run deploy:setup` | Bereitet den Server einmalig vor |
| `npm run deploy` | Baut und veröffentlicht die Website |
| `npm run uninstall` | Entfernt Dienste, Freigabe, Skill und Wächter vom Mac |

## Mehrere Websites auf einem Mac

Lege für jede Website ein eigenes Repo aus der Vorlage an und gib jeder beim Setup einen eigenen Kurznamen, Skill-Namen und Port. Dienste, Skills und Wächter tragen diese Namen und kommen sich nicht in die Quere.

## Wenn etwas nicht geht

**Die Vorschau lädt nicht.** `npm run status` zeigt, welcher Teil fehlt. `npm run preview:check` startet den Dienst neu, `npm run preview:logs` zeigt den Grund.

**Der Agent antwortet auf Telegram nicht.** `openclaw channels status --deep` zeigt den Zustand des Kanals. Steht er auf „stopped“, hilft `openclaw gateway restart`.

**Die Tailscale-Adresse öffnet sich nicht.** Das Gerät, von dem du zugreifst, muss im selben Tailnet angemeldet sein. Meldet `npm run share` einen Fehler, fehlen im Tailscale-Adminbereich MagicDNS oder die HTTPS-Zertifikate.

**Port belegt.** Führe `npm run setup` erneut aus und nenne einen anderen Port.

**Nach einem Node-Update startet die Vorschau nicht.** Führe `npm run setup` erneut aus, dann zeigt der Dienst wieder auf das aktuelle Node.

**Fehler -11 oder „Resource deadlock avoided“.** Das Repo liegt in einem iCloud-Ordner. Verschiebe es nach `~/Developer` und führe `npm run setup` erneut aus.

**Alarm bei Ausfall.** Trag in `kit.local.env` den Empfänger ein, etwa `WATCHDOG_ALERT_TO=telegram:123456789`, und führe `npm run setup` erneut aus. Nach zwei Fehlschlägen in Folge schickt OpenClaw eine Nachricht.

## Aufbau des Repos

| Ort | Inhalt |
| --- | --- |
| `AGENTS.md` | Regeln und Ablauf für jeden KI-Agenten |
| `BRIEF.md` | Was über den Betrieb bekannt ist, vom Agenten gepflegt |
| `beispiele/` | Vorbilder und eigenes Material |
| `docs/onboarding.md` | Ablauf des ersten Gesprächs |
| `kit.env` | Einstellungen: Kurzname, Skill-Name, Stichworte, Port, Domain, Server |
| `src/content/` | Alle Texte und Fakten der Website |
| `src/styles/tokens.css` | Farben, Schriften, Abstände |
| `scripts/` | Setup, Vorschau, OpenClaw, Veröffentlichung |
| `openclaw/` | Vorlage des OpenClaw-Skills |
| `deploy/`, `Dockerfile` | Konfiguration für den Server |
