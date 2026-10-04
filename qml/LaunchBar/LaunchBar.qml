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
import QtQml.Models 2.2
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import WebOSCompositorBase 1.0

import "../LunaSysAPI" as LunaSysAPI
import "../AppTweaks"

Item {
    id: launchBarItem

    // See AppTweaks.disableAnimations: instant on an E Ink panel.
    readonly property int animationDuration: AppTweaks.disableAnimations ? 0 : 150


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

    //! Apps the bar holds at most; the launcher button takes one more slot.
    readonly property int maxIcons: Settings.tabletUi ? 5 : 4

    /*!
     * Width of one slot. The apps and the launcher button share the bar in
     * equal slots, each icon centred in its own, so the gaps between all of
     * them - the button included - are the same.
     */
    readonly property real slotWidth: launchBarItem.width / (launchBarListView.count + 1)

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

            AnchorAnimation { easing.type:Easing.InOutQuad; duration: launchBarItem.animationDuration }
            SequentialAnimation {
                NumberAnimation { property: "opacity"; duration: launchBarItem.animationDuration }
                PropertyAction { property: "visible" }
            }
        },
        Transition {
            to: "visible"

            SequentialAnimation {
                PropertyAction { property: "visible" }
                ParallelAnimation {
                    AnchorAnimation { easing.type:Easing.InOutQuad; duration: launchBarItem.animationDuration }
                    NumberAnimation { property: "opacity"; duration: launchBarItem.animationDuration }
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
    DelegateModel {
        id: launcherListModel
        model: ListModel {
        }
        delegate:
            Item {
                id: launcherIconDelegate

                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                height: launcherIcon.height
                width: launchBarItem.slotWidth

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

                    // Dragged up out of the bar, the icon is on its way off it.
                    readonly property bool outOfBar: dragArea.held && y + height / 2 < 0
                    opacity: outOfBar ? 0.5 : 1

                    Drag.active: dragArea.held
                    Drag.source: launcherIconDelegate
                    Drag.keys: [ "launchbar-icon" ]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    glow: dragArea.held

                    onStartLaunchApplication: (appId) => { launchBarItem.startLaunchApplication(appId, {}); }

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

                    // Sideways to reorder, upwards to take the icon off the bar.
                    drag.target: held ? launcherIcon : undefined
                    drag.axis: Drag.XAndYAxis

                    property bool held: false

                    propagateComposedEvents: true
                    onPressAndHold: held = true;
                    onReleased: {
                        if (!held)
                            return;
                        var removing = launcherIcon.outOfBar;
                        held = false;

                        var ids = launchBarItem.currentLayout();
                        if (removing)
                            ids.splice(ids.indexOf(model.appId), 1);
                        launchBarItem.applyLayout(ids);
                    }
                }

            }
    }

    /*!
     * Reorders the bar while one of its icons is dragged along it: the icon
     * goes to whichever slot the drag is over. The slot comes from the drag's
     * position on the bar rather than from a drop area on each icon - those
     * slide while the others make room, pass back under the finger, and send
     * the icon back where it came from.
     */
    DropArea {
        anchors.fill: launchBarItem
        keys: [ "launchbar-icon" ]

        function follow(drag) {
            var to = Math.max(0, Math.min(launchBarListView.count - 1, Math.floor(drag.x / launchBarItem.slotWidth)));
            var from = drag.source.DelegateModel.itemsIndex;
            if (from !== to)
                launcherListModel.items.move(from, to);
        }

        onEntered: (drag) => follow(drag)
        onPositionChanged: (drag) => follow(drag)
    }

    /*!
     * Takes an app dragged out of the full launcher. Dropped on an app, it
     * takes that app's place; with a slot to spare it goes in where it was
     * dropped instead. An app already on the bar just moves. The app stays in
     * the launcher grid either way, as it did on webOS.
     */
    DropArea {
        id: launcherAppDropArea
        anchors.fill: launchBarItem
        keys: [ "launcher-app" ]

        // What FullLauncher checks before calling Drag.drop() on the bar.
        readonly property bool acceptsLauncherApps: true

        // Slot the drag is over, or -1.
        property int hoveredSlot: -1

        function slotAt(x) {
            return Math.max(0, Math.min(launchBarListView.count, Math.floor(x / launchBarItem.slotWidth)));
        }

        onEntered: (drag) => { hoveredSlot = slotAt(drag.x); }
        onPositionChanged: (drag) => { hoveredSlot = slotAt(drag.x); }
        onExited: hoveredSlot = -1;
        onDropped: (drop) => {
            var slot = slotAt(drop.x);
            hoveredSlot = -1;

            var appId = drop.source.modelId;
            if (!appId)
                return;

            var ids = launchBarItem.currentLayout();
            var existing = ids.indexOf(appId);
            if (existing !== -1) {
                ids.splice(existing, 1);
                ids.splice(Math.min(slot, ids.length), 0, appId);
            }
            else if (ids.length < launchBarItem.maxIcons) {
                ids.splice(Math.min(slot, ids.length), 0, appId);
            }
            else {
                ids[Math.min(slot, ids.length - 1)] = appId;
            }
            launchBarItem.applyLayout(ids);
        }

        // Marks where the app will land.
        Rectangle {
            visible: launcherAppDropArea.hoveredSlot >= 0
            x: Math.min(launcherAppDropArea.hoveredSlot, Math.max(0, launchBarListView.count - (launchBarListView.count < launchBarItem.maxIcons ? 0 : 1))) * launchBarItem.slotWidth
            width: launchBarItem.slotWidth
            height: launchBarItem.height
            color: "white"
            opacity: 0.25
            radius: height / 6
        }
    }

    RowLayout {
        id: launcherRow

        visible: false
        anchors.fill: launchBarItem
        spacing: 0

        ListView {
            id: launchBarListView
            Layout.fillWidth: false
            Layout.preferredHeight: launchBarItem.height
            Layout.preferredWidth: launchBarItem.slotWidth * count
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

            spacing: 0

            orientation: ListView.Horizontal
            interactive: false
            model: launcherListModel

            moveDisplaced: Transition {
                NumberAnimation { properties: "x"; duration: AppTweaks.disableAnimations ? 0 : 200 }
            }
        }

        // The launcher button, in a slot of its own like any app.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: launchBarItem.height
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

            Image {
                id: appsIcon

                anchors.centerIn: parent
                width: launchBarItem.launcherBarIconSize
                height: launchBarItem.launcherBarIconSize
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
    }
    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                  handleResultFct, __handleDBError)
    }

    /*!
     * The arrangement the user made, as app ids in order, or null while there
     * is none (then the bar follows /etc/palm/default-dock-positions.json).
     * The bar is rebuilt from this whenever the apps model refreshes, so it
     * has to be kept here: rebuilding from the defaults alone threw away
     * whatever the user had set up the next time an app was installed or the
     * shell restarted.
     */
    property var _savedLayout: null

    function __quickLaunchBarDBResult(message) {
        var result = JSON.parse(message.payload);

        if( result && result.results && result.results.length ) {
            var objs = result.results.slice();
            objs.sort(function(a, b) { return a.pos - b.pos; });
            _savedLayout = objs.map(function(obj) { return obj.appId; });
            refreshConfig();
        }
    }

    //! The app ids on the bar, in the order shown.
    function currentLayout() {
        var ids = [];
        for( var i=0; i<launcherListModel.items.count; ++i )
            ids.push(launcherListModel.items.get(i).model.appId);
        return ids;
    }

    //! Makes ids the bar's arrangement: remembers it, stores it, shows it.
    function applyLayout(ids) {
        _savedLayout = ids;
        saveCurrentLayout(ids);
        // Not from inside the handler of a delegate that is about to go.
        Qt.callLater(refreshConfig);
    }

    function saveCurrentLayout(ids) {
        if( Settings.isTestEnvironment ) return;

        // first, clean up the DB
        __queryDB("del",
                  {query:{from:"org.webosports.lunalauncher:1"}},
                  function (message) {});

        // then build up the object to save
        var data = [];
        for( var i=0; i<ids.length; ++i ) {
            data.push({_kind: "org.webosports.lunalauncher:1",
                       pos: i,
                       appId: ids[i]});
        }

        // and put it in the DB
        if( data.length > 0 )
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
                      {query:{from:"org.webosports.lunalauncher:1", orderBy: "pos", limit: launchBarItem.maxIcons}},
                      __quickLaunchBarDBResult);
        }
        launcherRow.visible = true;
    }
    property var _defaultLaunchBarConfig: []

    // refreshes the quick launcher configuration: the saved arrangement if
    // there is one, the default one otherwise, using the apps model's icons so
    // they are always up to date
    function refreshConfig() {
        launcherListModel.model.clear();

        var order = _savedLayout;
        if( !order ) {
            order = _defaultLaunchBarConfig.map(function(launchPointId) {
                return launchPointId.replace(/_default$/, "");
            });
        }

        for( var j = 0; j < order.length; ++j ) {
            for( var i = 0; i < appsModel.count; ++i ) {
                var appObj = appsModel.get(i);
                if( appObj.id === order[j] ) {
                    launcherListModel.model.append({appId: appObj.id, icon: appObj.icon});
                    break;
                }
            }
        }
    }
}
