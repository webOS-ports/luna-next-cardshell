import QtQuick 2.0

import "../Utils"

Item {
    id: cardViewItem

    property Item windowManagerInstance;
    focus: true
    Keys.forwardTo: listCardsView

    ListModel {
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
        spacing: 0 //root.computeFromLength(4)
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

    function appendCard(windowWrapper, winId) {
        // First, instantiate a new card
        var cardComponent = Qt.createComponent("CardWindow.qml");

        var cardComponentInstance = cardComponent.createObject(listCardsView,
                           {"view": listCardsView,
                            "windowWrapper": windowWrapper});

        listCardsModel.append({"cardWindowInstance": cardComponentInstance});
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

