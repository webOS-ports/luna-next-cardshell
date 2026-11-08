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
import QtQml.Models 2.2

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0
import LuneOS.Components 1.0

import "../Utils"
import "../AppTweaks"

Item {
    id: cardGroupListViewItem

    property bool enableDragnDrop: true

    //! The groups, for the card view and the tests
    readonly property alias cardGroupModel: listCardGroupsModel
    readonly property alias listView: internalListView

    property real maximizedCardTopMargin;

    property real cardScale: 0.6
    property real cardWindowWidth: width*cardScale
    property real cardWindowHeight: height*cardScale

    property bool interactiveList: true
    property bool isCardedViewActive: false

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);
    signal currentCardChanged();

    focus: true
    Component.onCompleted: updateKeysForwardTo(false)

    Connections {
        target: AppTweaks
        function onDragNDropTweakValueChanged() {
            updateDragNDropTweak();
        }

        function updateDragNDropTweak()
        {
            if (AppTweaks.dragNDropTweakValue === true){
                console.log("INFO: Enabling Drag'n'Drop...");
                enableDragnDrop = true;
            }
            else {
                console.log("INFO: Disabling Drag'n'Drop...");
                enableDragnDrop = false;
            }
        }
    }

    DelegateModel {
        id: groupsDataModel

        model: CardGroupModel {
            id: listCardGroupsModel

            activeGroupIndex: internalListView.currentIndex

            onNewCardInserted: (group, index, newWindow) => {
                // A new card ends any drag, as on LunaSysMgr, and comes forward
                cardGroupListViewItem.cancelCardDrag();
                internalListView.delayedCardSelect(newWindow);
            }
            onCardRemoved: (window) => {
                updateKeysForwardTo(false);
                if( window === cardGroupListViewItem.draggedWindow )
                    cardGroupListViewItem.cancelCardDrag();
            }
        }

        delegate: CardGroupDelegate {
            id: cardGroupDelegateItem
            cardGroupListViewInstance: cardGroupListViewItem
            cardGroupModel: listCardGroupsModel
            groupModel: windowList
            cardSpread: {
                // Not ListView.isCurrentItem: read in here, while a removed
                // group's delegate is laid out on its way out, it re-ran this
                // binding from inside itself (a binding loop on cardSpread).
                if(index === internalListView.currentIndex) {
                    if(cardGroupListViewItem.isCardedViewActive) {
                        // fetch ratio from card group model; gone while the
                        // delegate of a removed group is torn down
                        return spreadRatio !== undefined ? spreadRatio : 0.1;
                    } else {
                        return 0; // current card is maximized or fullscreen
                    }
                } else {
                    return 0.05; // default spreading when group isn't the current one
                }
            }

            delegateIsCurrent: ListView.isCurrentItem

            y: 0
            z: ListView.isCurrentItem ? 1 : 0

            onCardSelect: (window) => {
                //listCardGroupsModel.setWindowInFront(window, index)
                cardGroupListViewItem.cardSelect(window);
            }
            onCardRemove: (window) => cardGroupListViewItem.throwAway(window)
            onCardDragStart: (window) => cardGroupListViewItem.startCardDrag(window)
            onCardDragStop: cardGroupListViewItem.endCardDrag()
        }
    }

    /* Pinch to spread cards */
    PinchArea {
        anchors.fill: parent
        enabled: cardGroupListViewItem.interactiveList && !cardGroupListViewItem.draggedWindow
        property real _initialRatio: 0.1
        property bool _isCardAloneInGroup: true
        onPinchStarted: {
            var currentGroup = listCardGroupsModel.get(internalListView.currentIndex);
            _isCardAloneInGroup = (currentGroup.windowList.count === 1);
            if(_isCardAloneInGroup) {
                // pinch to zoom
                _initialRatio = cardGroupListViewItem.cardScale;
            } else {
                // pinch to spread
                _initialRatio = currentGroup.spreadRatio;
            }
        }
        onPinchFinished: {}
        onPinchUpdated: {
            var newRatio = _initialRatio*pinch.scale;
            if(_isCardAloneInGroup) {
                // pinch to zoom
                cardGroupListViewItem.cardScale = Math.max(0.2, Math.min(0.7, newRatio));
            } else {
                // pinch to spread
                listCardGroupsModel.get(internalListView.currentIndex).spreadRatio = Math.max(0.1, Math.min(0.6, newRatio));
            }
        }

        ListView {
            id: internalListView

            anchors.fill: parent

            // The current group in the middle, as a whole: LunaSysMgr slid
            // the active group to the centre of the screen (slideAllGroups).
            // A range one card wide centred a stack's first card instead.
            readonly property real currentGroupWidth: currentItem ? currentItem.width : cardWindowWidth
            preferredHighlightBegin: width/2-currentGroupWidth/2
            preferredHighlightEnd: width/2+currentGroupWidth/2
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            maximumFlickVelocity: width*10
            flickDeceleration: 0

            model: groupsDataModel
            spacing: Units.gu(2)
            orientation: ListView.Horizontal
            smooth: !internalListView.moving
            focus: true
            interactive: cardGroupListViewItem.interactiveList && !cardGroupListViewItem.draggedWindow
            snapMode: ListView.SnapOneItem

            onCurrentIndexChanged: {
                if( internalListView.currentIndex>=0 )
                    cardGroupListViewItem.currentCardChanged()
            }

            function delayedCardSelect(windowToSelect) {
                cardSelectTimer._windowToSelect = windowToSelect;
                cardSelectTimer._tries = 0;
                cardSelectTimer.start();
            }
            // A card can be listed before its wrapper is made, when the
            // surface is mapped: it can only be opened once it has one.
            Timer {
                id: cardSelectTimer
                running: false; repeat: false; interval: 10
                onTriggered: {
                    if(!_windowToSelect) return;
                    if(_windowToSelect.userData) cardGroupListViewItem.cardSelect(_windowToSelect);
                    else if(++_tries < 50) start();
                }
                property Item _windowToSelect
                property int _tries: 0
            }

            function setCurrentCardIndex(newIndex) {
                internalListView.currentIndex = newIndex
            }

            Keys.onPressed: (event) => {
                if (cardGroupListViewItem.isCardedViewActive) {
                    if (event.key === Qt.Key_Left) {
                        event.accepted = true;
                        // cycle between stacks of cards
                        setCurrentCardIndex(Math.max(currentIndex-1,0));
                        /* cycle between cards
                        var groupIndex = listCardGroupsModel.setCurrentCard(currentActiveWindow());
                        var group = listCardGroupsModel.get(groupIndex);
                        listCardGroupsModel.setCurrentCardInGroup(group, Math.max(group.currentCardInGroup-1,0));
                        */
                    }
                    if (event.key === Qt.Key_Right) {
                        event.accepted = true;
                        // cycle between stacks of cards
                        setCurrentCardIndex(Math.min(currentIndex+1,internalListView.count-1));
                        /* cycle between cards
                        var groupIndex = listCardGroupsModel.setCurrentCard(currentActiveWindow());
                        var group = listCardGroupsModel.get(groupIndex);
                        listCardGroupsModel.setCurrentCardInGroup(group, Math.min(group.currentCardInGroup+1,group.windowList.count-1));
                        */
                    }
                }
            }
        }

        // This item is used during a Drag'n'Drop operation, to
        // temporarily hold the dragged card. The card's place in the groups
        // follows it while it is dragged; this is only where it is drawn.
        Item {
            id: containerForDraggedCard

            visible: false
            anchors.fill: internalListView
            // LunaSysMgr's dragged card (CardWindowManager::enterReorder)
            opacity: 0.8

            Item {
                id: cardWindowWrapper

                anchors.fill: parent

                function setDraggedWindow(windowUserData) {
                    // convert position of card
                    var newPos = mapFromItem(windowUserData.parent, windowUserData.x, windowUserData.y)
                    // delete old anchors
                    windowUserData.anchors.fill = undefined;

                    // reparent
                    windowUserData.parent = cardWindowWrapper;

                    // set correct position
                    windowUserData.x = newPos.x;
                    windowUserData.y = newPos.y;
                    windowUserData.visible = true;
                }
            }

            DropArea {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: leftDropArea.right
                anchors.right: rightDropArea.left

                onEntered: (drag) => cardGroupListViewItem.__dragMovedTo(mapToItem(internalListView, drag.x, drag.y))
                onPositionChanged: (drag) => cardGroupListViewItem.__dragMovedTo(mapToItem(internalListView, drag.x, drag.y))
            }
            Timer {
                id: scrollLeft
                running: leftDropArea.containsDrag
                interval: 10
                repeat: true
                onTriggered: {
                    if( internalListView.atXBeginning )
                        cardGroupListViewItem.__dragPastTheEnd(true);
                    else
                        internalListView.contentX -= 5;
                }
            }
            DropArea {
                id: leftDropArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width*0.1
            }
            Timer {
                id: scrollRight
                running: rightDropArea.containsDrag
                interval: 10
                repeat: true
                onTriggered: {
                    if( internalListView.atXEnd )
                        cardGroupListViewItem.__dragPastTheEnd(false);
                    else
                        internalListView.contentX += 5;
                }
            }
            DropArea {
                id: rightDropArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: parent.width*0.1
            }

            function startDrag(window) {
                // this must be done *before* reparenting the window, otherwise the MouseArea will become hidden and this will cancel the mouse event
                containerForDraggedCard.visible = true;
                cardWindowWrapper.setDraggedWindow(window.userData);
            }
            function stopDrag() {
                containerForDraggedCard.visible = false;
            }
        }
    }

    ///////// Drag'n'drop //////////
    //
    // A held card can be dragged to another place in its group, into another
    // group, or out into a group of its own, as on LunaSysMgr
    // (CardWindowManager's ReorderState). The window stays in the model the
    // whole time and is moved there as the finger goes, so it always has
    // exactly one place: whatever ends the drag - a release anywhere, a
    // cancelled touch, a card opening or closing, the card view going away -
    // the card goes back into that place, with its shadow.

    //! The window being dragged, if any
    property Item draggedWindow: null

    // LunaSysMgr's cardGroupReorder animation: the slots settle before the
    // next step, so a card that moves under the finger does not bounce back.
    Timer {
        id: reorderStep
        interval: 350
        onTriggered: if( __pendingDragPoint ) cardGroupListViewItem.__dragMovedTo(__pendingDragPoint)
        property var __pendingDragPoint: null
    }

    function startCardDrag(window) {
        var wrapper = window ? window.userData : null;
        if( !wrapper ) return;

        var refusal = "";
        if( !enableDragnDrop )
            refusal = "Drag'n'drop is currently disabled.";
        else if( draggedWindow )
            refusal = "A Drag'n'drop transaction is already ongoing.";
        else if( !isCardedViewActive || !visible )
            refusal = "Cards can only be moved in the card view.";
        else if( listCardGroupsModel.listCardsModel.count < 2 || !listCardGroupsModel.find(window) )
            refusal = "There is nowhere else to put this card.";
        if( refusal ) {
            console.log(refusal);
            wrapper.cancelDrag();
            return;
        }

        console.log("Entering drag'n'drop mode...");
        draggedWindow = window;
        reorderStep.__pendingDragPoint = null;
        containerForDraggedCard.startDrag(window);
    }

    function endCardDrag() {
        if( !draggedWindow ) return;

        var window = draggedWindow;
        draggedWindow = null;
        reorderStep.stop();
        reorderStep.__pendingDragPoint = null;
        containerForDraggedCard.stopDrag();
        // Ended from here rather than by the card: let go of it too, so that
        // its place takes it back.
        if( window.userData )
            window.userData.cancelDrag();

        var groupIndex = listCardGroupsModel.setCurrentCard(window);
        if( groupIndex >= 0 )
            internalListView.currentIndex = groupIndex;
        console.log("Exited drag'n'drop mode.");
    }

    //! End any drag, the card going to where it was last put
    function cancelCardDrag() {
        endCardDrag();
    }

    // LunaSysMgr cancelled a reorder when the card view stopped being one
    // (maximize, lock, dock) - see CardWindowManager's signalExitReorder.
    onIsCardedViewActiveChanged: if( !isCardedViewActive ) cancelCardDrag()
    onVisibleChanged: if( !visible ) cancelCardDrag()

    // point is in internalListView's coordinates
    function __dragMovedTo(point) {
        if( !draggedWindow ) return;
        if( reorderStep.running ) {
            reorderStep.__pendingDragPoint = point;
            return;
        }
        reorderStep.__pendingDragPoint = null;

        var before = listCardGroupsModel.find(draggedWindow);
        if( !before ) return;
        before.groups = listCardGroupsModel.count;

        var x = point.x + internalListView.contentX;
        var y = point.y + internalListView.contentY;
        var groupIndex = internalListView.indexAt(x, y);
        if( groupIndex >= 0 ) {
            // Over a group: above the topmost card under the finger
            var group = internalListView.itemAt(x, y);
            var local = group.mapFromItem(internalListView, point.x, point.y);
            listCardGroupsModel.moveWindow(draggedWindow, groupIndex, group.slotAt(local.x));
        }
        else if( internalListView.currentIndex >= 0 ) {
            // Between groups: a group of its own, on that side of the middle one
            var middle = internalListView.currentIndex;
            listCardGroupsModel.moveWindowToNewGroup(draggedWindow, point.x < internalListView.width/2 ? middle : middle + 1);
        }

        __dragSettled(before);
    }

    // Held at either end of the list: a group of its own there
    function __dragPastTheEnd(atStart) {
        if( !draggedWindow || reorderStep.running ) return;
        var before = listCardGroupsModel.find(draggedWindow);
        if( !before ) return;
        before.groups = listCardGroupsModel.count;
        listCardGroupsModel.moveWindowToNewGroup(draggedWindow, atStart ? 0 : listCardGroupsModel.count);
        __dragSettled(before);
    }

    function __dragSettled(before) {
        var after = listCardGroupsModel.find(draggedWindow);
        if( !after ) return;
        // A new group, or an emptied one gone, changes the count even when
        // the card's indexes stay the same.
        if( after.group !== before.group || after.card !== before.card ||
            listCardGroupsModel.count !== before.groups ) {
            internalListView.currentIndex = after.group;
            reorderStep.restart();
        }
    }

    ///////// Closing cards //////////
    //
    // A card thrown away leaves its group at once, as on LunaSysMgr
    // (CardWindowManager::closeWindow, then removeCardFromGroup), rather than
    // when its app's surface goes, which can take a while or never happen.
    // Kept in the group meanwhile, it sat there swiped out of sight, and as
    // the current group it was the one in the middle, so the card left on
    // its own was off to one side. An app that is still there after a while
    // has ignored the close, and gets its card back.

    property var __closingWindows: []

    Timer {
        id: closingTimeout
        interval: 5000
        onTriggered: cardGroupListViewItem.__restoreUnclosed()
    }

    function throwAway(window) {
        updateKeysForwardTo(false);
        if( listCardGroupsModel.find(window) ) {
            if( window === draggedWindow )
                cancelCardDrag();
            listCardGroupsModel.removeWindow(window);
            __closingWindows.push(window);
            closingTimeout.restart();
        }
        cardRemove(window);
    }

    function __restoreUnclosed() {
        var stillThere = [];
        for( var i = 0; i < listCardGroupsModel.listCardsModel.count; ++i ) {
            var window = listCardGroupsModel.listCardsModel.get(i);
            if( __closingWindows.indexOf(window) >= 0 )
                stillThere.push(window);
        }
        __closingWindows = [];
        for( var j = 0; j < stillThere.length; ++j ) {
            console.log("Card " + stillThere[j] + " was thrown away but did not close; putting it back");
            listCardGroupsModel.restoreWindow(stillThere[j]);
        }
    }

    function currentActiveWindow() {
        if( internalListView.currentIndex >= 0 ) {
            return listCardGroupsModel.getCurrentCardOfGroup(listCardGroupsModel.get(internalListView.currentIndex));
        }

        return null;
    }

    function setCurrentActiveWindow(window) {
        // Brought forward again before it closed (the app was launched
        // again): it gets its card back.
        if( __closingWindows.indexOf(window) >= 0 && !listCardGroupsModel.find(window) ) {
            __closingWindows.splice(__closingWindows.indexOf(window), 1);
            listCardGroupsModel.restoreWindow(window);
        }
        var foundGroupIndex = listCardGroupsModel.setCurrentCard(window);
        if( foundGroupIndex>=0 ) {
            internalListView.setCurrentCardIndex(foundGroupIndex);
        }
        updateKeysForwardTo(true);
    }

    function updateKeysForwardTo(addWindow) {
        if (addWindow)
            Keys.forwardTo = [internalListView, currentActiveWindow()];
        else
            Keys.forwardTo = [internalListView];
    }
}

