/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import QtMultimedia 6.3

Item {
    id: batteryService

    property int level: -1
    property int percentage: 0
    property bool charging: false

    property bool powerdAvailable: false

    property bool _playSoundWhenCharged: false

    // Because powerd doesn't respond in error state, start there
    property bool error: true

    MediaPlayer {
        id: chargedSound
        source: "/usr/palm/sounds/battery_full.mp3"
        audioOutput: AudioOutput {}
    }

    MediaPlayer {
        id: batteryLowSound
        source: "/usr/palm/sounds/battery_low.mp3"
        audioOutput: AudioOutput {}
    }

    onPercentageChanged: {
        if (percentage < 95)
            _playSoundWhenCharged = true;
        else if (percentage === 100 && _playSoundWhenCharged) {
            _playSoundWhenCharged = false;
            chargedSound.play();
        }
        else if ((percentage === 20 || percentage === 10 || percentage === 5) && _playSoundWhenCharged)
        {
            batteryLowSound.play();
        }
    }

    LunaService {
        id: lunaService
        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true

        onInitialized: {
            lunaService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                                  "{\"serviceName\":\"com.palm.power\"}",
                                  handlePowerdServiceStatus, handleError);
            lunaService.subscribe("luna://com.palm.bus/signal/addmatch",
                                  "{\"category\":\"/com/palm/power\",\"method\":\"batteryStatus\"}",
                                  handlePowerdBatteryEvent, handleError);
            lunaService.subscribe("luna://com.palm.bus/signal/addmatch",
                                  "{\"category\":\"/com/palm/power\",\"method\":\"USBDockStatus\"}",
                                  handlePowerdUsbDockStatus, handleError);
        }
    }

    function handleError(message) {
        console.log("Service error: " + message);
    }

    function handlePowerdServiceStatus(message) {
        var response = JSON.parse(message.payload);

        powerdAvailable = response.connected;
        if (!powerdAvailable)
            batteryLevel = -1;
        else {
            /* query initial values */
            lunaService.call("luna://com.palm.power/com/palm/power/chargerStatusQuery",
                             "{}", handlePowerdUsbDockStatus, handleError);
            lunaService.call("luna://com.palm.power/com/palm/power/batteryStatusQuery",
                             "{}", handlePowerdBatteryEvent, handleError);
        }
    }

    function handlePowerdBatteryEvent(message) {
        var response = JSON.parse(message.payload);

        if (typeof response.percent_ui !== "undefined") {
            // Got a valid state, remove the error flag to show the indicator
            batteryService.error = false;
            // batteryLevel goes from 0 to 12.
            level = Math.floor((response.percent_ui * 12) / 100);
            percentage = response.percent_ui
        }
    }

    function handlePowerdUsbDockStatus(message) {
        var response = JSON.parse(message.payload);

        charging = response.Charging;
    }
}
