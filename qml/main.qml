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

import "CardView" as CardView
import "StatusBar"
import "LaunchBar"
import "LunaGestureArea"
import "NotificationArea"
import "Compositor"
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

        notificationsContainer: notificationsContainer
        cardView: cardViewDisplay
        statusBar: statusBarDisplay
        gestureArea: gestureAreaDisplay

        Loader {
            anchors.top: windowManager.top
            anchors.left: windowManager.left

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


        Loader {
            id: reticleArea
            anchors.fill: parent
            source: Settings.showReticle ? "Utils/ReticleArea.qml" : ""
        }

        // background
        Item {
            id: background
            anchors.top: statusBarDisplay.bottom
            anchors.bottom: gestureAreaDisplay.top
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

            RoundedItem {
                anchors.fill: parent
                cornerRadius: windowManager.cornerRadius
            }
        }

        // cardview
        CardView.CardView {
            id: cardViewDisplay

            anchors.top: windowManager.top
            anchors.bottom: gestureAreaDisplay.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            z: 0

            Connections {
                target: windowManager
                onWindowWrapperCreated: {
                    // insert a new card at the end
                    cardViewDisplay.appendCard(windowWrapper, winId);
                }
            }
        }

        // bottom area: launcher bar
        AppLauncher {
            id: appLauncherDisplay

            itemAboveLauncher: statusBarDisplay
            itemUnderLauncher: gestureAreaDisplay

            anchors.left: windowManager.left
            anchors.right: windowManager.right

            Connections {
                target: launchBarDisplay
                onToggleLauncherDisplay: appLauncherDisplay.toggleDisplay()
            }

            z: 1 // on top of cardview
        }

        // bottom area: launcher bar
        LaunchBar {
            id: launchBarDisplay

            anchors.bottom: gestureAreaDisplay.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            z: 1 // on top of cardview
        }

        // top area: status bar
        StatusBar {
            id: statusBarDisplay

            anchors.top: windowManager.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right
            height: windowManager.computeFromLength(30);

            z: 2 // can only be hidden by a fullscreen window
        }

        // notification area
        NotificationsContainer {
            id: notificationsContainer

            anchors.bottom: gestureAreaDisplay.top
            anchors.left: windowManager.left
            anchors.right: windowManager.right

            z: 2 // can only be hidden by a fullscreen window
        }

        // gesture area
        LunaGestureArea {
            id: gestureAreaDisplay

            anchors.bottom: windowManager.bottom
            anchors.left: windowManager.left
            anchors.right: windowManager.right
            height: windowManager.computeFromLength(16);

            z: 3 // the gesture area is in front of everything, like the fullscreen window

            onSwipeUpGesture:{
                cardWindowOrShowLauncher();
            }
            onTapGesture: {
                cardWindowOrShowLauncher();
            }

            function cardWindowOrShowLauncher() {
                if( windowManager.currentActiveWindowWrapper ) {
                    windowManager.setToCard(windowManager.currentActiveWindowWrapper);
                }
                else {
                    // toggle launcher
                    appLauncherDisplay.toggleDisplay();
                }
            }
        }

        // Utility to convert a pixel length expressed at DPI=132 to
        // a pixel length expressed in our DPI
        function computeFromLength(lengthAt132DPI) {
            return (lengthAt132DPI * (windowManager.screenDPI / 132.0));
        }

        function addNotification(notif) {
            notificationsContainer.addNotification(notif);
        }
    }
}
