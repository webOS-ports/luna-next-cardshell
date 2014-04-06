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
    id: cardListViewItem

    property real maximizedCardTopMargin;

    property Item cardView

    property alias interactiveList: listCardsView.interactive

    signal cardRemove(Item window);
    signal cardSelect(Item window);

    focus: true
    Keys.forwardTo: listCardsView

    CardGroupModel {
        id: listCardGroupsModel
    }

    ListView {
        id: listCardsView

        anchors.fill: parent

        property real cardScale: 0.6
        property real cardWindowWidth: width*cardScale
        property real cardWindowHeight: height*cardScale

        preferredHighlightBegin: width/2-cardWindowWidth/2
        preferredHighlightEnd: width/2+cardWindowWidth/2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true

        model: listCardGroupsModel
        spacing: 0
        orientation: ListView.Horizontal
        smooth: !listCardsView.moving
        focus: true

        property bool newCardInserted: false
        onCountChanged: {
            if( newCardInserted && count > 0 ) {
                newCardInserted = false;
                var lastWindow = listCardGroupsModel.getByIndex(count-1);
                if( lastWindow ) {
                    cardView.setCurrentCard(lastWindow);
                    cardListViewItem.cardSelect(lastWindow);
                }
            }
        }

        function setCurrentCardIndex(newIndex) {
            listCardsView.currentIndex = newIndex
            if( cardView && listCardsView.currentIndex>=0 ) {
                cardView.currentCardChanged(listCardsModel.getByIndex(listCardsView.currentIndex))
            }
        }

        delegate: Loader {
                id: delegateLoader
                sourceComponent: slidingCardComponent

                Connections {
                    target: listCardGroupsModel
                    onRowsAboutToBeRemoved: {
                        if( first === index )
                            sourceComponent = null;
                    }
                }

                z: ListView.isCurrentItem ? 1 : 0

                property bool delegateIsCurrent: ListView.isCurrentItem

                Component {
                    id: slidingCardComponent

                    CardGroupDelegate {
                        listCardsViewInstance: listCardsView
                        groupModel: windowList

                        delegateIsCurrent: delegateLoader.delegateIsCurrent

                        anchors.verticalCenter: delegateLoader.verticalCenter
                        height: listCardsView.height
                        width: listCardsView.cardWindowWidth
                    }
                }
        }
    }

    function currentActiveWindow() {
        if( listCardsView.currentIndex >= 0 )
            return listCardsModel.getByIndex(listCardsView.currentIndex)

        return null;
    }

    function setCurrentActiveWindow(window) {
        if( currentActiveWindow() !== window ) {
            var i;
            for(i=0; i<listCardsModel.count;i++) {
                var item=listCardsModel.getByIndex(i);
                if(item && item === window) {
                    listCardsView.setCurrentCardIndex(i);
                    break;
                }
            }
        }
    }
}

