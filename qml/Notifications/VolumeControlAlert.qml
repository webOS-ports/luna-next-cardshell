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
import LuneOS.Service 1.0
import LunaNext.Common 0.1

import "../Connectors"

Item {
    id: root

    visible: false

    anchors.centerIn: parent
    width: image.width + Units.gu(1)
    height: image.height

    property bool _hadFirstAudioStatus: false

    LunaService {
        id: playFeedback
        name: "org.webosports.luna"
        usePrivateBus: true
        service: "luna://org.webosports.audio"
        method: "playFeedback"
    }

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
        verticalAlignment: Image.AlignBottom;
        anchors.centerIn: parent
        opacity: 1.0
    }

    ServiceStatus {
        id: audioServiceStatus
        serviceName: "org.webosports.audio"
        onConnected: {
            audioService.subscribe("luna://org.webosports.audio/getStatus",
                                   "{\"subscribe\":true}",
                                   onAudioStatusChanged, onError);
        }
        onDisconnected: {
            console.log("Lost audio service!");
        }
    }

    LunaService {
        id: audioService

        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function onAudioStatusChanged(message) {
		var response = JSON.parse(message.payload);

        if (!_hadFirstAudioStatus) {
            _hadFirstAudioStatus = true;
            return;
        }

        playFeedback.call(JSON.stringify({"name":"AdjustVolume"}));

        // we don't indicate volume changes when sound is muted
        if (response.mute) {
            image.source = "../images/bell_off.png"
			image.width = Units.gu(9.6)
			image.height = Units.gu(9.6)
        }
        else {
            var normalizedVolume = 0;
            if (response.volume > 0)
                normalizedVolume = ((Math.round(response.volume/11))*10);
            if (normalizedVolume < 0)
                normalizedVolume = 0;
            image.source = ("../images/notification-music-indicator-" + normalizedVolume + ".png");
			image.width = Units.gu(24)
			image.height = Units.gu(7.2)
        }

        root.visible = true;
        hideTimer.start();
    }

    function onError(message) {
        console.log("Failed to call audio service: " + message);
    }
}
