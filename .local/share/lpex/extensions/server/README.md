# LPEX Server Extension: Homelab Orchestrator

Diese Extension ist das zentrale Nervensystem zur Steuerung, Überwachung und Orchestrierung des Homelabs. Sie implementiert eine strikte Trennung zwischen Steuerung (Control Plane) und Ausführung (Data Plane).

*Stand: April 2026*

---

## 1. Das Architektur-Paradigma

### 1.1 Die Rollenverteilung
*   **LPEX Desktop (Der Kommandant):** Hier laufen alle Fäden zusammen. Von hier aus werden Befehle manuell abgesetzt, Skripte entwickelt und per `push` verteilt. Es ist die einzige Instanz mit einer vollständigen Wissensdatenbank über das gesamte Netz.
*   **Observer / Raspberry Pi (Das autonome Gehirn):** Für 24/7 Aufgaben zuständig. Überwacht Hosts, entscheidet über Power-Management (WOL) und triggert automatisierte Events wie Backups. Zwei Instanzen (pi1 = Primary, pi2 = Standby) bilden ein HA-Paar.
*   **Proxmox Hosts (Die Muskeln):** `pve101`, `pve102`, `pve103` führen die eigentliche Arbeit aus. Sie besitzen keine eigene Entscheidungslogik, sondern reagieren auf SSH-Befehle vom Desktop oder Observer.

---

## 2. Daten- & Log-Architektur (3-Tier System)

Alle Daten werden nach Wichtigkeit und Lebensdauer getrennt auf dem zentralen NFS-Pool (`pool_fast`) gespeichert.

### Ebene 1: Status & Metriken (Live-Zustand)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/state/`
*   **Inhalt:** Kurzlebige `.json`-Dateien (z.B. `pve101_health.json`, `observer_heartbeat.json`).
*   **Zweck:** Primäre Datenquelle für `host status` und `observer status` — kein SSH nötig, kein Warten.

### Ebene 2: Das Log-Tagebuch (Management-Ebene)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/logs/daily/`
*   **Inhalt:** `TIMESTAMP : NODE : SCRIPT >>> MESSAGE`
*   **Zweck:** Menschlich lesbare Zusammenfassung der Cluster-Aktivitäten.

### Ebene 3: Die Blackbox (Rohdaten-Ebene)
*   **Pfad:** `/mnt/pool_fast/ServerData/monitoring/outputs/YYYY-MM/`
*   **Inhalt:** Komplette Terminal-Outputs (z.B. `apt upgrade`, Syncoid-Syncs).
*   **Zweck:** Detaillierte Fehleranalyse wenn Ebene 2 einen Fehler meldet.

---

## 3. Modul-Übersicht

Die Extension ist in drei Hauptbereiche unterteilt, erreichbar über `lpex server <modul>`.

### 3.1 Modul: `host`

Verwaltet die physischen Proxmox-Knoten.

| Submodul | Beschreibung |
|---|---|
| `status` | Zeigt Health-Status: liest standardmäßig aus der NFS-Ebene-1-Datei (`pve101_health.json`). `--live` erzwingt Live-SSH. `--all` fragt alle drei Nodes in einem Aufruf ab. |
| `control` | Power-Management: WOL (`--start`), ACPI-Shutdown (`--stop`), Neustart (`--restart`). |
| `ssh` | Direkter interaktiver SSH-Tunnel. |
| `cmd` | Ad-hoc Befehle per SSH ausführen (`--run`), als Macro speichern (`--save --alias <name>`) und per Alias aufrufen. `--list` zeigt alle gespeicherten Macros. Befehle werden via Base64 übertragen — Sonderzeichen und Anführungszeichen in Befehlen sind kein Problem. |
| `push` | Deployt Dateien vom lokalen Tree-Mirror auf den Host. `.sh`-Dateien erhalten automatisch `chmod +x`. |
| `fetch` | Zieht Dateien oder Verzeichnisse vom Host lokal herunter (Tree-Mirror). |
| `filesystem` | Smart Vault: Legt neue Dateien lokal an und sichert vorher ggf. die bestehende Remote-Version in den privaten Git-Repo. `--no-vault` überspringt den Remote-Check für bekannt-neue Dateien. |

