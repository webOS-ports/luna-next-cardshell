/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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

import QtQuick 2.9
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import WebOSCompositorBase 1.0
import WebOSCoreCompositor 1.0

import "../LunaSysAPI" as LunaSysAPI
import "../Utils"

Item {
    id: launcherItem

    property Item gestureAreaInstance
    property Item windowManagerInstance
    property bool fullLauncherVisible: false

    // LunaSysMgr's SystemUiController::setLauncherShown() played these.
    FeedbackSound { id: launcherOpenSound; soundName: "LauncherOpenApp" }
    FeedbackSound { id: launcherCloseSound; soundName: "LauncherCloseApp" }
    onFullLauncherVisibleChanged: fullLauncherVisible ? launcherOpenSound.play() : launcherCloseSound.play()

    property bool launcherActive: state === "fullLauncher" || state === "justTypeLauncher"

    /*!
     * When a hardware key last toggled the launcher (CardsArea.toggleLauncher).
     *
     * On a phone with capacitive keys under the screen (BlackBerry KEY2), a
     * swipe up that starts low enough brushes the Home key on its way to the
     * gesture area: Home toggles the launcher as the finger lands, and the
     * gesture area toggles it again ~70-90 ms later when it recognises the
     * swipe - so the launcher flashed open and shut, or shut and open, on
     * roughly every other swipe. A swipe-up this soon after a key toggle is
     * the same intent and is not acted on twice. The window is a double
     * tap's 500 ms: several times the gap measured, and short enough not to
     * eat a deliberate swipe made just after pressing Home.
     */
    property real lastHardwareKeyToggleAt: 0
    readonly property int keyThenSwipeWindowMs: 500
    property bool justTypeLauncherActive: state === "justTypeLauncher"

    property ListModel appsModel: LunaSysAPI.ApplicationModel {}

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "com.webos.surfacemanager-cardshell"
    }

    Keys.forwardTo: [ justTypeFieldInstance, fullLauncherInstance ]

    // JustType field
    JustTypeField {
        id: justTypeFieldInstance

        windowManagerInstance: launcherItem.windowManagerInstance

        anchors.top: parent.top
        anchors.topMargin: Units.gu(1);
        width: parent.width * 0.8
        height: Units.gu(5);
        anchors.horizontalCenter: parent.horizontalCenter

        onShowJustType: (pressedKey, modifiers) => {
            if( !!__justTypeLauncherWindow ) {
                launcherItem.state = "justTypeLauncher";
                launcherItem.__handOverJustTypeKey(pressedKey, modifiers);
            }
        }
    }

    // App launcher, which can slide up or down on demand
    FullLauncher {
        id: fullLauncherInstance

        iconSize: Units.gu(6);
        bottomMargin: launchBarInstance.height;

        anchors.left: parent.left
        anchors.right: parent.right
        commonAppsModel: launcherItem.appsModel
    }

    // bottom area: launcher bar
    LaunchBar {
        id: launchBarInstance

        height: Units.gu(8);
        anchors.left: parent.left
        anchors.right: parent.right
        appsModel: launcherItem.appsModel

        onToggleLauncherDisplay: {
            if( launcherItem.state === "launchbar" ) {
                launcherItem.state = "fullLauncher";
            }
            else {
                launcherItem.state = "launchbar";
            }
        }
    }

    // JustType launcher window container
    JustTypeLauncher {
        id: justTypeLauncherInstance

        anchors.left: parent.left
        anchors.right: parent.right
        height: launcherItem.height
    }

    state: "launchbar"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: launchBarInstance; state: "hidden" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
            PropertyChanges { target: launcherItem; fullLauncherVisible: false }
        },
        State {
            name: "launchbar"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "visible" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
            PropertyChanges { target: launcherItem; fullLauncherVisible: false }
            StateChangeScript { script: windowManagerInstance.switchToCardView() }
        },
        State {
            name: "fullLauncher"
            PropertyChanges { target: launchBarInstance; state: "visible" }
            PropertyChanges { target: fullLauncherInstance; state: "visible" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "hidden" }
            PropertyChanges { target: launcherItem; fullLauncherVisible: true }
            StateChangeScript { script: windowManagerInstance.switchToLauncherView() }
        },
        State {
            name: "justTypeLauncher"
            PropertyChanges { target: launchBarInstance; state: "hidden" }
            PropertyChanges { target: fullLauncherInstance; state: "hidden" }
            PropertyChanges { target: justTypeFieldInstance; state: "hidden" }
            PropertyChanges { target: justTypeLauncherInstance; state: "visible" }
            PropertyChanges { target: launcherItem; fullLauncherVisible: true }
            StateChangeScript {
                script: {
                    if (__justTypeLauncherWindow) {
                        // take focus for receiving input events
                        __justTypeLauncherWindow.takeFocus();
                    }
                }
            }
            StateChangeScript { script: windowManagerInstance.switchToLauncherView() }
        }
    ]

    /*!
     * \brief Give the launcher application the key that opened Just Type.
     *
     * That first keystroke is what asked for Just Type in the first place, so it
     * arrives while the shell still has the keyboard focus and the launcher
     * window has none - JustTypeField consumes it to know it was typed at all.
     * Without handing it over the search field comes up empty and the letter is
     * simply gone, which is what "Just Type swallows the first letter" was.
     *
     * Replaying it on the seat is how the shell already talks to a focused
     * surface: CardView's back gesture sends Escape the same way. The state
     * change above has just taken the focus for this window, so the key goes
     * there and nowhere else.
     *
     * Shift is replayed around it, balanced, because the client works out its own
     * modifier state from the key events it was sent and it never saw the Shift
     * that is still being held - so a capital first letter would otherwise
     * arrive lowercase. Balanced rather than left down until the real release:
     * that release is swallowed by WebOSKeyFilter, which drops the first release
     * after a focus change, and a Shift left depressed would then capitalise the
     * rest of the word.
     */
    function __handOverJustTypeKey(pressedKey, modifiers) {
        if( pressedKey === 0 ) return; // the field was tapped, nothing was typed

        if( !compositor || !compositor.defaultSeat ) {
            console.warn("Launcher: no seat to hand the Just Type key to");
            return;
        }

        var seat = compositor.defaultSeat;
        var shifted = (modifiers & Qt.ShiftModifier) !== 0;

        if( shifted ) seat.sendKeyEvent(Qt.Key_Shift, true);
        seat.sendKeyEvent(pressedKey, true);
        seat.sendKeyEvent(pressedKey, false);
        if( shifted ) seat.sendKeyEvent(Qt.Key_Shift, false);
    }

    function launchApplication(id, params, successCB) {
        console.log("launching app " + id + " with params " + JSON.stringify(params));
        state = "launchbar";
        lunaNextLS2Service.call("luna://com.webos.service.applicationManager/launch",
            JSON.stringify({"id": id, "params": params}), successCB, handleLaunchAppError)
    }

    Connections {
        target: launchBarInstance
        function onStartLaunchApplication(appId, appParams) {
            launchApplication(appId, appParams)
        }
    }

    Connections {
        target: fullLauncherInstance
        function onStartLaunchApplication(appId, appParams) {
            launchApplication(appId, appParams)
        }
    }

    function handleLaunchAppError(message) {
        console.log("Could not start application : " + message);
        state = "launchbar";
    }

    function expandLauncher() {
        state = "fullLauncher";
    }


    Connections {
        target: windowManagerInstance
        function onSwitchToLockscreen() {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        function onSwitchToDockMode() {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        function onSwitchToMaximize(window) {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        function onSwitchToFullscreen(window) {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        function onSwitchToCardView() {
            gestureAreaConnections.target = gestureAreaInstance;
            state = "launchbar";
        }
        function onSwitchToLauncherView() {
            gestureAreaConnections.target = gestureAreaInstance;
            if( !launcherActive ) {
                state = "fullLauncher";
            }
        }
    }

    ///////// gesture area management ///////////
    Connections {
        id: gestureAreaConnections
        target: gestureAreaInstance
        function onSwipeUpGesture(modifiers) {
            if( Date.now() - launcherItem.lastHardwareKeyToggleAt < launcherItem.keyThenSwipeWindowMs )
                return;
            if( state === "launchbar" ) {
                state = "fullLauncher";
            }
            else {
                state = "launchbar";
            }
        }
        function onSwipeLeftGesture(modifiers) {
            state = "launchbar";
        }
    }

    Connections {
        enabled: !__justTypeLauncherWindow
        target: compositor
        function onSurfaceMapped(item) {
            if (item.type === "_WEBOS_WINDOW_TYPE_SYSTEM_UI" &&
                item.appId === "com.palm.launcher") 
            {
                initJustTypeLauncherApp(item);
            }
        }
    }

    function initJustTypeLauncherApp(window) {
        if( !__justTypeLauncherWindow )
        {
            __justTypeLauncherWindow = window;
            justTypeLauncherInstance.setLauncherWindow(window);
        }
    }

    property Item __justTypeLauncherWindow;
}
