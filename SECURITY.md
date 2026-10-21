# Security Policy

Health Mode is a small, local-first plugin. It runs as your own user, only talks
to Omarchy/Quickshell on your machine, stores only reminder settings, and never
sends data anywhere. It holds no secrets, has no networking, and never needs
elevated access.

## Supported versions

Only the latest code on `main` (currently **2.0.x**) and the published
marketplace snapshot that matches it are supported. Older commits and older
published versions receive no security fixes — please update to current `main`
before reporting an issue.

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting** instead of a public
issue:

1. Open the **Security** tab of this repository.
2. Choose **Report a vulnerability**.
3. Describe the bug, how to trigger it, and what you think the impact is.

Expect an initial reply within a few days. This is a spare-time project, so
there is no hard SLA, but reports get read.

## In scope

- `bin/health-mode` — the shell engine: argument and config handling, `jq`
  usage, and file writes under `~/.config/health` and `~/.local/state/health`.
- `Health.qml` / `HealthPanel.qml` — the IPC handlers and process invocation.
- `manifest.json` and the plugin installation steps in the README.

## Out of scope

- Issues in Omarchy, Quickshell, Hyprland, or system sound libraries. Please
  report those upstream to the projects that own them.
- Anything requiring elevated access (root/other users). The plugin is
  incapable of this by design, so such reports are not Health Mode issues.
