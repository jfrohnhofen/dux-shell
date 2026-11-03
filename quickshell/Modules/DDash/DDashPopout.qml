pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DDash.Overview

DPopout {
    id: root

    layerNamespace: "dms:dash"
    fullHeightSurface: false
    popupWidth: 400
    popupHeight: 360
    minimumSurfaceWidth: 400
    contentHandlesKeys: true
    closesWithSource: false
    resizeCurve: Theme.expressiveCurves.standard
    resizeDuration: Theme.expressiveDurations.expressiveFastSpatial
    resizeMotion: true
    resizing: contentLoader.item?.panelResizing ?? false
    surfacePadding: PopoutMetrics.editOverflow * 2
    inputMargin: editGutter * 2
    hoverDismissSuspended: editMode
    onOpened: contentFocusTimer.restart()

    Timer {
        id: contentFocusTimer
        interval: 0
        onTriggered: {
            if (root.shouldBeVisible)
                root.contentLoader.item?.focusInitial();
        }
    }

    property bool dashVisible: false
    property var triggerScreen: null
    property string currentTabId: DashRegistry.defaultTabId
    property string detailTabId: ""
    property bool editMode: false
    property string overviewFocusId: CacheData.dashFocusCardId || "calendar"

    onEditModeChanged: {
        if (!editMode)
            contentLoader.item?.panelResizer.cancel();
        if (!shouldBeVisible)
            return;
        Qt.callLater(() => contentLoader.item?.focusInitial());
    }

    readonly property string activeTabId: detailTabId !== "" ? detailTabId : currentTabId
    readonly property var detailEntry: detailTabId !== "" ? DashRegistry.entry(detailTabId) : null
    readonly property var orderedTabIds: DashRegistry.visibleTabIds
    readonly property var navigationIds: DashRegistry.navigationIds
    readonly property int currentTabIndex: navigationIds.indexOf(currentTabId)
    readonly property bool showTabs: navigationIds.length > 1 && currentTabIndex >= 0 && detailTabId === ""
    readonly property bool canReturn: detailTabId !== "" && currentTabIndex >= 0
    readonly property bool showHeader: detailTabId === "" || editMode
    readonly property int navigationEdge: {
        switch (SettingsData.dashTabPosition) {
        case "left":
            return SettingsData.Left;
        case "right":
            return SettingsData.Right;
        case "bottom":
            return SettingsData.Bottom;
        case "center":
            return SettingsData.Top;
        }
        switch (effectiveBarPosition % 4) {
        case SettingsData.Left:
            return SettingsData.Right;
        case SettingsData.Right:
            return SettingsData.Left;
        default:
            return effectiveBarPosition % 4;
        }
    }
    readonly property bool verticalNavigation: showTabs && (navigationEdge === SettingsData.Left || navigationEdge === SettingsData.Right)
    readonly property real navigationWidth: verticalNavigation ? Theme.navigationRailWidth + DashMetrics.contentGap : 0

    readonly property int columnCap: DashMetrics.columnCapFor(screen ? screen.width - navigationWidth : undefined, SettingsData.showWeekNumber)
    readonly property real editGutter: editMode ? PopoutMetrics.editOverflow : 0

    triggerWidth: DashMetrics.triggerWidth
    screen: triggerScreen

    property bool __focusArmed: false

    function panelWidthFor(columns) {
        return DashMetrics.widthFor(SettingsData.showWeekNumber, screen ? screen.width - navigationWidth : undefined, columns) + navigationWidth;
    }

    function requestTab(tab) {
        const id = DashRegistry.resolveId(tab);
        if (DashRegistry.isSelectable(id)) {
            detailTabId = "";
            currentTabId = id;
            return;
        }
        if (DashRegistry.hasTab(id)) {
            detailTabId = id;
            return;
        }
        detailTabId = "";
        currentTabId = DashRegistry.defaultTabId;
    }

    function runAction(id) {
        if (id !== "settings")
            return;
        dashVisible = false;
        instantClose();
        PopoutService.focusOrToggleSettings();
    }

    function closeDetail() {
        if (!canReturn) {
            dashVisible = false;
            return;
        }
        detailTabId = "";
    }

    function cycleTab(dir) {
        const ids = orderedTabIds;
        if (ids.length === 0)
            return;
        const pos = ids.indexOf(currentTabId);
        const next = pos < 0 ? (dir > 0 ? 0 : ids.length - 1) : (pos + dir + ids.length) % ids.length;
        detailTabId = "";
        currentTabId = ids[next];
    }

    function focusContent(backwards) {
        contentLoader.item?.focusNavigation(backwards);
    }

    onActiveTabIdChanged: {
        editMode = false;
        contentLoader.item?.dismissOptions();
        contentLoader.item?.resetScroll();
        if (shouldBeVisible && !contentLoader.item?.navigationFocused)
            contentLoader.item?.focusInitial();
    }

    readonly property string registryVisibleTabIds: DashRegistry.visibleTabIds.join("\n")
    readonly property string registryTabIds: DashRegistry.tabIds.join("\n")

    onRegistryVisibleTabIdsChanged: {
        if (!DashRegistry.isSelectable(currentTabId))
            currentTabId = DashRegistry.defaultTabId;
    }

    onRegistryTabIdsChanged: {
        if (detailTabId !== "" && !DashRegistry.hasTab(detailTabId))
            detailTabId = "";
    }

    function __tryFocusOnce() {
        if (!__focusArmed)
            return;
        const win = root.contentWindow;
        if (!win || !win.visible)
            return;
        const content = contentLoader.item;
        if (!content)
            return;
        if (win.requestActivate)
            win.requestActivate();
        content.focusInitial();
        if (content.activeFocus)
            __focusArmed = false;
    }

    onDashVisibleChanged: {
        if (dashVisible) {
            __focusArmed = true;
            presentWhenReady();
            return;
        }
        __focusArmed = false;
        editMode = false;
        contentLoader.item?.dismissOptions();
        if (openDeadline.running) {
            openDeadline.stop();
            clearPrimedContent();
        }
        close();
        if (CacheData.dashFocusCardId !== overviewFocusId)
            CacheData.set("dashFocusCardId", overviewFocusId);
    }

    onPopoutClosed: {
        editMode = false;
        detailTabId = "";
    }

    function presentWhenReady() {
        primeContent();
        openDeadline.restart();
        Qt.callLater(presentIfReady);
    }

    function presentIfReady() {
        if (!openDeadline.running || !contentLoader.item?.ready)
            return;
        presentNow();
    }

    function presentNow() {
        openDeadline.stop();
        if (!dashVisible || shouldBeVisible)
            return;
        open();
        __tryFocusOnce();
    }

    Timer {
        id: openDeadline
        interval: DashMetrics.openReadyDeadline
        onTriggered: root.presentNow()
    }

    Connections {
        target: root.contentLoader.item ?? null
        ignoreUnknownSignals: true

        function onReadyChanged() {
            Qt.callLater(root.presentIfReady);
        }
    }

    Connections {
        target: contentLoader

        function onLoaded() {
            if (root.__focusArmed)
                root.__tryFocusOnce();
        }
    }

    Connections {
        target: root.contentWindow ? root.contentWindow : null
        enabled: !!root.contentWindow

        function onVisibleChanged() {
            if (root.__focusArmed)
                root.__tryFocusOnce();
        }
    }

    onBackgroundClicked: dashVisible = false

    content: Component {
        FocusScope {
            id: mainContainer

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            implicitWidth: 400
            implicitHeight: 360
            focus: true

            // Interface expected by DDashPopout/DPopout (the full dash content is replaced by a calendar card).
            readonly property bool ready: true
            readonly property bool navigationFocused: false
            readonly property bool panelResizing: false
            readonly property QtObject panelResizer: QtObject {
                function cancel() {
                }
            }

            function focusInitial() {
                calendarCard.forceActiveFocus(Qt.OtherFocusReason);
            }

            function focusNavigation(backwards) {
                focusInitial();
            }

            function resetScroll() {
            }

            function dismissOptions() {
            }

            CalendarOverviewCard {
                id: calendarCard
                anchors.fill: parent
            }
        }
    }
}
