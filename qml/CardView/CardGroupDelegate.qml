import QtQuick 2.0

import LunaNext.Compositor 0.1

import "../Utils"

Item {
    id: cardGroupDelegateItem

    property Item cardGroupListViewInstance

    property ListModel groupModel
    property bool delegateIsCurrent

    signal cardRemove(Item window);
    signal cardSelect(Item window);
    signal cardDragStart(Item window);

    Repeater {
        id: groupRepeater
        model: groupModel

        anchors.fill: parent

        delegate:
            SlidingItemArea {
                id: slidingCardDelegate

                property Item windowUserData;
                property bool isCurrentItem: cardGroupDelegateItem.delegateIsCurrent

                y: 0
                height: cardGroupListViewInstance.height
                width: cardGroupListViewInstance.cardWindowWidth

                slidingTargetItem: cardDelegateContainer
                slidingAxis: Drag.YAxis
                minTreshold: 0.4
                maxTreshold: 0.6
                slidingEnabled: isCurrentItem &&
                                !windowUserData.dragMode &&
                                windowUserData && windowUserData.windowState === WindowState.Carded
                filterChildren: true
                slideOnRight: false

                onSlidedLeft: {
                    // remove window
                    cardGroupDelegateItem.cardRemove(window);
                }

                onClicked: {
                    // maximize window
                    cardGroupDelegateItem.cardSelect(window);
                }

                onLongPress: {
                    // switch to drag'n'drop state
                    cardGroupDelegateItem.cardDragStart(window);
                }

                CardWindowDelegate {
                    id: cardDelegateContainer

                    anchors.horizontalCenter: slidingCardDelegate.horizontalCenter

                    windowUserData: slidingCardDelegate.windowUserData

                    scale:  slidingCardDelegate.isCurrentItem ? 1.0: 0.9

                    // rotate 3° each card
                    rotation: windowUserData.state === "card" ? 3*(index - 0.5*(groupRepeater.count-1)) : 0
                    //transformOrigin: Item.Bottom

                    cardHeight: cardGroupListViewInstance.cardWindowHeight
                    cardWidth: cardGroupListViewInstance.cardWindowWidth
                    cardY: cardGroupListViewInstance.height/2 - cardGroupListViewInstance.cardWindowHeight/2
                    maximizedY: cardGroupListViewInstance.maximizedCardTopMargin
                    maximizedHeight: cardGroupListViewInstance.height - cardGroupListViewInstance.maximizedCardTopMargin
                    fullscreenY: 0
                    fullscreenHeight: cardGroupListViewInstance.height
                    fullWidth: cardGroupListViewInstance.width
                }

                Component.onDestruction: {
                    console.log("Delegate is being destroyed");
                }

                Component.onCompleted: {
                    console.log("CardGroupDelegate instantiated for window " + window );
                    windowUserData = window.userData; // do not introduce a binding, to avoid
                                                      // errors if window gets destroyed brutally
                }
        }
    }
}
