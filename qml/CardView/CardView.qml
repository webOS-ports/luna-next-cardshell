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

import "../Utils"

Item {
    id: cardViewItem

    property Item windowManagerInstance;
    focus: true
    Keys.forwardTo: listCardsView

    ExtendedListModel {
        // This model contains the list of the cards
        id: listCardsModel
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

            slidingTargetItem: cardDelegateContainer
            slidingAxis: Drag.YAxis
            minTreshold: 0.2
            maxTreshold: 0.8
            slidingEnabled: ListView.isCurrentItem && !!model.cardWindowInstance && model.cardWindowInstance.isWindowCarded()
            filterChildren: true
            slideOnRight: false

            onSlidedLeft: {
                cardDelegateContainer.deleteCardWindowOnDestruction = true;
                var cardWindowInstance = model.cardWindowInstance;
                // remove card from model
                listCardsModel.remove(ListView.view.currentIndex);
                // remove window
                windowManagerInstance.removeWindow(cardWindowInstance.windowWrapper);
            }

            onSliderClicked: {
                // maximize window
                windowManagerInstance.maximizedMode()
            }

            CardWindowDelegate {
                id: cardDelegateContainer

                anchors.horizontalCenter: parent.horizontalCenter
                y: slidingCardDelegate.height/2 - cardDelegateContainer.height/2
                height: listCardsView.cardWindowHeight
                width: listCardsView.cardWindowWidth

                isCurrent: slidingCardDelegate.ListView.isCurrentItem

                cardWindow: model.cardWindowInstance
            }
        }
    }

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            listCardsView.enabled = false;
        }
        onSwitchToMaximize: {
            listCardsView.enabled = false;
        }
        onSwitchToFullscreen: {
            listCardsView.enabled = false;
        }
        onSwitchToCardView: {
            listCardsView.enabled = true;
        }
        onSwitchToLauncherView: {
            listCardsView.enabled = false;
        }
        onActiveWindowChanged: {
            __switchToCurrentWindow();
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

    function appendCard(windowWrapper, winId) {
        // First, instantiate a new card
        var cardComponent = Qt.createComponent("CardWindow.qml");

        var cardComponentInstance = cardComponent.createObject(listCardsView,
                           {"view": listCardsView,
                            "windowWrapper": windowWrapper});

        listCardsModel.append({"cardWindowInstance": cardComponentInstance,"winId":windowWrapper.wrappedWindow.winId});
        listCardsView.positionViewAtEnd();
    }

    function removeCard(windowWrapper, winId) {
        // Find the corresponding card
        var i=0;
        for(i=0; i<listCardsModel.count;i++) {
            var cardWindow=listCardsModel.get(i).cardWindowInstance;
            if(cardWindow && cardWindow.windowWrapper === windowWrapper) {
                // remove the card instance from the model
                listCardsModel.remove(i);
                // actually destroy the card instance. The window wrapper will be destroyed
                // by the window manager.
                cardWindow.destroy();
                break;
            }
        }
    }
}

