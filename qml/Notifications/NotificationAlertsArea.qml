/*
 * Copyright (C) 2015, 2026 Herman van Hazendonk <github.com@herrie.org>
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
import WebOSServices 1.0
import WebOSCompositorBase 1.0

/*
 * The alerts com.webos.notification hands out (createAlert): a title, a
 * message and a row of buttons, each with the luna call it stands for.
 *
 * Nothing drew these. notificationmgr already sends every one of them to the
 * shell, but only OSE's Enact notification app was written to show them, and
 * its window never comes on screen here - so a web app's permission question,
 * which WAM asks through createAlert, was never seen.
 *
 * They are drawn the way the QtWebEngine era's permission dialog was
 * (PermissionDialog in luneos-components): a dark rounded panel with the
 * title, the message, a warning icon and full width buttons, an "ok" button
 * green and a "cancel" one red. One alert is shown at a time; modal alerts
 * jump the queue, as notificationmgr's other clients order them.
 *
 * A press runs the button's call and then closes the alert at notificationmgr,
 * which tells every client, this one included, that it is gone.
 */
Item {
    id: root

    anchors.fill: parent
    visible: alertModel.count > 0 && !held

    //! While set, alerts are kept but not shown, e.g. under the lock screen.
    property bool held: false

    // One row per alert, the message kept as text: a ListModel turns nested
    // arrays into models of their own, and the buttons are easier to read
    // back from the json they arrived in.
    ListModel {
        id: alertModel
    }

    readonly property var currentAlert: alertModel.count > 0
                                        ? JSON.parse(alertModel.get(0).json).alertInfo
                                        : null

    function handleAlertMessage(message) {
        var i;
        switch (message.alertAction) {
        case "closeAll":
            alertModel.clear();
            return;
        case "close":
            if (!message.alertInfo)
                return;
            for (i = 0; i < alertModel.count; i++) {
                if (alertModel.get(i).timestamp === message.alertInfo.timestamp) {
                    alertModel.remove(i);
                    break;
                }
            }
            return;
        default:
            break;
        }

        if (!message.alertInfo)
            return;

        var row = {
            "timestamp": message.timestamp || "",
            "modal": message.alertInfo.modal === true,
            "json": JSON.stringify(message)
        };

        // Modal alerts go ahead of the ones that are not.
        if (row.modal) {
            for (i = 0; i < alertModel.count; i++) {
                if (!alertModel.get(i).modal) {
                    alertModel.insert(i, row);
                    return;
                }
            }
        }
        alertModel.append(row);
    }

    function pressButton(button) {
        var alert = currentAlert;
        var action = button.action;
        if (action && action.serviceURI && action.serviceMethod) {
            LS.adhoc.call(action.serviceURI, action.serviceMethod,
                          JSON.stringify(action.launchParams || {}));
        }

        // Gone from here at once; the close notificationmgr sends back finds
        // nothing left to remove.
        alertModel.remove(0);
        if (alert && alert.alertId) {
            LS.adhoc.call("luna://com.webos.notification", "/closeAlert",
                          JSON.stringify({"alertId": alert.alertId}));
        }
    }

    Service {
        id: notificationManagerStatus
        appId: LS.appId
        service: "luna://com.webos.service.bus"
        method: "signal/registerServerStatus"

        Component.onCompleted: callService({"serviceName": "com.webos.notification", "subscribe": true})

        onResponse: (method, payload, token) => {
            var response = JSON.parse(payload);
            if (response.connected)
                notificationManager.subscribe();
            else
                notificationManager.unsubscribe();
        }
    }

    Service {
        id: notificationManager
        appId: LS.appId
        service: "luna://com.webos.notification"

        property int alertToken: 0

        function subscribe() {
            unsubscribe();
            alertToken = call(service, "/getAlertNotification", '{"subscribe": true}');
        }

        function unsubscribe() {
            if (alertToken > 0) {
                cancel(alertToken);
                alertToken = 0;
            }
            // A restarted notificationmgr knows none of the old alerts.
            alertModel.clear();
        }

        onResponse: (method, payload, token) => {
            if (token !== alertToken)
                return;
            var message = JSON.parse(payload);
            if (!message || message.returnValue === false || message.subscribed === true)
                return;
            root.handleAlertMessage(message);
        }
    }

    // The question has to be answered; nothing behind it takes the press.
    MouseArea {
        anchors.fill: parent
        preventStealing: true
    }

    Rectangle {
        id: dialog

        anchors.centerIn: parent
        width: Math.min(parent.width - Units.gu(2), Units.gu(32))
        height: content.height + 2 * Units.gu(2)
        color: "#343434"
        opacity: 0.9
        radius: 10
        smooth: true

        Image {
            id: icon
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Units.gu(1.6)
            anchors.rightMargin: Units.gu(1.6)
            width: Units.gu(5.9)
            height: Units.gu(5.9)
            fillMode: Image.PreserveAspectFit
            // notificationmgr hands the icon over as a file:// url.
            source: root.currentAlert && root.currentAlert.iconUrl
                    ? root.currentAlert.iconUrl
                    : "../images/icon-warning.png"
        }

        Column {
            id: content

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Units.gu(2)
            spacing: Units.gu(0.5)

            Text {
                id: titleText
                width: parent.width - icon.width - Units.gu(1)
                text: root.currentAlert ? (root.currentAlert.title || "") : ""
                visible: text.length > 0
                font.family: "Prelude"
                font.pixelSize: FontUtils.sizeToPixels("16pt")
                font.weight: Font.DemiBold
                color: "white"
                elide: Text.ElideRight
            }

            Text {
                id: messageText
                width: parent.width - icon.width - Units.gu(1)
                text: root.currentAlert ? (root.currentAlert.message || "") : ""
                font.family: "Prelude"
                font.pixelSize: FontUtils.sizeToPixels("12pt")
                font.bold: true
                color: "white"
                wrapMode: Text.WordWrap
            }

            // Room between the text and the buttons, and clear of the icon
            // when the message is a single line.
            Item {
                width: 1
                height: Math.max(Units.gu(1.5),
                                 icon.height + Units.gu(1) - messageText.height
                                 - (titleText.visible ? titleText.height + content.spacing : 0))
            }

            Repeater {
                model: root.currentAlert ? root.currentAlert.buttons : []

                delegate: Rectangle {
                    id: button

                    required property var modelData

                    width: content.width
                    height: Units.gu(3.8)
                    radius: 4
                    color: modelData.type === "ok" ? "green"
                           : modelData.type === "cancel" ? "red"
                           : "#4b4b4b"

                    Image {
                        id: capLeft
                        anchors.left: parent.left
                        width: Units.gu(1.9)
                        height: parent.height
                        source: "../images/button-up-left.png"
                        fillMode: Image.Stretch
                    }
                    Image {
                        anchors.left: capLeft.right
                        anchors.right: capRight.left
                        height: parent.height
                        source: "../images/button-up-center.png"
                        fillMode: Image.Stretch
                    }
                    Image {
                        id: capRight
                        anchors.right: parent.right
                        width: Units.gu(1.9)
                        height: parent.height
                        source: "../images/button-up-right.png"
                        fillMode: Image.Stretch
                    }

                    Text {
                        anchors.centerIn: parent
                        text: button.modelData.label || ""
                        font.family: "Prelude"
                        font.pixelSize: FontUtils.sizeToPixels("14pt")
                        font.bold: true
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.pressButton(button.modelData)
                    }
                }
            }
        }
    }
}
