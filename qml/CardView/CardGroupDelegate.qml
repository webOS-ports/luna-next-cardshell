import QtQuick 2.0

import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupDelegateItem

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

                z: PathView.z
                rotation: slidingCardDelegate.PathView.angle
                scale:  slidingCardDelegate.isCurrentItem ? 1.0: 0.9

                property bool isCurrentItem: cardGroupDelegateItem.delegateIsCurrent
                property CardWindowWrapper windowUserData: window.userData

                interactive: isCurrentItem &&
                             !windowUserData.Drag.active &&
                             windowUserData && windowUserData.windowState === WindowState.Carded

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

                    // rotate 3° each card
                    //rotation: windowUserData.state === "card" ? 3*(index - 0.5*(groupDataModel.count-1)) : 0

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
                            // maximize window
                            cardGroupDelegateItem.cardSelect(window);
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
        return groupPathViewGroupCards.itemAt(x, y);
    }

/*
    Repeater {
        id: groupPathViewGroupCards
        model: groupDataModel
        anchors.fill: parent
    }
*/

    property real itemSize: cardGroupListViewInstance.cardWindowWidth
    property real itemAngle: 1*(groupDataModel.count-1)
    property real spread: (groupDataModel.count-1)*cardGroupListViewInstance.cardWindowWidth*0.05

    // with the PathView, the maximized card doesn't fill the screen
    PathView {
        id: groupPathViewGroupCards
        model: groupDataModel
        interactive: false
        anchors.fill: parent
        pathItemCount: undefined
        currentIndex: groupDataModel.count/2

        path: Path {
            startX: groupPathViewGroupCards.width/2 + spread; startY: groupPathViewGroupCards.height / 2
            PathAttribute { name: "z"; value: 50 }
            PathAttribute { name: "angle"; value: itemAngle }
            PathLine { relativeX: -spread*2-5; relativeY: 0  }
            PathAttribute { name: "z"; value: 0 }
            PathAttribute { name: "angle"; value: -itemAngle }
        }

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
