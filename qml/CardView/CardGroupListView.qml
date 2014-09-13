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

    property bool enableDragnDrop: false

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
        defaultValue: "false"
        onValueChanged: updateDragNDropTweak();

        function updateDragNDropTweak()
        {
            if (dragNDropTweak.value === "true"){
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

            onRowsInserted: {
                if( !containerForDraggedCard.visible ) { // don't activate the new card group during drag'n'drop
                    internalListView.newGroupIndex = last;
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
                height: cardGroupListViewItem.height
                width: cardGroupListViewItem.cardWindowWidth * (0.9+0.1*windowList.count)

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

        model: groupsDataModel
        spacing: 0
        orientation: ListView.Horizontal
        smooth: !internalListView.moving
        focus: true
        interactive: cardGroupListViewItem.interactiveList

        property int newGroupIndex: -1
        onCountChanged: {
            if( newGroupIndex>=0 && count > 0 ) {
                var newGroup = listCardGroupsModel.get(newGroupIndex);
                var lastWindow = listCardGroupsModel.getCurrentCardOfGroup(newGroup);
                if( lastWindow ) {
                    cardGroupListViewItem.cardSelect(lastWindow);
                }
                else {
                    currentIndex = newGroupIndex;
                }
                newGroupIndex = -1;
            }
        }

        function setCurrentCardIndex(newIndex) {
            internalListView.currentIndex = newIndex
            if( cardView && internalListView.currentIndex>=0 ) {
                cardView.currentCardChanged(currentActiveWindow())
            }
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
            property ListModel _tmpEmptyListModel: ListModel {}

            function insertUnresolvedCard(group, card, xRatio) {
                // If we are on the border of the group, insert a new temporary group before/after that group
                if( xRatio < 0.02 || xRatio > 0.98 ) {
                    console.log("CASE 1 : temporary group");
                    var destIndex = xRatio < 0.02 ? group.VisualDataModel.itemsIndex : group.VisualDataModel.itemsIndex+1;
                    // insert temporary group on the left of "group"
                    if( _temporaryUnresolvedGroup ) {
                        // we already have a temporary group ? just move the it.
                        if( _temporaryUnresolvedGroup.itemsIndex !== destIndex ) {
                            console.log("we already have a temporary group ? just move the it");
                            groupsDataModel.items.move(_temporaryUnresolvedGroup.itemsIndex, destIndex, 1);
                        }
                    }
                    else
                    {
                        if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                            // remove the temporary card
                            _groupForUnresolvedCard.visualGroupDataModel.items.remove(_temporaryUnresolvedCard.itemsIndex, 1);
                            _temporaryUnresolvedCard = null;
                            _groupForUnresolvedCard = null;
                        }
                        // insert a new temporary group
                        console.log("insert a new temporary group");
                        groupsDataModel.items.insert(destIndex, {"windowList": _tmpEmptyListModel, "currentCardInGroup": 0});
                        _temporaryUnresolvedGroup = groupsDataModel.items.get(destIndex);
                    }
                }
                else if( !card.VisualDataModel.isUnresolved ) {
                    console.log("CASE 2 : temporary card");
                    if( _temporaryUnresolvedGroup ) {
                        // remove the temporary group
                        console.log("remove the temporary group");
                        groupsDataModel.items.remove(_temporaryUnresolvedGroup.itemsIndex,1);
                        _temporaryUnresolvedGroup = null;
                    }
                    if( _groupForUnresolvedCard && _groupForUnresolvedCard !== group ) {
                        // remove the temporary card
                        console.log("remove the temporary card");
                        _groupForUnresolvedCard.visualGroupDataModel.items.remove(_temporaryUnresolvedCard.itemsIndex,1);
                        _temporaryUnresolvedCard = null;
                        _groupForUnresolvedCard = null;
                    }
                    if( _groupForUnresolvedCard && _groupForUnresolvedCard === group ) {
                        // same group => just move the temporary card
                        if( _temporaryUnresolvedCard.itemsIndex !== card.VisualDataModel.itemsIndex+1 ) {
                            console.log("same group => just move the temporary card from " + _temporaryUnresolvedCard.itemsIndex + " to " + (card.VisualDataModel.itemsIndex+1));
                            _groupForUnresolvedCard.visualGroupDataModel.items.move(_temporaryUnresolvedCard.itemsIndex, card.VisualDataModel.itemsIndex+1, 1);
                        }
                    }
                    if( !_groupForUnresolvedCard ) {
                        // no temporary card yet, insert a new temporary card above "card"
                        console.log("no temporary card yet, insert a new temporary card above 'card'");
                        group.visualGroupDataModel.items.insert(card.VisualDataModel.itemsIndex+1, {"window": drag.source.wrappedWindow});
                        _groupForUnresolvedCard = group;
                        _temporaryUnresolvedCard = group.visualGroupDataModel.items.get(card.VisualDataModel.itemsIndex+1);
                    }
                }
            }

            onPositionChanged: {
                //First, determine what group & card we are talking about
                var internalListViewCoords = mapToItem(internalListView, drag.x, drag.y);
                if( !internalListViewCoords ) return;
                var groupForDrop = internalListView.itemAt(internalListViewCoords.x+internalListView.contentX, internalListViewCoords.y+internalListView.contentY);

                //We have the group, but ignore the temporary one if any
                if( groupForDrop && !groupForDrop.VisualDataModel.isUnresolved ) {
                    var cardCoords = mapToItem(groupForDrop, drag.x, drag.y);
                    var slidingCardDelegate = groupForDrop.cardAt(cardCoords.x, cardCoords.y);
                    //console.log(slidingCardDelegate.x+"|"+slidingCardDelegate.width + "|" + cardCoords.x + "," + cardCoords.y + ":" + slidingCardDelegate);
                    if( slidingCardDelegate ) {
                        var xRatio = cardCoords.x/slidingCardDelegate.width;

                        insertUnresolvedCard(groupForDrop, slidingCardDelegate, xRatio);
                    }
                }
            }
            onExited: {
                // clean up the temporary stuff
                if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                    // remove the temporary card if any
                    _groupForUnresolvedCard.visualGroupDataModel.items.remove(_temporaryUnresolvedCard.itemsIndex, 1);
                    _temporaryUnresolvedCard = null;
                    _groupForUnresolvedCard = null;
                }
                else if( _temporaryUnresolvedGroup ) {
                    // remove the temporary group if any
                    groupsDataModel.items.remove(_temporaryUnresolvedGroup.itemsIndex, 1);
                    _temporaryUnresolvedGroup = null;
                }
            }
            onDropped: {
                if( _temporaryUnresolvedCard && _groupForUnresolvedCard ) {
                    // resolve the temporary card
                    var unresolvedCardIndex = _temporaryUnresolvedCard.itemsIndex;
                    console.log("unresolvedCardIndex="+unresolvedCardIndex);
                    _groupForUnresolvedCard.groupModel.insert(unresolvedCardIndex, {"window": drag.source.wrappedWindow});
                    _groupForUnresolvedCard.visualGroupDataModel.items.resolve(_temporaryUnresolvedCard.itemsIndex, unresolvedCardIndex);
                    //_groupForUnresolvedCard.visualGroupDataModel.items.remove(_temporaryUnresolvedCard.itemsIndex, 1);

                    _groupForUnresolvedCard.cardDragStop();

                    _temporaryUnresolvedCard = null;
                    _groupForUnresolvedCard = null;
                }
                else if( _temporaryUnresolvedGroup ) {
                    // resolve the temporary group
                    var unresolvedGroupIndex = _temporaryUnresolvedGroup.itemsIndex;
                    listCardGroupsModel.createNewGroup(drag.source.wrappedWindow, unresolvedGroupIndex);
                    //groupsDataModel.items.resolve(unresolvedGroupIndex+1, unresolvedGroupIndex);
                    groupsDataModel.items.remove(_temporaryUnresolvedGroup.itemsIndex, 1);

                    cardGroupListViewItem.interactiveList = true;
                    containerForDraggedCard.stopDrag();

                    _temporaryUnresolvedGroup = null;
                }

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

