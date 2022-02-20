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
import LuneOS.Components 1.0
import LunaNext.Common 0.1
import LunaNext.Shell 0.1
import WebOSCompositorBase 1.0

import "CardView"
import "StatusBar"
import "LaunchBar"
import "WindowManager"
import "LunaSysAPI"
import "Utils"
import "Notifications"
import "Connectors"
import "AppTweaks"

Rectangle {
    id: root

    color: "black"
    state: cardShellState // inherited from the main shell Loader

    Preferences {
        id: preferences
    }

    Loader {
        id: reticleItem
        property bool showReticle: true

        Connections {
            target: AppTweaks
            function onShowTapRippleTweakValueChanged() {
                updateShowTapRippleTweak();
            }
        }

        function updateShowTapRippleTweak() {
            if (AppTweaks.showTapRippleTweakValue === true){
                console.log("INFO: Enabling Reticle Area...");
                reticleItem.showReticle = true;
            }
            else {
                console.log("INFO: Disabling Reticle Area...");
                reticleItem.showReticle = false;
            }
        }

        source: Settings.showReticle && showReticle ? "Utils/ReticleItem.qml" : ""
        z: 1000
    }

    DeviceKeyHandler {
        property Item gestureItem: cardsArea.state==="normal"? cardsArea.gestureAreaInstance : null;

        onHomePressed: {
            console.log("Key: Home");
            if (gestureItem !== null)
                gestureItem.tapGesture();
        }
        onEndPressed: {
            console.log("Key: End");
            if (gestureItem !== null)
                gestureItem.swipeUpGesture(0);
        }
        onEscapePressed: {
            console.log("Key: Escape");
            if (gestureItem !== null)
                gestureItem.swipeLeftGesture(0);
        }
        onF6Pressed: {
            console.log("Key: F6");
            orientationHelper.setOrientation(0);
        }
        onF7Pressed: {
            console.log("Key: F7");
            orientationHelper.setOrientation(180);
        }
        onF8Pressed: {
            console.log("Key: F8");
            orientationHelper.setOrientation(270);
        }
        onF9Pressed: {
            console.log("Key: F9");
            orientationHelper.setOrientation(90);
        }
    }

    GestureHandler {
        id: gestureHandler
        fingerSize: Units.gu(5)
        minimalFlickLength: Units.gu(10)
        timeout: 2000
        height: orientationHelper.height
        width: orientationHelper.width

        signal screenEdgeFlickEdgeLeft(bool timeout,point pos)
        signal screenEdgeFlickEdgeRight(bool timeout, point pos)
        signal screenEdgeFlickEdgeTop(bool timeout,point pos)
        signal screenEdgeFlickEdgeBottom(bool timeout, point pos)

        onTouchBegin: orientationHelper.setLocked(true);
        onTouchEnd: orientationHelper.setLocked(false);
        onGestureEvent: {
            var screenPos = orientationHelper.convertRawPos(pos);

            switch (gestureType) {
            case GestureHandler.TapGesture:
                if (reticleItem.status === Loader.Ready)
                    reticleItem.item.startAt(screenPos);
                break;
            case GestureHandler.ScreenEdgeFlickGesture:
                if (screenPos.y < fingerSize) {
                    screenEdgeFlickEdgeTop(timeout, screenPos);
                } else if (screenPos.y > gestureHandler.height - fingerSize) {
                    screenEdgeFlickEdgeBottom(timeout, screenPos);
                } else if (screenPos.x < fingerSize) {
                    screenEdgeFlickEdgeLeft(timeout, screenPos);
                } else if (screenPos.x > gestureHandler.width - fingerSize) {
                    screenEdgeFlickEdgeRight(timeout, screenPos);
                }
                break;
            }
        }
    }

    VolumeControlAlert {
        id: volumeControlAlert
        z: 900
    }

    PowerMenu {
        id: powerMenuAlert
        z: 800

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Units.gu(5)
        anchors.rightMargin: Units.gu(1)

        width: parent.width * 0.6
    }

    CardsArea {
        id: cardsArea
        anchors.fill: parent

        state: root.state
        gestureHandlerInstance: gestureHandler

        onShowPowerMenu: {
            powerMenuAlert.showPowerMenu();
        }
    }
}
