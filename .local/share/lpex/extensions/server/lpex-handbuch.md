# LPEX (Linux Personal Extensions) - Benutzerhandbuch

LPEX ist ein modulares Bash-Framework zur Erstellung und Verwaltung von persönlichen Shell-Erweiterungen. Es bietet Werkzeuge für Datenbanken, Logging, Command-Execution, interaktive Menüs (FZF) und dynamische Autocompletions (Fish).

## Inhaltsverzeichnis

1. [Architektur & Ordnerstruktur](#1-architektur--ordnerstruktur)
2. [Erstellen einer Extension](#2-erstellen-einer-extension)
3. [Die Argument API (`arguments.sh`)](#3-die-argument-api-argumentssh)
4. [Die Framework API (`lx` Wrapper)](#4-die-framework-api-lx-wrapper)
   - [Output (`__output`)](#output-__output)
   - [Input & Questions (`__input`, `__question`)](#input--questions-__input-__question)
   - [Command Execution (`__cmd`)](#command-execution-__cmd)
   - [Database (`__db`)](#database-__db)
   - [Logging (`__log`)](#logging-__log)
   - [FZF UI (`__fzf`)](#fzf-ui-__fzf)

---

## 1. Architektur & Ordnerstruktur

Das Framework trennt ausführbaren Code und anfallende Daten (State) streng voneinander:

*   **System-Installation:** `/usr/share/lpex/core` (Hier liegt das Framework).
*   **Extensions (Code):** `~/.local/share/lpex/extensions/`
    *   *Hier wird eigener Code abgelegt und versioniert.*
*   **Daten (State):** `~/.local/state/lpex/data/<extension_name>`
    *   *Hier speichert LPEX automatisch alle SQLite-Datenbanken und Logs isoliert pro Extension ab.*

---

## 2. Erstellen einer Extension

Jede Extension repräsentiert einen Subcommand (z.B. `lpex test`) und wird als Ordner in `~/.local/share/lpex/extensions/` angelegt.

Ein Modul benötigt zwingend zwei Dateien:
1.  **`arguments.sh`**: Definiert eine Funktion `arguments()`, in der Flags und Parameter deklariert werden.
2.  **`main.sh`**: Beinhaltet die Funktion `extension_start()`, die den eigentlichen Programmablauf steuert.

Optional: Eine Datei namens `description` (ohne Dateiendung) liefert den Hilfetext, der in den Menüs und Shell-Completions angezeigt wird.

---

## 3. Die Argument API (`arguments.sh`)

Die Datei `arguments.sh` nutzt interne Helfer, um CLI-Parameter zu parsen und Autocompletions zu erzeugen. Deklarierte Argumente stehen später in `main.sh` als globale Bash-Variablen zur Verfügung.

### `arg_flag`
Definiert ein Boolean-Flag (ein/aus).
*   **Syntax:** `arg_flag @NAME [options]` -> Erzeugt in der Shell `$ARG_NAME=1` (wenn gesetzt).
*   **Optionen:**
    *   `--description "Text"`: Beschreibung für die Autocompletion.
    *   `--ask`: Falls das Flag beim Aufruf fehlt, fragt das Framework interaktiv beim Benutzer nach.
    *   `--depends-on "ARG_OTHER"`: Das Flag ist nur gültig und sichtbar, wenn ein definiertes Eltern-Flag ebenfalls gesetzt ist.

### `arg_value`
Definiert ein Argument, das einen oder mehrere Werte (Strings) erfordert.
*   **Syntax:** `arg_value @NAME [options]` -> Erzeugt die Variable `$ARG_NAME` oder ein Array `${ARG_NAME[@]}`.
*   **Optionen:**
    *   `--description "Text"`: Beschreibung.
    *   `--option "Wert1 # Beschreibung"`: Gibt eine fixe Auswahlmöglichkeit vor. Kann mehrfach verwendet werden.
    *   `--option-cmd "Befehl"`: Lädt Optionen dynamisch durch Ausführung eines Shell-Befehls.
    *   `--multi` oder `--more-vals`: Erlaubt die Angabe mehrerer Werte (Erzeugt ein Bash-Array).
    *   `--fzf`: Öffnet automatisch ein FZF-Auswahlmenü, falls der Wert auf der CLI fehlt.
    *   `--type <type>`: Spezifiziert den Typ (z. B. "file", "dir", "path"), um die native Datei- und Ordner-Navigation der Fish-Shell auszulösen.

### `arg_wrap`
Delegiert die Autocompletion ab diesem Punkt vollständig an ein anderes Kommando.
*   **Syntax:** `arg_wrap "git"`: Bricht die LPEX-Completion ab und nutzt die von `git`.

---

## 4. Die Framework API (`lx` Wrapper)

In `main.sh` werden die Framework-Funktionen über den Router **`lx <module>`** aufgerufen.

### Output (`__output`)
Der Output-Manager für einheitlich formatierte Konsolenausgaben.
*   `lx output --info "Text"` (Info-Meldung, Blau)
*   `lx output --ok "Text"` (Erfolgsmeldung, Grün)
*   `lx output --warn "Text"` (Warnung, Gelb)
*   `lx output --error "Text"` (Fehler, Rot, wird an `stderr` geleitet)
*   `lx output --section "Text"` (Titel, Fett, Lila)
*   `lx output --blank "Text"` (Unformatiert)
*   *Alias:* `DEBUG "Text"` (Wird nur ausgegeben, wenn intern das Debug-Flag `$ARG_DEBUG=1` gesetzt ist).

### Input & Questions (`__input`, `__question`)
Schnittstellen für interaktive Benutzereingaben.
*   **Input (`__input`):**
    *   `lx input --prompt "Name:" @return_var` (Speichert die Eingabe in `$return_var`)
    *   `--confirm`: Fragt den Benutzer um Bestätigung der Eingabe.
    *   `--password`: Versteckt die Zeicheneingabe.
    *   `--fzf`: Nutzt eine grafische FZF-Eingabe anstelle des Standard-`read`-Befehls.
*   **Question (`__question`):**
    *   `if lx question "Sicher?"; then ... fi` (Gibt Exit-Code 0 für Ja, 1 für Nein).
    *   `--default-yes` oder `--default-no`: Bestimmt die Standardauswahl.
    *   `--fzf`: Öffnet einen grafischen Auswahldialog.

### Command Execution (`__cmd`)
Ein Wrapper für Shell-Befehle, der Fehler abfängt, Ausgaben umleitet und Logs in die Datenbank schreiben kann.
*   **Grundaufruf:** `lx cmd --run "ls -la"`
*   **Optionen:**
    *   `@return_var`: Speichert Standard-Output (`stdout`) des Befehls in der angegebenen Variable.
    *   `--quiet`: Unterdrückt alle Ausgaben auf dem Terminal.
    *   `--show-cmd`: Gibt den auszuführenden Befehl zuvor auf dem Terminal aus.
    *   `--exit-on-fail`: Bricht das gesamte Skript ab, wenn der Befehl einen Exit-Code > 0 liefert.
    *   `--error-msg "Text"`: Eigene Fehlermeldung im Fehlerfall.
    *   `--log`: Schreibt den Befehl, den Exit-Code, sowie Stdout/Stderr automatisch in die Tabelle `logs_cmd`.
    *   `--log-tags "tag1,tag2"`: Fügt dem Datenbank-Log Tags hinzu.
    *   `--log-keep <days>`: Definiert, wie viele Tage der Log-Eintrag erhalten bleiben soll.

### Database (`__db`)
Ein SQLite3-Wrapper für das Framework. Greift standardmäßig auf `~/.local/state/lpex/data/<extension>/<db_name>` zu.
*   **Tabelle anlegen:** 
    `lx db --file "conf.db" --table "users" --create-table --cols "name TEXT, age INT"`
*   **Datensatz einfügen:** 
    `lx db --file "conf.db" --table "users" --insert --data "name" "Florian" "age" "30"`
*   **Datensätze lesen:** 
    `lx db --file "conf.db" --table "users" --select @results_array --cols "name, age" --where "age > 20"` (Speichert Ergebnisse getrennt durch `|||` im Array).

### Logging (`__log`)
Die Engine für strukturierte Zeitreihen-Daten. Verwaltet die Tabellen (inklusive Timestamp, Session-ID und automatischer Bereinigung).
*   **Initialisieren:** `lx log --init --table "custom_log" --cols "cpu INT, status TEXT"`
*   **Schreiben:** `lx log --write --table "custom_log" --keep-days 14 --tags "system" --data "cpu" "50" "status" "ok"`
*   **Lesen:** `lx log --read --table "custom_log" --limit 100 --time-range "> 1677628800" @result_array`
*   **Aufräumen:** `lx log --clean-table --table "custom_log"` (Löscht Datensätze, bei denen `timestamp + keep_days` abgelaufen ist).

### FZF UI (`__fzf`)
Ein Wrapper für den `fzf` Command-Line Fuzzy Finder.
*   **Aufruf:** `lx fzf @return_var --list "Option1\nOption2" --header "Bitte wählen:"`
*   **Optionen:**
    *   `--prompt "Text"`: Setzt den Eingabeprompt (Standard: `> `).
    *   `--preview "<cmd>"` oder `--preview-bash "<cmd>"`: Befehl zur Vorschau des aktuell markierten Eintrags (mit `{}` als Platzhalter).
    *   `--standard`, `--no-input`, `--enter`: Steuert das visuelle Theme.
    *   `--confirm`: Ruft nach der Auswahl `lx question` zur endgültigen Bestätigung auf.
    *   `--return-first-word`: Gibt nur das erste Wort des ausgewählten Strings zurück.