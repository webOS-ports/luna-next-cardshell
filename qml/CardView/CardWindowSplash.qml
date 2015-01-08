/*
 * Copyright (C) 2013-2015 Simon Busch <morphis@gravedo.de>
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

Image {
    id: splash

    property string appIcon: ""

    readonly property string _defaultAppIcon: "../images/default-app-icon.png"

    visible: true
    state: "visible"
    source: "../images/loading-bg.png"

    states: [
        State { name: "visible" },
        State { name: "hidden" }
    ]

    transitions: [
        Transition {
            from: "visible"
            to: "hidden"
            SequentialAnimation {
                NumberAnimation { target: splash; property: "opacity"; from: 1; to: 0; duration: 300 }
                ScriptAction { script: splash.visible = false }
            }
        },
        Transition {
            from: "hidden"
            to: "visible"
            ScriptAction { script: { splash.visible = true; splash.opacity = 1.0; } }
        }
    ]

    Image {
        id: icon
        anchors.centerIn: loadingGlow
        source: appIcon.length === 0 ? _defaultAppIcon : appIcon
        width: Settings.splashIconSize
        height: Settings.splashIconSize
    }

    Image {
        id: loadingGlow
        anchors.centerIn: parent
        source: "../images/loading-glow.png"
        width: Settings.splashIconSize * 1.2
        height: Settings.splashIconSize * 1.2
    }

    SequentialAnimation {
        id: loadingAnimation
        running: true
        loops: Animation.Infinite

        NumberAnimation {
            target: loadingGlow
            properties: "opacity"
            from: 0.1
            to: 1.0
            easing.type: Easing.Linear
            duration: 700
        }

        NumberAnimation {
            target: loadingGlow
            properties: "opacity"
            from: 1.0
            to: 0.1
            easing.type: Easing.Linear
            duration: 700
        }
    }
}
