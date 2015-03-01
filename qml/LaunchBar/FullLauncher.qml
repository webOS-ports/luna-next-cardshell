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
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import LunaNext.Common 0.1
import LuneOS.Service 1.0

import "../LunaSysAPI" as LunaSysAPI


Image {
    id: fullLauncher

    property real iconSize: Units.gu(12)
    property real bottomMargin: Units.gu(8)

    function calculateAppIconHMargin(_parent, appIconWidth) {
        var nbCellsPerLine = Math.floor(_parent.width / (appIconWidth + 10));
        var remainingHSpace = _parent.width - nbCellsPerLine * appIconWidth;
        return Math.floor(remainingHSpace / nbCellsPerLine);
    }

    property real appIconWidth: iconSize*1.5
    property real appIconHMargin: calculateAppIconHMargin(fullLauncher, appIconWidth)

    property real cellWidth: appIconWidth + appIconHMargin
    property real cellHeight: iconSize + iconSize*0.4*2 // we give margin for two lines of text

    property bool isEditionActive: false

    signal startLaunchApplication(string appId, string appParams)

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    source: "../images/launcher/launcher-bg.png"
    fillMode: Image.Tile

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: fullLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: fullLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: fullLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: fullLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: fullLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
            }
        }
    ]

    // background of the tabs row list
    BorderImage {
        border { top: 20; bottom: 20; left: 4; right: 4 }
        source: Qt.resolvedUrl("../images/launcher/tab-bg.png");
        anchors.fill: tabRowList
    }
    Image {
        anchors.top: tabRowList.bottom
        width: tabRowList.width
        height: 8
        source: Qt.resolvedUrl("../images/launcher/tab-shadow.png");
        fillMode: Image.Tile
    }

    ListView {
        id: tabRowList
        anchors.top: parent.top
        width: parent.width
        height: Units.gu(4)        
        orientation: ListView.Horizontal
        onCurrentIndexChanged: tabContentList.currentIndex = currentIndex
        delegate: Button {
            id: tabRowDelegate
            width: Units.gu(20)
            height: tabRowList.height
            checked: tabRowDelegate.ListView.isCurrentItem
            style: ButtonStyle {
                id: tabButtonStyle
                property string neutralButtonImage: Qt.resolvedUrl("../images/launcher/tab-bg.png");
                property string neutralButtonImagePressed: Qt.resolvedUrl("../images/launcher/tab-selected-bg.png");

                background: BorderImage {
                    property int borderSize: tabButtonStyle.control.checked ? 20 : 4
                    border { top: 20; bottom: 20; left: borderSize; right: borderSize }
                    source: tabButtonStyle.control.checked ? neutralButtonImagePressed: neutralButtonImage;
                }
                label: Text {
                    color: "white"
                    text: tabButtonStyle.control.text
                    font.family: Settings.fontStatusBar
                    font.pixelSize: tabRowDelegate.height*0.6
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            onClicked: {
                tabRowDelegate.ListView.view.currentIndex = index;
            }
            text: model.text

            // the separator on the left should only be visible if is not adjacent to a selected tab
            Image {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                source: Qt.resolvedUrl("../images/launcher/tab-divider.png");
                visible: !tabRowDelegate.ListView.isCurrentItem &&
                         tabRowDelegate.ListView.view.currentIndex !== index + 1
            }
        }

        model: ListModel {
            ListElement { text: "Apps" }
            ListElement { text: "Downloads" }
            ListElement { text: "Favorites" }
            ListElement { text: "Prefs" }
        }
    }
    Button {
        id: tabRowFooter
        width: Units.gu(10)
        height: tabRowList.height * 0.85
        anchors.right: tabRowList.right; anchors.rightMargin: 8
        anchors.verticalCenter: tabRowList.verticalCenter
        visible: fullLauncher.isEditionActive
        style: ButtonStyle {
            id: tabFooterButtonStyle
            property string doneButtonImage: Qt.resolvedUrl("../images/launcher/edit-button-done.png");
            property string doneButtonImagePressed: Qt.resolvedUrl("../images/launcher/edit-button-done-pressed.png");

            background: BorderImage {
                border { top: 10; bottom: 10; left: 10; right: 10 }
                source: tabFooterButtonStyle.control.pressed ? doneButtonImagePressed: doneButtonImage;
            }
            label: Text {
                color: "white"
                text: tabFooterButtonStyle.control.text
                font.family: Settings.fontStatusBar
                font.pixelSize: tabRowFooter.height*0.6
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        onClicked: {
            fullLauncher.isEditionActive = false;
        }
        text: "DONE"
    }

    LunaSysAPI.ApplicationModel {
        id: commonAppsModel
    }

    ListView {
        id: tabContentList
        anchors.top: tabRowList.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fullLauncher.bottomMargin
        width: fullLauncher.width
        clip: true
        orientation: ListView.Horizontal
        cacheBuffer: fullLauncher.width*tabRowList.model.count // don't destroy the delegates

        snapMode: ListView.SnapOneItem

        preferredHighlightBegin: 0
        preferredHighlightEnd: width
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 300
        onCurrentIndexChanged: tabRowList.currentIndex = currentIndex

        model: tabRowList.model

        delegate: Item {
            id: tabContentItem
            width: ListView.view.width
            height: ListView.view.height

            property string tabId: model.text

            GridView {
                id: fullLauncherGridView
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Units.gu(1)
                width: Math.floor(fullLauncher.width / fullLauncher.cellWidth) * fullLauncher.cellWidth
                height: parent.height

                model: DraggableAppIconDelegateModel {
                        id: draggableAppIconDelegateModel
                        // list of icons, filtered on that tab
                        model: TabApplicationModel {
                            appsModel: commonAppsModel // one app model for all tab models
                            launcherTab: tabContentItem.tabId
                            isDefaultTab: tabContentItem.tabId === "Apps" // apps without any tab indication go to the Apps tab
                        }

                        isEditionActive: fullLauncher.isEditionActive

                        dragParent: fullLauncher
                        dragAxis: Drag.XAndYAxis
                        iconWidth: fullLauncher.appIconWidth
                        iconSize: fullLauncher.iconSize

                        onStartLaunchApplication: fullLauncher.startLaunchApplication(appId, appParams);

                        onStartEdition: fullLauncher.isEditionActive = true;

                        onSaveCurrentLayout: {
                                if( Settings.isTestEnvironment ) return;

                                // first, clean up the DB
                                __queryDB("del",
                                          {query:{from:"org.webosports.lunalaunchertab:1"},
                                            where: [ {prop:"tab",op:"=",val:tabContentItem.tabId} ]},
                                          function (message) {});

                                // then build up the object to save
                                var data = [];
                                for( var i=0; i<draggableAppIconDelegateModel.items.count; ++i ) {
                                    var obj = draggableAppIconDelegateModel.items.get(i);
                                    data.push({_kind: "org.webosports.lunalaunchertab:1",
                                                  pos: obj.itemsIndex,
                                                  tab:tabContentItem.tabId,
                                                  appId: obj.model.appId});
                                }

                                // and put it in the DB
                                __queryDB("put", {objects: data}, function (message) {});
                        }
                }


                cellWidth: fullLauncher.cellWidth
                cellHeight: fullLauncher.cellHeight

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x, y"; duration: 200 }
                }

                /* Drop areas of the grid */
                DropArea {
                    // drop area on the left side of the grid
                    anchors {
                        top: parent.top; bottom: parent.bottom; left: parent.left
                    }
                    width: Units.gu(1)
                    Timer {
                        id: turnLeftTimer
                        interval: 500; running: false; repeat: false
                        onTriggered: tabContentList.decrementCurrentIndex();
                    }
                    onEntered: {
                        if( tabContentList.currentIndex > 0 )
                            turnLeftTimer.start();
                    }
                    onDropped: {
                    }
                    onExited: turnLeftTimer.stop();
                }
                DropArea {
                    // drop area on the right side of the grid
                    anchors {
                        top: parent.top; bottom: parent.bottom; right: parent.right
                    }
                    width: Units.gu(1)
                    Timer {
                        id: turnRightTimer
                        interval: 500; running: false; repeat: false
                        onTriggered: tabContentList.incrementCurrentIndex();
                    }
                    onEntered: {
                        if( tabContentList.currentIndex < tabContentList.count-1 )
                            turnRightTimer.start();
                    }
                    onExited: turnRightTimer.stop();
                }
                DropArea {
                    // main drop area covering the grid
                    property variant placeHolderItem;
                    anchors {
                        fill: parent
                        margins: Units.gu(1)
                    }
                    onEntered: {
                        // Find what index the drag is covering
                        var coordsDragInGridView = mapToItem(fullLauncherGridView, drag.x, drag.y);
                        var placeHolderPosition = fullLauncherGridView.indexAt(coordsDragInGridView.x, coordsDragInGridView.y+fullLauncherGridView.contentY);
                        if( placeHolderPosition < 0 )
                        {
                            // if the drag is not yet over an item, put the placeholder at the end
                            placeHolderPosition = draggableAppIconDelegateModel.items.count;
                        }
                        if( draggableAppIconDelegateModel.model.count === 0 ) {
                            // if there is no item in the persistent model, there is no properties either.
                            // This prevents us from inserting a light dynamic placeholder.
                            // So create an item in the model with the same properties.
                            draggableAppIconDelegateModel.model.insert(placeHolderPosition, {title: "", icon: "", id: "", params: ""});
                        }
                        else {
                            // Insert a new placeholder at that position
                            draggableAppIconDelegateModel.items.insert(placeHolderPosition, {title: "", icon: "", id: "", params: ""});
                        }
                        placeHolderItem = draggableAppIconDelegateModel.items.get(placeHolderPosition);
                    }
                    onPositionChanged: {
                        // Move the placeholder where the drag is
                        var coordsDragInGridView = mapToItem(fullLauncherGridView, drag.x, drag.y);
                        var placeHolderPosition = fullLauncherGridView.indexAt(coordsDragInGridView.x, coordsDragInGridView.y+fullLauncherGridView.contentY);
                        if( placeHolderPosition >= 0 && placeHolderPosition < draggableAppIconDelegateModel.items.count &&
                            placeHolderItem &&
                            placeHolderItem.itemsIndex !== placeHolderPosition ) {
                            draggableAppIconDelegateModel.items.move( placeHolderItem.itemsIndex, placeHolderPosition );
                        }
                    }
                    onExited: {
                        if( placeHolderItem.isUnresolved ) {
                            // Remove the placeholder
                            placeHolderItem.inItems = false;
                        }
                        else {
                            // The placeholder represents a real data: remove it
                            draggableAppIconDelegateModel.model.remove(placeHolderItem.itemsIndex);
                        }
                        placeHolderItem = undefined;
                    }
                    onDropped: {
                        if( placeHolderItem.isUnresolved ) {
                            // Commit the placeholder with the drag source data
                            placeHolderItem.model.title = drag.source.modelTitle;
                            placeHolderItem.model.icon = drag.source.modelIcon;
                            placeHolderItem.model.id = drag.source.modelId;
                            placeHolderItem.model.params = drag.source.modelParams;
                        }
                        else {
                            // The placeholder represents a real data: remove it
                            draggableAppIconDelegateModel.model.set(placeHolderItem.itemsIndex,
                                     {title : drag.source.modelTitle,
                                       icon: drag.source.modelIcon,
                                       id: drag.source.modelId,
                                       params: drag.source.modelParams});
                        }
                        // ... And just forget about it.
                        placeHolderItem = undefined;

                        // save that layout in DB
                        draggableAppIconDelegateModel.saveCurrentLayout();
                    }
                }
            }
        }
    }

    // db8 management
    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "org.webosports.luna"
        usePrivateBus: true
    }
    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                  handleResultFct, __handleDBError)
    }
}
