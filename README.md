# The Self-Reporting Linux Server

![OS](https://img.shields.io/badge/Rocky%20%7C%20Alma%20%7C%20RHEL-9-10B981)
![Bash](https://img.shields.io/badge/Bash-scripts-4EAA25?logo=gnubash&logoColor=white)
![SELinux](https://img.shields.io/badge/SELinux-Enforcing-CC0000)

One command turns a fresh **Rocky Linux / AlmaLinux / RHEL 9** machine into a web server that **reports on its own health** over HTTPS every minute, keeps a JSON copy of every report on its own disk, and archives them every 10 minutes. Every package comes from the server's **own signed private repository**, and nobody has to log in to fix anything by hand.

## Quick start

```bash
sudo dnf install -y git
git clone https://github.com/laith-iyad/linux-server-project.git
cd linux-server-project
sudo ./run.sh
```

Then open **`https://<server-ip>/`** in a browser. The certificate is self-signed, so the browser shows a warning the first time.

> [!NOTE]
> **Needs:** Rocky, AlmaLinux or RHEL 9 · `sudo` · internet on the first run (to fill the private repo) · about 2 GB of free disk space.
> `run.sh` is **safe to run again** at any time.

## What you get

- 📊 **A status page** at `https://<server-ip>/`, which rebuilds every minute and refreshes itself every 60 s
- 📦 **The private package repo** at `https://<server-ip>/repo/`
- 🧾 **A JSON report every minute** on its own disk → `/mnt/metrics`
- 🗄️ **A compressed, checksummed archive every 10 minutes** on a second disk → `/backup` (the last 48 = 8 hours)
- ✅ **`sudo ./verify.sh`**, a PASS / FAIL health check of the whole server

---

## How it works

### `run.sh`: one command, six steps

```mermaid
flowchart TD
  U["sudo ./run.sh"] --> R{"running as root?"}
  R -->|"no"| X["Please run as root, exit 1"]
  R -->|"yes"| L["everything is shown on screen<br/>and saved to install.log"]
  L --> S1["1 · setup_private_repo.sh"] --> S2["2 · install_apache.sh"] --> S3["3 · configure_https.sh"]
  S3 --> S4["4 · mount_disks.sh"] --> S5["5 · setup_crons.sh"] --> S6["6 · verify.sh"]
  S6 --> OK["Site ready: https://server-ip/"]
  S1 & S2 & S3 & S4 & S5 & S6 -.->|"a step fails"| E["ERROR: step failed, exit 1"]
```

| Step | Script | What it does |
|---|---|---|
| 1 | `setup_private_repo.sh` | Downloads every package + its dependencies into `/var/www/repo`, builds the index, checks signatures with the distribution's GPG key, then **disables every other repo** |
| 2 | `install_apache.sh` | Installs Apache from the private repo and runs its workers as the small system user `webreport` |
| 3 | `configure_https.sh` | Self-signed certificate (renewed only when needed), HTTP → HTTPS redirect, `/repo/` published, firewall opened for web only |
| 4 | `mount_disks.sh` | Creates two image-file disks (512 MB metrics, 1 GB backup), formats them with XFS, and mounts them through `/etc/fstab` |
| 5 | `setup_crons.sh` | Installs the report and archive jobs as `webreport` in `/etc/cron.d`, with log rotation |
| 6 | `verify.sh` | Checks everything and prints PASS / FAIL; exits with an error if anything fails |

### How the steps feed each other

```mermaid
flowchart LR
  S1["1 · Private repo"] -->|"httpd, mod_ssl"| S2["2 · Apache"]
  S1 -->|"served at /repo/"| S3["3 · HTTPS"]
  S1 -->|"jq, cronie, logrotate"| S5["5 · Reports + cron"]
  S2 -->|"web server + webreport user"| S3
  S3 -->|"HTTPS site"| S5
  S4["4 · Disks"] -->|"/mnt/metrics, /backup"| S5
  S5 -->|"page, JSON, archives"| S6["6 · Verify"]
```

All settings live in **`config.sh`**, which every script loads, so no path or IP address is typed into the scripts themselves.

---

## Behind the scenes

### Every minute and every 10 minutes

```mermaid
sequenceDiagram
  participant C as crond
  participant G as generate_report.sh
  participant A as archive_reports.sh
  participant M as /mnt/metrics
  participant B as /backup
  participant W as index.html
  C->>G: every minute, as webreport
  G->>M: new report_TIME.json
  G->>W: new status page (temp file, then mv)
  C->>A: every 10 minutes, as webreport
  A->>M: pack all JSON reports
  A->>B: reports_DATE.tar.gz + .sha256
  A->>M: delete only the reports that were packed
  A->>B: keep the newest 48 archives
  Note over C: all job output goes to cron.log (rotated daily, 7 kept)
```

### The life of one report

```mermaid
flowchart LR
  D["server data<br/>CPU, memory, disks,<br/>ports, services"] -->|"every minute"| J["report_TIME.json<br/>/mnt/metrics"]
  J -->|"every 10 min"| T["reports_DATE.tar.gz<br/>+ .sha256 in /backup"]
  T -->|"after 48 newer archives"| X["deleted"]
  D -->|"every minute"| P["index.html<br/>status page"]
```

### What happens when someone opens the site

```mermaid
sequenceDiagram
  participant B as Browser
  participant F as firewalld
  participant A as Apache
  participant S as SELinux
  B->>F: http://server-ip/ on port 80
  F->>A: allowed (service http)
  A-->>B: 301, go to https
  B->>F: https on port 443
  F->>A: allowed (service https)
  A->>A: TLS with the server certificate
  A->>S: worker (httpd_t) wants to read index.html
  S-->>A: allowed (httpd_sys_content_t)
  A-->>B: 200 + status page
```

### After a reboot

Nothing has to be fixed by hand. Everything comes back by itself:

```mermaid
flowchart LR
  B["boot"] --> SD["systemd"]
  SD --> F["fstab mounts both disks"]
  SD --> T["tmpfiles fixes the web root owner"]
  SD --> H["httpd · firewalld · crond start (enabled)"]
  H --> J["jobs continue every 1 / 10 min"]
```

---

## Security

- **Signed packages only:** `gpgcheck=1` with the distribution's key, and `private-local` is the only enabled repo
- **Least privilege:** Apache workers and both jobs run as `webreport` (no password, no login shell); the job scripts in `/opt` are owned by root, so `webreport` can run them but not change them
- **SELinux stays Enforcing:** wrong labels are fixed with `restorecon`, never by turning SELinux off
- **firewalld stays on:** only `http` and `https` are opened
- **HTTPS:** RSA 2048 key with mode `600`; the certificate covers the hostname **and** the IP; Apache's version is hidden; directory listing is off except for `/repo/`
- **Private data:** both disks are mode `750`, owned by `webreport`; `cron.log` is mode `640`

Every file has to pass **two locks**:

```mermaid
flowchart LR
  P["a program wants a file"] --> L1{"Linux permissions<br/>rwx"}
  L1 -->|"no"| N["Permission denied"]
  L1 -->|"yes"| L2{"SELinux label<br/>allowed for this program?"}
  L2 -->|"no"| N
  L2 -->|"yes"| Y["access granted"]
```

---

## Safe to run again

Every step checks before it changes anything:

- packages already in the repo are skipped, and the official repos are switched on **only for the download**
- a new certificate is made only if one is missing, expires within 30 days, or the IP changed
- a disk that already has a filesystem is **never reformatted**
- an `fstab` line, a firewall rule or a user is added only if it's missing
- the cron and logrotate files are rewritten, so there are never duplicate jobs

## Configuration

Everything is in **`config.sh`**. Some useful settings:

```bash
PACKAGES=(httpd mod_ssl jq cronie logrotate)   # what the private repo holds
REPORT_SCHEDULE="* * * * *"                    # report: every minute
ARCHIVE_SCHEDULE="*/10 * * * *"                # archive: every 10 minutes
ARCHIVE_KEEP=48                                # archives to keep (8 hours)
METRICS_SIZE="512M"; BACKUP_SIZE="1G"          # disk sizes
VALID_DAYS=365; RENEW_DAYS=30                  # certificate life / renew window
REFRESH_SEC=60                                 # page auto-refresh
```

## Checking the server

```bash
sudo ./verify.sh
```

```text
PASS  only private-local is enabled
PASS  httpd installed from private-local
PASS  httpd enabled and running
...
PASS  newest archive exists and checksum matches
PASS  SELinux is Enforcing
Site ready: https://<server-ip>/
```

<details>
<summary><b>All 17 checks</b></summary>

- only `private-local` is enabled, and `httpd` was installed from it
- `httpd`, `firewalld` and `crond` are enabled and running
- Apache workers run as `webreport`
- `https://<host>/` returns 200 without `-k` · `http://<host>/` returns 301 · `/repo/repodata/repomd.xml` returns 200
- both disks are mounted and listed in `/etc/fstab`, and `findmnt --verify` passes
- `index.html` was updated in the last 3 minutes
- the newest archive exists and its checksum matches
- SELinux is Enforcing

</details>

<details>
<summary><b>Example JSON report</b></summary>

```json
{
  "time": "2026-11-24 18:15:01",
  "hostname": "project-dev",
  "os": "Rocky Linux 9.8 (Blue Onyx)",
  "load_average": "0.05 0.03 0.01",
  "cpu_percent": 1,
  "memory_percent": 34,
  "disk_percent": { "root": 18, "metrics": 7, "backup": 5 },
  "logged_in_users": 1,
  "listening_ports": [22, 80, 443, 9090],
  "top_processes": ["gnome-shell (5.6%)", "httpd (1.5%)"],
  "services": { "httpd": "active", "crond": "active", "firewalld": "active" },
  "archives": { "count": 12, "newest": "reports_2026-11-24_181000.tar.gz" }
}
```

</details>

<details>
<summary><b>Where things live on the server</b></summary>

- private repo → `/var/www/repo` · repo file → `/etc/yum.repos.d/private-local.repo`
- site config → `/etc/httpd/conf.d/linux-server-project.conf` · page → `/var/www/html/index.html`
- certificate → `/etc/pki/tls/certs/apache.crt` · key → `/etc/pki/tls/private/apache.key`
- disk images → `/var/lib/linux-server-project/` · mounted on `/mnt/metrics` and `/backup`
- jobs → `/opt/linux-server-project/` · cron → `/etc/cron.d/linux-server-project`
- logs → `/var/log/linux-server-project/install.log` and `cron.log`

</details>

## Troubleshooting

```bash
sudo tail -n 40 /var/log/linux-server-project/install.log    # what run.sh did
sudo tail -n 20 /var/log/linux-server-project/cron.log       # the jobs' output
sudo tail -n 20 /var/log/httpd/linux-server-project_error.log
sudo ausearch -m avc -ts recent                              # SELinux blocks
sudo ./verify.sh                                             # what is failing
```

## Repository layout

```text
.
├── README.md
├── run.sh                  # runs steps 1-6, logs to install.log
├── config.sh               # every setting + shared functions
├── setup_private_repo.sh   # step 1
├── install_apache.sh       # step 2
├── configure_https.sh      # step 3
├── mount_disks.sh          # step 4
├── setup_crons.sh          # step 5
├── generate_report.sh      # cron job: every minute
├── archive_reports.sh      # cron job: every 10 minutes
└── verify.sh               # step 6
```

## Red Hat family notes

- The GPG key is chosen automatically from `ID` in `/etc/os-release` (Rocky, AlmaLinux or RHEL); other systems stop with a clear message.
- The names of the official repos are saved on the first run, so re-runs can download again after those repos are disabled.
- On a subscribed RHEL machine, `subscription-manager` manages `redhat.repo` and may switch repos back on.

---

*LFS101 final project by Laith (Abu Iyad).*
