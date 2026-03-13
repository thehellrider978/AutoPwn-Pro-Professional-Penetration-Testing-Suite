#!/usr/bin/env python3
"""
AutoPwn Pro — GUI Launcher
Run: python3 autopwn_gui.py
Requires: python3-tk (sudo apt install python3-tk)
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import subprocess
import threading
import os
import json
import time
import signal
from datetime import datetime
from pathlib import Path

# ── THEME COLORS ─────────────────────────────────────────────────────
BG        = "#07090d"
SURFACE   = "#0d1117"
SURFACE2  = "#161b22"
BORDER    = "#21262d"
TEXT      = "#e6edf3"
MUTED     = "#8b949e"
ACCENT    = "#58a6ff"
CRIT      = "#ff2d55"
HIGH      = "#ff6b35"
MED       = "#ffd60a"
LOW       = "#30d158"
GREEN     = "#39ff14"
PURPLE    = "#bf5af2"

FONT_MONO = ("Courier New", 10)
FONT_MONO_SM = ("Courier New", 9)
FONT_MONO_LG = ("Courier New", 13, "bold")
FONT_UI   = ("Courier New", 10)
FONT_TITLE= ("Courier New", 18, "bold")
FONT_HEAD = ("Courier New", 11, "bold")

class AutoPwnGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("AutoPwn Pro — Penetration Testing Suite")
        self.root.geometry("1100x750")
        self.root.minsize(900, 600)
        self.root.configure(bg=BG)

        self.process = None
        self.scan_running = False
        self.start_time = None
        self.findings_count = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
        self.timer_id = None

        self._build_ui()
        self._animate_title()

    # ── BUILD UI ──────────────────────────────────────────────────────
    def _build_ui(self):
        # TOP TITLE BAR
        title_frame = tk.Frame(self.root, bg=SURFACE, height=60)
        title_frame.pack(fill=tk.X, side=tk.TOP)
        title_frame.pack_propagate(False)

        self.title_label = tk.Label(
            title_frame, text="⚡ AUTOPWN PRO",
            font=FONT_TITLE, fg=ACCENT, bg=SURFACE
        )
        self.title_label.pack(side=tk.LEFT, padx=20, pady=10)

        tk.Label(
            title_frame, text="Professional Penetration Testing Suite",
            font=FONT_MONO_SM, fg=MUTED, bg=SURFACE
        ).pack(side=tk.LEFT, padx=5, pady=10)

        # Clock
        self.clock_label = tk.Label(
            title_frame, text="", font=FONT_MONO_SM, fg=MUTED, bg=SURFACE
        )
        self.clock_label.pack(side=tk.RIGHT, padx=20)
        self._update_clock()

        # Status dot
        self.status_dot = tk.Label(
            title_frame, text="●", font=("Courier New", 14), fg=BORDER, bg=SURFACE
        )
        self.status_dot.pack(side=tk.RIGHT, padx=5)

        tk.Label(
            title_frame, text="STATUS:", font=FONT_MONO_SM, fg=MUTED, bg=SURFACE
        ).pack(side=tk.RIGHT)

        # SEPARATOR
        tk.Frame(self.root, bg=BORDER, height=1).pack(fill=tk.X)

        # MAIN LAYOUT
        main = tk.Frame(self.root, bg=BG)
        main.pack(fill=tk.BOTH, expand=True, padx=0, pady=0)

        # LEFT PANEL (controls)
        left = tk.Frame(main, bg=SURFACE, width=300)
        left.pack(side=tk.LEFT, fill=tk.Y)
        left.pack_propagate(False)
        tk.Frame(main, bg=BORDER, width=1).pack(side=tk.LEFT, fill=tk.Y)

        # RIGHT PANEL (output)
        right = tk.Frame(main, bg=BG)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self._build_left(left)
        self._build_right(right)

    def _build_left(self, parent):
        # ── TARGET CONFIG ──
        self._section_label(parent, "TARGET CONFIGURATION")

        # Target domain
        self._field_label(parent, "TARGET DOMAIN")
        self.target_var = tk.StringVar(value="")
        target_entry = tk.Entry(
            parent, textvariable=self.target_var,
            font=FONT_MONO, bg=BG, fg=GREEN,
            insertbackground=GREEN, relief=tk.FLAT,
            bd=0, highlightthickness=1,
            highlightcolor=ACCENT, highlightbackground=BORDER
        )
        target_entry.pack(fill=tk.X, padx=12, pady=(0, 10), ipady=6)

        # Output directory
        self._field_label(parent, "OUTPUT DIRECTORY")
        out_frame = tk.Frame(parent, bg=SURFACE)
        out_frame.pack(fill=tk.X, padx=12, pady=(0, 10))

        self.outdir_var = tk.StringVar(value=str(Path.home() / "pentests"))
        out_entry = tk.Entry(
            out_frame, textvariable=self.outdir_var,
            font=FONT_MONO_SM, bg=BG, fg=TEXT,
            insertbackground=TEXT, relief=tk.FLAT,
            bd=0, highlightthickness=1,
            highlightcolor=ACCENT, highlightbackground=BORDER
        )
        out_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=5)

        browse_btn = tk.Button(
            out_frame, text="...", font=FONT_MONO_SM,
            bg=BORDER, fg=TEXT, relief=tk.FLAT,
            bd=0, padx=8, cursor="hand2",
            command=self._browse_dir
        )
        browse_btn.pack(side=tk.RIGHT, padx=(4, 0), ipady=5)

        # Script path
        self._field_label(parent, "SCRIPT PATH")
        self.script_var = tk.StringVar(value=str(Path.home() / "autopwn/autopwn_pro.sh"))
        script_entry = tk.Entry(
            parent, textvariable=self.script_var,
            font=FONT_MONO_SM, bg=BG, fg=TEXT,
            insertbackground=TEXT, relief=tk.FLAT,
            bd=0, highlightthickness=1,
            highlightcolor=ACCENT, highlightbackground=BORDER
        )
        script_entry.pack(fill=tk.X, padx=12, pady=(0, 12), ipady=5)

        # ── SCAN INTENSITY ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill=tk.X, padx=12, pady=4)
        self._section_label(parent, "SCAN INTENSITY")

        self.intensity_var = tk.StringVar(value="normal")
        intensities = [
            ("STEALTH  — Slow, low noise", "stealth"),
            ("NORMAL   — Balanced (rec.)", "normal"),
            ("AGGRESSIVE — Fast, thorough", "aggressive"),
        ]
        for txt, val in intensities:
            rb = tk.Radiobutton(
                parent, text=txt,
                variable=self.intensity_var, value=val,
                font=FONT_MONO_SM, fg=TEXT, bg=SURFACE,
                selectcolor=BG, activebackground=SURFACE,
                activeforeground=ACCENT,
                indicatoron=True, bd=0
            )
            rb.pack(anchor=tk.W, padx=16, pady=1)

        # ── MODULES ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill=tk.X, padx=12, pady=8)
        self._section_label(parent, "MODULES")

        self.module_vars = {}
        modules = [
            ("Subfinder + Amass", "recon", True),
            ("Nmap Port Scan",    "nmap",  True),
            ("Gobuster Dirs",     "dirs",  True),
            ("Admin Panel Hunt",  "admin", True),
            ("Nuclei CVE Scan",   "nuclei",True),
            ("SQLi (sqlmap)",     "sqli",  True),
            ("XSS (dalfox)",      "xss",   True),
            ("CORS Check",        "cors",  True),
            ("JS Secret Mining",  "js",    True),
            ("Sensitive Files",   "files", True),
        ]
        mod_frame = tk.Frame(parent, bg=SURFACE)
        mod_frame.pack(fill=tk.X, padx=12)

        for name, key, default in modules:
            var = tk.BooleanVar(value=default)
            self.module_vars[key] = var
            cb = tk.Checkbutton(
                mod_frame, text=name,
                variable=var,
                font=FONT_MONO_SM, fg=TEXT, bg=SURFACE,
                selectcolor=BG, activebackground=SURFACE,
                activeforeground=GREEN,
                bd=0, padx=4
            )
            cb.pack(anchor=tk.W, pady=1)

        # ── BUTTONS ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill=tk.X, padx=12, pady=10)

        btn_frame = tk.Frame(parent, bg=SURFACE)
        btn_frame.pack(fill=tk.X, padx=12, pady=(0, 10))

        self.start_btn = tk.Button(
            btn_frame, text="▶  START SCAN",
            font=FONT_HEAD, bg=GREEN, fg=BG,
            relief=tk.FLAT, bd=0, padx=10, pady=10,
            cursor="hand2", command=self._start_scan
        )
        self.start_btn.pack(fill=tk.X, pady=(0, 6))

        self.stop_btn = tk.Button(
            btn_frame, text="■  STOP SCAN",
            font=FONT_HEAD, bg=CRIT, fg=TEXT,
            relief=tk.FLAT, bd=0, padx=10, pady=10,
            cursor="hand2", command=self._stop_scan,
            state=tk.DISABLED
        )
        self.stop_btn.pack(fill=tk.X, pady=(0, 6))

        self.report_btn = tk.Button(
            btn_frame, text="📄  OPEN REPORT",
            font=FONT_HEAD, bg=ACCENT, fg=BG,
            relief=tk.FLAT, bd=0, padx=10, pady=10,
            cursor="hand2", command=self._open_report,
            state=tk.DISABLED
        )
        self.report_btn.pack(fill=tk.X)

        # ── ELAPSED TIME ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill=tk.X, padx=12, pady=8)
        timer_row = tk.Frame(parent, bg=SURFACE)
        timer_row.pack(fill=tk.X, padx=12)
        tk.Label(timer_row, text="ELAPSED:", font=FONT_MONO_SM, fg=MUTED, bg=SURFACE).pack(side=tk.LEFT)
        self.elapsed_label = tk.Label(timer_row, text="00:00:00", font=FONT_MONO, fg=ACCENT, bg=SURFACE)
        self.elapsed_label.pack(side=tk.LEFT, padx=8)

    def _build_right(self, parent):
        # TAB BAR
        tab_bar = tk.Frame(parent, bg=SURFACE2, height=38)
        tab_bar.pack(fill=tk.X)
        tab_bar.pack_propagate(False)

        self.active_tab = tk.StringVar(value="output")
        tabs = [("LIVE OUTPUT", "output"), ("FINDINGS", "findings"), ("PHASES", "phases")]

        self.tab_frames = {}
        self.tab_buttons = {}

        content = tk.Frame(parent, bg=BG)
        content.pack(fill=tk.BOTH, expand=True)

        for label, key in tabs:
            btn = tk.Button(
                tab_bar, text=label,
                font=FONT_MONO_SM, bg=SURFACE2, fg=MUTED,
                relief=tk.FLAT, bd=0, padx=16,
                cursor="hand2",
                command=lambda k=key: self._switch_tab(k)
            )
            btn.pack(side=tk.LEFT, fill=tk.Y)
            self.tab_buttons[key] = btn

        # ── OUTPUT TAB ──
        out_frame = tk.Frame(content, bg=BG)
        self.tab_frames["output"] = out_frame

        # Terminal header
        term_header = tk.Frame(out_frame, bg="#010409", height=28)
        term_header.pack(fill=tk.X)
        term_header.pack_propagate(False)
        for col in ["#ff5f57", "#febc2e", "#28c840"]:
            tk.Label(term_header, text="●", fg=col, bg="#010409",
                     font=("Courier New", 10)).pack(side=tk.LEFT, padx=4, pady=4)
        self.term_title = tk.Label(
            term_header, text="autopwn_pro.sh — not running",
            font=FONT_MONO_SM, fg=MUTED, bg="#010409"
        )
        self.term_title.pack(side=tk.LEFT, padx=10)

        self.output_text = scrolledtext.ScrolledText(
            out_frame, font=FONT_MONO_SM,
            bg="#010409", fg="#8ec8e8",
            insertbackground=GREEN,
            relief=tk.FLAT, bd=0,
            wrap=tk.WORD,
            state=tk.DISABLED
        )
        self.output_text.pack(fill=tk.BOTH, expand=True)

        # Tag colors for output
        self.output_text.tag_config("phase",  foreground=PURPLE, font=("Courier New", 10, "bold"))
        self.output_text.tag_config("found",  foreground=GREEN)
        self.output_text.tag_config("vuln",   foreground=CRIT, font=("Courier New", 10, "bold"))
        self.output_text.tag_config("warn",   foreground=MED)
        self.output_text.tag_config("info",   foreground=ACCENT)
        self.output_text.tag_config("muted",  foreground=MUTED)
        self.output_text.tag_config("normal", foreground="#8ec8e8")

        # ── FINDINGS TAB ──
        find_frame = tk.Frame(content, bg=BG)
        self.tab_frames["findings"] = find_frame

        # Severity counters
        sev_bar = tk.Frame(find_frame, bg=SURFACE)
        sev_bar.pack(fill=tk.X, padx=0, pady=0)

        self.sev_labels = {}
        for sev, col in [("CRITICAL", CRIT), ("HIGH", HIGH), ("MEDIUM", MED), ("LOW", LOW)]:
            box = tk.Frame(sev_bar, bg=SURFACE)
            box.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=1, pady=8)
            tk.Label(box, text=sev, font=FONT_MONO_SM, fg=col, bg=SURFACE).pack()
            lbl = tk.Label(box, text="0", font=("Courier New", 22, "bold"), fg=col, bg=SURFACE)
            lbl.pack()
            self.sev_labels[sev] = lbl

        tk.Frame(find_frame, bg=BORDER, height=1).pack(fill=tk.X)

        self.findings_text = scrolledtext.ScrolledText(
            find_frame, font=FONT_MONO_SM,
            bg=BG, fg=TEXT,
            relief=tk.FLAT, bd=0,
            wrap=tk.WORD,
            state=tk.DISABLED
        )
        self.findings_text.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
        self.findings_text.tag_config("crit_title", foreground=CRIT, font=("Courier New", 10, "bold"))
        self.findings_text.tag_config("high_title", foreground=HIGH, font=("Courier New", 10, "bold"))
        self.findings_text.tag_config("med_title",  foreground=MED,  font=("Courier New", 10, "bold"))
        self.findings_text.tag_config("low_title",  foreground=LOW,  font=("Courier New", 10, "bold"))
        self.findings_text.tag_config("label",      foreground=MUTED)
        self.findings_text.tag_config("value",      foreground=TEXT)
        self.findings_text.tag_config("poc",        foreground=GREEN)
        self.findings_text.tag_config("sep",        foreground=BORDER)

        # ── PHASES TAB ──
        phases_frame = tk.Frame(content, bg=BG)
        self.tab_frames["phases"] = phases_frame

        self.phase_rows = {}
        phases = [
            ("01", "PASSIVE RECON",     "Subfinder, Amass, GAU, Wayback"),
            ("02", "ACTIVE ENUM",       "Nmap, HTTPX, WAF, Whatweb"),
            ("03", "CRAWL & DISCOVER",  "Gobuster, FFUF, JS Mining"),
            ("04", "VULN SCANNING",     "Nuclei CVEs, Misconfigs, Exposures"),
            ("05", "VERIFICATION",      "SQLi, XSS, CORS, Open Redirect, 403 Bypass"),
            ("06", "REPORT GENERATION", "HTML Report, JSON, PoC Commands"),
        ]

        for num, name, tools in phases:
            row = tk.Frame(phases_frame, bg=SURFACE, relief=tk.FLAT, bd=0)
            row.pack(fill=tk.X, padx=16, pady=5)

            num_lbl = tk.Label(row, text=num, font=("Courier New", 20, "bold"),
                               fg=BORDER, bg=SURFACE, width=3)
            num_lbl.pack(side=tk.LEFT, padx=12, pady=12)

            info = tk.Frame(row, bg=SURFACE)
            info.pack(side=tk.LEFT, fill=tk.X, expand=True, pady=8)

            name_lbl = tk.Label(info, text=name, font=FONT_HEAD, fg=TEXT, bg=SURFACE, anchor=tk.W)
            name_lbl.pack(fill=tk.X)
            tk.Label(info, text=tools, font=FONT_MONO_SM, fg=MUTED, bg=SURFACE, anchor=tk.W).pack(fill=tk.X)

            status_lbl = tk.Label(row, text="WAITING", font=FONT_MONO_SM,
                                  fg=MUTED, bg=SURFACE, width=10)
            status_lbl.pack(side=tk.RIGHT, padx=12)

            self.phase_rows[num] = {
                "frame": row,
                "num": num_lbl,
                "status": status_lbl,
                "name": name_lbl
            }

        # PROGRESS BAR
        prog_frame = tk.Frame(phases_frame, bg=BG)
        prog_frame.pack(fill=tk.X, padx=16, pady=16)
        tk.Label(prog_frame, text="OVERALL PROGRESS", font=FONT_MONO_SM, fg=MUTED, bg=BG).pack(anchor=tk.W)
        self.progress = ttk.Progressbar(prog_frame, mode='determinate', maximum=100)
        self.progress.pack(fill=tk.X, pady=4)
        self.progress_label = tk.Label(prog_frame, text="0%", font=FONT_MONO_SM, fg=ACCENT, bg=BG)
        self.progress_label.pack(anchor=tk.E)

        # Style progressbar
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TProgressbar", troughcolor=BORDER, background=GREEN, thickness=8)

        # BOTTOM STATUS BAR
        status_bar = tk.Frame(self.root, bg=SURFACE2, height=24)
        status_bar.pack(fill=tk.X, side=tk.BOTTOM)
        status_bar.pack_propagate(False)
        tk.Frame(self.root, bg=BORDER, height=1).pack(fill=tk.X, side=tk.BOTTOM)

        self.status_label = tk.Label(
            status_bar, text="  Ready — Enter target and click START SCAN",
            font=FONT_MONO_SM, fg=MUTED, bg=SURFACE2, anchor=tk.W
        )
        self.status_label.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.finding_status = tk.Label(
            status_bar, text="Findings: 0  ",
            font=FONT_MONO_SM, fg=ACCENT, bg=SURFACE2
        )
        self.finding_status.pack(side=tk.RIGHT)

        # Show default tab
        self._switch_tab("output")

    # ── TAB SWITCHING ─────────────────────────────────────────────────
    def _switch_tab(self, key):
        for k, frame in self.tab_frames.items():
            frame.pack_forget()
        for k, btn in self.tab_buttons.items():
            btn.config(bg=SURFACE2, fg=MUTED)

        self.tab_frames[key].pack(fill=tk.BOTH, expand=True)
        self.tab_buttons[key].config(bg=BG, fg=ACCENT)
        self.active_tab.set(key)

    # ── HELPERS ───────────────────────────────────────────────────────
    def _section_label(self, parent, text):
        tk.Label(
            parent, text=f"// {text}",
            font=FONT_MONO_SM, fg=ACCENT, bg=SURFACE, anchor=tk.W
        ).pack(fill=tk.X, padx=12, pady=(12, 4))

    def _field_label(self, parent, text):
        tk.Label(
            parent, text=text,
            font=FONT_MONO_SM, fg=MUTED, bg=SURFACE, anchor=tk.W
        ).pack(fill=tk.X, padx=12, pady=(0, 2))

    def _browse_dir(self):
        d = filedialog.askdirectory(initialdir=str(Path.home()))
        if d:
            self.outdir_var.set(d)

    def _update_clock(self):
        self.clock_label.config(text=datetime.now().strftime("%Y-%m-%d  %H:%M:%S"))
        self.root.after(1000, self._update_clock)

    def _animate_title(self):
        colors = [ACCENT, PURPLE, GREEN, ACCENT]
        self._title_ci = 0
        def cycle():
            self.title_label.config(fg=colors[self._title_ci % len(colors)])
            self._title_ci += 1
            self.root.after(1500, cycle)
        cycle()

    def _update_elapsed(self):
        if self.scan_running and self.start_time:
            elapsed = int(time.time() - self.start_time)
            h, r = divmod(elapsed, 3600)
            m, s = divmod(r, 60)
            self.elapsed_label.config(text=f"{h:02d}:{m:02d}:{s:02d}")
            self.timer_id = self.root.after(1000, self._update_elapsed)

    # ── SCAN CONTROL ─────────────────────────────────────────────────
    def _start_scan(self):
        target = self.target_var.get().strip()
        if not target:
            messagebox.showerror("Error", "Please enter a target domain!")
            return

        script = self.script_var.get().strip()
        if not os.path.exists(script):
            messagebox.showerror(
                "Script Not Found",
                f"Cannot find:\n{script}\n\nMake sure autopwn_pro.sh is at that path."
            )
            return

        outdir = self.outdir_var.get().strip()
        os.makedirs(outdir, exist_ok=True)

        # Reset UI
        self._clear_output()
        self._reset_phases()
        self.findings_count = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
        self._update_finding_counts()
        self._clear_findings()
        self.progress["value"] = 0
        self.progress_label.config(text="0%")
        self.report_btn.config(state=tk.DISABLED)
        self.elapsed_label.config(text="00:00:00")

        # Start
        self.scan_running = True
        self.start_time = time.time()
        self.start_btn.config(state=tk.DISABLED, bg=BORDER, fg=MUTED)
        self.stop_btn.config(state=tk.NORMAL)
        self.status_dot.config(fg=MED)
        self.term_title.config(text=f"autopwn_pro.sh — scanning {target}")
        self.status_label.config(text=f"  Scanning: {target}  |  Output: {outdir}")
        self._update_elapsed()

        self._write_output(f"╔══════════════════════════════════════════════╗\n", "phase")
        self._write_output(f"║  AutoPwn Pro — Starting scan on {target:<13}║\n", "phase")
        self._write_output(f"╚══════════════════════════════════════════════╝\n\n", "phase")

        # Run in thread
        thread = threading.Thread(
            target=self._run_scan,
            args=(script, target, outdir),
            daemon=True
        )
        thread.start()

    def _run_scan(self, script, target, outdir):
        try:
            cmd = ["sudo", "bash", script, target, outdir]
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                preexec_fn=os.setsid
            )

            for line in iter(self.process.stdout.readline, ''):
                if not self.scan_running:
                    break
                self.root.after(0, self._process_line, line)

            self.process.wait()
            self.root.after(0, self._scan_finished, target, outdir)

        except FileNotFoundError:
            self.root.after(0, self._write_output,
                "ERROR: 'sudo' or bash not found. Make sure you're on Kali Linux.\n", "vuln")
            self.root.after(0, self._scan_finished, target, outdir)
        except Exception as e:
            self.root.after(0, self._write_output, f"ERROR: {e}\n", "vuln")
            self.root.after(0, self._scan_finished, target, outdir)

    def _process_line(self, line):
        line = line.rstrip()
        if not line:
            return

        # Determine tag
        tag = "normal"
        if "PHASE" in line and ("═" in line or "║" in line):
            tag = "phase"
        elif line.startswith("[VULN]") or "INJECTION CONFIRMED" in line or \
             "XSS CONFIRMED" in line or "TAKEOVER" in line or \
             "HARDCODED" in line or "EXPOSED" in line:
            tag = "vuln"
        elif line.startswith("[+]"):
            tag = "found"
        elif line.startswith("[!]"):
            tag = "warn"
        elif line.startswith("[*]"):
            tag = "info"
        elif "╔" in line or "╚" in line or "║" in line or "╠" in line:
            tag = "phase"

        self._write_output(line + "\n", tag)

        # Phase detection
        phase_map = {
            "PHASE 1": "01", "PHASE 2": "02", "PHASE 3": "03",
            "PHASE 4": "04", "PHASE 5": "05", "PHASE 6": "06"
        }
        for ptext, pnum in phase_map.items():
            if ptext in line:
                self._set_phase_status(pnum, "RUNNING")
                if pnum != "01":
                    prev = f"{int(pnum)-1:02d}"
                    self._set_phase_status(prev, "DONE")
                prog = (int(pnum) - 1) * 16
                self._update_progress(prog, f"Phase {pnum}/06")

        # Vuln detection — add to findings
        if tag == "vuln":
            self._parse_vuln_line(line)

    def _parse_vuln_line(self, line):
        sev = "HIGH"
        if "INJECTION" in line or "HARDCODED" in line or "SECRET" in line:
            sev = "CRITICAL"
        elif "XSS" in line or "TAKEOVER" in line or "EXPOSED SERVICE" in line or "ADMIN PANEL" in line:
            sev = "HIGH"
        elif "REDIRECT" in line or "CORS" in line or "BYPASS" in line:
            sev = "MEDIUM"
        elif "HEADER" in line or "MISSING" in line:
            sev = "LOW"

        self.findings_count[sev] = self.findings_count.get(sev, 0) + 1
        self._update_finding_counts()

        total = sum(self.findings_count.values())
        self.finding_status.config(text=f"Findings: {total}  ")

        # Add to findings tab
        self._add_finding(sev, line)

    def _add_finding(self, sev, line):
        col_map = {"CRITICAL": "crit_title", "HIGH": "high_title",
                   "MEDIUM": "med_title", "LOW": "low_title"}
        tag = col_map.get(sev, "high_title")

        self.findings_text.config(state=tk.NORMAL)
        self.findings_text.insert(tk.END, f"\n[{sev}] ", tag)
        self.findings_text.insert(tk.END, line.replace("[VULN]", "").strip() + "\n", "value")
        self.findings_text.insert(tk.END, "─" * 60 + "\n", "sep")
        self.findings_text.config(state=tk.DISABLED)
        self.findings_text.see(tk.END)

    def _scan_finished(self, target, outdir):
        self.scan_running = False
        if self.timer_id:
            self.root.after_cancel(self.timer_id)

        self._set_phase_status("06", "DONE")
        self._update_progress(100, "Complete!")

        self.start_btn.config(state=tk.NORMAL, bg=GREEN, fg=BG)
        self.stop_btn.config(state=tk.DISABLED)
        self.status_dot.config(fg=LOW)

        # Find report
        report_path = Path(outdir) / target / "06_report" / f"pentest_report_{target}.html"
        self.last_report = str(report_path)

        total = sum(self.findings_count.values())
        self._write_output(f"\n\n✓ Scan complete — {total} findings\n", "found")

        if report_path.exists():
            self.report_btn.config(state=tk.NORMAL)
            self._write_output(f"✓ Report ready: {report_path}\n", "found")
            self.status_label.config(text=f"  Scan complete — {total} findings — Click OPEN REPORT")
        else:
            self.status_label.config(text=f"  Scan complete — {total} findings found")
            self._write_output(f"  Report path: {report_path}\n", "warn")

        self.term_title.config(text=f"autopwn_pro.sh — finished [{target}]")

        # Load findings.json if exists
        findings_json = Path(outdir) / target / "findings.json"
        if findings_json.exists():
            self._load_findings_json(findings_json)

    def _load_findings_json(self, path):
        try:
            with open(path) as f:
                data = json.load(f)
            findings = data.get("findings", [])
            self._clear_findings()
            self.findings_count = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}

            for f in findings:
                sev = f.get("severity", "LOW")
                self.findings_count[sev] = self.findings_count.get(sev, 0) + 1

                col_map = {"CRITICAL": "crit_title", "HIGH": "high_title",
                           "MEDIUM": "med_title", "LOW": "low_title"}
                tag = col_map.get(sev, "high_title")

                self.findings_text.config(state=tk.NORMAL)
                self.findings_text.insert(tk.END, f"\n[{sev}] CVSS {f.get('cvss','?')} — ", tag)
                self.findings_text.insert(tk.END, f"{f.get('title','')}\n", "value")
                self.findings_text.insert(tk.END, "URL:   ", "label")
                self.findings_text.insert(tk.END, f"{f.get('url','')}\n", "value")
                self.findings_text.insert(tk.END, "PARAM: ", "label")
                self.findings_text.insert(tk.END, f"{f.get('parameter','')}\n", "value")
                self.findings_text.insert(tk.END, "EVIDENCE:\n", "label")
                self.findings_text.insert(tk.END, f"  {f.get('evidence','')}\n", "value")
                self.findings_text.insert(tk.END, "POC:\n", "label")
                for poc_line in f.get("poc","").split("\n"):
                    self.findings_text.insert(tk.END, f"  {poc_line}\n", "poc")
                self.findings_text.insert(tk.END, "FIX:\n", "label")
                self.findings_text.insert(tk.END, f"  {f.get('remediation','')}\n", "value")
                self.findings_text.insert(tk.END, "═" * 60 + "\n", "sep")
                self.findings_text.config(state=tk.DISABLED)

            self._update_finding_counts()
        except Exception:
            pass

    def _stop_scan(self):
        if self.process:
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            except Exception:
                pass
        self.scan_running = False
        self.start_btn.config(state=tk.NORMAL, bg=GREEN, fg=BG)
        self.stop_btn.config(state=tk.DISABLED)
        self.status_dot.config(fg=CRIT)
        self._write_output("\n[!] Scan stopped by user.\n", "warn")
        self.status_label.config(text="  Scan stopped by user.")

    def _open_report(self):
        if hasattr(self, 'last_report') and os.path.exists(self.last_report):
            subprocess.Popen(["firefox", self.last_report])
        else:
            # Try to find any report
            outdir = self.outdir_var.get()
            target = self.target_var.get()
            results = list(Path(outdir).glob(f"**/{target}**/06_report/*.html"))
            if results:
                subprocess.Popen(["firefox", str(results[0])])
            else:
                messagebox.showinfo("Not Found",
                    f"Report not found yet.\nLook in:\n{outdir}/{target}/06_report/")

    # ── OUTPUT HELPERS ────────────────────────────────────────────────
    def _write_output(self, text, tag="normal"):
        self.output_text.config(state=tk.NORMAL)
        self.output_text.insert(tk.END, text, tag)
        self.output_text.config(state=tk.DISABLED)
        self.output_text.see(tk.END)

    def _clear_output(self):
        self.output_text.config(state=tk.NORMAL)
        self.output_text.delete(1.0, tk.END)
        self.output_text.config(state=tk.DISABLED)

    def _clear_findings(self):
        self.findings_text.config(state=tk.NORMAL)
        self.findings_text.delete(1.0, tk.END)
        self.findings_text.config(state=tk.DISABLED)

    def _update_finding_counts(self):
        for sev, lbl in self.sev_labels.items():
            lbl.config(text=str(self.findings_count.get(sev, 0)))

    def _reset_phases(self):
        for num, row in self.phase_rows.items():
            row["frame"].config(bg=SURFACE)
            row["num"].config(fg=BORDER, bg=SURFACE)
            row["name"].config(fg=TEXT, bg=SURFACE)
            row["status"].config(text="WAITING", fg=MUTED, bg=SURFACE)

    def _set_phase_status(self, num, status):
        if num not in self.phase_rows:
            return
        row = self.phase_rows[num]
        if status == "RUNNING":
            row["frame"].config(bg=SURFACE2)
            row["num"].config(fg=MED, bg=SURFACE2)
            row["name"].config(fg=TEXT, bg=SURFACE2)
            row["status"].config(text="▶ RUNNING", fg=MED, bg=SURFACE2)
        elif status == "DONE":
            row["frame"].config(bg=SURFACE)
            row["num"].config(fg=LOW, bg=SURFACE)
            row["name"].config(fg=TEXT, bg=SURFACE)
            row["status"].config(text="✓ DONE", fg=LOW, bg=SURFACE)

    def _update_progress(self, val, label=""):
        self.progress["value"] = val
        self.progress_label.config(text=f"{val}% — {label}")


# ── MAIN ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    root = tk.Tk()

    # Make it look less like default Tk
    root.option_add("*tearOff", False)
    try:
        root.tk.call('tk', 'scaling', 1.2)
    except Exception:
        pass

    app = AutoPwnGUI(root)
    root.mainloop()
