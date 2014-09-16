import QtQuick 2.0

import LunaNext.Compositor 0.1

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

                z: isCarded ? (groupPathViewGroupCards.count-index) : (groupPathViewGroupCards.count+1)

                transform: [
                    Translate {
                        x: isCarded ? cardGroupDelegateItem.cardSpread*cardGroupListViewInstance.cardWindowWidth*(groupPathViewGroupCards.count-1 - index) : 0
                    },
                    Rotation {
                        origin.x: slidingCardDelegate.width/2
                        origin.y: (slidingCardDelegate.height + cardGroupListViewInstance.cardWindowHeight)/2
                        angle: isCarded ? cardGroupDelegateItem.angleInStack*(0.5*(groupPathViewGroupCards.count-1)-index) : 0
                    }
                ]

                scale:  slidingCardDelegate.isCurrentItem ? 1.0: 0.9

                property bool isCurrentItem: cardGroupDelegateItem.delegateIsCurrent
                property bool isCarded: windowUserData && windowUserData.windowState === WindowState.Carded
                property CardWindowWrapper windowUserData: window.userData

                interactive: isCurrentItem &&
                             !windowUserData.Drag.active &&
                             isCarded

                property Item myWindow: window
                onMyWindowChanged: {
                    console.assert(!!window, "window is now null !");
                }

                onRequestDestruction: {
                    // remove window
                    cardGroupDelegateItem.cardRemove(window);
                }

                cardComponent: CardWindowDelegate {
                    id: cardDelegateContainer

                    windowUserData: slidingCardDelegate.windowUserData
                    anchorWindowUserData: !slidingCardDelegate.VisualDataModel.isUnresolved

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
                        onClicked: {
                            // maximize window (only if the group if the active one)
                            if( isCurrentItem ) {
                                cardGroupDelegateItem.cardSelect(window);
                            }
                        }
                        onStartDrag: {
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

        PinchArea {
            anchors.fill: parent
            onPinchFinished: {
                log.text += "PinchArea onPinchFinished" + "\n"
            }
            onPinchStarted: {
                log.text += "PinchArea onPinchStarted" + "\n"
            }
            onPinchUpdated: {
                log.text += "PinchArea onPinchUpdated" + "\n"
            }
        }
    }
}
