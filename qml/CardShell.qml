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
import LunaNext 0.1

import "CardView"
import "StatusBar"
import "LaunchBar"
import "Dashboard"
import "WindowManager"
import "LunaSysAPI"
import "Utils" as Utils
import "Alerts"

// The window manager has two roles:
//  1. it manages the creation/destruction of
//     window wrappers whenever the compositor (or
//     eventually the app itself) requests it.
//  2. it manages the switch between different window modes
//     (card, maximized, fullscreen)
WindowManager {
    id: windowManager

    property real screenwidth: Settings.displayWidth
    property real screenheight: Settings.displayHeight
    property real screenDPI: Settings.dpi

    defaultWindowWidth: Settings.displayWidth
    defaultWindowHeight: Settings.displayHeight - statusBarInstance.height - gestureAreaInstance.height

    dashboardInstance: dashboardInstance
    statusBarInstance: statusBarInstance
    gestureAreaInstance: gestureAreaInstance
    compositorInstance: compositor
    launcherInstance: launcherInstance

    focus: true
    Keys.forwardTo: [ gestureAreaInstance, launcherInstance, cardViewInstance, currentActiveWindowWrapper ]

    //////////  fps counter ///////////
    Loader {
        anchors.top: background.top
        anchors.left: background.left

        width: 50
        height: 32

        // always on top of everything else!
        z: 1000

        Component {
            id: fpsTextComponent
            Text {
                color: "red"
                font.pixelSize: 20
                text: fpsCounter.fps + " fps"

                FpsCounter {
                    id: fpsCounter
                }
            }
        }

        sourceComponent: Settings.displayFps ? fpsTextComponent : null;
    }

    //////////  screenshot component ///////////
    ScreenShooter {
        id: screenShooter

        property int nbScreenshotsTaken: 0

        function takeScreenshot(path) {
            screenShooter.capture(path);
        }
    }
    Connections {
        target: gestureAreaInstance
        onSwipeRightGesture: screenShooter.takeScreenshot();
    }

    ////////// System Service //////////

    SystemService {
        id: systemService
        screenShooter: screenShooter
        windowManager: windowManager
    }

    ////////// Preferences /////////////

    Preferences {
        id: preferences
    }

    //////////  reticle on clic ///////////
    Loader {
        id: reticleArea
        anchors.fill: parent
        source: Settings.showReticle ? "Utils/ReticleArea.qml" : ""
        z: 1000
    }

    PowerMenu {
        id: powerMenuAlert
        z: 800

        anchors.top: statusBarInstance.bottom
        anchors.right: launcherInstance.right
        anchors.margins: 20

        width: parent.width * 0.6
    }

    VolumeControlAlert {
        id: volumeControlAlert
        z: 900
    }

    //////////  background ///////////
    Item {
        id: background
        anchors.top: windowManager.top
        anchors.bottom: gestureAreaInstance.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right

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

    //////////  cardview ///////////
    CardView {
        id: cardViewInstance

        windowManagerInstance: windowManager

        anchors.top: windowManager.top
        anchors.bottom: dashboardInstance.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 0

        Connections {
            target: windowManager
            onWindowWrapperCreated: {
                if( windowWrapper.windowType === WindowType.Card ) {
                    // insert a new card at the end
                    cardViewInstance.appendCard(windowWrapper, winId);
                }
            }
            onWindowWrapperDestruction: {
                if( windowWrapper.windowType === WindowType.Card ) {
                    // remove the corresponding card
                    cardViewInstance.removeCard(windowWrapper, winId);
                }
            }
        }
    }

    //////////  launcher ///////////
    Launcher {
        id: launcherInstance

        gestureArea: gestureAreaInstance
        windowManagerInstance: windowManager

        anchors.top: statusBarInstance.bottom
        anchors.bottom: dashboardInstance.top // not sure about this one
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 1 // on top of cardview
    }

    OverlaysManager {
        id: overlaysManagerInstance

        windowManagerInstance: windowManager

        anchors.top: statusBarInstance.bottom
        anchors.bottom: dashboardInstance.top // not sure about this one
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 4 // on top of everything (including fullscreen)

        Connections {
            target: windowManager
            onOverlayWindowAdded: {
                if( window.windowType === WindowType.Overlay ) {
                    // insert a new overlay on top of others
                    overlaysManagerInstance.appendOverlayWindow(window);
                }
            }
            onOverlayWindowRemoval: {
                if( window.windowType === WindowType.Overlay ) {
                    // insert a new overlay on top of others
                    overlaysManagerInstance.removeOverlayWindow(window);
                }
            }
        }
    }

    //////////  status bar ///////////
    StatusBar {
        id: statusBarInstance

        anchors.top: windowManager.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right
        height: Units.length(24);

        z: 2 // can only be hidden by a fullscreen window

        windowManagerInstance: windowManager
        fullLauncherVisible: launcherInstance.fullLauncherVisible
        justTypeLauncherActive: launcherInstance.justTypeLauncherActive
    }

    //////////  notification area ///////////
    Dashboard {
        id: dashboardInstance

        windowManagerInstance: windowManager

        anchors.bottom: gestureAreaInstance.top
        anchors.left: windowManager.left
        anchors.right: windowManager.right

        z: 2 // can only be hidden by a fullscreen or overlay window

        Connections {
            target: windowManager
            onWindowWrapperCreated: {
                if( windowWrapper.windowType === WindowType.Dashboard ) {
                    // insert a new overlay on top of others
                    dashboardInstance.appendDashboardWindow(windowWrapper, winId);
                }
            }
            onWindowWrapperDestruction: {
                if( windowWrapper.windowType === WindowType.Dashboard ) {
                    // insert a new overlay on top of others
                    dashboardInstance.removeDashboardWindow(windowWrapper, winId);
                }
            }
        }
    }

    //////////  gesture area ///////////
    LunaGestureArea {
        id: gestureAreaInstance

        anchors.bottom: windowManager.bottom
        anchors.left: windowManager.left
        anchors.right: windowManager.right
        height: Units.length(40);

        z: 3 // the gesture area is in front of everything, like the fullscreen window
    }

    function addNotification(notif) {
        dashboardInstance.addNotification(notif);
    }
}
