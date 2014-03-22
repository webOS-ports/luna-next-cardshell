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

import QtQuick 2.0
import LunaNext 0.1

Item {
    id: launcherItem

    property Item gestureAreaInstance
    property Item windowManagerInstance
    property bool fullLauncherVisible: false

    property bool launcherActive: state === "fullLauncher" || state === "justTypeLauncher"
    property bool justTypeLauncherActive: state === "justTypeLauncher"

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    Keys.forwardTo: [ justTypeFieldInstance ]

    // JustType field
    JustTypeField {
        id: justTypeFieldInstance

        windowManagerInstance: launcherItem.windowManagerInstance

        anchors.top: parent.top
        anchors.topMargin: Units.length(10);
        width: parent.width * 0.8
        height: Units.length(40);
        anchors.horizontalCenter: parent.horizontalCenter

        onShowJustType: {
            if( !!__justTypeLauncherWindow ) {
                launcherItem.state = "justTypeLauncher";
            }
        }
    }

    // App launcher, which can slide up or down on demand
    FullLauncher {
        id: fullLauncherInstance

        iconSize: Units.length(40);
        bottomMargin: launchBarInstance.height;

        anchors.left: parent.left
        anchors.right: parent.right
    }

    // bottom area: launcher bar
    LaunchBar {
        id: launchBarInstance

        height: Units.length(80);
        anchors.left: parent.left
        anchors.right: parent.right

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

    function launchApplication(id, params) {
        console.log("launching app " + id + " with params " + params);
        state = "launchbar";
        lunaNextLS2Service.call("luna://com.palm.applicationManager/launch",
            JSON.stringify({"id": id, "params": params}), undefined, handleLaunchAppError)
    }

    Connections {
        target: launchBarInstance
        onStartLaunchApplication: launchApplication(appId, appParams)
    }

    Connections {
        target: fullLauncherInstance
        onStartLaunchApplication: launchApplication(appId, appParams)
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
        onSwitchToDashboard: {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        onSwitchToMaximize: {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        onSwitchToFullscreen: {
            gestureAreaConnections.target = null;
            state = "hidden";
        }
        onSwitchToCardView: {
            gestureAreaConnections.target = gestureAreaInstance;
            state = "launchbar";
        }
        onSwitchToLauncherView: {
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
        onTapGesture: {
            state = "launchbar";
        }
        onSwipeUpGesture:{
            if( state === "launchbar" ) {
                state = "fullLauncher";
            }
            else {
                state = "launchbar";
            }
        }
        onSwipeLeftGesture:{
            state = "launchbar";
        }
    }

    WindowModel {
        id: launcherListModel
        windowTypeFilter: WindowType.Launcher

        onRowsInserted: {
            initJustTypeLauncherApp(launcherListModel.get(launcherListModel.count-1).window);
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
