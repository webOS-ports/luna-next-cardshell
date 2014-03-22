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
import LunaNext 0.1

import "../Utils"

Item {
    id: cardListViewItem

    property ListModel listCardsModel;
    property real maximizedCardTopMargin;

    property alias currentCardIndex: listCardsView.currentIndex

    property alias interactiveList: listCardsView.interactive

    signal cardRemove(Item window);
    signal cardSelect(Item window);

    focus: true
    Keys.forwardTo: listCardsView

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

        delegate: SlidingItemArea {
            id: slidingCardDelegate

            anchors.verticalCenter: parent.verticalCenter
            height: listCardsView.height
            width: listCardsView.cardWindowWidth

            z: ListView.isCurrentItem ? 1 : 0

            property Item modelWindow: window

            slidingTargetItem: cardDelegateContainer
            slidingAxis: Drag.YAxis
            minTreshold: 0.2
            maxTreshold: 0.8
            slidingEnabled: ListView.isCurrentItem && modelWindow.userData.windowState === WindowState.Carded
            filterChildren: true
            slideOnRight: false

            onSlidedLeft: {
                // remove window
                cardListViewItem.cardRemove(slidingCardDelegate.modelWindow);
            }

            onSliderClicked: {
                // maximize window
                cardListViewItem.cardSelect(slidingCardDelegate.modelWindow);
            }

            CardListWindowDelegate {
                id: cardDelegateContainer

                anchors.horizontalCenter: slidingCardDelegate.horizontalCenter

                window: slidingCardDelegate.modelWindow

                scale:  slidingCardDelegate.ListView.isCurrentItem ? 1.0: 0.9

                cardHeight: listCardsView.cardWindowHeight
                cardWidth: listCardsView.cardWindowWidth
                cardY: slidingCardDelegate.height/2 - listCardsView.cardWindowHeight/2
                maximizedY: cardListViewItem.maximizedCardTopMargin
                maximizedHeight: cardListViewItem.height - cardListViewItem.maximizedCardTopMargin
                fullscreenY: 0
                fullscreenHeight: cardListViewItem.height
                fullWidth: cardListViewItem.width
            }
        }
    }

    function __switchToCurrentWindow() {
        var windowWrapper = windowManagerInstance.currentActiveWindowWrapper;

        if (!windowWrapper || !windowWrapper.wrappedWindow)
            return;

        var index = listCardsModel.getIndexFromProperty("winId", windowWrapper.wrappedWindow.winId);
        if (index < 0)
            return;

        if (listCardsView.currentIndex === index)
            return;

        listCardsView.positionViewAtIndex(index, ListView.Beginning);
    }
}

