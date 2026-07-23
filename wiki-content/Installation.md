# Installation

## Prerequisites

- **[Julia 1.9+](https://julialang.org/downloads/)** — required runtime

## Option 1: Prebuilt Binary (Fastest)

Download the prebuilt binary from the [`grug-binary/`](https://github.com/grug-group420/grugbot420/tree/main/grug-binary) directory:

```bash
git clone https://github.com/grug-group420/grugbot420.git
cd grugbot420
chmod +x grug-binary/grugbot420
./grug-binary/grugbot420
```

First run detects a missing Julia install, opens the download page, and waits. Every run after that goes straight to the `Brain >` prompt.

## Option 2: One-Click Installer

Use the [grug-install](https://github.com/grug-group420/grug-install) scripts:

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/grug-group420/grug-install/main/install.ps1 | iex
```

**Linux/macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/grug-group420/grug-install/main/install.sh | bash
```

## Option 3: Run from Source

```bash
git clone https://github.com/grug-group420/grugbot420.git
cd grugbot420
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. src/Main.jl
```

## Option 4: Web Interface

Use the [grugbot-server](https://github.com/grug-group420/grugbot-server) for a browser-based experience:

```bash
git clone https://github.com/grug-group420/grugbot-server.git
cd grugbot-server
bun run serve
# Open http://localhost:3420
```

## Verifying Installation

After launching, you should see the `Brain >` prompt. Type `/status` to verify the engine is running:

```
Brain > /status
```

This prints a full system health snapshot: node count, Hopfield cache, memory estimate, lobe summary, and subsystem stats.

## Next Steps

→ [[Quick Start Guide]]
