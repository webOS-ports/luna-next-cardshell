/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014-2015 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.5
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import LuneOS.Components 1.0

import "../Utils"
import "../AppTweaks"

import "SystemMenu"


/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- / -- (custom) carrier name -- |   --- title ---    |  -- indicators --]
Item {
    id: statusBar

    property Item windowManagerInstance
    property Item gestureHandlerInstance
    property bool fullLauncherVisible: false
    property bool justTypeLauncherActive: false
    property Item batteryService
    property Item wifiService

    /*
     * The bar has two heights on a panel with a notch, and the difference is the
     * whole trick.
     *
     * contentHeight is how tall the bar's own contents are - the carrier name,
     * the clock, the indicator icons - and it is what the bar has always been.
     * barHeight is how tall the bar has to be for the hardware to fall inside it,
     * which on a device with a deep cutout is more. The contents keep
     * contentHeight and sit at the bottom of barHeight, so the icons do not
     * inflate from 45px to fill a 102px bar and they end up as far from the notch and the
     * corner curves as the bar allows.
     *
     * Android splits the same two numbers (status_bar_height_portrait against the
     * content height, placed with bottomAlignedMargin) for the same reason.
     *
     * Bottom-aligning is not only about size: it is also what makes the corner
     * inset small. The curve only eats into the top of the bar, so content that
     * starts lower down loses far less to it - on radon 3px a side rather than
     * the 17px it would lose centred, or the 75px a naive full-radius inset takes.
     */
    readonly property real contentHeight: Units.gu(3)
    readonly property real barHeight: ScreenShape.topBarHeight(contentHeight,
                                                               orientationHelper.orientationAngle)

    /* How far in from each end the contents have to start to clear the rounded
     * corners, measured at the height the contents actually sit at. */
    readonly property real contentInsetLeft:
        ScreenShape.topLeftInset(barHeight - contentHeight, orientationHelper.orientationAngle)
    readonly property real contentInsetRight:
        ScreenShape.topRightInset(barHeight - contentHeight, orientationHelper.orientationAngle)

    property string carrierName: "LuneOS"
    // operator reported for the default voice SIM, and the combined list when
    // more than one SIM is up; updateCarrierName() picks between them
    property string singleSimCarrierName: "LuneOS"
    property string multiSimCarrierName: ""
    property string defaultColor: "#FF515558"
    property real fontSize: carrierText.font.pixelSize

    // blackMode: statusBar is black and nonsensitive to mouse events
    property bool blackMode: windowManagerInstance.state==="firstuse" || state==="dockmode"
    property QtObject compositorInstance

    // The classic tree-based system menu and the tabbed "New Device
    // Menu" implement the same external interface; the tweak picks
    // which one gets loaded into systemMenuLoader.
    property Item systemMenu: systemMenuLoader.item

    // Exhibition mode: the page on show, and a tap on the app menu asking for
    // the exhibition page list. Both are wired up to DockMode by CardsArea.
    property string dockModeAppMenuTitle: "Time"
    signal dockModeMenuToggled()

    signal showPowerMenu()

    function probeNetworkStatus()
    {
        networkStatusQuery.subscribe(
                    "luna://com.palm.telephony/networkStatusQuery",
                    "{\"subscribe\":true}",
                    onNetworkStatusChanged, onError)
    }

    function onNetworkStatusChanged(message) {
        var response = JSON.parse(message.payload)

        if (!response.returnValue &&
              response.errorText === "Backend not initialized") {
            resubscribeTimer.start();
            return;
        }
        else if(response.extended.state==="noservice")
            return;
        else if (response.extended.registration && response.extended.state !== "noservice") {
            singleSimCarrierName = response.extended.networkName
            updateCarrierName()
        }
    }

    function onError(message) {
        console.log("Failed to call networkStatus service: " + message)
    }

    function probeSimList()
    {
        simListQuery.subscribe(
                    "luna://com.palm.telephony/simListQuery",
                    "{\"subscribe\":true}",
                    onSimListChanged, onSimListError)
    }

    /*
     * With two SIMs a single operator name hides half of what the device is
     * connected to, so the carrier area lists them all, e.g. "Vodafone | KPN".
     */
    function onSimListChanged(message) {
        var response = JSON.parse(message.payload)

        if (!response.returnValue || !response.sims) {
            multiSimCarrierName = ""
            updateCarrierName()
            return;
        }

        var names = []

        if (response.simCount >= 2) {
            for (let i = 0; i < response.sims.length; i++) {
                let sim = response.sims[i]

                if (!sim.present || !sim.powered)
                    continue;

                names.push(sim.operatorName && sim.operatorName.length > 0 ? sim.operatorName
                                                                          : sim.name)
            }
        }

        multiSimCarrierName = names.length > 0 ? names.join(" | ") : ""
        updateCarrierName()
    }

    /*
     * The carrier area has three possible sources, in order of precedence: a
     * custom string from Tweaks, the combined operator list when more than one
     * SIM is up, and the single operator reported by networkStatusQuery.
     * Both subscriptions funnel through here so that whichever answers last
     * cannot clobber the other.
     */
    function updateCarrierName() {
        carrierName = multiSimCarrierName.length > 0 ? multiSimCarrierName
                                                     : singleSimCarrierName

        if (AppTweaks.enableCustomCarrierStringValue === true)
            carrierText.text = AppTweaks.customCarrierStringValue
        else
            carrierText.text = carrierName
    }

    function onSimListError(message) {
        console.log("Failed to call simListQuery service: " + message)
    }

    /*
     * The bar's paint, full width and the full barHeight - including the strip the
     * notch sits in, and right into the rounded corners.
     *
     * Deliberately separate from the contents below: the window is full-bleed and
     * only the *content* is inset, which is what Android does too
     * (PhoneStatusBarView pads its contents; the window keeps the whole width).
     * Painting the bar colour under the cutout and behind the curve is what stops
     * a bright app showing as a sliver around the camera, and it means the bar
     * reads as one object rather than as a stripe with notches cut out of it.
     */
    Rectangle {
        id: barFill
        anchors.fill: parent
        color: (!Settings.tabletUi || statusBar.blackMode)?"black":"transparent";

        Rectangle {
            anchors.fill: parent
            color: statusBar.defaultColor
            opacity: (statusBar.state==="application-visible")||(statusBar.state==="launcher-visible")
            Behavior on opacity { NumberAnimation {duration: 300} }
            visible: Settings.tabletUi && !statusBar.blackMode
        }

        Image {
            source: "../images/statusbar/status-bar-background.png"
            fillMode: Image.TileHorizontally
            verticalAlignment: Image.AlignLeft
            anchors.fill: parent
            visible: Settings.tabletUi && !statusBar.blackMode
        }
    }

    /*
     * Where the bar's contents live: full width, contentHeight tall, at the bottom
     * of the bar.
     *
     * On every device without a declared cutout this is the whole bar, exactly as
     * before - barHeight equals contentHeight and this item fills its parent. It
     * keeps the id "background" because everything inside it is positioned
     * relative to "parent", and parent.height being the content height rather than
     * the bar height is the point: the carrier's margins and font size are both
     * derived from it and must not grow when the bar does.
     */
    Item {
        id: background
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: statusBar.contentHeight

        Text {
            id: titleTextDate
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            /*
             * The lock screen's date occupies the same middle-of-the-bar slot as
             * the clock below, so it has the same problem with a centred lens and
             * gets the same treatment. Kept simpler than the clock's because
             * nothing else competes for the space in this state: centre it, then
             * move it off the camera within the room the corners leave.
             */
            x: {
                var minX = statusBar.contentInsetLeft;
                var maxX = background.width - statusBar.contentInsetRight;
                var centred = Math.round((background.width - contentWidth) / 2);

                return ScreenShape.shiftClear(centred, contentWidth,
                                              ScreenShape.obstaclesInBand(
                                                  statusBar.barHeight - statusBar.contentHeight,
                                                  statusBar.contentHeight,
                                                  orientationHelper.orientationAngle),
                                              minX, maxX);
            }
            width: contentWidth
            visible: statusBar.state === "lockscreen"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: statusBar.fontSize
            font.bold: true

            function updateClock() {
                titleTextDate.text = Qt.formatDateTime(new Date(), "M/d/yy")
            }

            text: Qt.formatDateTime(new Date(), "M/d/yy")
        }

        Component {
            id: tweaksClock
            TweaksClock {
                visible: statusBar.state!=="lockscreen"
                fontSize: statusBar.fontSize
                onTriggered: titleTextDate.updateClock()
            }
        }

        /*
         * The phone clock is centred in the status bar, but never under the
         * indicator block.
         *
         * It used to be anchors.fill: parent with the text centred inside,
         * so it was painted at the middle of the status bar with no idea
         * where anything else was. On a tablet there is enough slack either
         * side for that to look deliberate; on a 720 px phone the centre of
         * the bar is already underneath the indicator block, so the time was
         * drawn on top of the mute and wifi icons at the ordinary interface
         * size, and on top of the carrier name as well once the interface
         * was scaled up.
         *
         * So: centred when the middle of the bar is clear, and pushed left
         * of the indicators when it is not. The carrier side needs no such
         * clamp, because the carrier anchors to the clock's left edge and
         * elides into whatever room remains.
         */
        Loader {
            id: phoneTweaksClock
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            /*
             * Centred, then clamped away from the indicators, then moved off the
             * camera.
             *
             * The first two were already here and are unchanged. The third is the
             * bug this was written for: on a panel with a centred hole punch the
             * middle of the bar is exactly where the lens is, so a clock that has
             * been told only "be centred, but not under the indicators" is drawn
             * behind it. radon is the case in point - a 72px notch centred on 360
             * of 720.
             *
             * shiftClear moves it to whichever side of the obstacle is nearer, so
             * it ends up just left or just right of the lens rather than jumping to
             * an end of the bar. minX is the left corner inset and maxX the point
             * the indicator clamp already established, so the two rules compose
             * instead of fighting: the clock cannot be pushed onto the indicators
             * or under the other corner.
             *
             * Phosh picks a side the same way and warns when neither fits;
             * ScreenShape.shiftClear does the warning.
             */
            x: {
                var minX = statusBar.contentInsetLeft;
                var maxX = systemIndicatorsBoundingRect.x - Units.gu(0.5);
                var centred = Math.max(minX, Math.min((background.width - width) / 2,
                                                      maxX - width));

                return ScreenShape.shiftClear(centred, width,
                                              ScreenShape.obstaclesInBand(
                                                  statusBar.barHeight - statusBar.contentHeight,
                                                  statusBar.contentHeight,
                                                  orientationHelper.orientationAngle),
                                              minX, maxX);
            }

            // Its natural width, so the carrier below can be told what is
            // left rather than both of them guessing.
            width: item ? item.implicitWidth : 0
            sourceComponent: !Settings.tabletUi? tweaksClock : undefined;
        }

        Item {
            id: carrierString
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: parent.height * 0.25
            anchors.bottomMargin: parent.height * 0.25
            // Its own margin, plus whatever the rounded corner takes.
            anchors.leftMargin: parent.height * 0.25 + statusBar.contentInsetLeft
            /*
             * Half the bar on a tablet, as it always was. On a phone,
             * whatever is left once the clock and the indicators have taken
             * theirs - the carrier name is the one thing here that can be
             * shortened without losing information, and it already elides.
             *
             * A fixed half is what made this collide: on a 720 px screen
             * half the bar runs under the indicator block, so the clock had
             * nowhere to be that was not on top of something, and scaling
             * the interface up only moved the collision further left.
             */
            anchors.right: Settings.tabletUi ? undefined : phoneTweaksClock.left
            anchors.rightMargin: Settings.tabletUi ? 0 : Units.gu(0.5)
            width: Settings.tabletUi ? (background.width / 2) - Units.gu(3) : undefined
            visible: !appMenu.visible

            LunaService {
                id: networkStatusQuery

                name: "com.webos.surfacemanager-cardshell"

                onInitialized: {
                    probeNetworkStatus()
                }

            }

            LunaService {
                id: simListQuery

                name: "com.webos.surfacemanager-cardshell"

                onInitialized: {
                    probeSimList()
                }
            }

            Text {
                id: carrierText
                anchors.fill: parent
                horizontalAlignment: Text.AlignHLeft
                verticalAlignment: Text.AlignVCenter
                color: "white"
                font.family: Settings.fontStatusBar
                font.pixelSize: parent.height
                font.bold: true
                text: carrierName
                width: parent.width
                elide: Text.ElideRight

                Connections {
                    target: AppTweaks
                    function onEnableCustomCarrierStringValueChanged() {
                        updateCarrierString()
                    }
                    function onCustomCarrierStringValueChanged() {
                        updateCarrierString()
                    }
                    function updateCarrierString() {
                        // single place that decides what the carrier area shows
                        statusBar.updateCarrierName()
                    }
                }
            }
        }

        AppMenu {
            id: appMenu
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            // The app menu takes the carrier's place at the left end, so it has to
            // clear the same corner.
            anchors.leftMargin: statusBar.contentInsetLeft
            fontSize: statusBar.fontSize
            dockModeAppMenuTitle: statusBar.dockModeAppMenuTitle

            onDockModeMenuToggled: statusBar.dockModeMenuToggled()
        }

        Loader {
            id: notificationAreaInstance
            anchors.top: parent.top
            height: parent.height
            anchors.right: systemIndicators.left
            enabled: !statusBar.blackMode
            visible: !lockScreen.visible
            active: Settings.tabletUi

            Component.onCompleted: {
                notificationAreaInstance.setSource("../Notifications/NotificationAreaTablet.qml",
                {
                    "windowManagerInstance": statusBar.windowManagerInstance,
                    "compositorInstance": statusBar.compositorInstance,
                    "maxDashboardWindowHeight": Qt.binding(() => {return windowManagerInstance.height*0.67;}),
                    "blackMode": statusBar.blackMode,
                });
            }
        }

        BorderImage {
            id: systemMenuOpenBg
            visible: Settings.tabletUi && systemMenu && systemMenu.visible && !systemMenu.centered && statusBar.state!=="dockmode"
            source: "../images/statusbar/status-bar-menu-dropdown-tab.png"
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: parent.width-systemIndicators.x+19
            x: systemIndicatorsBoundingRect.x-9
            smooth: false
            border.left: 11
            border.right: 11
            border.top: 2
        }

        Item {
            id: systemIndicatorsBoundingRect
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: statusBar.contentInsetRight
            width: systemIndicators.width+2*systemIndicators.anchors.margins-systemIndicators.spacing
        }

        Row {
            id: systemIndicators
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Units.gu(1) / 2
            // anchors.margins already covers the right edge; the corner inset is
            // on top of it, so the icons clear the curve as well as the edge.
            anchors.rightMargin: Units.gu(1) / 2 + statusBar.contentInsetRight
            spacing: Units.gu(1) / 2

            Image {
                id: statusBarSeparator
                source: "../images/statusbar/status-bar-separator.png"
                anchors.verticalCenter: parent.verticalCenter
                // The content band, not the bar: on a notched panel the bar is
                // taller than its contents and a full-height separator would
                // stick out of the top of them.
                height: statusBar.contentHeight
                width: 2
                mipmap: true
                opacity: Settings.tabletUi && !(systemMenu && systemMenu.visible)
                visible: statusBar.state!=="lockscreen"
            }

            SystemIndicators {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: parent.spacing
            }

            Loader {
                id: tabletTweaksClock
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                sourceComponent: Settings.tabletUi? tweaksClock : undefined;
                visible: statusBar.state!=="lockscreen"
            }

            Image {
                id: systemMenuArrow
                source: "../images/statusbar/menu-arrow.png"
                anchors.verticalCenter: parent.verticalCenter
                height: Units.gu(2.6)
                width: Units.gu(1.5)
                mipmap: true
                visible: !statusBar.blackMode && !(statusBar.state==="lockscreen")
            }
        }

        MouseArea {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            // Follow the icons in, so the tap target stays over them.
            anchors.rightMargin: statusBar.contentInsetRight
            width: systemIndicators.width
            onClicked: {
                if (systemMenu && !lockScreen.locked && !dockMode.visible && windowManagerInstance.state === "normal")
                    systemMenu.toggleState()
            }
        }

        Connections {
            target: lockScreen
            function onLockedChanged() {
                if (!systemMenu)
                    return;
                if (lockScreen.locked) {
                    systemMenu.visibleBeforeLock = systemMenu.isVisible();
                    systemMenu.visible = false;
                }
                else {
                    systemMenu.visible = systemMenu.visibleBeforeLock;
                }
            }
        }

        Connections {
            target: gestureHandlerInstance
            function onScreenEdgeFlickEdgeTop(timeout, pos) {
                if (!timeout && windowManagerInstance.gesturesEnabled === true) {
                    if (appMenu.contains(mapToItem(appMenu, pos.x, pos.y)))
                        appMenu.toggleState()
                    else if (!statusBar.blackMode && systemMenu) {
                        if (!Settings.tabletUi && systemMenuLoader.contains(mapToItem(systemMenuLoader, pos.x, systemMenuLoader.y)))
                            systemMenu.toggleState()
                        else if (Settings.tabletUi && systemIndicatorsBoundingRect.contains(mapToItem(systemIndicatorsBoundingRect, pos.x, pos.y)))
                            systemMenu.toggleState()
                        else if ((notificationAreaInstance.status === Loader.Ready) && notificationAreaInstance.item.boundingRect.contains(mapToItem(notificationAreaInstance.item.boundingRect, pos.x, pos.y)))
                            notificationAreaInstance.item.clicked()
                    }
                }
            }
        }

        Loader {
            id: systemMenuLoader
            anchors.top: parent.bottom
            enabled: !statusBar.blackMode
            // use item.width, not the Loader's own width, to keep the x
            // binding free of self-geometry (avoids a binding loop warning)
            x: !item ? 0
               : item.centered ? Math.round((parent.width - item.width) / 2)
                               : parent.width - item.width + item.edgeOffset
            source: AppTweaks.newDeviceMenuTweakValue ? "SystemMenu/NewDeviceMenu.qml" : "SystemMenu/SystemMenu.qml"

            onLoaded: item.visible = false

            Connections {
                target: systemMenuLoader.item
                function onCloseSystemMenu() {
                    systemMenu.resetMenu()
                    systemMenu.toggleState()
                }
                function onShowPowerMenu() {
                    statusBar.showPowerMenu();
                }
                // Both menu implementations only announce the request; the
                // radios are switched in one place, AirplaneModeService.
                function onAirplaneModeTriggered() {
                    airplaneModeService.toggle();
                }
            }
        }

        Timer {
                id: resubscribeTimer
                interval: 500
                repeat: false
                running: false
                onTriggered: {
                    probeNetworkStatus();
                }
            }
    }

    state: "default"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBar; visible: false }
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "default"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "dockmode"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "dockmode" }
        },
        State {
            name: "application-visible"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "appmenu" }
        },
        State {
            name: "launcher-visible"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: carrierText; text: "Launcher"}
            PropertyChanges { target: appMenu; state: "hidden" }
        },
        State {
            name: "lockscreen"
            PropertyChanges { target: statusBar; visible: true }
            PropertyChanges { target: appMenu; state: "hidden" }
        }
    ]

    Connections {
        target: windowManagerInstance
        function onSwitchToLockscreen () {
            state = "lockscreen"
        }
        function onSwitchToDockMode () {
            state = "dockmode"
        }
        function onSwitchToMaximize (window) {
            state = "application-visible"
        }
        function onSwitchToFullscreen (window) {
            state = "hidden"
        }
        function onSwitchToCardView () {
            state = "default"
        }
        function onSwitchToLauncherView () {
            state = "launcher-visible"
            if (systemMenu && systemMenu.isVisible())
                systemMenu.toggleState()
        }
    }
}
