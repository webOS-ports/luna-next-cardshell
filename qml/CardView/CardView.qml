import QtQuick 2.0

Item {
    id: cardViewDisplay

    signal cardAdded(Item cardComponentInstance)
    signal cardRemoved(Item cardComponentInstance)

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
                // maximize window
                windowManager.setToMaximized(cardWindow.windowWrapper);
            }
            onDestructionRequest: {
                // remove card & emit signal
                listCardsModel.remove(index);
                cardRemoved(cardWindow);
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

        // emit corresponding signal
        cardAdded(cardComponentInstance);
    }
}

