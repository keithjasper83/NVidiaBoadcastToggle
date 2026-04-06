# NVIDIA Broadcast Stream Deck Control

Lightweight PowerShell tooling to control **NVIDIA Broadcast** with a proper state-aware toggle, automatic shutdown when you’re away, and optional self-updating via GitHub.

## Purpose

Run NVIDIA Broadcast **only when needed** — reduce constant GPU usage, add reliable Stream Deck control, and keep everything automatically maintained.

---

## Quick Start (One-Liner Install)

```powershell
iwr -useb https://raw.githubusercontent.com/keithjasper83/NVidiaBoadcastToggle/main/install-broadcast-tools.ps1 | iex
```

This will:

* Install scripts to your user OneDrive (default)
* Set execution permissions (session-level)
* Install the scheduled task (auto-close on lock)
* Pull latest scripts (if GitHub mode enabled)

---

## Default Install Location

```text
%OneDrive%\Documents\BroadcastTools
```

### Why this location

* Synced via OneDrive (backup + portability)
* User-scoped (no admin clutter)
* Consistent path across machines

### Alternative (if not using OneDrive)

Falls back to:

```text
%USERPROFILE%\Documents\BroadcastTools
```

---

## What Gets Installed

* `toggle-nvidia-broadcast.ps1` → Stateful toggle (launch/kill)
* `status-nvidia-broadcast.ps1` → Returns ON/OFF state
* `close-broadcast-on-lock.ps1` → Kills app when workstation locks
* `update-broadcast-tools.ps1` → Pull latest scripts from GitHub (if enabled)

---

## Stream Deck Setup

### Toggle Action

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%OneDrive%\Documents\BroadcastTools\toggle-nvidia-broadcast.ps1"
```

### Status (for dynamic button state)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%OneDrive%\Documents\BroadcastTools\status-nvidia-broadcast.ps1"
```

Use a plugin that supports **state polling + JSON parsing** for full ON/OFF visual feedback.

---

## Scheduled Task

Automatically installed:

* **Trigger**: Workstation lock
* **Action**: Force-close NVIDIA Broadcast

This ensures:

* No idle GPU usage
* Clean shutdown when you leave

---

## Updating Scripts

Manual update:

```powershell
powershell -ExecutionPolicy Bypass -File "%OneDrive%\Documents\BroadcastTools\update-broadcast-tools.ps1"
```

Recommended:

* Bind this to a **Stream Deck button**

---

## Notes

* Designed for **low overhead and reliability**
* No background services or polling loops required
* Toggle is **process-aware**, not state-blind

---

## Requirements

* Windows 10/11
* NVIDIA GPU (RTX recommended for Broadcast)
* NVIDIA Broadcast installed

---

## Future Improvements (optional)

* Version-aware updater
* Stream Deck profile export
* Mic routing presets
* Idle-time auto shutdown (beyond lock event)

---

## License

MIT (or your choice)
