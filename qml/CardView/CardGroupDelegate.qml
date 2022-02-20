import QtQuick 2.0

import WebOSCompositorBase 1.0

import "../Utils"

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

    VisualDataModel {
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
                property bool isCarded: windowUserData && windowUserData.windowState === WindowState.Carded
                property CardWindowWrapper windowUserData: window.userData

                scale: slidingCardDelegate.isCurrentItem ? 1.0 : 0.95
                Behavior on scale { NumberAnimation { duration: 300 } }

                interactive: isCurrentItem &&
                             !windowUserData.Drag.active &&
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
                    }
                }

                Component.onDestruction: {
                    console.log("Delegate " + slidingCardDelegate + " is being destroyed for window " + window);
                }

                Component.onCompleted: {
                    console.log("Delegate " + slidingCardDelegate + " instantiated for window " + window);
                    windowUserData = window.userData; // do not introduce a binding, to avoid
                                                      // errors if window gets destroyed brutally
                }
            }
    }

    function cardAt(x,y) {
        return cardGroupDelegateItem.childAt(x, y);
    }

    Repeater {
        id: groupPathViewGroupCards
        model: groupDataModel
    }
}
