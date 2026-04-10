# LPEX Server Extension: Homelab Orchestrator

Diese Extension ist das zentrale Nervensystem zur Steuerung, Überwachung und Orchestrierung deines Homelabs. Sie implementiert eine strikte Trennung zwischen Steuerung (Control Plane) und Ausführung (Data Plane).

## 1. Das Architektur-Paradigma

Das System folgt einer hierarchischen Struktur, um maximale Stabilität und Vorhersehbarkeit zu gewährleisten.

### 1.1 Die Rollenverteilung
*   **LPEX Desktop (Der Kommandant):** Hier laufen alle Fäden zusammen. Von hier aus werden Befehle manuell abgesetzt, Skripte entwickelt und per `push` verteilt. Es ist die einzige Instanz mit einer vollständigen Wissensdatenbank über das gesamte Netz.
*   **Observer / Raspberry Pi (Das autonome Gehirn):** Diese Instanz ist für 24/7 Aufgaben zuständig. Sie überwacht die Hosts, entscheidet über das Power-Management (WOL/Shelly) und triggert automatisierte Events wie Backups.
*   **Proxmox Hosts (Die Muskeln):** `pve101`, `pve102`, `pve103` führen die eigentliche Arbeit aus. Sie besitzen keine eigene Entscheidungslogik über den Cluster-Zustand, sondern reagieren auf Befehle vom Desktop oder dem Observer.

---

## 2. Daten- & Log-Architektur (3-Tier System)

Um eine effiziente Analyse zu ermöglichen, werden Daten nach ihrer "Wichtigkeit" und "Lebensdauer" getrennt auf dem zentralen NFS-Pool (`pool_fast`) gespeichert.

### Ebene 1: Status & Metriken (Live-Zustand)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/state/`
*   **Inhalt:** Kurzlebige `.json` oder `.txt` Dateien (z.B. `lxc_live.txt`).
*   **Zweck:** Ermöglicht LPEX am Desktop eine extrem schnelle Autocompletion (z.B. Container-IDs) ohne SSH-Latenz.

### Ebene 2: Das Log-Tagebuch (Management-Ebene)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/logs/daily/`
*   **Inhalt:** Strukturierte Text-Logs im Format: `TIMESTAMP : NODE : SCRIPT >>> MESSAGE`.
*   **Zweck:** Menschlich lesbare Zusammenfassung der Cluster-Aktivitäten (Erfolge/Fehler).

### Ebene 3: Die Blackbox (Rohdaten-Ebene)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/outputs/YYYY-MM/`
*   **Inhalt:** Komplette Terminal-Outputs von Befehlen (z.B. `apt upgrade`).
*   **Zweck:** Detaillierte Fehleranalyse (Deep-Dive), wenn Ebene 2 einen Fehler meldet.

---

## 3. Modul-Übersicht

Die Extension ist in drei Hauptbereiche unterteilt, die jeweils über `lpex server <modul>` erreichbar sind.

### 3.1 Modul: `host`
Verwaltet die physischen Proxmox-Knoten.
*   **`status`**: Zeigt Uptime, CPU-Last und anstehende Updates der PVE-Nodes.
*   **`control`**: Power-Management (Shutdown, Reboot) und Wake-on-LAN Integration.
*   **`ssh`**: Direkter Tunnel für administrative Aufgaben.
*   **`push`**: Verteilt Konfigurationen und Skripte vom Desktop auf die Hosts.

### 3.2 Modul: `container`
Fokussiert auf die Verwaltung der LXC-Container innerhalb des Proxmox-Clusters.
*   **`cmd`**: Führt Befehle innerhalb eines Containers aus (Struktur: `pct exec`).
*   **`filesystem`**: Ermöglicht den Zugriff auf Container-Daten und das Synchronisieren von Verzeichnissen.
*   **`fetch` / `push`**: Datentransfer zwischen Desktop und Container-Dateisystem.

### 3.3 Modul: `observer`
Steuert die Überwachungs-Einheiten (Raspberry Pis).
*   **`service`**: Management der Hintergrunddienste (z.B. Health-Checks).
*   **`logs`**: Aggregiert und visualisiert die Logs der Observer-Einheiten.
*   **`status`**: Überprüft die Verfügbarkeit und den Zustand des "autonomen Gehirns".

---

## 4. Globale Helfer & Konfiguration (`extension_global.sh`)

Die `extension_global.sh` fungiert als Shared Library für alle Submodule.

*   **Single Source of Truth:** Alle IPs und Pfade werden zentral in `~/.local/state/lpex/data/server/config.conf` verwaltet.
*   **Validierung:** Die Funktion `enforce_config_var` verhindert Skript-Abbrüche durch fehlende Variablen.
*   **Dynamische Completion:** `get_lxc_completion_cmd` liest den Live-Cache vom NFS-Pool, damit die Tab-Completion für Container-IDs verzögerungsfrei funktioniert.
*   **Host-Resolution:** `get_active_host` ermittelt dynamisch den aktuell primären PVE-Server.

---

## 5. Zentrale Workflows

### 5.1 Update-Prozess (Sicherheits-First)
1.  **Check:** `lpex server host status` prüft auf Updates.
2.  **Snapshot:** Vor jedem Update wird automatisch ein ZFS-Snapshot erstellt.
3.  **Execution:** Das Update wird durchgeführt, der Output landet in der "Blackbox" (Ebene 3).
4.  **Log:** Ein Erfolg/Fehler-Eintrag wird im Tagebuch (Ebene 2) vermerkt.

### 5.2 Backup-Orchestrierung
Der **Observer** weckt nachts Backup-Hosts (`pve102`/`pve103`) per WOL, triggert die ZFS-Replikation auf `pve101` und schaltet die Backup-Hosts nach erfolgreichem Transfer wieder ab. LPEX am Desktop kann diesen Status jederzeit über das Dashboard visualisieren.

---
*Dokumentation generiert am 31. März 2026 für das LPEX Framework.*
