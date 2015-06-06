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
import QtGraphicalEffects 1.0

import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupListViewItem

    property bool enableDragnDrop: true

    property real maximizedCardTopMargin;

    property real cardScale: 0.6
    property real cardWindowWidth: width*cardScale
    property real cardWindowHeight: height*cardScale

    property Item cardView

    property bool interactiveList: true

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);

    focus: true
    Keys.forwardTo: internalListView
    Tweak {
        id: dragNDropTweak
        owner: "luna-next-cardshell"
        key: "stackedCardSupport"
        defaultValue: true
        onValueChanged: updateDragNDropTweak();

        function updateDragNDropTweak()
        {
            if (dragNDropTweak.value === true){
                console.log("INFO: Enabling Drag'n'Drop...");
                enableDragnDrop = true;
            }
            else {
                console.log("INFO: Disabling Drag'n'Drop...");
                enableDragnDrop = false;
            }
        }
    }

    VisualDataModel {
        id: groupsDataModel

        model: CardGroupModel {
            id: listCardGroupsModel

            onNewCardInserted: {
                if( !containerForDraggedCard.visible ) { // don't activate the new card group during drag'n'drop
                    internalListView.delayedCardSelect(newWindow);
                }
            }
        }

        delegate: CardGroupDelegate {
            id: cardGroupDelegateItem
            cardGroupListViewInstance: cardGroupListViewItem
            cardGroupModel: listCardGroupsModel
            groupModel: windowList

            delegateIsCurrent: ListView.isCurrentItem

            y: 0

            z: ListView.isCurrentItem ? 1 : 0

            onCardSelect: {
                listCardGroupsModel.setWindowInFront(window, index)
                cardGroupListViewItem.cardSelect(window);
            }
            onCardRemove: cardGroupListViewItem.cardRemove(window);
            onCardDragStart: {
                if( !enableDragnDrop ) {
                    console.log("Drag'n'drop is currently disabled.");
                }
                else if( containerForDraggedCard.visible ) {
                    console.log("A Drag'n'drop transaction is already ongoing. Please drop the dragged window somewhere valid.");
                }
                else if( listCardGroupsModel.listCardsModel.count >= 2 ) {
                    console.log("Entering drag'n'drop mode...");
                    cardGroupListViewItem.interactiveList = false;
                    containerForDraggedCard.startDrag(window);
                    listCardGroupsModel.removeWindow(window);
                }
            }
            onCardDragStop: {
                cardGroupListViewItem.interactiveList = true;
                containerForDraggedCard.stopDrag();
            }
        }
    }

    ListView {
        id: internalListView

        anchors.fill: parent

        preferredHighlightBegin: width/2-cardGroupListViewItem.cardWindowWidth/2
        preferredHighlightEnd: width/2+cardGroupListViewItem.cardWindowWidth/2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0

        model: groupsDataModel
        spacing: Units.gu(2)
        orientation: ListView.Horizontal
        smooth: !internalListView.moving
        focus: true
        interactive: cardGroupListViewItem.interactiveList

        onCurrentIndexChanged: {
            if( cardView && internalListView.currentIndex>=0 )
                cardView.currentCardChanged(currentActiveWindow())
        }

        function delayedCardSelect(windowToSelect) {
            cardSelectTimer._windowToSelect = windowToSelect;
            cardSelectTimer.start();
        }
        Timer {
            id: cardSelectTimer
            running: false; repeat: false; interval: 10
            onTriggered: {
                if(_windowToSelect) cardGroupListViewItem.cardSelect(_windowToSelect);
            }
            property Item _windowToSelect
        }

        function setCurrentCardIndex(newIndex) {
            internalListView.currentIndex = newIndex
        }
    }

    // This item is used during a Drag'n'Drop operation, to
    // temporarily hold the dragged card
    Item {
        id: containerForDraggedCard

        visible: false
        anchors.fill: internalListView
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

            property var _temporaryUnresolvedGroup
            property CardGroupDelegate _groupForUnresolvedCard
            property var _temporaryUnresolvedCard

            function insertUnresolvedGroup(groupAtCenter, insertOnLeft, wrappedWindow) {
                // CASE 1: insert temporary group on the left (or on the right) of "group"
                var destIndexTmp = insertOnLeft ? groupAtCenter.VisualDataModel.itemsIndex-1 : groupAtCenter.VisualDataModel.itemsIndex+1;
                if( _temporaryUnresolvedGroup && _temporaryUnresolvedGroup.itemsIndex !== destIndexTmp ) {
                    // we already have a temporary group ? remove it. (move doesn't work so well...)
                    listCardGroupsModel.remove(_temporaryUnresolvedGroup.itemsIndex,1);
                    _temporaryUnresolvedGroup = null;
                }
                if( !_temporaryUnresolvedGroup )
                {
                    if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                        // remove the temporary card
                        _groupForUnresolvedCard.groupModel.remove(_temporaryUnresolvedCard.itemsIndex, 1);
                        _temporaryUnresolvedCard = null;
                        _groupForUnresolvedCard = null;
                    }
                    // insert a new temporary group
                    var destIndex = insertOnLeft ? groupAtCenter.VisualDataModel.itemsIndex : groupAtCenter.VisualDataModel.itemsIndex+1;
                    listCardGroupsModel.createNewGroup(wrappedWindow, destIndex);
                   // groupsDataModel.items.insert(destIndex, {"windowList": _tmpEmptyListModel, "currentCardInGroup": 0});
                    _temporaryUnresolvedGroup = groupsDataModel.items.get(destIndex);
                }
            }

            function insertUnresolvedCard(group, card, wrappedWindow) {
                if( !card || !_temporaryUnresolvedCard ||
                    card.VisualDataModel.itemsIndex !== _temporaryUnresolvedCard.itemsIndex ) {
                    // CASE 2: temporary card
                    var destIndexTmp, destIndex;
                    if( _temporaryUnresolvedGroup ) {
                        // remove the temporary group
                        listCardGroupsModel.remove(_temporaryUnresolvedGroup.itemsIndex,1);
                        _temporaryUnresolvedGroup = null;
                    }

                    destIndexTmp = card ? card.VisualDataModel.itemsIndex+1 : 0;
                    // If we have to move the card, remove it first, because the "move" operation on delegate lists is bugged.
                    if( _groupForUnresolvedCard && _temporaryUnresolvedCard &&
                        ( _temporaryUnresolvedCard.itemsIndex !== destIndexTmp || _groupForUnresolvedCard !== group ) ) {
                        // remove the temporary card
                        _groupForUnresolvedCard.groupModel.remove(_temporaryUnresolvedCard.itemsIndex,1);
                        _temporaryUnresolvedCard = null;
                        _groupForUnresolvedCard = null;
                    }
                    if( !_groupForUnresolvedCard ) {
                        // no temporary card yet, insert a new temporary card above "card" (if not no card under, at the bottom of the stack)
                        destIndex = card ? card.VisualDataModel.itemsIndex+1 : 0;
                        group.groupModel.insert(destIndex, {"window": wrappedWindow});
                        _groupForUnresolvedCard = group;
                        _temporaryUnresolvedCard = group.visualGroupDataModel.items.get(destIndex);
                    }
                }
            }

            onPositionChanged: {
                //First, determine what group & card we are talking about
                var internalListViewCoords = mapToItem(internalListView, drag.x, drag.y);
                if( !internalListViewCoords ) return;
                var groupForDrop = internalListView.itemAt(internalListViewCoords.x+internalListView.contentX, internalListViewCoords.y+internalListView.contentY);
                if( !groupForDrop ) {
                    groupForDrop = internalListView.itemAt(internalListView.width/2+internalListView.contentX, internalListView.height/2+internalListView.contentY);
                    if( groupForDrop ) {
                        insertUnresolvedGroup(groupForDrop, internalListViewCoords.x < internalListView.width/2, drag.source.wrappedWindow);
                    }
                }
                else if( !_temporaryUnresolvedGroup || _temporaryUnresolvedGroup.itemsIndex !== groupForDrop.VisualDataModel.itemsIndex ) {
                    //We have the group, but ignore the temporary one if any
                    var cardCoordsX = drag.source.x + internalListView.contentX - groupForDrop.x;
                    var slidingCardDelegate = groupForDrop.cardAt(cardCoordsX, groupForDrop.height/2);
                    insertUnresolvedCard(groupForDrop, slidingCardDelegate, drag.source.wrappedWindow);
                }
            }
            onExited: {
                // clean up the temporary stuff
                if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                    // remove the temporary card if any
                    _groupForUnresolvedCard.groupModel.remove(_temporaryUnresolvedCard.itemsIndex, 1);
                }
                else if( _temporaryUnresolvedGroup ) {
                    // remove the temporary group if any
                    listCardGroupsModel.remove(_temporaryUnresolvedGroup.itemsIndex, 1);
                }
                _temporaryUnresolvedCard = null;
                _groupForUnresolvedCard = null;
                _temporaryUnresolvedGroup = null;
            }
            onDropped: {
                if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                    _groupForUnresolvedCard.cardDragStop();
                }
                else if( _temporaryUnresolvedGroup ) {
                    cardGroupListViewItem.interactiveList = true;
                    containerForDraggedCard.stopDrag();
                }
                else {
                    // last-chance fallback
                    listCardGroupsModel.createNewGroup(drag.source.wrappedWindow, 0);
                }

                _temporaryUnresolvedCard = null;
                _groupForUnresolvedCard = null;
                _temporaryUnresolvedGroup = null;

                console.log("Exited drag'n'drop mode.");
            }
        }
        Timer {
            id: scrollLeft
            running: leftDropArea.containsDrag
            interval: 10
            repeat: true
            onTriggered: internalListView.contentX -= internalListView.atXBeginning ? 0 : 5;
        }
        DropArea {
            id: leftDropArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width*0.1

            onDropped: {
                listCardGroupsModel.createNewGroup(drag.source.wrappedWindow, 0);
                cardGroupListViewItem.interactiveList = true;
                containerForDraggedCard.stopDrag();
            }
        }
        Timer {
            id: scrollRight
            running: rightDropArea.containsDrag
            interval: 10
            repeat: true
            onTriggered: internalListView.contentX += internalListView.atXEnd ? 0 : 5;
        }
        DropArea {
            id: rightDropArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width*0.1

            onDropped: {
                listCardGroupsModel.createNewGroup(drag.source.wrappedWindow, listCardGroupsModel.count);
                cardGroupListViewItem.interactiveList = true;
                containerForDraggedCard.stopDrag();
            }
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

    function currentActiveWindow() {
        if( internalListView.currentIndex >= 0 ) {
            return listCardGroupsModel.getCurrentCardOfGroup(listCardGroupsModel.get(internalListView.currentIndex));
        }

        return null;
    }

    function setCurrentActiveWindow(window) {
        var foundGroupIndex = listCardGroupsModel.setCurrentCard(window);
        if( foundGroupIndex>=0 ) {
            internalListView.setCurrentCardIndex(foundGroupIndex);
        }
    }
}

