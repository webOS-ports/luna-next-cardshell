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

import "CardView"
import "StatusBar"
import "LaunchBar"
import "WindowManager"
import "LunaSysAPI"
import "Utils"
import "Notifications"
import "Connectors"

Rectangle {
    id: root

    color: "black"
    state: cardShellState // inherited from the main shell Loader

    Preferences {
        id: preferences
    }

    Loader {
        id: reticleArea
        property bool showReticle: true
		
        Tweak {
        id: showTapRippleTweak
        owner: "luna-next-cardshell"
        key: "tapRippleSupport"
        defaultValue: true
        onValueChanged: updateShowTapRippleTweak();

        function updateShowTapRippleTweak() {
            if (showTapRippleTweak.value === true){
                console.log("INFO: Enabling Reticle Area...");
                reticleArea.showReticle = true;
            }
            else {
                console.log("INFO: Disabling Reticle Area...");
                reticleArea.showReticle = false;
            }
        }
    }

        anchors.fill: parent
        source: Settings.showReticle && showReticle ? "Utils/ReticleArea.qml" : ""
        z: 1000
    }

    DeviceKeyHandler {
        property Item gestureItem: cardsArea.gestureAreaInstance

        onHomePressed: {
            console.log("Key: Home");
            gestureItem.tapGesture();
        }
        onEndPressed: {
            console.log("Key: End");
            gestureItem.swipeUpGesture(0);
        }
        onEscapePressed: {
            console.log("Key: Escape");
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

        onShowPowerMenu: {
            powerMenuAlert.showPowerMenu();
        }
    }
}
