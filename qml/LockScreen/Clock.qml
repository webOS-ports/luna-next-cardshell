/*
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.6
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import QtQml 2.2

Item {
    id: clockItem
    anchors.fill: parent
    property string timeFormat: "HH12"
    property string localeLanguage: "en"
    property string localeCountry: "en"
    property alias firstImageUrl: firstImage.source
    property alias secondImageUrl: secondImage.source
    property string timeSeparator: ""
    property alias thirdImageUrl: thirdImage.source
    property alias fourthImageUrl: fourthImage.source
    property alias fifthImageUrl: fifthImage.source
    property string screenLockImagePrefix: "../images/lockscreen/screen-lock-clock-"
    property string screenLockImageSuffix: ".png"

    function probePrefs()
    {
        prefsQuery.subscribe(
                            "luna://com.webos.service.systemservice/getPreferences",
                            JSON.stringify({"subscribe":true, "keys":["timeFormat", "locale"]}),
                            onPrefsChanged, onPrefsError)
    }

    function onPrefsChanged(message) {
        var response = JSON.parse(message.payload)
        if (response.timeFormat !== undefined) {

        timeFormat = response.timeFormat
        }

        if (response.locale.countryCode !== undefined) {
            localeCountry = response.locale.countryCode.toUpperCase()
        }
        if (response.locale.languageCode !== undefined) {
            localeLanguage = response.locale.languageCode
        }
    }

    function onPrefsError(message) {
        console.log("Failed to call timeFormat service: " + message)
    }

    function timeChanged() {
        firstImageUrl = screenLockImagePrefix.concat(timeFormat === "HH24" ? Qt.formatTime(new Date(), "hh:mm").substring(0,1) : Qt.formatTime(new Date(), "hh:mm AP").substring(0,1)).concat(screenLockImageSuffix)
        secondImageUrl = screenLockImagePrefix.concat(timeFormat === "HH24" ? Qt.formatTime(new Date(), "hh:mm").substring(1,2) : Qt.formatTime(new Date(), "hh:mm AP").substring(1,2)).concat(screenLockImageSuffix)

        var locale = Qt.locale(localeLanguage+"_"+localeCountry)
        if(locale.timeFormat().toUpperCase().indexOf("H.M")!==-1) {
            timeSeparator = "decimal"
        } else {
            timeSeparator = "colon"
        }

        thirdImageUrl = screenLockImagePrefix.concat(timeSeparator).concat(screenLockImageSuffix)
        fourthImageUrl = screenLockImagePrefix.concat(timeFormat === "HH24" ? Qt.formatTime(new Date(), "hh:mm").substring(3,4) : Qt.formatTime(new Date(), "hh:mm AP").substring(3,4)).concat(screenLockImageSuffix)
        fifthImageUrl = screenLockImagePrefix.concat(timeFormat === "HH24" ? Qt.formatTime(new Date(), "hh:mm").substring(4,5) : Qt.formatTime(new Date(), "hh:mm AP").substring(4,5)).concat(screenLockImageSuffix)
    }

    Timer {
        interval: 1000
        running: true
        triggeredOnStart :true
        repeat: true
        onTriggered: timeChanged()
    }


    LunaService {
        id: prefsQuery

        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true

        onInitialized: {
            probePrefs()
        }
    }

    Row {
        id: clockDigits
        height: Units.gu(8)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: (parent.height * 0.35) - (clockDigits.height * 2)
        children: [
        Image {
            id: firstImage
            source: firstImageUrl
            visible: (timeFormat === "HH24" && Qt.formatTime(new Date(), "hh:mm").substring(0,1) !== "0") || (timeFormat === "HH12" && Qt.formatTime(new Date(), "hh:mm AP").substring(0,1) !== "0")
            height: parent.height
            fillMode: Image.PreserveAspectFit
            mipmap: true
        },

        Image {
            id: secondImage
            source: secondImageUrl
            height: parent.height
            fillMode: Image.PreserveAspectFit
            mipmap: true
        },

        Image {
            id: thirdImage
            source: "../images/lockscreen/screen-lock-clock-colon.png" //thirdImageUrl
            height: parent.height
            fillMode: Image.PreserveAspectFit
            mipmap: true
        },

        Image {
            id: fourthImage
            source: fourthImageUrl
            height: parent.height
            fillMode: Image.PreserveAspectFit
            mipmap: true
        },

        Image {
            id: fifthImage
            source: fifthImageUrl
            height: parent.height
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }]
    }
}
