# Damage Tracker | ALiTiS | v1.0

A real-time damage tracking overlay plugin for Diablo IV, built for use with a Lua-based game scripting framework.

---

## Important — accuracy disclaimer

**This plugin cannot be 100% accurate. Please read this before using it.**

The game does not expose damage events through the scripting API. There is no "on hit" or "on damage" callback available. Instead, the plugin works by sampling enemy health every ~33 milliseconds and calculating the difference between samples. This means:

- Damage that occurs between two samples may be partially missed, especially during high-speed multi-hit skills or DoT effects that tick rapidly
- The numbers you see will generally be **lower than your actual damage output**
- The faster and more frequent your hits are, the higher the undercount can be
- Despite this, the tracker gives a useful **relative indicator** of your performance — comparisons between builds or sessions are still meaningful, even if the absolute number is not perfect

There is no workaround for this limitation given the current API. The tracker is as accurate as the polling method allows.

---

## What it does

Damage Tracker monitors enemies in real time and displays live combat statistics on your screen as an overlay. It tracks damage dealt, DPS, peak DPS, kill count, and session time — all broken down per activity zone. All stats are also written to a log file that updates every 5 seconds, so you can review your performance after each session.

---

## Installation

1. Place the plugin folder anywhere inside your scripts directory.
2. Load the plugin through your scripting framework as usual.

The log file will be created automatically in the **same folder as the plugin**:
```
damage_tracker_log.txt
```

---

## Features

### Per-zone session tracking

The plugin automatically detects which activity you are in and keeps separate stats for each zone:

- **Infernal Horde** — detected by zone name
- **The Pit** — detected by active quest ID
- **Helltide** — detected via the helltide API flag
- **General** — fallback for everything else

Each zone has its own independent session. **Stats accumulate across multiple visits to the same zone** — re-entering The Pit, for example, continues adding to the same session rather than starting from zero. Sessions are only reset when you press Reset All Sessions manually or use the keybind. This means your Pit total reflects your entire play session, not just one run.

### Damage tracking

Enemy health and damage shield are sampled every ~33ms. The delta between consecutive samples is recorded as damage dealt. Both the HP pool and the damage shield are tracked — hits that land on a shield are not missed. When an enemy dies, any remaining effective HP not yet captured between the last sample and death is also recorded, reducing loss from the polling gap.

### Kill counting

Kills are detected using two methods in order of priority: the native `is_dead()` flag on the actor, and actor disappearance from the valid enemy list as a fallback. When a kill is detected, any remaining health and shield that was not yet captured in the last sample is also recorded as damage, reducing loss from the killing blow.

### Rolling DPS

DPS is calculated over a configurable rolling time window (default 30 seconds, adjustable from 1 to 30 seconds in the menu). Only damage events within the window are included in the calculation. The number updates continuously and decays smoothly to zero during downtime.

### Peak DPS

The highest rolling DPS value recorded in the current session is stored and displayed. When current DPS reaches 80% or more of the peak, the DPS line highlights in yellow to indicate near-peak performance.

### Session time

Elapsed time for the current zone session is displayed in hours, minutes, and seconds.

### Log file

A log file is written to `damage_tracker_log.txt` in the plugin root folder and updated every 5 seconds. It contains two sections:

- **Active sessions** — live stats for all zones currently in memory
- **Session history** — a permanent record of every session, appended each time you press Reset All Sessions

If you open the log in Notepad++ with auto-reload enabled, you can watch the stats update live while playing.

---

## Overlay display

The overlay is rendered directly on screen. Every element can be configured from the menu.

| Setting | Range | Default | Description |
|---|---|---|---|
| Offset X | 0 – 4000 | 0 | Horizontal position of the overlay |
| Offset Y | −200 – 1500 | 0 | Vertical position of the overlay |
| Font Size | 12 – 30 | 19 | Text size |
| Header Gap | 2 – 16 | 9 | Spacing after the header line |
| Line Gap | 0 – 10 | 4 | Spacing between stat lines |
| DPS Window | 1 – 30s | 30s | Rolling window for DPS calculation |

Each stat line (DPS, Peak DPS, Total Damage, Kills, Session Time, Zone Name) can be toggled on or off individually, and most can be set to bold.

The header colour changes depending on the current zone:

| Zone | Colour |
|---|---|
| Infernal Horde | Orange |
| The Pit | Red |
| Helltide | Purple |
| General | White |

---

## Menu buttons and controls

| Control | Description |
|---|---|
| Enable | Turns the overlay and tracking on or off |
| Open Log File | Prints the log to the in-game console and attempts to open the file in your default text editor |
| Clear Log File | Erases all session history from the log file |
| Reset All Sessions | Saves all current sessions to the log and resets all zone data immediately |
| Reset keybind | Same as Reset All Sessions, triggered by keyboard (default: Numpad Enter) |

---

## File structure

```
Damage Tracker/
  main.lua                 — entry point, wires update/render/menu
  gui.lua                  — menu elements and render function
  core/
    settings.lua           — reads GUI values into a runtime settings table
    tracker.lua            — per-zone session state: damage log, kills, peak DPS
    drawing.lua            — renders the on-screen overlay
    logger.lua             — writes and reads the log file
    utils.lua              — number and time formatting helpers
    zones.lua              — detects current activity zone
  data/
    colors.lua             — centralised color theme for the overlay
  tasks/
    track.lua              — main update task: samples actors, records damage and kills
  damage_tracker_log.txt        — auto-generated, written to the plugin root folder
```

---

## Tips

- Use a **longer DPS window** (30s) for a stable average that reflects your sustained output. Use a **shorter window** (3–5s) if you want a more reactive number that spikes with burst damage.
- The **Peak DPS** value is the best single number to compare between sessions, as it captures your highest sustained burst over the window rather than an average dragged down by downtime.
- Stats accumulate across multiple runs in the same zone. If you want a clean slate for a new run, press Reset All Sessions (or use the keybind) before entering.
- If numbers seem very low right after loading, give it a second — the tracker needs one pulse to register existing enemies before it starts recording deltas.
- The log file is a plain text file. You can open it with any text editor at any time.
