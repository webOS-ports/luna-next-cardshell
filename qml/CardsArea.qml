/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Common 0.1
import LunaNext.Shell 0.1
import LunaNext.Compositor 0.1
import LunaNext.Performance 0.1

import "CardView"
import "DockMode"
import "StatusBar"
import "LaunchBar"
import "WindowManager"
import "LunaSysAPI"
import "Utils"
import "Notifications"
import "Connectors"
import "LockScreen"

// The window manager manages the switch between different window modes
//     (card, maximized, fullscreen, ...)
// All the card related management itself is done by the CardView component
WindowManager {
    id: windowManager

    property real screenwidth: Settings.displayWidth
    property real screenheight: Settings.displayHeight
    property real screenDPI: Settings.dpi

    states: [
        State {
            name: "firstuse"
            PropertyChanges { target: gestureAreaInstance; height: 0 }
            PropertyChanges { target: lockScreen; isFirstUse: true }
        },
        State {
            name: "normal"
            PropertyChanges { target: gestureAreaInstance; height: Units.gu(4) }
            PropertyChanges { target: lockScreen; isFirstUse: false }
        }
    ]

    gestureAreaInstance: gestureAreaInstance

    focus: true
    Keys.forwardTo: [ gestureAreaInstance, launcherInstance, cardViewInstance, volumeControl ]

    onSwitchToCardView: {
        // we're back to card view so no card should have the focus
        // for the keyboard anymore
        if( compositor )
            compositor.clearKeyboardFocus();
    }

    Loader {
        anchors.top: parent.top
        anchors.left: parent.left

        width: 50
        height: 32

        // always on top of everything else!
        z: 1000

        Component {
            id: fpsTextComponent
            Text {
                color: "red"
                font.pixelSize: FontUtils.sizeToPixels("medium")
                text: fpsCounter.fps + " fps"

                FpsCounter {
                    id: fpsCounter
                }
            }
        }

        sourceComponent: systemService.fpsVisible ? fpsTextComponent : null;
    }

    /* Component already uses an Loader internally so need to do that again here */
    PerformanceOverlay {
        id: performanceOverlay
        z: 1000
        active: false
        onActiveChanged: {
            /* User can disable performance UI by clicking on it */
            if (active !== systemService.performanceUIVisible)
                systemService.performanceUIVisible = active;
        }
    }


    Item {
        id: background
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        z: -1; // the background item should always be behind other components

        Image {
            id: backgroundImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: preferences.wallpaperFile
            asynchronous: true
            smooth: true
            sourceSize: Qt.size(Settings.displayWidth, Settings.displayHeight)
        }
    }

    VolumeControl {
        id: volumeControl
    }

    ScreenShooter {
        id: screenShooter
    }

    Connections {
        target: gestureAreaInstance
        onSwipeRightGesture: screenShooter.capture("");
    }

    SystemService {
        id: systemService
        screenShooter: screenShooter
        cardViewInstance: cardViewInstance
        compositorInstance: compositor

        onPerformanceUIVisibleChanged: {
            performanceOverlay.active = performanceUIVisible;
        }
    }

    NotificationService {
        id: notificationService
    }

    CardView {
        id: cardViewInstance

        compositorInstance: compositor
        gestureAreaInstance: gestureAreaInstance
        windowManagerInstance: windowManager

        maximizedCardTopMargin: statusBarInstance.y + statusBarInstance.height

        anchors.top: parent.top
        anchors.bottom: notificationAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        onStateChanged: {
            if( cardViewInstance.state === "cardList" ) {
                cardViewInstance.z = 0;   // cardlist under all the rest
            }
            else if( cardViewInstance.state === "maximizedCard" ) {
                cardViewInstance.z = 2;   // active card over justtype and launcher, under dashboard and statusbar
            }
            else {
                cardViewInstance.z = 3;   // active card over everything
            }
        }

        visible: !lockScreen.visible
    }

    Launcher {
        id: launcherInstance

        gestureAreaInstance: gestureAreaInstance
        windowManagerInstance: parent

        anchors.top: statusBarInstance.bottom
        anchors.bottom: notificationAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible && !dockMode.visible

        z: 1 // on top of cardview when no card is active
    }

    NotificationArea {
        id: notificationAreaInstance

        windowManagerInstance: parent

        anchors.bottom: dashboardAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 2 // on top of cardview when no card is active
    }

    DashboardArea {
        id: dashboardAreaInstance

        anchors.bottom: alertWindowsAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 4 // just under the keyboard
    }

    AlertWindowsArea {
        id: alertWindowsAreaInstance

        anchors.bottom: gestureAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 4 // just under the keyboard
    }

    OverlaysManager {
        id: overlaysManagerInstance

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 4 // on top of everything (including fullscreen)
    }

    DockMode {
        id: dockMode

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager

        z: 5 // fullscreen window, above keyboard
    }

    SIMPinWindowArea {
        id: simPinWindowArea

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager

        visible: !lockScreen.visible && simPinWindowArea.simPinWindowPresent

        z: 5 // fullscreen window, above keyboard
    }

    LockScreen {
        id: lockScreen

        z: 700

        isFirstUse: false

        anchors.top: statusBarInstance.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    StatusBar {
        id: statusBarInstance

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Units.gu(3);

        z: 2 // can only be hidden by a fullscreen window

        windowManagerInstance: windowManager
        fullLauncherVisible: launcherInstance.fullLauncherVisible
        justTypeLauncherActive: launcherInstance.justTypeLauncherActive
        lockScreen: lockScreen
        dockMode: dockMode
    }

    LunaGestureArea {
        id: gestureAreaInstance

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Units.gu(4);

        visible: !lockScreen.visible

        z: 3 // the gesture area is in front of everything, like the fullscreen window
    }
}
