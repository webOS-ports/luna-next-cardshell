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
import LunaNext 0.1

Item {
    id: systemService

    property variant screenShooter
    property variant windowManager

    LunaService {
        id: systemServicePrivate
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            systemServicePrivate.registerMethod("/", "takeScreenShot", handleTakeScreenShot);
            systemServicePrivate.registerMethod("/", "focusApplication", handleFocusApplication);
            systemServicePrivate.registerMethod("/", "getFocusApplication", handleGetFocusApplication);s
        }
    }

    LunaService {
        id: systemServicePublic
        name: "org.webosports.luna"
        onInitialized: {
            systemServicePublic.registerMethod("/", "takeScreenShot", handleTakeScreenShot);
        }
    }

    function buildErrorResponse(message) {
        return JSON.stringify({ "returnValue": false, "errorMessage": message });
    }

    function handleTakeScreenShot(data) {
        var request = JSON.parse(data);

        if (request === null)
            return buildErrorResponse("Invalid parameters.");

        if (systemService.screenShooter === null)
            return buildErrorResponse("Internal error.");

        var filename = "";
        if (typeof request.file !== 'undefined')
            filename = request.file;

        screenShooter.takeScreenshot(filename);

        return JSON.stringify({"returnValue":true});
    }

    function handleFocusApplication(data) {
        var request = JSON.parse(data);

        if (request === null)
            return buildErrorResponse("Invalid parameters.");

        if (typeof request.appId === 'undefined' || request.appId.length === 0)
            return buildErrorResponse("Invalid application id");

        if (!windowManager.focusApplication(request.appId))
            return buildErrorResponse("Failed to focus application");

        return JSON.stringify({"returnValue":true});
    }

    function handleGetFocusApplication(data) {
        if (windowManager.currentActiveWindowWrapper === null ||
            (windowManager.currentActiveWindowWrapper.windowState !== WindowState.Maximized &&
             windowManager.currentActiveWindowWrapper.windowState !== WindowState.Fullscreen))
            return JSON.stringify({"returnValue":true});

        var currentWindow = windowManager.currentActiveWindowWrapper.wrappedWindow;
        return JSON.stringify({"returnValue":true,
                               "appId":currentWindow.appId,
                               "processId":currentWindow.processId});
    }
}
