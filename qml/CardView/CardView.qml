import QtQuick 2.0

Item {
    id: cardViewItem

    property Item windowManagerInstance;

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

        delegate: CardWindowDelegate {
            height: listCardsView.height
            width: listCardsView.cardWindowWidth

            cardWidth: listCardsView.cardWindowWidth
            cardHeight: listCardsView.cardWindowHeight

            cardWindow: model.cardWindowInstance

            onSwitchToMaximize: {
                // maximize current window
                windowManagerInstance.maximizedMode();
            }
            onDestructionRequest: {
                deleteCardWindowOnDestruction = true;
                // remove card from model
                listCardsModel.remove(ListView.view.currentIndex);
                // remove window
                windowManagerInstance.removeWindow(cardWindow.windowWrapper);
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

