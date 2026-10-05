import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Health Mode bar widget. Shows a heart-pulse glyph whose opacity reflects the
// mode (On 1.0 / Silent 0.6 / Off 0.75); hover shows the next nudge; left click
// opens the settings popout (HealthPanel.qml).
//
// Self-contained: the engine ships in bin/health-mode beside this file and this
// widget owns the once-a-minute heartbeat. Config lives in
// ~/.config/health/config.json, runtime state in ~/.local/state/health/state.json
// (both auto-created by the engine). The widget never invents state; it renders
// `health-mode summary`.
BarWidget {
  id: root
  moduleName: "never.health"

  // Engine ships with the plugin — resolve it beside this QML file so nothing
  // has to be installed system-wide. Invoked via `bash` so the exec bit can't
  // matter. (Quickshell gives a file:// URL; strip the scheme for a real path.)
  readonly property string engine: Qt.resolvedUrl("bin/health-mode").toString().replace("file://", "")

  readonly property string glyph: mode === "off"
    ? String.fromCodePoint(0xF0759)   // nf-md-heart_off — paused reads distinctly
    : String.fromCodePoint(0xF05F6)   // nf-md-heart_pulse
  property string mode: "on"            // on | silent | off
  property bool reminders: true
  property bool sound: true
  property string nextStream: ""
  property int nextSecs: -1

  readonly property real glyphOpacity: mode === "on" ? 1.0 : (mode === "silent" ? 0.6 : 0.75)

  function streamNice(name) {
    switch (name) {
      case "eye": return "Eyes"
      case "move": return "Move"
      case "water": return "Water"
      case "breath": return "Breathe"
      case "meal": return "Meal"
      case "winddown": return "Wind-down"
      default: return name
    }
  }

  function nextLabel() {
    if (nextSecs < 0 || nextStream === "") return "none scheduled"
    var mins = Math.round(nextSecs / 60)
    var when = new Date((Date.now() / 1000 + nextSecs) * 1000)
    var hh = ("0" + when.getHours()).slice(-2)
    var mm = ("0" + when.getMinutes()).slice(-2)
    var rel = mins <= 0 ? "due" : ("in " + mins + "m")
    return streamNice(nextStream) + " " + rel + " (" + hh + ":" + mm + ")"
  }

  function modeWord() {
    return mode === "on" ? "On" : (mode === "silent" ? "Silent" : "Off")
  }

  function tooltip() {
    return "Health Mode: " + modeWord() + "\nNext: " + nextLabel() + "\nClick for settings"
  }

  function refresh() {
    if (!summaryProc.running) summaryProc.running = true
  }

  function applySummary(raw) {
    var d
    try { d = JSON.parse(raw) } catch (e) { return }
    root.reminders = d.reminders === true
    root.sound = d.sound === true
    root.mode = String(d.mode || "on")
    var n = d.next || {}
    root.nextStream = String(n.stream || "")
    root.nextSecs = (n.secs === undefined || n.secs === null) ? -1 : Number(n.secs)
  }

  // ---- Popout contract (shape Bar.findPanelWidget requires) ----
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var t = panelLoader.item
    if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!tickProc.running) tickProc.running = true
  }

  function panelOpen() { return root.opened }

  Process {
    id: summaryProc
    command: ["bash", root.engine, "summary"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySummary(text)
    }
  }

  // Heartbeat: fire any due reminders, then refresh the tooltip. Replaces the
  // old systemd timer so the plugin is installable with `omarchy plugin add`
  // alone. A missed tick only costs one minute; state.json resumes the schedule.
  Process {
    id: tickProc
    command: ["bash", root.engine, "tick"]
    onExited: if (!root.panelOpen()) root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("HealthPanel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: "never.health"
    function refresh(): void { root.broadcast("refresh") }
    function status(): string { return root.mode }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    opacity: root.glyphOpacity
    tooltipText: root.tooltip()
    onPressed: function() { root.togglePanel() }
  }
}
