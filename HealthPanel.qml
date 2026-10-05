import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Health Mode settings popout. Opened by a click on the bar icon (see Health.qml).
//
// Master on/silent/off is two switches (Reminders + Sound). Every stream has a
// toggle and a native PanelSlider for its cadence (minutes for intervals,
// time-of-day for clock streams). Changes are written straight to
// ~/.config/health/config.json via the bundled engine (`bin/health-mode set`),
// so they take effect on the next heartbeat — no terminal, no service restart.
//
// Controls are optimistic: the row updates at once and the file is re-read to
// confirm. Writes are serialized through a queue so holding a slider or clicking
// fast never drops a step, and a failed write surfaces instead of silently
// reverting.
Panel {
  id: root
  moduleName: "never.health"
  ipcTarget: "never.health"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // Engine ships beside this file (see Health.qml); invoked via bash so the
  // exec bit can't matter.
  readonly property string engine: Qt.resolvedUrl("bin/health-mode").toString().replace("file://", "")

  property bool reminders: true
  property bool sound: true
  property var streams: []
  property var setQueue: []

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

  function cadenceText(s) {
    if (s.at) return "at " + s.at + " each day"
    var e = s.every || 0
    if (e >= 60 && e % 60 === 0) return "every " + (e / 60) + " h"
    return "every " + e + " min"
  }

  function pad(n) { return ("0" + n).slice(-2) }
  function toMins(hm) {
    var p = String(hm).split(":")
    return (Number(p[0]) || 0) * 60 + (Number(p[1]) || 0)
  }
  function minsToHM(m) {
    m = ((m % 1440) + 1440) % 1440
    return pad(Math.floor(m / 60)) + ":" + pad(m % 60)
  }

  function sliderValue(s) { return s.at ? toMins(s.at) : (s.every || 20) }
  function sliderMin(s) { return s.at ? 0 : 5 }
  function sliderMax(s) { return s.at ? 1425 : 240 }
  function sliderStep(s) { return s.at ? 15 : 5 }
  function cadenceLabel(s, v) {
    if (s.at) return minsToHM(v)
    var e = Math.round(v)
    if (e >= 60 && e % 60 === 0) return (e / 60) + " h"
    return e + " min"
  }

  function findStream(name) {
    for (var i = 0; i < streams.length; i++) if (streams[i].name === name) return streams[i]
    return null
  }

  function load() {
    if (!sumProc.running) sumProc.running = true
  }

  function parseSummary(raw) {
    var d
    try { d = JSON.parse(raw) } catch (e) { return }
    root.reminders = d.reminders === true
    root.sound = d.sound === true
    root.streams = d.streams || []
  }

  // Serialize writes: if one is in flight, queue the next.
  function commit(path, value) {
    var cmd = ["bash", root.engine, "set", path, "" + value]
    if (setProc.running) { setQueue.push(cmd); return }
    setProc.command = cmd
    setProc.running = true
  }

  function afterWrite() {
    root.load()
    if (root.hostWidget && typeof root.hostWidget.refresh === "function") root.hostWidget.refresh()
  }

  function notifyError() {
    errProc.command = ["omarchy-notification-send", "-u", "low",
      "Health Mode", "Couldn't save a setting — the change was reverted."]
    errProc.running = true
  }

  function toggleReminders() { root.reminders = !root.reminders; commit("reminders", root.reminders) }
  function toggleSound() { root.sound = !root.sound; commit("sound", root.sound) }

  function toggleStream(name) {
    var s = findStream(name); if (!s) return
    s.enabled = !s.enabled
    root.streams = root.streams.slice()
    commit("streams." + name + ".enabled", s.enabled)
  }

  function commitCadence(name, v) {
    var s = findStream(name); if (!s) return
    if (s.at) commit("streams." + name + ".at", minsToHM(v))
    else commit("streams." + name + ".every", Math.round(v))
  }

  onOpenedChanged: if (opened) root.load()

  Process {
    id: sumProc
    command: ["bash", root.engine, "summary"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseSummary(text)
    }
  }

  Process {
    id: setProc
    onExited: function(code) {
      if (code !== 0) root.notifyError()
      if (root.setQueue.length) {
        setProc.command = root.setQueue.shift()
        setProc.running = true
      } else {
        root.afterWrite()
      }
    }
  }

  Process { id: errProc }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(scroll.contentHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: "Health Mode"
            meta: root.reminders ? (root.sound ? "On · chime" : "Silent · no chime") : "Off · paused"
          }

          PanelSeparator { width: parent.width }

          Toggle {
            width: parent.width
            label: "Reminders"
            description: "Master switch for all health nudges."
            checked: root.reminders
            onClicked: root.toggleReminders()
          }

          Toggle {
            width: parent.width
            label: "Sound"
            description: "Play a chime with each reminder."
            checked: root.sound
            onClicked: root.toggleSound()
          }

          PanelSeparator { width: parent.width }

          PanelSectionHeader { text: "STREAMS" }

          Repeater {
            model: root.streams

            Column {
              id: streamRow
              required property var modelData
              width: parent.width
              spacing: Style.space(4)

              Toggle {
                width: parent.width
                label: root.streamNice(streamRow.modelData.name)
                description: root.cadenceText(streamRow.modelData)
                checked: streamRow.modelData.enabled === true
                onClicked: root.toggleStream(streamRow.modelData.name)
              }

              Row {
                visible: streamRow.modelData.enabled === true
                width: parent.width
                spacing: Style.space(8)

                PanelSlider {
                  id: cadenceSlider
                  width: parent.width - cadenceValue.width - Style.space(8)
                  bar: root.bar
                  minimum: root.sliderMin(streamRow.modelData)
                  maximum: root.sliderMax(streamRow.modelData)
                  step: root.sliderStep(streamRow.modelData)
                  integer: true
                  value: root.sliderValue(streamRow.modelData)
                  onReleased: function(v) { root.commitCadence(streamRow.modelData.name, v) }
                }

                Text {
                  id: cadenceValue
                  width: Style.space(56)
                  anchors.verticalCenter: parent.verticalCenter
                  horizontalAlignment: Text.AlignRight
                  text: root.cadenceLabel(streamRow.modelData, cadenceSlider.liveValue)
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }
  }
}
