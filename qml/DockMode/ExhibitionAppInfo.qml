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

// listDockModeLaunchPoints only carries an application's id and title, so its
// icon has to be looked up separately - the same getAppInfo lookup the rest
// of the shell uses (see StatusBar/AppMenu.qml and
// Notifications/IconPathServices.qml).
QtObject {
    id: exhibitionAppInfo

    property LunaService service: LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
    }

    // Resolves appId's icon and hands the path to setterFct. Stays quiet if
    // the application has no icon: callers fall back to the default one.
    function resolveIcon(appId, setterFct) {
        if (!appId || appId.length === 0)
            return;

        service.call("luna://com.webos.service.applicationManager/getAppInfo",
            JSON.stringify({"id": appId}),
            function (message) {
                var response = JSON.parse(message.payload);
                if (!response.returnValue || !response.appInfo)
                    return;

                var icon = response.appInfo.icon || response.appInfo.miniicon;
                var folderPath = response.appInfo.folderPath;
                if (!icon || !folderPath)
                    return;

                // An absolute icon path is used as-is, a relative one is
                // taken from the application's own folder.
                setterFct(icon[0] === '/' ? icon : folderPath + "/" + icon);
            },
            function (message) {
                console.log("ExhibitionAppInfo: could not get app info for " + appId + ": " + message);
            });
    }
}
