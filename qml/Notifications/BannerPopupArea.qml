/*
 * Copyright (C) 2015-2016 Christophe Chapuis <chris.chapuis@gmail.com>
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

import QtQuick 2.0
import QtMultimedia 5.5
import LuneOS.Service 1.0
import LunaNext.Common 0.1

Item {
    id: bannerItemsPopups
    property string color: Settings.tabletUi? "transparent" : "black";

    property ListModel popupModel: ListModel {
        id: bannerItemsModel
    }

    clip: true

    IconPathServices {
           id: iconPathServices
    }

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    LunaService {
            id: systemService

            name: "org.webosports.luna"

            property variant keysToWatch: ["ringtone","alerttone","notificationtone","locale"]

            onInitialized: {
                console.log("Calling preferences service for system sounds and locale...");

                // subscribe to preference change events so that we know when something has changed
                // and we can notify the relevant parts about this
                systemService.call("luna://com.palm.systemservice/getPreferences",
                                        JSON.stringify({"keys": keysToWatch,"subscribe":true}),
                                        handlePreferencesResponse,
                                        handleError);
            }

            function handlePreferencesResponse(message) {
                var response = JSON.parse(message.payload);

                if (response.hasOwnProperty("ringtone")) {
                    preferences.ringtoneFullPath = response.ringtone.fullPath;
                }
                if (response.hasOwnProperty("alerttone")) {
                    preferences.alerttoneFullPath = response.alerttone.fullPath;
                }
                if (response.hasOwnProperty("notificationtone")) {
                    preferences.notificationtoneFullPath = response.notificationtone.fullPath;
                }
                if (response.hasOwnProperty("locale")) {
                    preferences.locale = response.locale.languageCode+"_"+response.locale.countryCode;
                }
            }

            function handleError(message) {
                console.log("Failed to call preferences service: " + message);
            }
        }

    Loader {
        active: !Settings.tabletUi
        sourceComponent: Component {
            Rectangle {
                color: bannerItemsPopups.color
                anchors.fill: parent
            }
        }
    }

    function isEmpty(str) {
        if (typeof str == 'undefined' || !str || str.length === 0 || str === "" || !/[^\s]/.test(str) || /^\s*$/.test(str))
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    function getResourcePathFromString(entry, appId, systemResourceFolder)
    {
        var basePathRoot = "";
        if (isEmpty(entry))
            return "";

        // Absolute path?
        if (entry[0] === '/') {
            if (FileUtils.exists(entry)){
                return entry;
            }
        }

        // relative path. first check in the app folder
        service.call("luna://com.palm.applicationManager/getAppBasePath",
                     JSON.stringify({"appId":appId}),
                     handleGetAppInfoResponse, handleGetAppInfoError);

        function handleGetAppInfoResponse(message) {
            var response = JSON.parse(message.payload);
            if (response.returnValue && response.basePath){
                var basePath = response.basePath;
                var appFolder = basePath.match(/(.*)[\/\\]/)[1]||'';

                // Try the locale in the resources folder used by both Enyo 1 and 2.
                basePathRoot = appFolder + "/resources/" + preferences.locale + "/" + entry;
                if (FileUtils.exists(basePathRoot)){
                    return basePathRoot;
                }

                // Try in the Enyo 2 assets folder path
                basePathRoot = appFolder + "/assets/" + entry;
                if (FileUtils.exists(basePathRoot)){
                    return basePathRoot;
                }

                // Try in the standard app folder path
                basePathRoot = appFolder + "/" + entry;
                if (FileUtils.exists(basePathRoot)){
                    return basePathRoot;
                }
            }
        }

        function handleGetAppInfoError(error) {
            console.log("Could not retrieve information about current application: " + error);
        }

        // Look for it in the system folder
        basePathRoot = systemResourceFolder + "/" + entry;
        if (FileUtils.exists(basePathRoot)){
            return basePathRoot;
        }

        // ah well... we give up
        return "";
    }

    function getSoundFilePath(soundFilePath, soundFile, soundClass, appId) {
        if (isEmpty(soundFilePath) &&isEmpty(soundClass) && isEmpty(soundFile)){
            return "";
        }

        if (soundClass === "none"){
            return "";
        }

        if (soundClass === "vibrate") {
            //FIXME: We don't have vibrateNamedEffect implemented yet, so not calling it here, we're using regular vibrate for now
            //luna://com.palm.vibrate/vibrateNamedEffect '{"name":"notifications"}';
            service.call("luna://com.palm.vibrate/vibrate",
                         JSON.stringify({"period": 500, "duration": 200}),
                         undefined,
                         console.log("Unable to vibrate"));
            return "";
        }

        var streamClass = soundClass;

        if (streamClass === "alert"){
            streamClass = "alerts";
        } else if (streamClass === "notification") {
            streamClass = "notifications";
        } else if (streamClass === "ringtone") {
            streamClass = "ringtones";
        }
        if (streamClass !== "alerts" &&
                streamClass !== "alarm" &&
                streamClass !== "calendar" &&
                streamClass !== "notifications" &&
                streamClass !== "ringtones" &&
                streamClass !== "feedback"){
            streamClass = "notifications";
        }

        var mySoundFilePath = "";

        if(!isEmpty(soundFilePath)){
            mySoundFilePath = soundFilePath;
        }

        if(!isEmpty(soundFile)){
            mySoundFilePath = getResourcePathFromString(soundFile, appId, Settings.lunaSystemSoundsPath);
        }

        if (isEmpty(soundFilePath)) {
            if (streamClass === "ringtones") {
                mySoundFilePath = preferences.ringtoneFullPath;
            } else if (streamClass === "alerts" ||
                       streamClass === "alarm"  ||
                       streamClass === "calendar") {
                mySoundFilePath = preferences.alerttoneFullPath;
            } else {
                mySoundFilePath = preferences.notificationtoneFullPath;
            }
        }

        if (isEmpty(mySoundFilePath)) {
            if(FileUtils.exists(Settings.lunaSystemSoundsPath + "/" + Settings.lunaDefaultAlertSound)){
                mySoundFilePath = Settings.lunaSystemSoundsPath + "/" + Settings.lunaDefaultAlertSound;
            }
        }

        if (isEmpty(mySoundFilePath)) {
            return "";
        }
        if(FileUtils.exists(mySoundFilePath)){
            return mySoundFilePath;
        } else {
            return "";
        }
    }

    function getSoundFileDuration(duration){
        var soundFileDuration;

        if (duration <= 0) {
            soundFileDuration = -1; // use the duration of the file
        }
        // If stream class is of type notifications, then cap duration to maximum allowed by system
        if (streamClass === "notifications" && duration <= 0) {
            soundFileDuration = Settings.notificationSoundDuration;
        }
        return soundFileDuration;
    }

    property int visibleWidth: {
        var max = 0;
        for(var i=0; i<bannerItemsPopups.children.length; i++) {
            max = Math.max(max, bannerItemsPopups.children[i].width);
        }
        return max;
    }

        Repeater {
        model: bannerItemsModel
        delegate:Rectangle {
            id: itemDelegate
            color: bannerItemsPopups.color
            width: Settings.tabletUi? 0 : bannerItemsPopups.width;
            height: Units.gu(3)
            y: Settings.tabletUi? 0 : Units.gu(3);
            anchors.right: Settings.tabletUi? parent.right : undefined;

            property int delegateIndex: index

            Audio {
                id: notifsound
                source: getSoundFilePath(object.soundFilePath, object.soundFile, object.soundClass, object.ownerId)
                //FIXME: We need to be able to set playback duration, seems duration in Audio is readonly and we'll need a Timer or NumberAnimation for this?
                //duration: getSoundFileDuration (object.duration)
            }

            Row {
                anchors.fill: parent
                anchors.margins: 0.5*Units.gu(1)
                spacing: Units.gu(0.8)

                Image {
                    id: freshItemIcon
                    height: parent.height
                    width: parent.height
                    fillMode: Image.PreserveAspectFit

                    function setSourceIcon(resolvedUrl) {
                        freshItemIcon.source = resolvedUrl;
                    }

                    Component.onCompleted: {
                        iconPathServices.setIconUrlOrDefault(object.iconPath, object.ownerId, setSourceIcon);
                    }
                }
                Text {
                    id: notifTitle
                    height: parent.height
                    width: parent.width - freshItemIcon.width
                    text: object.title.length > 0 ? object.body.length > 0 ? object.title + ": " + object.body : object.title : object.body
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    font.bold: false
                    color: "white"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }

            SequentialAnimation {
                id: slideItemAnimation
                running: false

                NumberAnimation {
                    target: itemDelegate
                    property: Settings.tabletUi? "width" : "y";
                    to: Settings.tabletUi? bannerItemsPopups.width : 0;
                    duration: 500;
                    easing.type: Easing.InOutQuad
                }

                ScriptAction {
                    script: {
                        if(!isEmpty(notifsound.source))
                        {
                            notifsound.play();
                        }

                    }
                }
                PauseAnimation { duration: Settings.tabletUi? 0 : 1500; }

                ScriptAction {
                    script: if (Settings.tabletUi)
                                timerAnimation.start();
                            else
                                bannerItemsModel.remove(delegateIndex);
                }
            }

            Timer {
                id: timerAnimation
                running: false
                interval: 3000
                onTriggered: {
                    slideOutItemAnimation.start();
                }
            }

            SequentialAnimation {
                id: slideOutItemAnimation
                running: false

                NumberAnimation {
                    target: itemDelegate
                    property: "width"; to: 0; duration: 500; easing.type: Easing.InOutQuad
                }

                ScriptAction {
                    script: bannerItemsModel.remove(delegateIndex);
                }
            }

            onDelegateIndexChanged: {
                if( (delegateIndex === 0) && !Settings.tabletUi )
                    slideItemAnimation.start();
            }

            Connections {
                target: Settings.tabletUi? bannerItemsPopups.popupModel : null;
                onCountChanged: {
                    if (delegateIndex < bannerItemsPopups.popupModel.count-1) {
                        itemDelegate.opacity = 0.5;
                        if (timerAnimation.running) {
                            timerAnimation.stop();
                            timerAnimation.triggered();
                        }
                        else
                            timerAnimation.interval = 0;
                    }
                }
            }

            Component.onCompleted: {
                if( delegateIndex === 0 )
                    slideItemAnimation.start();
                else if (Settings.tabletUi)
                    slideItemAnimation.start();
            }
        }
    }
}

