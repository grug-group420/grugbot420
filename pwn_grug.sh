#!/bin/bash
# Hak5-style Grugbot Pwn Tool
# Usage: ./pwn_grug.sh

echo -e "\033[1;31m"
cat << "EOF"
  ██████  ██████  ██    ██  ██████  ██████   █████  ████████ 
 ██       ██   ██ ██    ██ ██       ██   ██ ██   ██    ██    
 ██   ███ ██████  ██    ██ ██   ███ ██████  ███████    ██    
 ██    ██ ██   ██ ██    ██ ██    ██ ██   ██ ██   ██    ██    
  ██████  ██   ██  ██████   ██████  ██   ██ ██   ██    ██    
EOF
echo -e "\033[0m"
echo -e "\033[1;33m[+] GRUGBOT420 PENETRATION TEST v1.0\033[0m"
echo -e "\033[1;33m[+] HACK THE PLANET - HAK5 STYLE\033[0m"
echo ""

# The pwnage
echo -e "\033[1;31m[!] SCANNING FOR VULNERABILITIES...\033[0m"

# Critical vulns
echo -e "\n\033[1;31m=== CRITICAL: RCE VECTORS ===\033[0m"
grep -rn "eval\|exec\|system\|shell" --include="*.jl" --include="*.py" . 2>/dev/null | \
  grep -v "test\|debug" | \
  while read line; do
    echo -e "    \033[1;31m[PWN]\033[0m $line"
  done

# Credentials
echo -e "\n\033[1;33m=== HIGH: CREDENTIAL EXPOSURE ===\033[0m"
grep -rn "password\|secret\|key\|token\|api" --include="*.jl" --include="*.py" --include="*.toml" . 2>/dev/null | \
  grep -v "\.git" | \
  while read line; do
    echo -e "    \033[1;33m[KEY]\033[0m $line"
  done

# Backdoors
echo -e "\n\033[1;31m=== BACKDOOR CANDIDATES ===\033[0m"
grep -rn "debug\|backdoor\|admin\|root" --include="*.jl" --include="*.py" . 2>/dev/null | \
  grep -v "test\|README" | \
  head -10 | \
  while read line; do
    echo -e "    \033[1;31m[DOOR]\033[0m $line"
  done

# Network recon
echo -e "\n\033[1;36m=== NETWORK FOOTPRINT ===\033[0m"
grep -rn "http://\|https://\|socket\|connect\|listen" --include="*.jl" --include="*.py" . 2>/dev/null | \
  head -10 | \
  while read line; do
    echo -e "    \033[1;36m[NET]\033[0m $line"
  done

# The final pwn
echo -e "\n\033[1;31m"
echo "[+] EXPLOIT SUMMARY:"
echo "    ───────────────"
TOTAL_VULNS=$(grep -rn "eval\|exec\|system\|password\|secret\|key" --include="*.jl" --include="*.py" . 2>/dev/null | grep -v "\.git\|test" | wc -l)
echo -e "    \033[1;31m[!]\033[0m Total vulnerabilities: $TOTAL_VULNS"
echo -e "    \033[1;33m[*]\033[0m RCE vectors: $(grep -rn "eval\|exec\|system" --include="*.jl" --include="*.py" . 2>/dev/null | grep -v "test" | wc -l)"
echo -e "    \033[1;33m[*]\033[0m Exposed secrets: $(grep -rn "password\|secret\|key" --include="*.jl" --include="*.py" . 2>/dev/null | grep -v "\.git\|test" | wc -l)"
echo -e "    \033[1;33m[*]\033[0m Lines of code: $(find . -type f -name "*.jl" -o -name "*.py" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')"
echo ""
echo -e "\033[1;32m[+] GRUG IS PWNED - RECOMMEND IMMEDIATE PATCHING\033[0m"
echo -e "\033[1;32m[+] HAK5 APPROVED - KEEP IT CRUNK\033[0m"
echo -e "\033[1;31m[!] Press any key to exploit...\033[0m"
read -n 1
