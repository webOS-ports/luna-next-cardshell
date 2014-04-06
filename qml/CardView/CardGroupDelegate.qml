import QtQuick 2.0

import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupDelegateItem

    property Item listCardsViewInstance

    property ListModel groupModel
    property bool delegateIsCurrent

    Repeater {
        id: groupRepeater
        model: groupModel

        anchors.centerIn: parent

        delegate:
            SlidingItemArea {
                id: slidingCardDelegate

                property Item modelWindow: window
                property bool isCurrentItem: cardGroupDelegateItem.delegateIsCurrent

                anchors.verticalCenter: cardGroupDelegateItem.verticalCenter
                height: listCardsViewInstance.height
                width: listCardsViewInstance.cardWindowWidth

                slidingTargetItem: cardDelegateContainer
                slidingAxis: Drag.YAxis
                minTreshold: 0.2
                maxTreshold: 0.8
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

                    window: slidingCardDelegate.modelWindow

                    scale:  slidingCardDelegate.isCurrentItem ? 1.0: 0.9

                    // rotate 5° each card
                    rotation: 5*(index - 0.5*(groupRepeater.count-1))
                    transformOrigin: Item.Bottom

                    cardHeight: listCardsViewInstance.cardWindowHeight
                    cardWidth: listCardsViewInstance.cardWindowWidth
                    cardY: slidingCardDelegate.height/2 - listCardsViewInstance.cardWindowHeight/2
                    maximizedY: cardListViewItem.maximizedCardTopMargin
                    maximizedHeight: cardListViewItem.height - cardListViewItem.maximizedCardTopMargin
                    fullscreenY: 0
                    fullscreenHeight: cardListViewItem.height
                    fullWidth: cardListViewItem.width
                }

                Component.onDestruction: {
                    console.log("Delegate is being destroyed");
                }

                Component.onCompleted: {
                    console.log("CardGroupDelegate instantiated for window " + window );
                }
        }
    }
}
