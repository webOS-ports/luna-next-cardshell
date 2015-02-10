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
import LuneOS.Service 1.0
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
            systemServicePublic.registerMethod("/", "create", handleCreateNotification);
            systemServicePublic.registerMethod("/", "close", handleCloseNotification);
            systemServicePublic.registerMethod("/", "closeAll", handleCloseAllNotifications);
        }
    }

    LunaService {
        id: systemServicePrivate
        name: "org.webosports.notifications"
        usePrivateBus: true
        onInitialized: {
            systemServicePrivate.registerMethod("/", "create", handleCreateNotification);
            systemServicePrivate.registerMethod("/", "close", handleCloseNotification);
            systemServicePrivate.registerMethod("/", "closeAll", handleCloseAllNotifications);
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

/* Expected API:
createNotification {
   "ownerId": "", // taken automatically from received message, either applicationId or serviceId
   "launchId": "", // for apps this can default to ownerId, but allow to freely set in general for services and apps
   "launchParams": "", // parameters supplied to app when (re-)launched because user clicked on the notification
   "title": "", // no markup
   "message": "", // should use some markup
   "iconUrl: "", // only local urls (file://) are allowed
   "replacesId": <int>, // if the notification should be replaced with a new one. Allow only to replace notifications with same ownerId.
   "priority": <int>,
   "expiresTimeout": <int>, // in seconds
}
*/

        /* we have to take the application/service id here from the message as that is what the
         * app can't influence. */
        var ownerId = "";
        if (message.applicationId && message.applicationId !== '') {
            ownerId = message.applicationId;
        }
        else if (message.serviceId && message.serviceId !== '') {
            ownerId = message.serviceId;
        }
        else {
            return buildErrorResponse("Error: an application id or a service id must be set on the notification message.");
        }

        var launchId      = request.launchId ? request.launchId : "";  // string
        var launchParams  = request.launchParams ? request.launchParams : "";  // string

        var title         = request.title ? request.title : "";  // string (no markup)
        var body          = request.body ? request.body : ""; // string (with eventual markup)
        var iconUrl       = request.iconUrl ? request.iconUrl : ""; // local url
        var replacesId    = request.replacesId ? request.replacesId : 0;  // uint
        var priority      = request.priority ? request.priority : 0;  // uint
        var expireTimeout = request.expireTimeout ? request.expireTimeout : 10000; // int

        var id = notificationManager.notify(ownerId, replacesId, launchId, launchParams, title, body, iconUrl, priority, expireTimeout);

        return JSON.stringify({"returnValue":true, "id": id});
    }

    function handleCloseNotification(message) {
        var request = JSON.parse(message.payload);

        if (request === null || typeof request.id === 'undefined')
            return buildErrorResponse("Invalid parameters");

        var notificationId = request.id;

        var notification = notificationManager.getNotificationById(notificationId);
        if (notification === null)
            return buildErrorResponse("Invalid notification id provided");

        /* verify we're deleting only a notiication which belongs to the calling app */
        if (message.applicationId !== notification.ownerId)
            return buildErrorResponse("Not allowed to close a not owned notification")

        notificationManager.closeById(notificationId);

        return JSON.stringify({"returnValue":true});
    }

    function handleCloseAllNotifications(message) {
        var request = JSON.parse(message.payload);

        if (request === null)
            return buildErrorResponse("Invalid parameters");

        if (message.applicationId === '')
            return buildErrorResponse("No application id set which is required");

        notificationManager.closeAllByOwner(message.applicationId);

        return JSON.stringify({"returnValue":true});
    }
}