### 3.2 Modul: `container`

Verwaltet LXC-Container innerhalb des Proxmox-Clusters.

| Submodul | Beschreibung |
|---|---|
| `cmd` | Führt Befehle via `pct exec` im Container aus. `--list` zeigt Macros. Befehle werden Base64-kodiert übertragen, um verschachtelte Quoting-Probleme zu vermeiden. |
| `control` | Start, Stop, Restart eines Containers via `pct`. |
| `ssh` | Interaktive Shell im Container via `pct enter`. |
| `push` | Deployt Dateien in den Container via `pct push`. `.sh`-Dateien erhalten automatisch `chmod +x`. |
| `fetch` | Zieht Dateien aus dem Container via Tar-Pipe (da `pct pull` keine Verzeichnisse unterstützt). |
| `filesystem` | Smart Vault mit `pct exec`-Introspection. `--no-vault` für neue Dateien. |

### 3.3 Modul: `observer`

Steuert die Observer-Pis (pi1 und pi2).

| Submodul | Beschreibung |
|---|---|
| `status` | Zeigt HA-Zustand: Leader-Rolle, ZFS-Sync-Flag, aktive Timer und Heartbeat-Alter aus NFS. `--all` zeigt pi1 + pi2 nebeneinander. |
| `control` | Graceful Shutdown (`--stop`) und Reboot (`--restart`) per SSH. Zeigt Bestätigungsfrage bei `--stop`. |
| `service` | Steuert systemd Units via sudo: `--start`, `--stop`, `--restart`, `--enable`, `--disable`. `--status` zeigt `systemctl status`-Ausgabe. |
| `logs` | Streamt Journal-Logs eines systemd-Units. `--no-follow` für Snapshot, `--lines <n>` für Anzahl, `--since <time>` für Zeitfilter. |
| `cmd` | Ad-hoc Befehle per SSH mit `--list`, `--save`, `--run`. Base64-Übertragung. |
| `push` | Deployt Dateien auf Observer. Multi-Node: `--node pi1 --node pi2`. Pfad-Kürzel: `systemd/name.service` und `scripts/pfad/script.sh`. Node-spezifische Payloads haben Vorrang vor globalem Pool. Systemd Units triggern automatisch `daemon-reload`. `.sh`-Dateien erhalten `chmod +x`. |
| `fetch` | Zieht Dateien vom Pi via sudo+Tar-Pipe (für System-Pfade). |
| `filesystem` | Smart Vault mit sudo-Introspection. `--no-vault` für neue Dateien. |
| `ssh` | Interaktiver SSH-Tunnel. |

---

## 4. Globale Helfer & Konfiguration (`extension_global.sh`)

`extension_global.sh` fungiert als Shared Library für alle Submodule.

| Funktion | Beschreibung |
|---|---|
| `enforce_config_var` | Bricht mit Fehlermeldung ab wenn eine Config-Variable fehlt |
| `get_active_host` | Gibt `$IP_ACTIVE_PVE` zurück (der aktuell primäre PVE-Server) |
| `get_observer_ip` | Mappt `pi1` / `pi2` auf die konfigurierte IP (aus `config.conf`) |
| `get_lxc_completion_cmd` | Liefert den Befehl zum Live-Laden der Container-IDs vom NFS-Cache |
| `ensure_fs_dir` | Erstellt und gibt den lokalen Tree-Mirror-Pfad zurück (`host/pve101/filesystem`, `global/observer/filesystem` etc.) |
| `init_command_db` | Erstellt die Macro-Datenbank-Tabelle wenn noch nicht vorhanden |

*   **Single Source of Truth:** Alle IPs, MACs und Pfade in `~/.local/state/lpex/data/server/config.conf`.

---

## 5. Zentrale Workflows

### 5.1 Typischer Entwicklungs-Zyklus

