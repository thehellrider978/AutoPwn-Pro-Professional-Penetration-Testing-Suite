<div align="center">

```
  __HACKEROFHELL_        _        ____                 _RAJESH BAJIYA___  ____   ___
 / _ \ _   _| |_ ___ |  _ \__      ___ __ |  _ \|  _ \ / _ \
| | | | | | | __/ _ \| |_) \ \ /\ / / '_ \| |_) | |_) | | | |
| |_| | |_| | || (_) |  __/ \ V  V /| | | |  __/|  _ <| |_| |
 \___/ \__,_|\__\___/|_|     \_/\_/ |_| |_|_|   |_| \_\\___/
```

# AutoPwn Pro — Professional Penetration Testing Suite

**Automated bug bounty & pentest framework for Kali Linux**  
Full recon → enumeration → vulnerability scanning → PoC verification → HTML report

[![Kali Linux](https://img.shields.io/badge/Platform-Kali%20Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![For Educational Use](https://img.shields.io/badge/Use-Educational%20%2F%20Authorized%20Only-red?style=flat-square)]()

</div>

---

## ⚠️ Legal Disclaimer

> **AutoPwn Pro is for authorized penetration testing and bug bounty hunting ONLY BY RAJESH BAJIYA.**  
> Only run this tool against systems you own or have **explicit written permission** to test.  
> Unauthorized scanning is illegal under the Computer Fraud and Abuse Act (CFAA) and similar laws worldwide.  
> The author is not responsible for any misuse of this tool.

---

## 📋 Table of Contents

- [What is AutoPwn Pro?](#-what-is-autopwn-pro)
- [Features](#-features)
- [Tool Architecture](#-tool-architecture)
- [Files in This Project](#-files-in-this-project)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
  - [Terminal Mode](#1-terminal-mode-script-only)
  - [GUI Mode](#2-gui-mode-recommended)
- [Scan Phases Explained](#-scan-phases-explained)
- [What Bugs It Finds](#-what-bugs-it-finds)
- [Output Structure](#-output-structure)
- [Reading the Report](#-reading-the-html-report)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🔍 What is AutoPwn Pro?

AutoPwn Pro is a **fully automated penetration testing framework** built for Kali Linux. It chains together 15+ industry-standard tools into a single workflow — from passive reconnaissance all the way to a professional HTML report with CVSS-scored findings, evidence, and PoC commands.

It is designed for:
- 🎯 **Bug bounty hunters** targeting in-scope web applications
- 🔐 **Penetration testers** needing fast, repeatable recon + vuln discovery
- 🎓 **Security students** learning the full pentest methodology

**Key principle: Only confirmed vulnerabilities appear in the report.** No false positives, no noise.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🤖 **Fully Automated** | One command runs the entire 6-phase workflow |
| 🖥️ **Python GUI** | Tkinter desktop UI — no terminal knowledge needed |
| 📊 **Live Output** | Watch findings appear in real time |
| 📄 **HTML Report** | Professional pentest report auto-generated |
| 🎯 **Confirmed Only** | Only verified vulnerabilities saved — zero noise |
| 🔢 **CVSS Scoring** | Every finding has a CVSS score (1–10) |
| 💡 **PoC Commands** | Copy-paste curl/exploit commands for every bug |
| 🔧 **Remediation** | Fix instructions included for every finding |
| 🔀 **Modular** | Toggle any module on/off before scanning |
| 📁 **Organized Output** | Results saved in structured folders |

---

## 🏗️ Tool Architecture

```
autopwn_pro.sh          ← Main bash script (the engine)
autopwn_gui.py          ← Python GUI launcher (the interface)
pentest_report.html     ← Report template / preview

FLOW:
┌─────────────────────────────────────────────────────────────┐
│  GUI (autopwn_gui.py)                                       │
│   Enter target → Click Start → Watch live output           │
│   ↓                                                         │
│  Script (autopwn_pro.sh)                                    │
│   Phase 1: Recon → Phase 2: Enum → Phase 3: Crawl          │
│   Phase 4: Vuln Scan → Phase 5: Verify → Phase 6: Report   │
│   ↓                                                         │
│  Output (~/pentests/target.com/)                            │
│   findings.json → pentest_report_target.html                │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Files in This Project

```
autopwn-pro/
├── autopwn_pro.sh          ← Main scanner script
├── autopwn_gui.py          ← Desktop GUI (Python/Tkinter)
├── pentest_report.html     ← Report preview / template
└── README.md               ← This file
```

---

## 📦 Requirements

### Operating System
- **Kali Linux** (2023.x or newer) — recommended
- Any Debian-based Linux with security tools installed

### Python
- Python 3.8+
- `python3-tk` for the GUI

### Tools Required

| Tool | Type | Install Method |
|---|---|---|
| `nmap` | Port scanner | `apt` |
| `gobuster` | Directory brute force | `apt` |
| `ffuf` | Web fuzzer | `apt` |
| `sqlmap` | SQL injection | `apt` |
| `whatweb` | Tech fingerprint | `apt` |
| `wafw00f` | WAF detection | `apt` |
| `wpscan` | WordPress scanner | `apt` |
| `seclists` | Wordlists | `apt` |
| `subfinder` | Subdomain enum | `go install` |
| `amass` | Subdomain enum | `go install` |
| `dnsx` | DNS resolver | `go install` |
| `httpx` | HTTP prober | `go install` |
| `nuclei` | Vuln scanner | `go install` |
| `dalfox` | XSS scanner | `go install` |
| `gau` | URL collector | `go install` |
| `waybackurls` | Wayback URLs | `go install` |
| `getJS` | JS file extractor | `go install` |

---

## 🚀 Installation

### Step 1 — Clone the Repository

```bash
git clone https://github.com/thehellrider978/AutoPwn-Pro-Professional-Penetration-Testing-Suite.git
```

### Step 2 — Make Script Executable

```bash
chmod +x autopwn_pro.sh
```

### Step 3 — Install APT Tools

```bash
sudo apt update && sudo apt install -y \
  nmap gobuster ffuf sqlmap \
  whatweb wafw00f wpscan \
  seclists python3-tk \
  curl wget python3 tmux
```

### Step 4 — Install Go Tools

> Make sure Go is installed first: `go version`  
> If not: `sudo apt install golang -y`

```bash
# Install all Go-based tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/owasp-amass/amass/v4/...@master
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/hahwul/dalfox/v2@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/tomnomnom/getJS@latest
```

### Step 5 — Add Go to PATH

```bash
# Add to PATH permanently
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify tools are accessible
which subfinder httpx nuclei dalfox
```

### Step 6 — Update Nuclei Templates

```bash
nuclei -update-templates
```

### Step 7 — Verify Installation

```bash
# Check all tools are installed
for tool in nmap gobuster ffuf sqlmap subfinder dnsx httpx nuclei dalfox gau waybackurls; do
  if command -v $tool &> /dev/null; then
    echo "[✓] $tool"
  else
    echo "[✗] $tool — NOT FOUND"
  fi
done
```

---

## 🎮 Usage

### 1. Terminal Mode (Script Only)

**Basic scan:**
```bash
sudo ./autopwn_pro.sh target.com
```

**Scan with custom output directory:**
```bash
sudo ./autopwn_pro.sh target.com ~/my-pentests
```

**Open the generated report:**
```bash
firefox ~/pentests/target.com/06_report/pentest_report_target.com.html
```

**Watch scan live in split terminal (tmux):**
```bash
# Install tmux
sudo apt install tmux -y

# Start split session
tmux new-session -d -s autopwn
tmux split-window -h -t autopwn
tmux send-keys -t autopwn:0.0 'sudo ./autopwn_pro.sh target.com' Enter
tmux send-keys -t autopwn:0.1 'watch -n 2 "ls -lh ~/pentests/target.com/**/"' Enter
tmux attach -t autopwn
```

**Find report after scan:**
```bash
find ~/pentests -name "*.html" 2>/dev/null
```

---

### 2. GUI Mode (Recommended)

**Launch the GUI:**
```bash
python3 autopwn_gui.py
```

**The GUI window has:**

```
┌────────────────────────────────────────────────────────────┐
│  LEFT PANEL                │  RIGHT PANEL (3 tabs)         │
│                            │                               │
│  Target Domain: [______]   │  [LIVE OUTPUT] [FINDINGS]     │
│  Output Dir:   [______]    │               [PHASES]        │
│  Script Path:  [______]    │                               │
│                            │  Tab 1: Real-time terminal    │
│  Intensity:                │  Tab 2: Confirmed bugs only   │
│  ○ Stealth                 │  Tab 3: Phase progress        │
│  ● Normal                  │                               │
│  ○ Aggressive              │                               │
│                            │                               │
│  Modules: [checkboxes]     │                               │
│                            │                               │
│  [▶ START SCAN]            │                               │
│  [■ STOP SCAN ]            │                               │
│  [📄 OPEN REPORT]          │                               │
└────────────────────────────────────────────────────────────┘
```

**Step by step:**

1. Type your target domain (e.g. `target.com`) in the **Target Domain** box
2. Set your **Output Directory** (default: `~/pentests`)
3. Make sure **Script Path** points to `autopwn_pro.sh`
4. Choose **scan intensity**
5. Toggle **modules** on/off as needed
6. Click **▶ START SCAN**
7. Watch live output in the **LIVE OUTPUT** tab
8. Switch to **FINDINGS** tab to see confirmed bugs as they appear
9. Switch to **PHASES** tab to see overall progress
10. When complete, click **📄 OPEN REPORT** to open the HTML report in Firefox

---

## 🔄 Scan Phases Explained

### Phase 1 — Passive Reconnaissance
```bash
# What runs internally:
subfinder -d target.com -silent -all
amass enum -passive -d target.com
dnsx -l subs.txt -a -cname -resp
gau target.com --threads 5
waybackurls target.com
whois target.com
```
**What it finds:** Subdomains, DNS records, CNAME chains, historical URLs, IP info, ASN

---

### Phase 2 — Active Enumeration
```bash
# What runs internally:
nmap -sS -T3 -sV -sC --open -p 21,22,80,443,3306,6379,8080,8443,27017 target.com
httpx -l subs.txt -title -tech-detect -status-code
wafw00f https://target.com
whatweb https://target.com
```
**What it finds:** Open ports, services, software versions, WAF type, technology stack

---

### Phase 3 — Crawl & Directory Discovery
```bash
# What runs internally:
gobuster dir -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt
gobuster dir -u https://target.com -w /usr/share/seclists/Discovery/Web-Content/AdminPanels.txt
ffuf -u https://target.com:8080/FUZZ -w wordlist.txt -mc 200,301,302,403
getJS --url https://target.com
```
**What it finds:** Hidden directories, admin panels, JavaScript files, API endpoints, backup files

---

### Phase 4 — Automated Vulnerability Scanning
```bash
# What runs internally:
nuclei -l live_urls.txt \
  -t ~/nuclei-templates/cves/ \
  -t ~/nuclei-templates/vulnerabilities/ \
  -t ~/nuclei-templates/exposures/ \
  -t ~/nuclei-templates/misconfiguration/ \
  -severity critical,high,medium \
  -rate-limit 150
```
**What it finds:** Known CVEs, exposed services, misconfigurations, default credentials, info leaks

---

### Phase 5 — Targeted Vulnerability Verification

All findings are **manually verified** before saving — no false positives.

```bash
# XSS Testing
dalfox file param_urls.txt --skip-bav --no-spinner

# SQL Injection
sqlmap -m param_urls.txt --batch --level=2 --risk=2

# CORS Check
curl -H "Origin: https://test-origin.com" https://target.com/api -I

# Open Redirect
curl -Lv "https://target.com/login?returnUrl=https://test.com"

# 403 Bypass
curl -H "X-Original-URL: /admin" https://target.com/
curl -H "X-Forwarded-For: 127.0.0.1" https://target.com/admin

# Sensitive Files
curl -sk https://target.com/.env
curl -sk https://target.com/.git/config
```

---

### Phase 6 — Report Generation

Automatically generates a professional HTML report containing:
- Executive summary with finding counts
- Every confirmed vulnerability with CVSS score
- Evidence for each finding
- PoC (Proof of Concept) commands
- Remediation recommendations
- Sorted by severity (Critical → High → Medium → Low)

---

## 🐛 What Bugs It Finds

| Vulnerability | Severity | CVSS | Detection Method |
|---|---|---|---|
| SQL Injection | 🔴 Critical | 9.8 | sqlmap |
| Hardcoded Secrets in JS | 🔴 Critical | 9.1 | Custom regex |
| Remote Code Execution | 🔴 Critical | 9.5 | Nuclei CVE templates |
| Subdomain Takeover | 🟠 High | 8.1 | dnsx + curl |
| Cross-Site Scripting (XSS) | 🟠 High | 7.4 | dalfox |
| CORS Misconfiguration | 🟠 High | 7.5 | curl |
| Exposed Admin Panels | 🟠 High | 7.2 | gobuster |
| Default Credentials | 🟠 High | 8.0 | Nuclei templates |
| Unauthenticated API Access | 🟠 High | 8.2 | curl |
| Open Redirect | 🟡 Medium | 6.1 | curl |
| Sensitive File Exposure (.env, .git) | 🟡 Medium | 5.3–9.1 | curl |
| SSRF | 🟡 Medium | 7.5 | Nuclei |
| Directory Traversal / LFI | 🟡 Medium | 6.5 | Nuclei |
| 403 Access Control Bypass | 🟡 Medium | 6.8 | curl |
| Exposed Services (Redis, MongoDB) | 🟠 High | 7.5 | nmap |
| Missing Security Headers | 🟢 Low | 4.3 | curl |
| Information Disclosure | 🟡 Medium | 5.3 | Nuclei |

---

## 📂 Output Structure

After a scan, your results are saved here:

```
~/pentests/target.com/
│
├── 01_recon/
│   ├── all_subs.txt          ← All discovered subdomains
│   ├── dns_resolved.txt      ← DNS resolution results
│   ├── gau_urls.txt          ← Historical URLs
│   └── whois.txt             ← WHOIS data
│
├── 02_enum/
│   ├── nmap_targeted.txt     ← Nmap port scan results
│   ├── live_hosts.txt        ← Live subdomains with titles
│   ├── live_urls.txt         ← Clean list of live URLs
│   ├── waf.txt               ← WAF detection results
│   └── whatweb.txt           ← Technology fingerprint
│
├── 03_crawl/
│   ├── admin_panels_found.txt ← Discovered admin paths
│   ├── dirs_found.txt         ← Accessible directories
│   ├── js_files.txt           ← JavaScript files found
│   └── param_urls.txt         ← URLs with parameters
│
├── 04_vuln/
│   └── nuclei_results.jsonl  ← Raw nuclei findings
│
├── 05_poc/
│   ├── xss_dalfox.json       ← Confirmed XSS findings
│   ├── sqlmap/               ← SQLmap results folder
│   ├── 403_bypass.txt        ← Successful bypasses
│   ├── js_secrets.txt        ← Hardcoded secrets found
│   └── subdomain_takeover.txt ← Takeover candidates
│
├── 06_report/
│   └── pentest_report_target.com.html  ← ⭐ OPEN THIS
│
├── findings.json             ← All findings in JSON format
└── autopwn.log               ← Full scan log
```

---

## 📊 Reading the HTML Report

Open the report in Firefox:
```bash
firefox ~/pentests/target.com/06_report/pentest_report_target.com.html
```

The report has:

```
┌─────────────────────────────────────────────────┐
│  PENETRATION TEST REPORT — target.com           │
│  Date: 2024-XX-XX | Method: Automated           │
│                              Critical/High: [N] │
├─────────────────────────────────────────────────┤
│  Findings by Severity  │  Scan Statistics       │
│  CRITICAL ████ 2       │  Total: 9              │
│  HIGH     ███  4       │  Critical: 2           │
│  MEDIUM   ██   2       │  High: 4               │
│  LOW      █    1       │  Medium: 2             │
├─────────────────────────────────────────────────┤
│  [CRITICAL] CVSS 9.8 — SQL Injection     ▼      │
│  ┌─────────────────────────────────────────┐   │
│  │ URL: https://target.com/api/login       │   │
│  │ Parameter: username                     │   │
│  │ Evidence: Blind time-based confirmed    │   │
│  │ PoC: sqlmap -u '...' --dbs --batch      │   │
│  │ Fix: Use prepared statements            │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

Click any finding to expand it and see full details.

---

## 🔧 Troubleshooting

### Script not found
```bash
# Make sure script is in the right place
ls ~/autopwn/autopwn_pro.sh

# If missing, move it there
mkdir -p ~/autopwn
mv autopwn_pro.sh ~/autopwn/
chmod +x ~/autopwn/autopwn_pro.sh
```

### Permission denied
```bash
chmod +x autopwn_pro.sh
sudo ./autopwn_pro.sh target.com
```

### Go tools not found after install
```bash
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc
which subfinder  # should print a path now
```

### GUI won't open
```bash
sudo apt install python3-tk -y
python3 autopwn_gui.py
```

### Nuclei templates missing
```bash
nuclei -update-templates
```

### Report not found after scan
```bash
# Find it automatically
find ~/ -name "pentest_report_*.html" 2>/dev/null

# Or check scan log for errors
cat ~/pentests/target.com/autopwn.log | tail -50
```

### Scan runs but finds nothing
```bash
# Check if target is reachable
ping target.com
curl -sk https://target.com | head -20

# Try running individual tools manually
subfinder -d target.com
nmap -sV target.com
```

---

## 🛠️ Manual Commands Reference

If you want to run individual phases manually:

```bash
# Subdomain enumeration
subfinder -d target.com -silent -o subs.txt
amass enum -passive -d target.com

# DNS resolution
dnsx -l subs.txt -a -cname -resp

# Probe live hosts
httpx -l subs.txt -title -tech-detect -status-code

# Port scan
nmap -sS -T3 -sV -sC --open -oN nmap.txt target.com

# Directory brute force
gobuster dir -u https://target.com \
  -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt

# Admin panel hunt
gobuster dir -u https://target.com \
  -w /usr/share/seclists/Discovery/Web-Content/AdminPanels.txt

# Nuclei vulnerability scan
nuclei -u https://target.com -severity critical,high,medium

# XSS testing
dalfox url "https://target.com/search?q=test"

# SQL injection
sqlmap -u "https://target.com/login" --data "user=a&pass=b" --batch

# Check sensitive files
for f in /.env /.git/config /phpinfo.php /wp-config.php; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" https://target.com$f)
  echo "$code — $f"
done

# CORS check
curl -H "Origin: https://test.com" https://target.com/api -I | grep -i access-control

# Security headers check
curl -sk -I https://target.com | grep -iE "strict|csp|x-frame|x-content|referrer"

# Open the report
firefox ~/pentests/target.com/06_report/pentest_report_target.com.html
```

---

## 🤝 Contributing

Pull requests are welcome! To contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-module`
3. Add your changes
4. Test on Kali Linux
5. Submit a pull request

**Ideas for contributions:**
- New vulnerability check modules
- Additional report formats (PDF, Markdown)
- Docker support
- CI/CD integration
- More nuclei template categories

---

## 📜 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

## ⭐ Star this repo if it helped you!

<div align="center">

**Built for the security community — use responsibly.**

`recon` • `enumeration` • `vulnerability-scanning` • `bug-bounty` • `penetration-testing` • `kali-linux` • `automated`

</div>
