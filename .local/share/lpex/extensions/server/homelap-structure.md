# Master-Architektur-Konzept: Homelab Orchestrierung mit LPEX

Dieses Dokument beschreibt die verbindliche Systemarchitektur, die Rollenverteilung und die Datenflüsse für das gesamte Home-Lab-Netzwerk (Proxmox-Hosts, LXC-Container, Raspberry Pi Observer und Desktop-Client).

---

## 1. Die Rollenverteilung (Das Paradigma)

Das System folgt strikt dem Paradigma der "Control Plane" (Steuerungsebene) und der "Data Plane" (Ausführungsebene). Es gibt keine Autonomie bei den "dummen" Systemen.

### 1.1. Der Desktop PC (LPEX)
*   **Die Rolle:** Flottenkommandant & Entwicklungszentrum.
*   **Aufgabe:** Hier werden alle Skripte geschrieben, verwaltet (Smart Vault Git) und per `lpex push` auf die Server verteilt.
*   **Dashboard:** Aggregiert die finalen Status-JSONs vom Netzwerk-Pool und stellt sie als grafisches Terminal-Dashboard (`homenet status`) dar.
*   **Updates:** Stoßen Updates (Host & Container) **manuell** über LPEX-Makros nach dem "Sonntags-Wartungsfenster"-Prinzip an.

### 1.2. Der Observer (Raspberry Pi)
*   **Die Rolle:** Das autonome Gehirn & High-Availability (HA) Controller.
*   **Aufgabe:** Überwacht kontinuierlich die Hosts. Triggert alle System-Events, die ohne menschliches Eingreifen laufen müssen (z.B. Backup-Jobs).
*   **Power-Management:** Nur der Observer entscheidet, wann ein Standby-Server (`pve102`, `pve103`) aufgeweckt (WOL / Shelly) oder heruntergefahren wird.
*   **Log-Zentrum:** Die SD-Karte des Observers ist der manipulationssichere Flugdatenschreiber. Alle Systeme pushen ihre Logs zuerst hierher.

### 1.3. Die Proxmox Hosts (`pve101`, `pve102`, `pve103`)
*   **Die Rolle:** Die ausführenden "Muskeln".
*   **Aufgabe:** Führen isolierte, atomare Tasks aus, wenn der Observer es befiehlt (z.B. `zfs-sync-task.sh`).
*   **Regel:** Keine Autostart-Container! Der Observer befiehlt den Start. Kein Host weckt einen anderen Host auf.

---

## 2. Die Daten- & Log-Architektur (3-Tier System)

Daten werden physisch nach ihrem Verwendungszweck getrennt, um maximale Übersichtlichkeit für den Menschen und sofortige Parsbarkeit für Maschinen (Conky, Grafana) zu gewährleisten. Alle Daten fließen final auf den zentralen NFS-Pool (`pool_fast`).

### 2.1. Ebene 1: Status & Metriken (Flüchtig)
Speicherort: `/mnt/pool_fast/ServerData/monitoring/state/`
*   Hier liegen überschreibbare `.json` oder `.txt` Dateien.
*   Beispiel `lxc_live.txt`: Ein winziger Systemd-Dienst auf `pve101` dumpt alle 5 Sekunden `pct list` in den Pool. Das erlaubt LPEX am Desktop eine Autocompletion in 0.01 Sekunden ohne SSH.
*   Beispiel `dashboard.json`: Enthält Uptime, offene APT-Updates und kritische Fehler-Counts.

### 2.2. Ebene 2: Das Log-Tagebuch (Kompakt)
Speicherort: `/mnt/pool_fast/ServerData/monitoring/logs/daily/`
*   Das Erzähl-Tagebuch des Clusters. Enthält nur Management-Entscheidungen und knappe Erfolgs-/Fehlermeldungen.
*   **Strikes Format:** `YYYY-MM-DD HH:MM:SS : <node> : <script> >>> <message>`
*   Farben: Keine ANSI-Codes in den Dateien. Farben werden nur vom LPEX Frontend beim Auslesen gerendert.

### 2.3. Ebene 3: Die Blackbox (Rohdaten)
Speicherort: `/mnt/pool_fast/ServerData/monitoring/outputs/YYYY-MM/`
*   Wenn ein Befehl (z.B. `apt upgrade` oder `syncoid`) ausgeführt wird, wird der komplette Output in eine einmalige Textdatei (z.B. `20260324_pve102_apt-update.txt`) geschrieben.
*   Im Fehlerfall verweist Ebene 2 auf diese Datei zur detaillierten Tiefenrecherche.

### 2.4. Aufbewahrung (Retention)
*   **Text-Logs (Ebene 2 & 3):** 100 Tage. Danach greift Linux `logrotate` und löscht alte Daten.
*   **Pre-Update Snapshots:** 50 Tage. Ein Cleanup-Skript löscht alte Update-Sicherungen.

---

## 3. Die Konfiguration (Single Source of Truth)

Alle Infrastruktur-Daten (IPs, MAC-Adressen) dürfen niemals hart in Skripte geschrieben werden.

*   **Der LPEX Master:** Alles wird zentral in `~/.local/state/lpex/data/server/config.conf` auf dem Desktop verwaltet.
*   **Der Config-Push:** Wenn sich eine IP ändert, führt LPEX einen `push --config` aus. Die Datei wird als `homelab.conf` auf den Observer (und bei Bedarf Hosts) kopiert.
*   **Die Umsetzung:** Jedes Skript auf dem Observer macht ein `source ~/scripts/homelab.conf` und hat sofort die aktuellen Adressen.

---

## 4. Workflows & Prozesse

### 4.1. Der Backup-Workflow (Observer-gesteuert)
1.  Der Timer auf dem Observer triggert das Skript `backup-orchestrator.sh`.
2.  Observer sendet Wake-On-LAN (WOL) an `pve102` und wartet auf Ping.
3.  Observer triggert auf `pve101` den Daten-Transport: `ssh root@pve101 /root/scripts/zfs-sync-task.sh`.
4.  Nach Erfolg feuert der Observer den `apt update` Scan auf `pve102` ab, um das Dashboard zu füttern.
5.  Observer triggert den ACPI-Shutdown (`ssh root@pve102 shutdown -h now`).
6.  Observer schreibt das Resultat als einen sauberen Eintrag ins Tages-Log auf den Pool.

### 4.2. Der Pre-Flight Update Workflow (Lokal getriggert)
Updates von Systemen passieren manuell an arbeitsfreien Tagen vom LPEX-Desktop aus.
1.  Aufruf: `lpex server host update pve102`
2.  LPEX weckt den Server (falls schlafend).
3.  LPEX triggert einen ZFS Snapshot (OS-Root oder Container).
4.  LPEX führt das Update aus. Outputs fließen in Ebene 3.
5.  LPEX schaltet den Server wieder ab.

---
*Status: Architektur definiert. Nächster technischer Schritt: Implementierung des "Config-Push" Systems zum Ausrollen der zentralen Variablen auf den Observer.*