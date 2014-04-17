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

    WindowModel {
        id: listCardsModel
        windowTypeFilter: WindowType.Card

        onRowsAboutToBeInserted: listCardsView.newCardInserted = true;
        onRowsAboutToBeRemoved: if( listCardsView.currentIndex === last ) cardView.setCurrentCardState(WindowState.Carded);
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

        model: listCardsModel
        spacing: 0
        orientation: ListView.Horizontal
        smooth: true
        focus: true

        property bool newCardInserted: false
        onCountChanged: {
            if( newCardInserted && count > 0 ) {
                newCardInserted = false;
                var lastWindow = listCardsModel.getByIndex(count-1);
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
                    target: listCardsModel
                    onRowsAboutToBeRemoved: {
                        if( first === index )
                            sourceComponent = null;
                    }
                }

                z: ListView.isCurrentItem ? 1 : 0

                property bool delegateIsCurrent: ListView.isCurrentItem

                Component {
                    id: slidingCardComponent

                    SlidingItemArea {
                        id: slidingCardDelegate

                        property Item modelWindow: window
                        property bool isCurrentItem: delegateIsCurrent

                        anchors.verticalCenter: delegateLoader.verticalCenter
                        height: listCardsView.height
                        width: listCardsView.cardWindowWidth

                        slidingTargetItem: cardDelegateContainer
                        slidingAxis: Drag.YAxis
                        minTreshold: 0.4
                        maxTreshold: 0.6
                        slidingEnabled: isCurrentItem && modelWindow && modelWindow.userData.windowState === WindowState.Carded
                        filterChildren: true
                        slideOnRight: false

                        onSlidedLeft: {
                            // remove window
                            cardListViewItem.cardRemove(modelWindow);
                        }

                        onSliderClicked: {
                            // maximize window
                            cardListViewItem.cardSelect(modelWindow);
                        }

                        CardListWindowDelegate {
                            id: cardDelegateContainer

                            anchors.horizontalCenter: slidingCardDelegate.horizontalCenter

                            window: modelWindow

                            scale:  slidingCardDelegate.isCurrentItem ? 1.0: 0.9

                            cardHeight: listCardsView.cardWindowHeight
                            cardWidth: listCardsView.cardWindowWidth
                            cardY: slidingCardDelegate.height/2 - listCardsView.cardWindowHeight/2
                            maximizedY: cardListViewItem.maximizedCardTopMargin
                            maximizedHeight: cardListViewItem.height - cardListViewItem.maximizedCardTopMargin
                            fullscreenY: 0
                            fullscreenHeight: cardListViewItem.height
                            fullWidth: cardListViewItem.width
                        }

                        Component.onDestruction: {
                            console.log("Delegate is being destroyed");
                        }
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