```
1. Datei anlegen:   lpex server observer filesystem --node pi1 --add home/fadmin/scripts/observer/myscript.sh
   → Smart Vault sichert ggf. die bestehende Remote-Version in Git
   → Öffnet nvim zur Bearbeitung

2. Deployen:        lpex server observer push --node pi1 --node pi2 --local-file scripts/observer/myscript.sh
   → Shorthand "scripts/" wird zu "home/fadmin/scripts/" expandiert
   → Deployt auf beide Pis in einem Aufruf
   → chmod +x automatisch gesetzt

3. Status prüfen:   lpex server observer service --node pi1 --name myscript.service --status
```

### 5.2 Nacht-Backup-Orchestrierung

Der Observer weckt nachts Backup-Hosts (`pve102`/`pve103`) per WOL, triggert die ZFS-Replikation auf `pve101` und schaltet die Backup-Hosts nach erfolgreichem Transfer wieder ab. Die resultierenden `pveXXX_health.json`-Dateien auf dem NFS-Share werden von `lpex server host status` direkt gelesen.

### 5.3 Schneller Cluster-Überblick

```bash
lpex server host status --all          # Alle drei PVE-Hosts aus NFS-Cache
lpex server observer status --all      # pi1 + pi2 HA-Zustand mit Heartbeat-Alter
```

---

## 6. Ownership-Garantie bei Tar-Push

Alle drei Push-Module (`host push`, `observer push`, `container push`) erstellen Tarballs mit expliziten Ownership-Flags:

| Modul | Regel | Begründung |
|---|---|---|
| `host push` | Immer `--owner=root --group=root` | `USER_PVE` ist root; alle System-Pfade müssen root gehören. sshd, sudo und andere Tools prüfen Ownership und verweigern bei falschen Werten. |
| `observer push` | `--owner=root --group=root` nur wenn `needs_sudo=1` (Systempfade: `/etc/`, `/root/` etc.) | Fadmin-Pfade (`/home/fadmin/`) werden ohne sudo als fadmin extrahiert — Ownership-Override wäre dort falsch. |
| `container push` | Immer `--owner=root --group=root` | `pct exec` läuft als root im Container; bei unprivilegierten Containern übernimmt `pct` das UID-Mapping automatisch. |

**Hintergrund:** Ohne diese Flags archiviert `tar` die lokale UID des Entwickler-Rechners (z.B. `1000 = florian`). Nach dem Entpacken auf dem Remote-System gehören Verzeichnisse wie `/`, `/root/`, `/etc/` dem falschen User — sshd verweigert dann Key-Auth (`StrictModes`), und andere privilegierte Tools schlagen fehl.

**Wichtig für den Tree-Mirror:** Verzeichnisse im lokalen Tree-Mirror, die auf dem Remote-System `700`-Permissions haben müssen (insbesondere `root/`), müssen auch lokal `700` gesetzt sein — sonst überschreibt der Push die Remote-Permissions.

```bash
# Korrekte lokale Permissions für das root/-Verzeichnis im Tree-Mirror
chmod 700 ~/.local/state/lpex/data/server/global/host/filesystem/root/
chmod 700 ~/.local/state/lpex/data/server/host/pve101/filesystem/root/
chmod 700 ~/.local/state/lpex/data/server/global/observer/filesystem/root/
```

---

## 7. Pfad-Kürzel für `observer push`

Der häufigste Einsatz von `observer push` sind Systemd-Units und Scripts. Statt des vollen Pfades können Kürzel verwendet werden:

| Eingabe | Expandiert zu |
|---|---|
| `systemd/obs-heartbeat.service` | `etc/systemd/system/obs-heartbeat.service` |
| `scripts/observer/obs-heartbeat.sh` | `home/fadmin/scripts/observer/obs-heartbeat.sh` |
| `scripts/homelab.conf` | `home/fadmin/scripts/homelab.conf` |

Systemd-Units triggern automatisch `systemctl daemon-reload` nach dem Deploy.

---

*Dokumentation aktualisiert: 2026-04-13.*
