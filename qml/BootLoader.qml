/*
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

Item {
    property Loader shellLoader

    LunaService {
        id: systemService
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            console.log("Calling boot status service ...");

            systemService.subscribe("palm://com.palm.bus/signal/registerServerStatus",
                               "{\"serviceName\":\"org.webosports.bootmgr\"}",
                               handleBootMgrStatus, handleError);
        }

        function handleBootMgrStatus(message) {
            var response = JSON.parse(message.payload);
            if (response.hasOwnProperty("connected") && response.connected) {
                systemService.subscribe("luna://org.webosports.bootmgr/getStatus",
                                        JSON.stringify({"subscribe":true}),
                                        handleBootStatusChanged,
                                        handleError);
            }
        }

        function handleBootStatusChanged(message) {
            console.log("Got response");
            var response = JSON.parse(message.payload);

            if( response.hasOwnProperty("state") ) {
                if( response.state === "firstuse" ) {
                    bootScreenItem.opacity = 0;
                    shellLoader.source = "FirstUseShell.qml";
                }
                else if ( response.state === "normal" ) {
                    bootScreenItem.opacity = 0;
                    shellLoader.source = "CardShell.qml";
                }
            }
        }

        function handleError(message) {
            console.log("Failed to call boot status service: " + message);
        }
    }

    // Boot screen animation
    Rectangle {
        id: bootScreenItem

        color: "black"

        anchors.fill: parent

        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 1000 }
        }

        /* glow percentage, between 0 and 1 */
        property real glow: 0

        Image {
            id: logoGlow
            anchors.centerIn: logoMoon
            source: "images/boot/glow-bg.png"
            width: Math.min(parent.width, parent.height)
            height: Math.min(parent.width, parent.height)
            fillMode: Image.PreserveAspectFit
            opacity: 0.1 + 0.9*bootScreenItem.glow
        }

        Image {
            id: logoMoon
            anchors.centerIn: parent
            source: "images/boot/moon.png"
            fillMode: Image.PreserveAspectFit
            opacity: 0.7 + 0.3*bootScreenItem.glow
        }

        Image {
            id: logoText
            anchors.horizontalCenter: logoMoon.horizontalCenter
            anchors.verticalCenter: logoMoon.verticalCenter
            anchors.verticalCenterOffset: 160
            source: "images/boot/lune-os-txt.png"
            fillMode: Image.PreserveAspectFit
        }

        SequentialAnimation {
            id: loadingAnimation
            running: true
            loops: Animation.Infinite

            NumberAnimation {
                target: bootScreenItem
                properties: "glow"
                from: 0
                to: 1
                easing.type: Easing.Linear
                duration: 1200
            }

            NumberAnimation {
                target: bootScreenItem
                properties: "glow"
                from: 1
                to: 0
                easing.type: Easing.Linear
                duration: 1200
            }
        }
    }
}
