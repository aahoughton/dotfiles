---
name: herdr
description: >
  Finds the right manual for Herdr, which may be hosting this terminal. Use when
  `$HC_TERMINAL_ID` or `HERDR_ENV` is set and the task needs another terminal: reading
  or messaging one, starting an agent the user can watch, running a command on another
  machine, or changing what the Herdr window shows. Also use when the user mentions
  Herdr, `hc`, or `herdr-app`.
---

# Herdr

Herdr's manuals ship with its binaries and match the installed version. Read the one
that applies before using its commands.

| Signal | Host | Manual |
|--------|------|--------|
| `$HC_TERMINAL_ID` is set | herdr-core, shown by the Herdr window | `hc --skill` |
| `HERDR_ENV=1` | the older Herdr TUI | `herdr --skill` |
| Neither | not in a Herdr terminal; `hc` may still be installed | `hc --skill` |

`herdr-app --skill` covers changing the window: spaces, tabs, layouts, mods. `herdr-app`
exists only on the machine running the window, which may not be this one.

## Before acting

- `hc ls` lists all of the user's live terminals, and `hc send` types into them. Do not
  send input to a terminal you did not start unless the user asks.
- A terminal stays out of the window unless it has a `herdr.space=<id>` label. Add the
  label only when the user wants to see the terminal.
- Terminals you start end when your program ends, unless started with `--outlive-parent`
  or `--no-parent`.
- Do not stop or restart the core or the window unless the user asks. It affects every
  terminal.
