/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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

Item {
    id: root

    visible: false

    anchors.centerIn: parent
    width: image.width + Units.gu(1)
    height: image.height

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: root.visible = false
    }

    Rectangle {
        id: imageBackground

        anchors.centerIn: parent
        anchors.fill: parent
        color: "black"
        opacity: 0.4
        radius: 4
    }

    Image {
        id:  image

        width: Units.gu(24)
		height: Units.gu(7.2)
        verticalAlignment: Image.AlignBottom;
        anchors.centerIn: parent
        opacity: 1.0
    }

    LunaService {
        id: audioService

        name: "org.webosports.luna"
        usePrivateBus: true

        onInitialized: {
            audioService.subscribe("luna://org.webosports.audio/getStatus",
                                   "{\"subscribe\":true}",
                                   onAudioStatusChanged, onError);
        }
    }

    function onAudioStatusChanged(message) {
        var response = JSON.parse(message.payload);

        // we don't indicate volume changes when sound is muted
        if (response.mute) {
            image.source = "../images/bell_off.png"
        }
        else {
            var normalizedVolume = 0;
            if (response.volume > 0)
                normalizedVolume = (Math.round(response.volume/10) - 1) * 10;
            if (normalizedVolume < 0)
                normalizedVolume = 0;
            image.source = ("../images/notification-music-indicator-" + normalizedVolume + ".png");
        }

        root.visible = true;
        hideTimer.start();
    }

    function onError(message) {
        console.log("Failed to call audio service: " + message);
    }
}
