/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import QtMultimedia 6.3

Item {
    property Loader shellLoader

    property bool wentThroughFirstUse: false

    MediaPlayer {
        id: bootSound
        source: "/usr/palm/sounds/boot.mp3"
        audioOutput: AudioOutput {}
    }

    // The boot sound used to start the moment bootmgr reported the boot
    // state - ~0.1 s before audiod registered. audiod's start-up then ran
    // initStreamVolume (volume 0 / mute / real volume, sink by sink) right
    // through it, and the sound crackled on every boot while the same file
    // played cleanly any other time. Play it once audiod is up and has had a
    // moment to settle (its bus name appears before initStreamVolume is done,
    // hence 2.5 s); the boot screen itself is not held back.
    property bool bootSoundRequested: false
    property bool audioServiceUp: false

    function maybePlayBootSound() {
        if (bootSoundRequested && audioServiceUp
                && bootSound.playbackState !== MediaPlayer.PlayingState)
            bootSound.play();
    }

    Timer {
        id: audioSettleDelay
        interval: 2500
        onTriggered: {
            audioServiceUp = true;
            maybePlayBootSound();
        }
    }

    LunaService {
        id: systemService
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: {
            console.log("Calling boot status service ...");

            systemService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                               "{\"serviceName\":\"org.webosports.bootmgr\"}",
                               handleBootMgrStatus, handleError);
            systemService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                               "{\"serviceName\":\"com.webos.service.audio\"}",
                               handleAudioStatus, handleError);
        }

        function handleAudioStatus(message) {
            var response = JSON.parse(message.payload);
            if (response.hasOwnProperty("connected") && response.connected)
                audioSettleDelay.start();
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

                bootSoundRequested = true;
                maybePlayBootSound();
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

        /* Size of the logo artwork as a fraction of the screen's short edge,
           so the logo takes the same share of the screen on every device.
           Left at its native size, the 720x720 artwork filled a 720p screen
           but shrank to half of a 1440p one. 1.0 keeps the look the Q25
           (720x720) always had, where it was drawn 1:1: the logo itself is
           307px of that canvas, 43% of the short edge, the rest is room for
           the glow. Both PNGs share the canvas, so the glow keeps lining up. */
        property real logoFraction: 1.0
        property real canvasSize: Math.min(width, height) * logoFraction

        /* The artwork comes at 720, 1440 (@2x) and 2880 (@4x) px; the source is
           graphics/psd/LuneOS-bootscreen@4x.psd. Pick the smallest one that is
           not scaled up: decoding the 4x PNGs costs ~10x the 1x ones, which a
           small armv7 device would spend with the screen still black. The
           size passes through 0 and other transient values during layout, so
           the tier is chosen once it has settled; otherwise the 1x art would
           be decoded first and thrown away. */
        property string artSuffix: ""
        function pickArt() {
            if (canvasSize > 0)
                artSuffix = canvasSize > 1440 ? "@4x" : canvasSize > 720 ? "@2x" : "@1x";
        }
        onCanvasSizeChanged: Qt.callLater(pickArt)
        function artSource(name) {
            if (artSuffix === "")
                return "";
            return "images/lune-os-bootscreen-" + name + "-alpha"
                    + (artSuffix === "@1x" ? "" : artSuffix) + ".png";
        }

        Image {
            id: logoNormal
            anchors.centerIn: parent
            width: bootScreenItem.canvasSize
            height: bootScreenItem.canvasSize
            source: bootScreenItem.artSource("idle")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Image {
            id: logoGlow
            anchors.centerIn: logoNormal
            width: bootScreenItem.canvasSize
            height: bootScreenItem.canvasSize
            source: bootScreenItem.artSource("glowing")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
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
