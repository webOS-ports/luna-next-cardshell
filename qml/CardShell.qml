/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
        anchors.fill: parent
        source: Settings.showReticle ? "Utils/ReticleArea.qml" : ""
        z: 1000
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
