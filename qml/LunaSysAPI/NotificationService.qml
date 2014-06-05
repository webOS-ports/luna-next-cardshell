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
import LunaNext.Compositor 0.1
import LunaNext.Shell.Notifications 0.1

Item {
    id: notificationService

    NotificationManager {
        id: notificationManager
    }

    LunaService {
        id: systemServicePublic
        name: "org.webosports.notifications"
        onInitialized: {
            systemServicePublic.registerMethod("/", "createNotification", handleCreateNotification);
            systemServicePublic.registerMethod("/", "closeNotification", handleCloseNotification);
        }
    }

    function buildErrorResponse(message, subscribed) {
        var response = { "returnValue": false, "errorMessage": message };

        if (typeof subscribed !== 'undefined')
            response["subscribed"] = false;

        return JSON.stringify(response);
    }

    function handleCreateNotification(message) {
        var request = JSON.parse(message.payload);

        if (request === null)
            return buildErrorResponse("Invalid parameters.");


        /* we have to take the application id here from the message as that is what the
         * app can't influence. */
        var appName       = message.applicationId;

        var replacesId    = request.replacesId ? request.replacesId : 0;  // uint
        var appIcon       = request.appIcon ? request.appIcon : ""; // string
        var summary       = request.summary ? request.summary : ""; // string
        var body          = request.body ? request.body : "";    // string
        var actions       = request.actions ? request.actions : null;  // list<string>
        var hints         = request.hints ? request.hints : null;      // dict<string,variant>
        var expireTimeout = request.expireTimeout ? request.expireTimeout : 10000; // int

        var id = notificationManager.notify(appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout);

        return JSON.stringify({"returnValue":true, "id": id});
    }

    function handleCloseNotification(message) {
        var request = JSON.parse(message.payload);

        if (request === null || typeof request.id === 'undefined')
            return buildErrorResponse("Invalid parameters");

        var notificationId = response.id;

        var notification = notificationManager.getById(id);
        if (notification === null)
            return buildErrorResponse("Invalid notification id provided");

        /* verify we're deleting only a notiication which belongs to the calling app */
        if (message.applicationId !== notification.appName)
            return buildErrorResponse("Not allowed to close a not owned notification")

        notificationManager.closeById(id);

        return JSON.stringify({"returnValue":true});
    }
}
