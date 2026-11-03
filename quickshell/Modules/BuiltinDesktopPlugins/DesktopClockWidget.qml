import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

DClockWidget {
    id: root

    property real widgetWidth: (lockScreen || !!lockHost) ? 560 : 280
    property real widgetHeight: (lockScreen || !!lockHost) ? 185 : 200
    property string instanceId: ""
    property var instanceData: null
    property var lockHost: null
    lockScreen: !!lockHost
    // The lock host sizes widgets from defaultWidth/defaultHeight: ~120px digits like the pre-2.0 lock clock.
    defaultWidth: lockScreen ? 560 : baseWidth() * defaultScale
    defaultHeight: lockScreen ? 185 : baseHeight() * defaultScale

    cfg: instanceData?.config ?? ({})
    enabled: instanceData?.enabled ?? true
    now: systemClock.date
    locale: I18n.locale()
    use24HourClock: SettingsData.use24HourClock
    padHours12Hour: SettingsData.padHours12Hour
    // The inline lock clock draws its own AM/PM; keep the shared face from adding a second one below.
    showAmPm: inlineLockClock ? false : SettingsData.showAmPm
    dateFormat: lockScreen ? SettingsData.lockDateFormat : SettingsData.clockDateFormat
    fallbackFontFamily: SettingsData.lockScreenFontFamily
    readonly property color faceColor: lockHost ? lockHost.contentColor(colorMode, customColor) : themeAccent
    // Lock screen digital clock: draw "h:mm AM" on one line at full size (pre-2.0 look)
    // instead of the shared face, which puts AM/PM in small text below the time.
    readonly property bool inlineLockClock: lockScreen && face === "digital" && !showDate
    accentColor: inlineLockClock ? "transparent" : faceColor

    Row {
        id: inlineClock

        readonly property real size: Math.min(root.height * 0.65, root.width * 0.22)
        readonly property real digitWidth: size * 0.625

        visible: root.inlineLockClock
        anchors.centerIn: parent
        spacing: 0

        component InlineText: StyledText {
            font.pixelSize: inlineClock.size
            font.family: root.fontFamily !== "" ? root.fontFamily : resolvedFontFamily
            font.weight: root.digitWeight
            color: root.faceColor
        }

        component Digit: InlineText {
            width: inlineClock.digitWidth
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.hoursText.split("")
            Digit {
                required property string modelData
                text: modelData
            }
        }

        InlineText {
            text: ":"
        }

        Repeater {
            model: root.minutesText.split("")
            Digit {
                required property string modelData
                text: modelData
            }
        }

        InlineText {
            visible: root.showDigitalSeconds
            text: ":"
        }

        Repeater {
            model: root.showDigitalSeconds ? root.secondsText.split("") : []
            Digit {
                required property string modelData
                text: modelData
            }
        }

        Item {
            visible: ampmText.visible
            width: inlineClock.size / 6
            height: 1
        }

        InlineText {
            id: ampmText
            visible: !root.use24HourClock && SettingsData.showAmPm
            text: root.meridiem.toLowerCase()
        }
    }

    SystemClock {
        id: systemClock
        precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService

        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = true;
        }
    }
}
