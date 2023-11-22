/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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
import QtQuick.Controls.LuneOS 2.0
//import QtQuick.Controls.Styles 1.1
import QtQml 2.15
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import LuneOS.Components 1.0

import "../Utils"
import "../LunaSysAPI" as LunaSysAPI
import "../AppTweaks"


Item {
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
    property real cellHeight: iconSize + Units.gu(1.4)*2 + Units.gu(3)  // we give margin for two lines of text

    property bool isEditionActive: false

    signal startLaunchApplication(string appId, var appParams)

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    focus: true
    Keys.onPressed: {
        if (event.key === Qt.Key_Left) {
            event.accepted = true;
            tabRowList.currentIndex = Math.max(tabRowList.currentIndex - 1,0);
        }
        if (event.key === Qt.Key_Right) {
            event.accepted = true;
            tabRowList.currentIndex = Math.min(tabRowList.currentIndex + 1,tabRowList.count-1);
        }
    }

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: fullLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: fullLauncher; visible: false }
            PropertyChanges { target: fullLauncher; isEditionActive: false; restoreEntryValues: false }
            PropertyChanges { target: flkMouseArea; contentY: 0; restoreEntryValues: false }
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

    // Background of the full launcher
    Image {
        anchors.fill: parent
        source: "../images/launcher/launcher-bg.png"
        fillMode: Image.Tile

        MouseArea {
            anchors.fill: parent
            onClicked: fullLauncher.isEditionActive = false;
        }
    }

    // Background of the tabs row list
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

        interactive: !draggedLauncherIcon.draggingActive

        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: AppTweaks.tabIndicatorNumberTweakValue === "default" ? width/2 - Units.gu(10) : 0;
        preferredHighlightEnd: AppTweaks.tabIndicatorNumberTweakValue === "default" ? width/2 + Units.gu(10) : tabRowList.width;
        highlightMoveDuration: 500
        highlightMoveVelocity: -1

        snapMode: ListView.SnapOneItem

        //Optional arrow indicators
        Image {
            anchors {
                left: parent.left
                leftMargin: Units.gu(0.5)
                verticalCenter: parent.verticalCenter
            }
            source: Qt.resolvedUrl("../images/launcher/dark-arrow-left.png")
            height: Units.gu(2.5)
            fillMode: Image.PreserveAspectFit
            visible: !tabRowList.atXBeginning
            smooth: true
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    tabRowList.currentIndex = tabRowList.currentIndex - 1
                }
            }
        }

        Image {
            anchors {
                right: parent.right
                rightMargin: Units.gu(0.5)
                verticalCenter: parent.verticalCenter
            }
            source: Qt.resolvedUrl(
                        "../images/launcher/dark-arrow-right.png")
            height: Units.gu(2.5)
            fillMode: Image.PreserveAspectFit
            visible: !tabRowList.atXEnd
            smooth: true
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    tabRowList.currentIndex = tabRowList.currentIndex + 1
                }
            }
        }


        onCurrentIndexChanged: tabContentList.currentIndex = currentIndex;

        Component.onCompleted: {
            tabRowList.positionViewAtBeginning();
        }

        delegate: Button {
            id: tabRowDelegate
            width: AppTweaks.tabIndicatorNumberTweakValue === "default" ? Units.gu(20) :
                   AppTweaks.tabIndicatorNumberTweakValue === "all" ? tabRowList.width / tabRowDelegate.ListView.view.count :
                                                                      tabRowList.width / AppTweaks.tabIndicatorNumberTweakValue
            height: tabRowList.height
            checked: tabRowDelegate.ListView.isCurrentItem

            property bool highlight: false

            background: BorderImage {
                readonly property string neutralButtonImage: Qt.resolvedUrl("../images/launcher/tab-bg.png");
                readonly property string neutralButtonImagePressed: Qt.resolvedUrl("../images/launcher/tab-selected-bg.png");
                readonly property string neutralButtonImageHighlight: Qt.resolvedUrl("../images/launcher/tab-highlight.png");

                property int borderSize: tabRowDelegate.checked ? 20 : 4
                border { top: 20; bottom: 20; left: borderSize; right: borderSize }
                source: tabRowDelegate.highlight ? neutralButtonImageHighlight : tabRowDelegate.checked ? neutralButtonImagePressed: neutralButtonImage;
            }

            onClicked: {
                tabRowDelegate.ListView.view.currentIndex = index;
            }
            text: AppTweaks.tabTitleCaseTweakValue === "upperCase" ? model.text.toString().toUpperCase() :
                  AppTweaks.tabTitleCaseTweakValue === "lowerCase" ? model.text.toString().toLowerCase() : model.text

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
        visible: fullLauncher.isEditionActive && !draggedLauncherIcon.draggingActive

        LuneOSButton.mainColor: LuneOSButton.blueColor

        background: BorderImage {
            readonly property string doneButtonImage: Qt.resolvedUrl("../images/launcher/edit-button-done.png");
            readonly property string doneButtonImagePressed: Qt.resolvedUrl("../images/launcher/edit-button-done-pressed.png");

            border { top: 10; bottom: 10; left: 10; right: 10 }
            source: tabRowFooter.pressed ? doneButtonImagePressed: doneButtonImage;
        }

        onClicked: {
            fullLauncher.isEditionActive = false;
        }
        text: "DONE"
    }
    /* Drop areas of the row buttons */
    DropArea {
        // drop area on the left side of the grid
        anchors.fill: tabRowList
        onEntered: {
            // Find what index the drag is covering
            var coordsDragInTabRowList = mapToItem(tabRowList, drag.x, drag.y);
            var dragPosition = tabRowList.indexAt(coordsDragInTabRowList.x+tabRowList.contentX, 0);
            if( dragPosition >= 0 ) {
                tabRowList.currentItem.highlight = false;
                tabRowList.currentIndex = dragPosition;
                tabRowList.currentItem.highlight = true;
            }
        }
        onExited: {
            tabRowList.currentItem.highlight = false;
        }
        onPositionChanged: {
            // Find what index the drag is covering
            var coordsDragInTabRowList = mapToItem(tabRowList, drag.x, drag.y);
            var dragPosition = tabRowList.indexAt(coordsDragInTabRowList.x+tabRowList.contentX, 0);
            if( dragPosition >= 0 && dragPosition !==  tabRowList.currentIndex ) {
                tabRowList.currentItem.highlight = false;
                tabRowList.currentIndex = dragPosition;
                tabRowList.currentItem.highlight = true;
            }
        }
    }

    property ListModel commonAppsModel

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

        interactive: !draggedLauncherIcon.draggingActive

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

            property alias launcherGridView: fullLauncherGridView
            property string tabId: model.text

            GridView {
                id: fullLauncherGridView
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Units.gu(1)
                width: Math.floor(fullLauncher.width / fullLauncher.cellWidth) * fullLauncher.cellWidth
                height: parent.height

                // list of icons, filtered on that tab
                model: TabApplicationModel {
                    id: gridTabModel
                    appsModel: commonAppsModel // one app model for all tab models
                    launcherTab: tabContentItem.tabId
                    isDefaultTab: tabContentItem.tabId === "Apps" // apps without any tab indication go to the Apps tab
                }

                Connections {
                    target: commonAppsModel
                    function onAppsModelRefreshed() {
                        gridTabModel.refreshConfig();
                    }
                }

                delegate: DraggableAppIcon {
                    modelTitle: model.title
                    modelIcon: model.icon
                    modelId: model.id
                    modelParams:  (typeof model.params === "undefined") ? ({}) : model.params
                    modelIndex: index
                    modelRemovable: !!model.removable
                    modelHideable: false

                    iconWidth: fullLauncher.appIconWidth
                    iconSize: fullLauncher.iconSize

                    editionMode: fullLauncher.isEditionActive

                    width: fullLauncher.cellWidth
                    height: fullLauncher.cellHeight

                    onStartLaunchApplication: {
                        if( !fullLauncher.isEditionActive ) fullLauncher.startLaunchApplication(appId, appParams);
                    }
                    onRemoveAppLauncher:  {
                        if( fullLauncher.isEditionActive ) fullLauncher.removeApplication(appId);
                    }
                }

                cellWidth: fullLauncher.cellWidth
                cellHeight: fullLauncher.cellHeight

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x, y"; duration: 200 }
                }

                Connections {
                    target: fullLauncher
                    function onIsEditionActiveChanged () {
                        if( !fullLauncher.isEditionActive ) {
                            fullLauncherGridView.saveCurrentLayout();
                        }
                    }
                }

                function saveCurrentLayout() {
                        if( Settings.isTestEnvironment ) return;

                        // first, clean up the DB
                        __queryDB("del",
                                  {query:{from:"org.webosports.lunalaunchertab:1",
                                    where: [ {prop:"tab",op:"=",val:tabContentItem.tabId} ]}},
                                  function (message) {});

                        // then build up the object to save
                        var data = [];
                        for( var i=0; i<gridTabModel.count; ++i ) {
                            var obj = gridTabModel.get(i);
                            data.push({_kind: "org.webosports.lunalaunchertab:1",
                                          pos: i,
                                          tab:tabContentItem.tabId,
                                          appId: obj.id});
                        }

                        // and put it in the DB
                        __queryDB("put", {objects: data}, function (message) {});
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

                    Image {
                        anchors.fill: parent
                        visible: turnLeftTimer.running
                        fillMode: Image.TileVertically
                        source: Qt.resolvedUrl("../images/launcher/scroll-tab-left.png")
                    }
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

                    Image {
                        anchors.fill: parent
                        visible: turnRightTimer.running
                        fillMode: Image.TileVertically
                        source: Qt.resolvedUrl("../images/launcher/scroll-tab-right.png")
                    }
                }
                DropArea {
                    // main drop area covering the grid
                    property int placeHolderPosition;
                    anchors {
                        fill: parent
                        margins: Units.gu(1)
                    }
                    onEntered: {
                        // Find what index the drag is covering
                        var coordsDragInGridView = mapToItem(fullLauncherGridView, drag.x, drag.y);
                        placeHolderPosition = fullLauncherGridView.indexAt(coordsDragInGridView.x, coordsDragInGridView.y+fullLauncherGridView.contentY);
                        if( placeHolderPosition < 0 )
                        {
                            // if the drag is not yet over an item, put the placeholder at the end
                            placeHolderPosition = gridTabModel.count;
                        }

                        gridTabModel.insert(placeHolderPosition, {title: "", icon: "", id: "", params: "", removable: false});
                    }
                    onPositionChanged: {
                        // Move the placeholder where the drag is
                        var coordsDragInGridView = mapToItem(fullLauncherGridView, drag.x, drag.y);
                        var destPlaceHolderPosition = fullLauncherGridView.indexAt(coordsDragInGridView.x, coordsDragInGridView.y+fullLauncherGridView.contentY);
                        if( destPlaceHolderPosition >= 0 && destPlaceHolderPosition < gridTabModel.count &&
                            placeHolderPosition !== destPlaceHolderPosition ) {
                            gridTabModel.move( placeHolderPosition, destPlaceHolderPosition, 1 );
                            placeHolderPosition = destPlaceHolderPosition;
                        }
                    }
                    onExited: {
                        // The placeholder represents a real data: remove it
                        gridTabModel.remove(placeHolderPosition);
                    }
                    onDropped: {
                        // The placeholder represents a real data: remove it
                        gridTabModel.set(placeHolderPosition,
                                 {title : drag.source.modelTitle,
                                   icon: drag.source.modelIcon,
                                   id: drag.source.modelId,
                                   params: drag.source.modelParams,
                                   removable: drag.source.modelRemovable});
                    }
                }
            }
        }

        Flickable {
            id: flkMouseArea
            anchors { fill: parent }
            flickableDirection: Flickable.VerticalFlick

            interactive: !dragArea.held

            contentHeight: tabContentList.currentItem.launcherGridView.contentHeight
            contentWidth: tabContentList.currentItem.launcherGridView.contentWidth

            // bind the Y with the Y of the grid
            Binding {
                target: tabContentList.currentItem.launcherGridView
                property: "contentY"
                value: flkMouseArea.contentY
                when: !!tabContentList.currentItem.launcherGridView
                restoreMode: Binding.RestoreBinding
            }

            /* Drag area of the grids */
            MouseArea {
                id: dragArea
                anchors { fill: parent }

                drag.target: held ? draggedLauncherIcon : undefined
                drag.axis: (!held) ? Drag.XAxis : Drag.XAndYAxis

                property GridView currentGridView: tabContentList.currentItem.launcherGridView

                property bool held: false
                Timer {
                    id: releaseHeld
                    interval: 200; running: false; repeat: false
                    onTriggered: dragArea.held = false;
                }

                propagateComposedEvents: true

                onPressed:  {
                    if( fullLauncher.isEditionActive && !held ) {
                        console.log("=== drag ===");

                        var coordsDragInGridView = mapToItem(currentGridView, mouse.x, mouse.y);
                        var targetItem = currentGridView.itemAt(coordsDragInGridView.x, coordsDragInGridView.y+currentGridView.contentY);

                        if( targetItem )
                        {
                            draggedLauncherIcon.initiateDragWithItem(targetItem, targetItem.x, targetItem.y-currentGridView.contentY);
                            held = true;

                            currentGridView.model.remove(targetItem.modelIndex);

                            draggedLauncherIcon.draggingActive = true;
                        }
                        else
                        {
                            console.log("Couldn't deduce which item was under mouse!");
                        }
                    }
                }
                onPressAndHold: {
                    if( !held ) {
                        console.log("=== drag ===");
                        // move our delegate to the persisted items group

                        var coordsDragInGridView = mapToItem(currentGridView, mouse.x, mouse.y);
                        var targetItem = currentGridView.itemAt(coordsDragInGridView.x, coordsDragInGridView.y+currentGridView.contentY);

                        if( targetItem ) {
                            draggedLauncherIcon.initiateDragWithItem(targetItem, targetItem.x, targetItem.y-currentGridView.contentY);
                            fullLauncher.isEditionActive = true;
                            held = true;

                            currentGridView.model.remove(targetItem.modelIndex);

                            draggedLauncherIcon.draggingActive = true;
                        }
                        else
                        {
                            console.log("Couldn't deduce which item was under mouse!");
                        }
                    }
                }
                onReleased: {
                    if( held && !releaseHeld.running ) {
                        console.log("trigger drop");
                        if( draggedLauncherIcon.Drag.target && (typeof draggedLauncherIcon.Drag.target.placeHolderPosition !== "undefined") ) {
                            draggedLauncherIcon.Drag.drop();
                        }
                        else {
                            console.log("no drop target, resetting drag source");
                            currentGridView.model.insert(draggedLauncherIcon.modelIndex,
                                                {title : draggedLauncherIcon.modelTitle,
                                                 icon: draggedLauncherIcon.modelIcon,
                                                 id: draggedLauncherIcon.modelId,
                                                 params: draggedLauncherIcon.modelParams,
                                                 removable: draggedLauncherIcon.modelRemovable});
                        }

                        draggedLauncherIcon.draggingActive = false;
                        releaseHeld.start();
                    }
                }
            }
        }

        DraggableAppIcon {
            id: draggedLauncherIcon

            iconWidth: fullLauncher.appIconWidth
            iconSize: fullLauncher.iconSize

            editionMode: fullLauncher.isEditionActive

            width: fullLauncher.cellWidth
            height: fullLauncher.cellHeight

            visible: draggingActive

            function initiateDragWithItem(targetItem, atX, atY) {
                draggedLauncherIcon.modelTitle = targetItem.modelTitle
                draggedLauncherIcon.modelIcon = targetItem.modelIcon
                draggedLauncherIcon.modelId = targetItem.modelId
                draggedLauncherIcon.modelParams = targetItem.modelParams
                draggedLauncherIcon.modelIndex = targetItem.modelIndex
                draggedLauncherIcon.modelRemovable = targetItem.modelRemovable
                draggedLauncherIcon.modelHideable = false

                draggedLauncherIcon.x = atX;
                draggedLauncherIcon.y = atY;
            }
        }
    }

    // ls2 management
    property QtObject lunaNextLS2Service: LunaService {
        id: lunaNextLS2Service
        name: "com.webos.surfacemanager-cardshell"
    }
    // ls2 db8 management
    function __handleDBError(message) {
        console.log("Could not fulfill DB operation : " + message)
    }

    function __queryDB(action, params, handleResultFct) {
        lunaNextLS2Service.call("luna://com.palm.db/" + action, JSON.stringify(params),
                  handleResultFct, __handleDBError)
    }

    // ls2 launchPoint removal
    function removeApplication(id) {
        console.log("Removing app " + id);
        lunaNextLS2Service.call("luna://com.webos.appInstallService/remove",
            JSON.stringify({"id": id}), undefined, handleRemoveAppError)
    }
    function handleRemoveAppError(message) {
        console.log("Could not remove application : " + message);
    }
}
