/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Alan Stice <alan@alanstice.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org> 
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
import LuneOS.Components 1.0
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
import "AppTweaks"

// The window manager manages the switch between different window modes
//     (card, maximized, fullscreen, ...)
// All the card related management itself is done by the CardView component
WindowManager {
    id: windowManager

    property real screenwidth: windowManager.width
    property real screenheight: windowManager.height
    property real screenDPI: Settings.dpi

    signal showPowerMenu()

    states: [
        State {
            name: "firstuse"
            PropertyChanges { target: gestureAreaInstance; height: 0 }
            PropertyChanges { target: lockScreen; isFirstUse: true }
            PropertyChanges { target: cardViewInstance; keepCurrentCardMaximized: false }
        },
        State {
            name: "normal"
            PropertyChanges { target: gestureAreaInstance; height: Units.gu(4) }
            PropertyChanges { target: lockScreen; isFirstUse: false }
            PropertyChanges { target: cardViewInstance; keepCurrentCardMaximized: false }
        }
    ]

    gestureAreaInstance: gestureAreaInstance
    property bool gesturesEnabled: !lockScreen.locked && !dockMode.visible && state === "normal"

    focus: true
    Keys.forwardTo: [ gestureAreaInstance, launcherInstance, cardViewInstance, volumeControl ]

    onSwitchToCardView: {
        // we're back to card view so no card should have the focus
        // for the keyboard anymore
        if( compositor )
            compositor.clearKeyboardFocus();
        focus = true;
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
            layer.mipmap: true
            sourceSize: Qt.size(screenwidth, screenheight)
        }
    }

    VolumeControl {
        id: volumeControl
    }

    ScreenShooter {
        id: screenShooter
    }

    ScreenShooterGradient {
        id: screenShooterGradient
        anchors.fill: parent
		z: 11
    }

    Connections {
        target: gestureAreaInstance
        onSwipeRightGesture: {
            screenShooter.capture("");
            screenShooterGradient.startShootEffect();
        }
    }

    Connections {
        target: gestureHandlerInstance
        onScreenEdgeFlickEdgeBottom: {
            if (!timeout && gestureAreaInstance.visible === false
                    && gesturesEnabled === true)
                gestureAreaInstance.swipeUpGesture(0);
        }
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

        maximizedCardTopMargin: cardViewInstance.state === "fullscreenCard" ? 0 : statusBarInstance.y + statusBarInstance.height

        anchors.top: parent.top
        anchors.bottom: cardViewInstance.state === "fullscreenCard" ? notificationAreaInstance.bottom : notificationAreaInstance.top
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
    }

    Launcher {
        id: launcherInstance

        gestureAreaInstance: gestureAreaInstance
        windowManagerInstance: parent

        anchors.top: statusBarInstance.bottom
        anchors.bottom: notificationAreaInstance.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1 // on top of cardview when no card is active
    }

    Loader {
        id: notificationAreaInstance

        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible

        z: 2 // on top of cardview when no card is active

        Component.onCompleted: if (!Settings.tabletUi) {
            notificationAreaInstance.setSource("Notifications/NotificationArea.qml",
                {"compositorInstance": compositor, "windowManagerInstance": parent, "maxDashboardWindowHeight": parent.height/2});
        }
    }

    AlertWindowsArea {
        id: alertWindowsAreaInstance

        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible
        windowManagerItem: windowManager
        compositorInstance: compositor

        z: 4 // just under the keyboard
    }

    OverlaysManager {
        id: overlaysManagerInstance

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        visible: !lockScreen.visible || lockScreen.needKeyboard
        compositorInstance: compositor

        z: 4 // on top of everything (including fullscreen)
    }

    DockMode {
        id: dockMode

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager

        z: 5 // fullscreen window, above keyboard
    }

    SIMPinWindowArea {
        id: simPinWindowArea

        anchors.top: statusBarInstance.bottom
        anchors.bottom: gestureAreaInstance.visible ? gestureAreaInstance.top : gestureAreaInstance.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        windowManagerInstance: windowManager

        visible: !lockScreen.visible && simPinWindowArea.simPinWindowPresent

        z: 5 // fullscreen window, above keyboard
    }

    LockScreen {
        id: lockScreen

        z: 700
		
        windowManagerInstance: windowManager

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
        gestureHandlerInstance: windowManager.gestureHandlerInstance
        fullLauncherVisible: launcherInstance.fullLauncherVisible
        justTypeLauncherActive: launcherInstance.justTypeLauncherActive
        compositorInstance: compositor

        onShowPowerMenu: windowManager.showPowerMenu();
    }

    LunaGestureArea {
        id: gestureAreaInstance

        Connections {
            target: AppTweaks
            onGestureAreaTweakValueChanged: updateShowGestureAreaTweak();

            function updateShowGestureAreaTweak() {
                if (AppTweaks.gestureAreaTweakValue === true){
                    console.log("INFO: Enabling Gesture Area...");
                    gestureAreaInstance.enableGestureArea = true;
                }
                else {
                    console.log("INFO: Disabling Gesture Area...");
                    gestureAreaInstance.enableGestureArea = false;
                }
            }
        }
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: gestureAreaInstance.enableGestureArea ? Units.gu(4) : Units.gu(0);

        visible: !lockScreen.visible && gestureAreaInstance.enableGestureArea

        z: 3 // the gesture area is in front of everything, like the fullscreen window
    }
}
