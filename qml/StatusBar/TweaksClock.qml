/*
 * Copyright (C) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2017 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2017 Nikolay Nizov <nizovn@gmail.com>
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

import "../AppTweaks"

Item {
    id: title
    implicitWidth: titleText.contentWidth
    property string timeFormat: "HH24"
    property real fontSize: FontUtils.sizeToPixels("medium")
    signal triggered

    function probeTimeFormat()
    {
        timeFormatQuery.subscribe(
                    "luna://com.palm.systemservice/getPreferences",
                    JSON.stringify({"subscribe":true, "keys":["timeFormat"]}),
                    onTimeFormatChanged, onTimeFormatError)
    }

    function onTimeFormatChanged(message) {
        var response = JSON.parse(message.payload)
        timeFormat = response.timeFormat
    }

    function onTimeFormatError(message) {
        console.log("Failed to call timeFormat service: " + message)
    }

    LunaService {
        id: timeFormatQuery

        name: "org.webosports.luna"
        usePrivateBus: true

        onInitialized: {
            probeTimeFormat()
        }
    }

    Text {
        id: titleText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "white"
        font.family: Settings.fontStatusBar
        font.pixelSize: title.fontSize
        font.bold: true

        //Set the default to Time in case no Tweaks option has been set yet.
        Timer {
            id: clockTimer
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                titleText.updateClock()
                title.triggered()
            }
        }

        function updateClock() {
            if (AppTweaks.dateTimeTweakValue === "dateTime")
                titleText.text = timeFormat === "HH24" ? Qt.formatDateTime(new Date(),
                                                   "dd-MMM-yyyy h:mm") : Qt.formatDateTime(new Date(),
                                                   "dd-MMM-yyyy h:mm AP")
            else if (AppTweaks.dateTimeTweakValue === "timeOnly")
                titleText.text = timeFormat === "HH24" ? Qt.formatTime(new Date(), "h:mm") : Qt.formatTime(new Date(), "h:mm AP")
            else if (AppTweaks.dateTimeTweakValue === "dateOnly")
                titleText.text = Qt.formatDate(new Date(),
                                                   "dd-MMM-yyyy")
        }

        text: timeFormat === "HH24" ? Qt.formatDateTime(new Date(), "h:mm") : Qt.formatDateTime(new Date(), "h:mm AP")
    }
}
