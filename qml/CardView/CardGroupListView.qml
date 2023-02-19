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

            onNewCardInserted: (group, index, newWindow) => {
                if( !containerForDraggedCard.visible ) { // don't activate the new card group during drag'n'drop
                    internalListView.delayedCardSelect(newWindow);
                }
            }
            onCardRemoved: updateKeysForwardTo(false);
        }

        delegate: CardGroupDelegate {
            id: cardGroupDelegateItem
            cardGroupListViewInstance: cardGroupListViewItem
            cardGroupModel: listCardGroupsModel
            groupModel: windowList
            cardSpread: {
                if(ListView.isCurrentItem) {
                    if(cardGroupListViewItem.isCardedViewActive) {
                        return spreadRatio; // fetch ratio from card group model
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
            onCardRemove: (window) => {
                cardGroupListViewItem.updateKeysForwardTo(false);
                cardGroupListViewItem.cardRemove(window);
            }
            onCardDragStart: (window) => {
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
                    internalListView.forceLayout();
                }
            }
            onCardDragStop: {
                cardGroupListViewItem.interactiveList = true;
                containerForDraggedCard.stopDrag();
            }
        }
    }

    /* Pinch to spread cards */
    PinchArea {
        anchors.fill: parent
        enabled: cardGroupListViewItem.interactiveList
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

            preferredHighlightBegin: cardGroupListViewItem.isCardedViewActive ? width/2-cardWindowWidth/2 : 0
            preferredHighlightEnd: cardGroupListViewItem.isCardedViewActive ? width/2+cardWindowWidth/2 : width
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
            interactive: cardGroupListViewItem.interactiveList
            snapMode: ListView.SnapOneItem

            onCurrentIndexChanged: {
                if( internalListView.currentIndex>=0 )
                    cardGroupListViewItem.currentCardChanged()
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

            Keys.onPressed: {
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

                onEntered: positionChanged(drag);
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
        updateKeysForwardTo(true);
    }

    function updateKeysForwardTo(addWindow) {
        if (addWindow)
            Keys.forwardTo = [internalListView, currentActiveWindow()];
        else
            Keys.forwardTo = [internalListView];
    }
}

