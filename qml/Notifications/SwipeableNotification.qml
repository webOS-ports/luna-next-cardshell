import QtQuick 2.15
import QtQml 2.15

Item {
    id: swipeableRoot
    property Component notifComponent
    property alias notifItem: notifLoader.item
    property bool blockSwipesToLeft: false
    // A group with more than one layer: a swipe moves its top layer only,
    // which reads layerOffset, and the rest stays where it is - Enyo's
    // dashboard, whose layers were swipeables of their own. The last layer
    // goes with the whole entry, as before.
    property bool layered: false
    readonly property real layerOffset: layered && !wholeDrag ? -flickableArea.contentX : 0
    // Enyo's layers went right only (allowLeft: false), as the tablet's
    // entries do: to the left a top layer would go out past the icon, and
    // uncover nothing of the text of the one under it.
    readonly property bool leftBlocked: blockSwipesToLeft || layered || ownLayers
    // A dashboard whose page swipes its own layers (Enyo 1's, with more than
    // one): a drag on it is the page's, which moves its top layer.
    property bool ownLayers: false
    // How far in from the left edge the entry's icon reaches. A drag that
    // starts there on an entry with layers takes the whole entry, and a swipe
    // then removes the whole group, as luna-sysmgr did (DashboardWindow-
    // Container: a press within the badge width of a dashboard that handled
    // its own drags moved the whole window, one further in went to the page).
    // 0: no such zone.
    property real iconZoneWidth: 0
    readonly property bool stacked: layered || ownLayers
    // The drag under way (or the slide that follows it) started on the icon
    // of a stacked entry.
    property bool wholeDrag: false

    signal requestDestruction()
    // The whole group was swiped away from its icon.
    signal requestGroupDestruction()

    // An entry for a group of toasts outlives a swipe: only the toast on top
    // goes. The area calls this when the entry has taken up the next one, and
    // it is back in place, showing that.
    function comeBack() {
        if (!swipeoutNotification.running)
            flickableArea.settled = true;
    }

    Flickable {
        id: flickableArea

        width: swipeableRoot.width
        height: swipeableRoot.height

        flickableDirection: Flickable.HorizontalFlick
        // Not on a dashboard that swipes its own layers, unless the drag
        // starts on its icon.
        interactive: !swipeableRoot.ownLayers || swipeableRoot.wholeDrag
        boundsBehavior: Flickable.DragOverBounds
        contentWidth: swipeableRoot.width
        // Put confortable margins on top and bottom of card to enable flicking
        leftMargin: swipeableRoot.width
        rightMargin: swipeableRoot.width
        contentX: 0

        Item {
            width: swipeableRoot.width
            height: swipeableRoot.height
            // Layered, the entry stays put while the flickable moves: the
            // top layer follows layerOffset instead.
            x: swipeableRoot.layered && !swipeableRoot.wholeDrag ? flickableArea.contentX : 0

            Loader {
                id: notifLoader
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: swipeableRoot.notifComponent
            }
        }
        onContentXChanged: if ((contentX>0) && (swipeableRoot.leftBlocked)) contentX=0;

        // Let go short of a swipe-out, it slides back into place. (A Behavior
        // on contentY was meant to do this, but the notification moves along
        // contentX, and the Binding below put it back at 0 in one jump.)
        property bool settled: true
        onMovementStarted: {
            slideBack.stop();   // caught again on its way back
            settled = false;
        }
        onMovementEnded: {
            if (!swipeoutNotification.running)
                slideBack.start();
        }
        NumberAnimation {
            id: slideBack
            target: flickableArea
            property: "contentX"
            to: 0
            duration: 150
            easing.type: Easing.OutQuad
            onStopped: {
                flickableArea.settled = true;
                swipeableRoot.wholeDrag = false;
            }
        }

        /* A resize moves the content as well: the margins are the width, and
         * when the width grows and shrinks again (the phone turned landscape
         * and back) the content is left off centre - 85 pixels to the right on
         * a sargo. The Binding below writes 0 only when it comes into force,
         * so it does not bring it back; this does, once the width, margins and
         * content width have all followed. */
        function recentre() {
            if (settled && !swipeoutNotification.running && !slideBack.running && !moving)
                contentX = 0;
        }
        onWidthChanged: Qt.callLater(recentre)
        onContentWidthChanged: Qt.callLater(recentre)
        onLeftMarginChanged: Qt.callLater(recentre)
        onRightMarginChanged: Qt.callLater(recentre)

        // When nothing special is happening, always have the card centered
        Binding {
            when: flickableArea.settled && !swipeoutNotification.running
            target: flickableArea
            property: "contentX"
            value: 0
            restoreMode: Binding.RestoreBinding
        }

        // handling of card swipe-out, either by drag or by flick
        SmoothedAnimation {
            id: swipeoutNotification
            target: flickableArea
            property: "contentX"
            duration: 200
            onStopped: {
                // delete card, or the whole group
                if (swipeableRoot.wholeDrag) {
                    swipeableRoot.wholeDrag = false;
                    requestGroupDestruction();
                } else {
                    requestDestruction();
                }
            }
        }

        /* Slides the notification out the way it was swiped: a positive
         * contentX (or velocity) is the content moving left. The direction used
         * to come from swipeableRoot.contentX, which does not exist - always
         * undefined, so every notification left to the right, whichever way it
         * was swiped. */
        function swipeOut(toLeft) {
            swipeoutNotification.to = toLeft ? swipeableRoot.width : -swipeableRoot.width;
            swipeoutNotification.start();
        }

        onDraggingChanged: {
            if(!dragging && !swipeoutNotification.running) {
                if(contentX>(swipeableRoot.width*0.5) ||
                   contentX<(-swipeableRoot.width*0.5))
                {
                    swipeOut(contentX > 0);
                }
            }
        }
        onFlickingChanged: {
            if(flicking && !swipeoutNotification.running) {
                if( ((!swipeableRoot.leftBlocked)&&(horizontalVelocity>1000)) ||
                   horizontalVelocity<-1000)
                {
                    swipeOut(horizontalVelocity > 0);
                }
            }
        }
    }

    /* Where a press lands, seen before the Flickable and the entry under it
     * see it: on top of them, and passive, so it takes nothing from them - a
     * tap on the icon still reaches the entry (opening the app, or Enyo's
     * dashboard's icon tap). A press on the icon of a stacked entry makes the
     * drag a whole-entry one, and lets the Flickable take a dashboard that
     * otherwise swipes its own layers. Not while a slide is still running:
     * that one finishes as it started. */
    Item {
        anchors.fill: parent
        z: 1
        PointHandler {
            id: pressWatch
            onActiveChanged: {
                if (!active || swipeoutNotification.running || slideBack.running)
                    return;
                swipeableRoot.wholeDrag = swipeableRoot.stacked &&
                        point.pressPosition.x < swipeableRoot.iconZoneWidth;
            }
        }
    }
}
