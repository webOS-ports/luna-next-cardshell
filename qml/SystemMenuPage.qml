/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Shell.Notifications 0.1

import "Utils"

Rectangle {
    id: systemMenuPage

    color: "black"

    signal launchApplication(string appId, string appParams);
    onLaunchApplication: {
        systemMenuPage.__launchApplication(appId, appParams);
    }

    /*
    Q_PROPERTY(QString appName READ appName)
    Q_PROPERTY(uint replacesId READ replacesId)
    Q_PROPERTY(QString appIcon READ appIcon)
    Q_PROPERTY(QString summary READ summary NOTIFY summaryChanged)
    Q_PROPERTY(QString body READ body NOTIFY bodyChanged)
    Q_PROPERTY(QStringList actions READ actions)
    Q_PROPERTY(int expireTimeout READ expireTimeout)
    Q_PROPERTY(QString icon READ icon NOTIFY iconChanged)
    Q_PROPERTY(QDateTime timestamp READ timestamp NOTIFY timestampChanged)
    Q_PROPERTY(QString previewIcon READ previewIcon NOTIFY previewIconChanged)
    Q_PROPERTY(QString previewSummary READ previewSummary NOTIFY previewSummaryChanged)
    Q_PROPERTY(QString previewBody READ previewBody NOTIFY previewBodyChanged)
    Q_PROPERTY(int urgency READ urgency NOTIFY urgencyChanged)
    Q_PROPERTY(int itemCount READ itemCount NOTIFY itemCountChanged)
    Q_PROPERTY(int priority READ priority NOTIFY priorityChanged)
    Q_PROPERTY(QString category READ category NOTIFY categoryChanged)
    Q_PROPERTY(bool userRemovable READ isUserRemovable NOTIFY userRemovableChanged)
    */
    NotificationListModel {
        id: notificationModel
    }

    ListView {
        id: notificationList
        anchors.fill: parent
        spacing: Units.gu(1) / 2
        anchors.margins: Units.gu(1)
        model: notificationModel
        delegate:
            SlidingItemArea {
                id: slidingNotificationArea
                slidingTargetItem: notificationItem

                height: notificationItem.height
                width: notificationItem.width

                NotificationItem {
                    id: notificationItem

                    anchors.verticalCenter: slidingNotificationArea.verticalCenter
                    width: systemMenuPage.width - Units.gu(1) * 2
                    height: Units.gu(6)
                    summary: object.summary
                    body: object.body
                }

                onSliderClicked:systemMenuPage.launchApplication(object.appName, "{}");
                onSlidedLeft: notificationModel.remove(index);
                onSlidedRight: notificationModel.remove(index);
            }
    }

    /////// private //////

    property QtObject __lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function __launchApplication(id, params) {
        console.log("launching app " + id + " with params " + params);
        lunaNextLS2Service.call("luna://com.palm.applicationManager/launch",
            JSON.stringify({"id": id, "params": params}), undefined, __handleLaunchAppError)
    }
    function __handleLaunchAppError(message) {
        console.log("Could not start application : " + message);
    }
}
