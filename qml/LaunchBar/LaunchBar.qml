/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2014-2016 Herman van Hazendonk <github.com@herrie.org>
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
import QtQuick.Layouts 1.0
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0

import "../LunaSysAPI" as LunaSysAPI

Item {
    id: launchBarItem


    property ListModel appsModel

    Connections {
        target: appsModel
        function onAppsModelRefreshed () {
            launchBarItem.refreshConfig();
        }
    }

    signal startLaunchApplication(string appId, var appParams)
    signal toggleLauncherDisplay

    state: "visible"
    anchors.bottom: parent.bottom

    property real launcherBarIconSize: launchBarItem.height * 0.7;

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: launchBarItem; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: launchBarItem; opacity: 0 }
            PropertyChanges { target: launchBarItem; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: launchBarItem; anchors.top: undefined; anchors.bottom: parent.bottom }
            PropertyChanges { target: launchBarItem; opacity: 1 }
            PropertyChanges { target: launchBarItem; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "hidden"

            AnchorAnimation { easing.type:Easing.InOutQuad; duration: 150 }
            SequentialAnimation {
                NumberAnimation { property: "opacity"; duration: 150 }
                PropertyAction { property: "visible" }
            }
        },
        Transition {
            to: "visible"

            SequentialAnimation {
                PropertyAction { property: "visible" }
                ParallelAnimation {
                    AnchorAnimation { easing.type:Easing.InOutQuad; duration: 150 }
                    NumberAnimation { property: "opacity"; duration: 150 }
                }
            }
        }
    ]

    // background of quick laucnh
    Rectangle {
        anchors.fill: launchBarItem
        opacity: 0.2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "grey" }
            GradientStop { position: 1.0; color: "white" }
        }
    }

  /*
    // list of icons
    DraggableAppIconDelegateModel {
        id: launcherListModel
        // list of icons
        model: ListModel { }

        dragParent: fullLauncher
        dragAxis: Drag.XAxis
        iconWidth: launchBarItem.launcherBarIconSize
        iconSize: launchBarItem.launcherBarIconSize

        onStartLaunchApplication: launchBarItem.startLaunchApplication(appId, "");
        onSaveCurrentLayout: saveCurrentLayout();
    }
*/
    // list of icons
    VisualDataModel {
        id: launcherListModel
        model: ListModel {
        }
        delegate:
            Item {
                id: launcherIconDelegate

                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                height: launcherIcon.height
                width: launcherIcon.width

                LaunchableAppIcon {
                    id: launcherIcon

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }

                    appIcon: model.icon
                    appId: model.appId

                    iconSize: launchBarItem.launcherBarIconSize
                    width: launchBarItem.launcherBarIconSize

                    Drag.active: dragArea.held
                    Drag.source: launcherIconDelegate
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    glow: dragArea.held

                    onStartLaunchApplication: launchBarItem.startLaunchApplication(appId, {});

                    states: State {
                        when: dragArea.held
                        ParentChange { target: launcherIcon; parent: launchBarItem }
                        AnchorChanges {
                            target: launcherIcon
                            anchors { horizontalCenter: undefined; verticalCenter: undefined }
                        }
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors { fill: parent }

                    drag.target: held ? launcherIcon : undefined
                    drag.axis: Drag.XAxis

                    property bool held: false

                    propagateComposedEvents: true
                    onPressAndHold: held = true;
                    onReleased: {
                        held = false;

                        // save that layout in DB
                        saveCurrentLayout();
                    }
                }

                DropArea {
                    anchors { fill: parent; margins: 10 }

                    onEntered: {
                        if( drag.source !== launcherIconDelegate ) {
                            launcherListModel.items.move(
                                    drag.source.VisualDataModel.itemsIndex,
                                    launcherIconDelegate.VisualDataModel.itemsIndex);
                        }
                    }
                }
            }
    }

    RowLayout {
        id: launcherRow

        visible: false
        anchors.fill: launchBarItem
        spacing: 0

        ListView {
            id: launchBarListView
            Layout.fillWidth: true
            Layout.preferredHeight: launchBarItem.height
            Layout.preferredWidth: launchBarItem.width
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

            spacing: count > 0 ? (width - launchBarItem.launcherBarIconSize*count) / count : 0

            orientation: ListView.Horizontal
            interactive: false
            model: launcherListModel

            header: Item {
                width: launchBarListView.spacing/2
            }
            moveDisplaced: Transition {
                NumberAnimation { properties: "x"; duration: 200 }
            }
        }

        Item {
            Layout.fillWidth: false
            Layout.preferredHeight: launchBarItem.launcherBarIconSize
            Layout.minimumWidth: launchBarItem.launcherBarIconSize
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

            Image {
                id: appsIcon

                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: "../images/empty-launcher.png"

                MouseArea {
                    anchors.fill: parent
                    onClicked: launchBarItem.toggleLauncherDisplay()
                }
            }
        }
    }

    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "com.webos.surfacemanager-cardshell"
        usePrivateBus: true
    }
    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                  handleResultFct, __handleDBError)
    }

    function __quickLaunchBarDBResult(message) {
        var result = JSON.parse(message.payload);

        if( result && result.results && result.results.length ) {
            for( var i=0; i<result.results.length; ++i ) {
                var obj = result.results[i];
                launcherListModel.model.append({appId: obj.appId, icon: obj.icon});
            }
        }
        else {
            //fallback to static filling

            //Icons are depending on Settings.tabletUi, which we check and we'll populate the list accordingly
            if(Settings.tabletUi)
            {
                launcherListModel.model.append({appId: "org.webosports.app.browser",   icon: "/usr/palm/applications/org.webosports.app.browser/icon.png"});
                launcherListModel.model.append({appId: "com.palm.app.email",         icon: "/usr/palm/applications/com.palm.app.email/icon.png"});
                launcherListModel.model.append({appId: "com.palm.app.calendar", icon: "/usr/palm/applications/com.palm.app.calendar/images/launcher/icon-"+Qt.formatDate(new Date, "d")+".png"});
                launcherListModel.model.append({appId: "org.webosports.app.messaging", icon: "/usr/palm/applications/org.webosports.app.messaging/icon.png"});
                launcherListModel.model.append({appId: "org.webosports.app.memos",   icon: "/usr/palm/applications/org.webosports.app.memos/icon.png"});
            }
            else
            {
                launcherListModel.model.append({appId: "org.webosports.app.phone",   icon: "/usr/palm/applications/org.webosports.app.phone/icon.png"});
                launcherListModel.model.append({appId: "org.webosports.app.messaging", icon: "/usr/palm/applications/org.webosports.app.messaging/icon.png"});
                launcherListModel.model.append({appId: "com.palm.app.email",         icon: "/usr/palm/applications/com.palm.app.email/icon.png"});
                launcherListModel.model.append({appId: "com.palm.app.calendar", icon: "/usr/palm/applications/com.palm.app.calendar/images/launcher/icon-"+Qt.formatDate(new Date, "d")+".png"});
            }
        }
    }
    function saveCurrentLayout() {
        if( Settings.isTestEnvironment ) return;

        // first, clean up the DB
        __queryDB("del",
                  {query:{from:"org.webosports.lunalauncher:1"}},
                  function (message) {});

        // then build up the object to save
        var data = [];
        for( var i=0; i<launcherListModel.items.count; ++i ) {
            var obj = launcherListModel.items.get(i);
            data.push({_kind: "org.webosports.lunalauncher:1",
                       pos: obj.itemsIndex,
                       appId: obj.model.appId,
                       icon: obj.model.icon});
        }

        // and put it in the DB
         __queryDB("put", {objects: data}, function (message) {});
    }

    Component.onCompleted: {
        // fill the listModel statically
        // Read the default dock positions configuation file
        var xhr = new XMLHttpRequest;
        if( !Settings.isTestEnvironment ) {
            xhr.open("GET", Qt.resolvedUrl("/etc/palm/default-dock-positions.json"));
        }
        else {
            xhr.open("GET", Qt.resolvedUrl("../Tests/default-dock-positions.json"));
        }
        xhr.onreadystatechange = function() {
            if( xhr.readyState === XMLHttpRequest.DONE ) {
                var launchBarConfig = JSON.parse(xhr.responseText);
                _defaultLaunchBarConfig = [];

                var iItem;
                var deviceType = Settings.tabletUi ? "tablet" : "phone";
                for ( var iType in launchBarConfig){
                    if(launchBarConfig[iType].type === deviceType)
                    {
                        for( iItem in launchBarConfig[iType].items ) {
                            _defaultLaunchBarConfig.push(launchBarConfig[iType].items[iItem]);
                        }
                    }
                }
                refreshConfig();
            }
        }
        xhr.send();
        // Read the db8 configuration: the db schema the following:
        // appId: string
        if( !Settings.isTestEnvironment ) {
            __queryDB("find",
                      {query:{from:"org.webosports.lunalauncher:1", orderBy: "pos", limit:5}},
                      __quickLaunchBarDBResult);
        }
        launcherRow.visible = true;
    }
    property var _defaultLaunchBarConfig: []

    // refreshes the quick launcher configuration
    function refreshConfig() {
        // for all the apps from appsModel, use their icon so we always have an up-2-date icons
        launcherListModel.model.clear();
        var unsortedAppsArray = [];
        var nbApps = appsModel.count;
        for( var i = 0; i < nbApps; ++i ) {
            var appObj = appsModel.get(i);
            if(_defaultLaunchBarConfig.indexOf(appObj.id+"_default") !== -1)
            {
                unsortedAppsArray.push({pos: _defaultLaunchBarConfig.indexOf(appObj.id+"_default"), appId: appObj.id, icon: appObj.icon});
            }
        }

        //Sort the apps
        unsortedAppsArray.sort(function(a,b){ return a.pos - b.pos; });
        // fill the model
        for( var j = 0; j < unsortedAppsArray.length; ++j ) {
            launcherListModel.model.append({appId: unsortedAppsArray[j].appId, icon: unsortedAppsArray[j].icon});
        }
    }
}
