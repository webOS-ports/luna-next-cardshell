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

    /*
     * Every battery batteryd knows about, primary first, as
     * { name, role, label, primary, present, charging, percentage, level }.
     * Empty on a device with a single battery: batteryd only sends the array
     * when there is more than one, and level/percentage/charging above always
     * describe the primary one, so nothing has to read this to work.
     */
    property var batteries: []

    /*
     * The batteries that are not the primary one and are actually there - the
     * PinePhone keyboard's while the phone is docked in it. What the status bar
     * shows in addition to its usual indicator.
     */
    property var auxBatteries: []

    property bool batterydAvailable: false

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

        onInitialized: {
            lunaService.subscribe("luna://com.palm.bus/signal/registerServerStatus",
                                  "{\"serviceName\":\"com.webos.service.battery\"}",
                                  handleBatterydServiceStatus, handleError);
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

    function handleBatterydServiceStatus(message) {
        var response = JSON.parse(message.payload);

        batterydAvailable = response.connected;
        if (!batterydAvailable)
            batteryLevel = -1;
        else {
            /* query initial values */
            lunaService.call("luna://com.webos.service.battery/com/palm/power/chargerStatusQuery",
                             "{}", handlePowerdUsbDockStatus, handleError);
            lunaService.call("luna://com.webos.service.battery/com/palm/power/batteryStatusQuery",
                             "{}", handlePowerdBatteryEvent, handleError);
        }
    }

    // batteryLevel goes from 0 to 12.
    function __levelForPercentage(percentUi) {
        return Math.floor((percentUi * 12) / 100);
    }

    // What to call a battery in the UI. batteryd names the role, not the label,
    // so a role nobody has taught us about still reads as something.
    function __labelForRole(role) {
        if (role === "main" || !role)
            return "Battery";
        if (role === "keyboard")
            return "Keyboard";
        return role.charAt(0).toUpperCase() + role.slice(1);
    }

    function handlePowerdBatteryEvent(message) {
        var response = JSON.parse(message.payload);

        /*
         * Not every payload that reaches here is a battery status. Subscribing
         * to the addmatch signal is acknowledged with a bare
         * {"returnValue":true}, and on a cardshell restart that ack races the
         * reply to batteryStatusQuery. Rebuilding the list below from an ack
         * emptied it, so whether the keyboard indicator appeared came down to
         * which of the two arrived last - the same coin flip, one layer up.
         * percent_ui is in every real status and in nothing else.
         */
        if (typeof response.percent_ui === "undefined")
            return;

        // Got a valid state, remove the error flag to show the indicator
        batteryService.error = false;
        level = __levelForPercentage(response.percent_ui);
        percentage = response.percent_ui

        /*
         * batteryd sends "batteries" only on a device that has more than one -
         * a PinePhone (Pro) docked in its keyboard. Its absence means the one
         * battery already described above, so the lists stay empty and every
         * consumer of level/percentage carries on unchanged.
         */
        var all = [];

        if (response.batteries instanceof Array) {
            for (var i = 0; i < response.batteries.length; i++) {
                var battery = response.batteries[i];

                all.push({
                    "name": battery.name,
                    "role": battery.role,
                    "label": __labelForRole(battery.role),
                    "primary": battery.primary === true,
                    "present": battery.present === true,
                    "charging": battery.charging === true,
                    "percentage": battery.percent_ui,
                    "level": __levelForPercentage(battery.percent_ui)
                });
            }
        }

        batteries = all;
        auxBatteries = all.filter(function(battery) {
            return !battery.primary && battery.present;
        });
    }

    function handlePowerdUsbDockStatus(message) {
        var response = JSON.parse(message.payload);

        charging = response.Charging;
    }
}
