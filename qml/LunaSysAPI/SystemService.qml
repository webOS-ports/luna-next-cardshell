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
    property Item cardViewInstance
    property QtObject compositorInstance

    property variant currentWindow: null

    LunaService {
        id: systemServicePrivate
        name: "org.webosports.luna"
        usePrivateBus: true
        onInitialized: {
            systemServicePrivate.registerMethod("/", "takeScreenShot", handleTakeScreenShot);
            systemServicePrivate.registerMethod("/", "focusApplication", handleFocusApplication);
            systemServicePrivate.registerMethod("/", "getFocusApplication", handleGetFocusApplication);
            systemServicePrivate.registerMethod("/", "setDisplayState", handleSetDisplayState);
        }
    }

    LunaService {
        id: systemServicePublic
        name: "org.webosports.luna"
        onInitialized: {
            systemServicePublic.registerMethod("/", "takeScreenShot", handleTakeScreenShot);
        }
    }

    function buildErrorResponse(message, subscribed) {
        var response = { "returnValue": false, "errorMessage": message };

        if (typeof subscribed !== 'undefined')
            response["subscribed"] = false;

        return JSON.stringify(response);
    }

    function handleTakeScreenShot(message) {
        var request = JSON.parse(message.payload);

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

    function handleFocusApplication(message) {
        var request = JSON.parse(message.payload);

        if (request === null)
            return buildErrorResponse("Invalid parameters.");

        if (typeof request.appId === 'undefined' || request.appId.length === 0)
            return buildErrorResponse("Invalid application id");

        if (!cardViewInstance.focusApplication(request.appId))
            return buildErrorResponse("Failed to focus application");

        return JSON.stringify({"returnValue":true});
    }

    function handleGetFocusApplication(message) {
        var request = JSON.parse(message.payload);
        var subscribed = false;

        if (request.subscribe) {
            systemServicePrivate.addSubscription("/getFocusApplication", message);
            subscribed = true;
        }

        var currentWindow = cardViewInstance.currentActiveWindow;
        if (!currentWindow || !cardViewInstance.isCurrentCardActive)
            return JSON.stringify({"returnValue":true, "subscribed": subscribed});

        return JSON.stringify({"returnValue":true,
                               "appId":currentWindow.appId,
                               "processId":currentWindow.processId});
    }

    property bool windowHasFocus: false

    Connections {
        target: cardViewInstance
        onCurrentActiveWindowChanged: sendFocusWindowChanged(cardViewInstance.currentActiveWindow, cardViewInstance.isCurrentCardActive);
    }

    function sendFocusWindowChanged(window, hasFocus) {
        var payload = { "returnValue": true };

        if(hasFocus && window) {
            payload["appId"] = window.appId;
            payload["processId"] = window.processId;
        }

        if( !windowHasFocus && !hasFocus ) // if no change in the focus, don't send any event
            return;

        windowHasFocus = hasFocus;

        systemServicePrivate.replyToSubscribers("/getFocusApplication",
                                                JSON.stringify(payload));
    }

    function handleSetDisplayState(message) {
        var request = JSON.parse(message.payload);

        if (!request || !request.state)
            return buildErrorResponse("Invalid parameters.");

        if (request.state === "on") {
            DisplayController.displayOn();
            compositorInstance.show();
        }
        else if (request.state === "off") {
            compositorInstance.hide();
            DisplayController.displayOff();
        }
        else
            return buildErrorResponse("Invalid parameters");

        return JSON.stringify({"returnValue":true});
    }
}
