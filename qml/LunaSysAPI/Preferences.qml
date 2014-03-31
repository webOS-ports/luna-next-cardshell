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
    id: preferences

    property bool airplaneMode: false
    property bool rotationLock: false
    property bool muteSound: false

    property string wallpaperFile: ""

    //
    // private
    //

    onAirplaneModeChanged: systemService.setPreference("airplaneMode", preferences.airplaneMode)
    onRotationLockChanged: systemService.setPreference("rotationLock", preferences.rotationLock)
    onMuteSoundChanged: systemService.setPreference("muteSound", preferences.muteSound)

    LunaService {
        id: systemService

        name: "org.webosports.luna"

        property variant keysToWatch: ["wallpaper","airplaneMode","rotationLock","muteSound"]

        onInitialized: {
            console.log("Calling preferences service ...");

            // subscribe to preference change events so that we know when something has changed
            // and we can notify the relevant parts of the UI about this
            systemService.subscribe("palm://com.palm.systemservice/getPreferences",
                                    JSON.stringify({"keys": keysToWatch,"subscribe":true}),
                                    handlePreferencesChanged,
                                    handleError);
        }

        function handlePreferencesChanged(message) {
            var response = JSON.parse(message.payload);

            if (response.hasOwnProperty("wallpaper")) {
                preferences.wallpaperFile = response.wallpaper.wallpaperFile;
            }
            else if (response.hasOwnProperty("airplaneMode")) {
                preferences.airplaneMode = response.airplaneMode;
            }
            else if (response.hasOwnProperty("rotationLock")) {
                preferences.rotationLock = response.rotationLock;
            }
            else if (response.hasOwnProperty("muteSound")) {
                preferences.muteSound = response.muteSound;
            }
        }

        function handleError(message) {
            console.log("Failed to call preferences service: " + message);
        }

        function setPreference(key, value) {
            systemservice.call("palm://com.palm.systemservice/setPreferences",
                                    JSON.stringify({key:value}),
                                    function (message) { },
                                    handleError);
        }
    }
}
