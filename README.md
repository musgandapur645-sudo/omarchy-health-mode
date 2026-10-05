# omarchy-health-mode

Break reminders for the [Omarchy](https://github.com/basecamp/omarchy) shell bar.
A heart-pulse widget that nudges you to rest your eyes, move, drink water,
breathe, eat, and wind down — with a native settings popout, so no cadence ever
needs a terminal.

Self-contained: the reminder engine ships inside the plugin and the widget owns
its own once-a-minute heartbeat. No systemd units, no external binaries.

## Install

```sh
omarchy plugin add https://github.com/musgandapur645-sudo/omarchy-health-mode --enable
```

Then click the heart in the bar. Manual install: clone this repo into
`~/.config/omarchy/plugins/never.health` and run
`omarchy plugin enable never.health`.

## Use

- Click the heart to open settings.
- **Reminders** and **Sound** are the master switches; each stream has its own
  toggle and cadence slider (minutes for intervals, time-of-day for Meal and
  Wind-down).
- The glyph reflects state: heart-pulse (on) · dimmed (silent) · slashed heart
  (off). Hover shows the next nudge.
- Reminders pause while the session is idle or locked.

## Configuration

Kept outside the plugin so `omarchy plugin update` never touches it:

- `~/.config/health/config.json` — `reminders`, `sound`, and per-stream
  `enabled` / `every` / `at`
- `~/.local/state/health/state.json` — runtime (`last`, `firedToday`)

Both are created with defaults on first run. Default cadences: eyes 20 min,
move 45 min, water 90 min, breathe 3 h, meal 14:00, wind-down 23:30.

The bundled engine is a plain CLI too:

```sh
bash bin/health-mode summary            # JSON: mode, streams, next reminder
bash bin/health-mode tick               # fire anything due (the heartbeat)
bash bin/health-mode set streams.eye.every 25
bash bin/health-mode fire water         # force one nudge (preview)
```

## Requirements

Omarchy, and the tools its shell already ships: `jq`, `omarchy-notification-send`,
`paplay`, and a Nerd Font in the bar (the Omarchy default).

## Uninstall

```sh
omarchy plugin remove never.health
rm -rf ~/.config/health ~/.local/state/health
```

## Notes

- The heartbeat runs only while the shell runs; a missed tick costs at most a
  minute, and `state.json` resumes the schedule on the next one.
- With Omarchy "stay awake" enabled, idle suppression stops working, because
  that mode disables the shell's idle monitor.

## License

MIT — see [LICENSE](LICENSE).
