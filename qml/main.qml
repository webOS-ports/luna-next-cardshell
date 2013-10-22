/****************************************************************************
**
** Copyright (C) 2012 Digia Plc and/or its subsidiary(-ies).
** Contact: http://www.qt-project.org/legal
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of Digia Plc and its Subsidiary(-ies) nor the names
**     of its contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

import QtQuick 2.0
import LunaNext 0.1

import "CardView"
import "StatusBar"
import "LaunchBar"
import "Dashboard"
import "WindowManager"
import "Utils" as Utils

// The compositor is exposed by the LunaNext module.
// It manages the creation/destruction of windows
// in accordance with the lifecycle of the apps.
Compositor {
    id: compositor

    width: Settings.displayWidth
    height: Settings.displayHeight

    Component.onCompleted: {
        compositor.show();
    }

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

        anchors.fill: parent

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

            function takeScreenshot() {
                nbScreenshotsTaken = nbScreenshotsTaken + 1
                screenShooter.capture("/tmp/luna-next-screenshot-" + nbScreenshotsTaken + ".png");
            }
        }
        Connections {
            target: gestureAreaInstance
            onSwipeRightGesture: screenShooter.takeScreenshot();
        }


        //////////  reticle on clic ///////////
        Loader {
            id: reticleArea
            anchors.fill: parent
            source: Settings.showReticle ? "Utils/ReticleArea.qml" : ""
            z: 1000
        }

        //////////  background ///////////
        Item {
            id: background
            anchors.top: statusBarInstance.bottom
            anchors.bottom: gestureAreaInstance.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            z: -1; // the background item should always be behind other components

            Image {
                id: backgroundImage

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: "images/background.jpg"
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

            Connections {
                target: windowManager
                onWindowWrapperCreated: {
                    if( windowWrapper.windowType === WindowType.Launcher ) {
                        // init the launcher
                        launcherInstance.initJustTypeLauncherApp(windowWrapper, winId);
                    }
                }
            }
        }

        OverlaysManager {
            id: overlaysManagerInstance

            windowManagerInstance: windowManager

            anchors.bottom: dashboardInstance.top // not sure about this one
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            z: 1 // on top of cardview

            Connections {
                target: windowManager
                onWindowWrapperCreated: {
                    if( windowWrapper.windowType === WindowType.Overlay ) {
                        // insert a new overlay on top of others
                        overlaysManagerInstance.appendOverlayWindow(windowWrapper, winId);
                    }
                }
                onWindowWrapperDestruction: {
                    if( windowWrapper.windowType === WindowType.Overlay ) {
                        // insert a new overlay on top of others
                        overlaysManagerInstance.removeOverlayWindow(windowWrapper, winId);
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
            height: windowManager.computeFromLength(24);

            z: 2 // can only be hidden by a fullscreen window

            windowManagerInstance: windowManager
        }

        //////////  rounded corners of the main view ///////////
        Utils.RoundedItem {
            anchors.top: statusBarInstance.bottom
            anchors.bottom: dashboardInstance.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            cornerRadius: windowManager.cornerRadius

            z: 2 // can only be hidden by a fullscreen window
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
            height: windowManager.computeFromLength(40);

            z: 3 // the gesture area is in front of everything, like the fullscreen window
        }

        // Utility to convert a pixel length expressed at DPI=132 to
        // a pixel length expressed in our DPI
        function computeFromLength(lengthAt132DPI) {
            return (lengthAt132DPI * (windowManager.screenDPI / 132.0));
        }

        function addNotification(notif) {
            dashboardInstance.addNotification(notif);
        }
    }
}
