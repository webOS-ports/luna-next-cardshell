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
import LunaNext.Common 0.1
import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupListViewItem

    property real maximizedCardTopMargin;

    property real cardScale: 0.6
    property real cardWindowWidth: width*cardScale
    property real cardWindowHeight: height*cardScale

    property Item cardView

    property alias interactiveList: internalListView.interactive

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);

    focus: true
    Keys.forwardTo: internalListView

    CardGroupModel {
        id: listCardGroupsModel

        onRowsInserted: internalListView.newCardInserted = true;
    }

    ListView {
        id: internalListView

        anchors.fill: parent

        preferredHighlightBegin: width/2-cardGroupListViewItem.cardWindowWidth/2
        preferredHighlightEnd: width/2+cardGroupListViewItem.cardWindowWidth/2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true

        model: listCardGroupsModel
        spacing: 0
        orientation: ListView.Horizontal
        smooth: !internalListView.moving
        focus: true

        property bool newCardInserted: false
        onCountChanged: {
            if( newCardInserted && count > 0 ) {
                newCardInserted = false;
                var lastWindow = listCardGroupsModel.getCurrentCardOfGroup(listCardGroupsModel.get(count-1));
                if( lastWindow ) {
                    cardGroupListViewItem.cardSelect(lastWindow);
                }
            }
        }

        function setCurrentCardIndex(newIndex) {
            internalListView.currentIndex = newIndex
            if( cardView && internalListView.currentIndex>=0 ) {
                cardView.currentCardChanged(currentActiveWindow())
            }
        }

        delegate: CardGroupDelegate {
                        cardGroupListViewInstance: cardGroupListViewItem
                        groupModel: windowList

                        delegateIsCurrent: ListView.isCurrentItem

                        anchors.verticalCenter: parent.verticalCenter
                        height: cardGroupListViewItem.height
                        width: cardGroupListViewItem.cardWindowWidth

                        z: ListView.isCurrentItem ? 1 : 0

                        onCardSelect: cardGroupListViewItem.cardSelect(window);
                        onCardRemove: cardGroupListViewItem.cardRemove(window);
                        onCardDragStart: {
                            internalListView.interactive = false;
                            console.log("drag'n'drop mode !");
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
    }
}

