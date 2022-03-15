/*
 * Copyright (C) 2013-2014 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2014 Herman van Hazendonk <github.com@herrie.org>
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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

import QtQuick 2.5
import LuneOS.Service 1.0
import LunaNext.Common 0.1

Item {
    id: appMenu

    width: appMenuRow.width + appMenuRow.anchors.leftMargin - appMenuSeparator.width/2
    state: "hidden"
    visible: false

    property real fontSize: FontUtils.sizeToPixels("medium")
    property string activeWindowAppId: ""
    property string activeWindowTitle: defaultAppMenuTitle
    readonly property string defaultAppMenuTitle: "App Menu"
    property string dockModeAppMenuTitle: "Time" // this will need to be more flexible with exhibition apps

    onActiveWindowAppIdChanged: {
        // now, if the appId is valid, fetch the app name
        if (activeWindowAppId.length > 0) {
            service.call("luna://com.webos.service.applicationManager/getAppInfo",
                         JSON.stringify({"appId":activeWindowAppId}),
                         handleGetAppInfoResponse, handleGetAppInfoError);
        }
        else
        {
            // reset window title
            activeWindowTitle = defaultAppMenuTitle;
        }
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true
    }

    function determineActiveWindowAppId() {
        var appId = "";
        if (launcherInstance.state === "justTypeLauncher")
            appId = "com.palm.launcher";
        else
            appId = cardViewInstance.getAppIdForFocusApplication();
        return appId;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggleState();
    }

    function toggleState() {
        if (activeWindowAppId.length === 0)
            return;
        var params = {"id":activeWindowAppId, "params":"{\"palm-command\":\"open-app-menu\"}"};
        service.call("luna://com.webos.service.applicationManager/launch", JSON.stringify(params),
                     function(message) { }, function(error) { });
    }

    function handleGetAppInfoResponse(message) {
        var response = JSON.parse(message.payload);
        if (response.returnValue && response.appInfo && response.appInfo.appmenu)
            activeWindowTitle = response.appInfo.appmenu;
        else
            activeWindowTitle = defaultAppMenuTitle;
    }

    function handleGetAppInfoError(error) {
        console.log("Could not retrieve information about current application: " + error);
        activeWindowTitle = defaultAppMenuTitle;
    }

    Row {
        id: appMenuRow
        anchors.left: parent.left
        anchors.leftMargin: parent.height*0.25
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Units.gu(1) / 2

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.family: Settings.fontStatusBar
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: appMenu.fontSize
            font.bold: true
            text: defaultAppMenuTitle
        }

        Image {
            id: separator
            anchors.verticalCenter: title.verticalCenter
            mipmap: true
            source: "../images/statusbar/menu-arrow.png"
            fillMode: Image.PreserveAspectFit
            height: Units.gu(2.6)
            width: Units.gu(1.5)
        }

        Image {
            id: appMenuSeparator
            source: "../images/statusbar/status-bar-separator.png"
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: 2
            mipmap: true
            opacity: Settings.tabletUi
        }
    }

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: appMenu; visible: false }
            PropertyChanges { target: title; text: defaultAppMenuTitle }
        },
        State {
            name: "appmenu"
            StateChangeScript { script: { activeWindowAppId = determineActiveWindowAppId(); } }
            PropertyChanges { target: appMenu; visible: true }
            PropertyChanges { target: title; text: activeWindowTitle }
        },
        State {
            name: "dockmode"
            PropertyChanges { target: appMenu; activeWindowAppId: "" }
            PropertyChanges { target: appMenu; visible: true }
            PropertyChanges { target: title; text: dockModeAppMenuTitle }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"
            SequentialAnimation {
                PropertyAction { target: appMenu; property: "visible" }
                NumberAnimation { target: appMenu; properties: "opacity"; from: 0; to: 1; duration: 300 }
            }
        },
        Transition {
            to: "hidden"
            SequentialAnimation {
                NumberAnimation { target: appMenu; properties: "opacity"; from: 1; to: 0; duration: 300 }
                PropertyAction { target: appMenu; property: "visible" }
                PropertyAction { target: appMenu; property: "title" }
            }
        }
    ]
}
