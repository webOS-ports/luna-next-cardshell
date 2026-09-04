/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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

// Wraps luna-appmanager's dock-mode launch point list - the same
// listDockModeLaunchPoints/addDockModeLaunchPoint/removeDockModeLaunchPoint
// LS2 calls org.webosports.app.settings' Exhibition page already uses to let
// the user pick which apps are exhibition-enabled. This component only
// reads the result; enabling/disabling an app stays the Settings app's job.
QtObject {
    id: dockModeLaunchPointsModel

    // Every launch point the service knows about, exactly as returned. A
    // real reply (verified against webOS 3.0.5's LunaSysMgr, which
    // luna-appmanager derives from) carries rather more than the id and the
    // enabled flag:
    //
    //   { "id": "com.palm.app.photos", "appId": "com.palm.app.photos",
    //     "title": "Photos & Videos", "exhibitionMode": true,
    //     "exhibitionModeTitle": "Photos", "enabled": true,
    //     "icon": "/media/cryptofs/apps/.../icon.png", ... }
    property var launchPoints: []

    // Just the ones the user ticked on, in the order the service returns
    // them - this is what the exhibition carousel shows. Normalised here so
    // that the carousel and the switcher don't each have to know the quirks:
    //
    //  - exhibitionModeTitle is the name the application asked to be shown
    //    under in exhibition mode (appinfo.json's exhibitionModeOptions.title,
    //    e.g. "Photos" rather than the launcher's "Photos & Videos"), so it
    //    wins over the plain title when present.
    //  - icon comes back as an absolute path already, saving a getAppInfo
    //    round-trip per application.
    //  - appId falls back to id, the way LunaSysAPI/ApplicationModel.qml
    //    already guards against a reply that only carries the latter.
    readonly property var enabledApps: launchPoints
        .filter(function (launchPoint) { return launchPoint.enabled === true; })
        .map(function (launchPoint) {
            return {
                "appId": launchPoint.appId || launchPoint.id,
                "title": launchPoint.exhibitionModeTitle || launchPoint.title,
                "icon": launchPoint.icon || ""
            };
        })

    property LunaService service: LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            service.subscribe("luna://com.palm.applicationManager/listDockModeLaunchPoints",
                JSON.stringify({"subscribe": true}), handleResponse, handleError);
        }

        function handleResponse(message) {
            var response = JSON.parse(message.payload);
            if (response.returnValue && response.launchPoints !== undefined)
                dockModeLaunchPointsModel.launchPoints = response.launchPoints;
        }

        function handleError(message) {
            console.log("DockModeLaunchPointsModel: failed to query dock-mode launch points: " + message);
        }
    }
}
