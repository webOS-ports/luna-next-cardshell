/*
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
import LunaNext 0.1

Item {
    id: appMenu

    width: Units.length(100)
    state: "hidden"
    visible: false

    property string activeWindowAppId: ""
    readonly property string defaultAppMenuTitle: "App Menu"

    LunaService {
        id: service
        name: "org.webosports.luna"
        usePrivateBus: true
    }

    function determineActiveWindowAppId() {
        var appId = "";
        if (launcherInstance.state === "justTypeLauncher")
            appId = "com.palm.launcher";
        else if (cardViewInstance.isCurrentCardActive)
            appId = cardViewInstance.getAppIdForFocusApplication();
        return appId;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var activeWindowAppId = determineActiveWindowAppId();
            if (activeWindowAppId.length === 0)
                return;
            var params = {"id":activeWindowAppId, "params":"{\"palm-command\":\"open-app-menu\"}"};
            service.call("luna://com.palm.applicationManager/launch", JSON.stringify(params),
                         function(message) { }, function(error) { });
        }
    }

    function handleGetAppInfoResponse(message) {
        var response = JSON.parse(message.payload);
        if (response.returnValue && response.appInfo && response.appInfo.appmenu)
            title.text = response.appInfo.appmenu;
        else
            title.text = defaultAppMenuTitle;
    }

    function handleGetAppInfoError(error) {
        console.log("Could not retrieve information about current application: " + error);
        title.text = defaultAppMenuTitle;
    }

    function updateAfterAppChange() {
        var activeWindowAppId = determineActiveWindowAppId();
        if (activeWindowAppId.length === 0)
            return;
        service.call("palm://com.palm.applicationManager/getAppInfo",
                     JSON.stringify({"appId":activeWindowAppId}),
                     handleGetAppInfoResponse, handleGetAppInfoError);
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Units.length(5)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Units.length(3)

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: parent.height;
            text: defaultAppMenuTitle
        }

        Image {
            id: separator
            anchors.verticalCenter: title.verticalCenter
            smooth: true
            source: "../images/statusbar/menu-arrow.png"
            fillMode: Image.PreserveAspectFit
        }
    }

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: appMenu; activeWindowAppId: "" }
        },
        State { name: "visible" }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "visible"
            ScriptAction { script: { updateAfterAppChange(); appMenu.visible = true } }
            NumberAnimation { target: appMenu; properties: "opacity"; from: 0; to: 1; duration: 300 }
        },
        Transition {
            from: "visible"
            to: "hidden"
            SequentialAnimation {
                NumberAnimation { target: appMenu; properties: "opacity"; from: 1; to: 0; duration: 300 }
                ScriptAction { script: appMenu.visible = false }
            }
        }
    ]
}
