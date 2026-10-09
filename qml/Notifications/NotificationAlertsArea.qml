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

import "../Utils"

/*
 * The alerts com.webos.notification hands out (createAlert): a title, a
 * message and a row of buttons, each with the luna call it stands for.
 *
 * Nothing drew these. notificationmgr already sends every one of them to the
 * shell, but only OSE's Enact notification app was written to show them, and
 * its window never comes on screen here - so a web app's permission question,
 * which WAM asks through createAlert, was never seen.
 *
 * This is the alert's content only: AlertWindowsArea hosts it the way it hosts
 * an application's popup alert window, in the same bar resting on the
 * notification area on a phone and the same panel under the status bar on a
 * tablet - where legacy put its system alerts - with the same "tap outside to
 * dismiss", which a modal alert does not give in to. The buttons are the
 * shell's own notification buttons (ActionButton): affirmative for "ok",
 * negative for "cancel".
 *
 * One alert is shown at a time; modal alerts jump the queue, as
 * notificationmgr's other clients order them. A press runs the button's call
 * and then closes the alert at notificationmgr, which tells every client, this
 * one included, that it is gone.
 */
Item {
    id: root

    //! Whether there is an alert to show.
    readonly property bool showing: alertModel.count > 0
    //! Whether the alert shown has to be answered: no tap elsewhere closes it.
    readonly property bool modal: showing && alertModel.get(0).modal

    height: showing ? content.height + 2 * Units.gu(1.5) : 0
    visible: showing

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

    // Takes the alert shown away here and at notificationmgr.
    function closeCurrent() {
        var alert = currentAlert;

        // Gone from here at once; the close notificationmgr sends back finds
        // nothing left to remove.
        alertModel.remove(0);
        if (alert && alert.alertId) {
            LS.adhoc.call("luna://com.webos.notification", "/closeAlert",
                          JSON.stringify({"alertId": alert.alertId}));
        }
    }

    function pressButton(button) {
        var action = button.action;
        if (action && action.serviceURI && action.serviceMethod) {
            LS.adhoc.call(action.serviceURI, action.serviceMethod,
                          JSON.stringify(action.launchParams || {}));
        }
        closeCurrent();
    }

    //! A tap outside the alerts: closes the alert shown unless it is modal.
    function dismiss() {
        if (showing && !modal)
            closeCurrent();
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

    // A press on the alert itself is the alert's, not a tap outside it.
    MouseArea {
        anchors.fill: parent
    }

    Image {
        id: icon
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Units.gu(1.5)
        anchors.rightMargin: Units.gu(1.5)
        width: Units.gu(4.8)
        height: Units.gu(4.8)
        fillMode: Image.PreserveAspectFit
        // notificationmgr hands the icon over as a file:// url. Without one,
        // the yellow warning legacy drew on its error screens, from the Mojo
        // framework already on the device rather than a copy of it here.
        source: root.currentAlert && root.currentAlert.iconUrl
                ? root.currentAlert.iconUrl
                : "file:///usr/palm/frameworks/mojo/submissions/506/images/warning-large.png"
    }

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Units.gu(1.5)
        spacing: Units.gu(0.5)

        Text {
            id: titleText
            width: parent.width - icon.width - Units.gu(1)
            text: root.currentAlert ? (root.currentAlert.title || "") : ""
            textFormat: Text.PlainText
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
            textFormat: Text.PlainText
            font.family: "Prelude"
            font.pixelSize: FontUtils.sizeToPixels("12pt")
            font.bold: true
            color: "white"
            wrapMode: Text.WordWrap
        }

        // Room between the text and the buttons, and clear of the icon when
        // the message is a single line.
        Item {
            width: 1
            height: Math.max(Units.gu(1),
                             icon.height + Units.gu(0.5) - messageText.height
                             - (titleText.visible ? titleText.height + content.spacing : 0))
        }

        Repeater {
            model: root.currentAlert ? root.currentAlert.buttons : []

            delegate: ActionButton {
                required property var modelData

                width: content.width
                height: Units.gu(4)

                caption: modelData.label || ""
                affirmative: modelData.type === "ok"
                negative: modelData.type === "cancel"

                onAction: root.pressButton(modelData)
            }
        }
    }
}
