# 🧠 grugbot420 — Debian Deployment Guide

Platform: Debian 12 (Bookworm) · Architecture: x86_64

---

## The short version

GrugBot ships as a single self-extracting binary with a built-in install wizard.
No Julia install required upfront, no dependency wrangling, no source checkout.
Download, chmod, run — the wizard handles everything else on first launch.

```bash
wget https://github.com/marshalldavidson61-arch/grugbot420/raw/main/grug-binary/grugbot420
chmod +x grugbot420
./grugbot420
```

---

## What happens on first run

The install wizard launches automatically and walks you through five steps:

1. **Welcome** — intro screen, press Enter to continue
2. **License** — MIT license text, type `accept` and press Enter to proceed
3. **Dependencies** — checks whether `julia` is on your PATH
   - If Julia is present: shows ✓ and moves on
   - If Julia is missing: downloads the installer directly, launches it, waits for you to confirm, then re-checks
4. **Configuration** — summary of default settings (specimen file, arousal, mode)
5. **Finish** — wizard exits and GrugBot starts automatically

Every run after the first goes straight to the `Brain >` prompt — the wizard only runs once.

To re-run the wizard at any time:
```bash
bindboss reset grugbot420
./grugbot420
```

---

## Installing Julia manually (optional)

The install wizard handles Julia automatically. If you'd rather install it yourself
before the first run, or if the wizard's download step fails on your network:

```bash
# Download Julia 1.10 (1.9+ required)
wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz
tar -xzf julia-1.10.5-linux-x86_64.tar.gz
sudo mv julia-1.10.5 /opt/julia

# Add to PATH — add this line to ~/.bashrc or ~/.profile for persistence
export PATH=/opt/julia/bin:$PATH

# Verify
julia --version
```

Then run the binary normally — the wizard will detect Julia and skip the download step.

---

## Running in the background (daemon mode)

The wizard is interactive and requires a terminal on first run. After the first run
completes, you can run GrugBot in the background:

```bash
nohup ./grugbot420 > grugbot.log 2>&1 &
tail -f grugbot.log
```

---

## systemd service

> **Note:** Set up the service after the first interactive run so the wizard has
> already completed and Julia is confirmed installed. systemd won't have a TTY
> for the wizard prompts.

Create `/etc/systemd/system/grugbot420.service`:

```ini
[Unit]
Description=GrugBot420 AI Engine
After=network.target

[Service]
ExecStart=/path/to/grugbot420
WorkingDirectory=/path/to
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable grugbot420
sudo systemctl start grugbot420
sudo journalctl -u grugbot420 -f
```

---

## Verifying the binary

```bash
# Requires bindboss (github.com/marshalldavidson61-arch/Bindboss)
bindboss verify ./grugbot420
```

Expected SHA-256: `eeea4dd9f54e7287196701e4aedbac0e78348067b3f307fbe97849e25c0a03f0`

---

## Coming soon

GrugBot420 will be available directly from Linux package repositories (apt, etc.).
When that lands, installation will be a single `apt install grugbot420` with no manual steps.
Watch the repo for updates.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Wizard runs every time | Run `bindboss reset grugbot420` once to clear state, then re-run — should write state correctly after wizard completes |
| `julia: command not found` after wizard | The wizard may have downloaded Julia but it's not on PATH yet — add Julia's `bin/` to PATH and re-run |
| `julia: command not found` after manual install | Add Julia's `bin/` directory to PATH (`export PATH=/opt/julia/bin:$PATH`) and open a new terminal |
| Binary won't run: `Permission denied` | Run `chmod +x grugbot420` |
| Engine starts but crashes immediately | Check `grugbot.log` — most likely a missing Julia package; run `julia --project=. -e 'using Pkg; Pkg.instantiate()'` in the extracted dir (`~/.bindboss/grugbot420/`) |
| Want to force wizard to run again | `bindboss reset grugbot420` then re-run the binary |
| Running under systemd / no TTY | Run once interactively first so wizard completes, then hand off to systemd |