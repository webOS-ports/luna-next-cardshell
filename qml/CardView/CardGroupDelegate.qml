import QtQuick 2.0
import QtQml.Models 2.2

import WebOSCompositorBase 1.0

import "../Utils"
import "../WindowStateStub.js" as WindowState

Item {
    id: cardGroupDelegateItem

    height: cardGroupListViewInstance.height
    width: cardGroupListViewInstance.cardWindowWidth * (1.0+cardSpread*(groupPathViewGroupCards.count-1))

    property real cardSpread: 0.1 // what proportion of the card is visible when behind a stack of cards
    property real angleInStack: cardSpread*10 // in degrees, angle between two consecutive cards in a stack

    property Item cardGroupListViewInstance

    property CardGroupModel cardGroupModel
    property ListModel groupModel
    property bool delegateIsCurrent

    property alias visualGroupDataModel: groupDataModel

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);
    signal cardDragStop();

    DelegateModel {
        id: groupDataModel

        model: groupModel
        delegate:
            SwipeableCard {
                id: slidingCardDelegate
                height: cardGroupListViewInstance.height
                width: cardGroupListViewInstance.cardWindowWidth

                z: isCarded ? 0 : 1

                property real shiftX: isCarded ? cardGroupDelegateItem.cardSpread*cardGroupListViewInstance.cardWindowWidth*index : 0
                property real shiftAngle: isCarded ? cardGroupDelegateItem.angleInStack*(index-0.5*(groupPathViewGroupCards.count-1)) : 0

                transform: [
                    Translate {
                        x: slidingCardDelegate.shiftX
                    },
                    Rotation {
                        origin.x: slidingCardDelegate.width/2
                        origin.y: (slidingCardDelegate.height + cardGroupListViewInstance.cardWindowHeight)/2
                        angle: slidingCardDelegate.shiftAngle
                    }
                ]

                Behavior on shiftAngle { SmoothedAnimation { duration: 1000 } }
                Behavior on shiftX { SmoothedAnimation { duration: 1000 } }

                property bool isCurrentItem: cardGroupDelegateItem.delegateIsCurrent
                property bool isCarded: !!windowUserData && windowUserData.windowState === WindowState.Carded
                // A binding: the card's wrapper is made when the surface is
                // mapped, which can come after the card is in the model.
                // window goes null with its window, and so does this.
                property CardWindowWrapper windowUserData: (window && window.userData) || null

                scale: slidingCardDelegate.isCurrentItem ? 1.0 : 0.95
                Behavior on scale { NumberAnimation { duration: 300 } }

                interactive: isCurrentItem &&
                             !!windowUserData && !windowUserData.Drag.active &&
                             isCarded

                onRequestDestruction: {
                    // remove window
                    cardGroupDelegateItem.cardRemove(window);
                }

                cardComponent: CardWindowDelegate {
                    id: cardDelegateContainer

                    windowUserData: slidingCardDelegate.windowUserData

                    cardHeight: cardGroupListViewInstance.cardWindowHeight
                    cardWidth: cardGroupListViewInstance.cardWindowWidth
                    cardY: cardGroupListViewInstance.height/2 - cardGroupListViewInstance.cardWindowHeight/2
                    maximizedY: cardGroupListViewInstance.maximizedCardTopMargin
                    maximizedHeight: cardGroupListViewInstance.height - cardGroupListViewInstance.maximizedCardTopMargin
                    fullscreenY: 0
                    fullscreenHeight: cardGroupListViewInstance.height
                    fullWidth: cardGroupListViewInstance.width

                    Connections {
                        target: windowUserData
                        function onClicked() {
                            // maximize window (only if the group if the active one)
                            if( isCurrentItem ) {
                                cardGroupDelegateItem.cardSelect(window);
                            }
                        }
                        function onStartDrag() {
                            console.log("startDrag with window " + window);
                            cardGroupDelegateItem.cardDragStart(window);
                        }
                        function onStopDrag() {
                            cardGroupDelegateItem.cardDragStop();
                        }
                    }
                }

                Component.onDestruction: {
                    console.log("Delegate " + slidingCardDelegate + " is being destroyed for window " + window);
                }

                Component.onCompleted: {
                    console.log("Delegate " + slidingCardDelegate + " instantiated for window " + window);
                }
            }
    }

    function cardAt(x,y) {
        return cardGroupDelegateItem.childAt(x, y);
    }

    //! Where a card dragged to x should go in this group: just above the
    //! topmost card under x, at the bottom left of them all, on top right of
    //! them all. Counted as CardGroupModel.moveWindow() counts.
    function slotAt(x) {
        var count = groupModel ? groupModel.count : 0;
        var cardWidth = cardGroupListViewInstance.cardWindowWidth;
        for( var i = count - 1; i >= 0; --i ) {
            var left = cardSpread * cardWidth * i;
            if( x >= left && x < left + cardWidth )
                return i + 1;
        }
        return x < 0 ? 0 : count;
    }

    Repeater {
        id: groupPathViewGroupCards
        model: groupDataModel
    }
}
