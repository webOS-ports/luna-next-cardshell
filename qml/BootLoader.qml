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
import LunaNext.Common 0.1
import QtMultimedia 5.4

Item {
    property Loader shellLoader

    property bool wentThroughFirstUse: false

    Audio {
        id: bootSound
        source: "/usr/palm/sounds/boot.mp3"
    }

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
                console.log("boot state changed to: " + response.state);
                if( response.state === "firstuse" || response.state === "normal" )
                    shellLoader.state = response.state;

                bootSound.play();
                shellLoader.source = "CardShell.qml";
                bootScreenItem.opacity = 0;
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

        Image {
            id: logoNormal
            anchors.centerIn: parent
            source: "images/lune-os-bootscreen-idle-alpha.png"
            fillMode: Image.PreserveAspectFit
        }

        Image {
            id: logoGlow
            anchors.centerIn: logoNormal
            source: "images/lune-os-bootscreen-glowing-alpha.png"
            fillMode: Image.PreserveAspectFit
            opacity: 0.1
        }

        SequentialAnimation {
            id: loadingAnimation
            running: bootScreenItem.visible
            loops: Animation.Infinite

            NumberAnimation {
                target: logoGlow
                properties: "opacity"
                from: 0.1
                to: 1.0
                easing.type: Easing.Linear
                duration: 700
            }

            NumberAnimation {
                target: logoGlow
                properties: "opacity"
                from: 1.0
                to: 0.1
                easing.type: Easing.Linear
                duration: 700
            }
        }
    }
}
