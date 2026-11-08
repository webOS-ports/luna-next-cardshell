import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * A card's shadow is LunaSysMgr's (CardDropShadowEffect): 20 px around the
 * window and 5 px lower, in window pixels at a grid unit of 10, drawn on the
 * card so it shrinks with it - instead of a fixed 30 px around a card of any
 * size, whose corners then no longer go with the card's.
 */
TestCase {
    name: "CardShadow"
    width: 480
    height: 800

    Compositor { id: compositor }

    Item {
        id: windowManager
        property int nbRegisteredTapActionsBeforeTap: 0
        signal switchToMaximize(Item window)
        signal switchToFullscreen(Item window)
        signal switchToCardView()
        signal switchToLauncherView()
        signal switchToLockscreen()
        signal switchToDockMode()
        function isScreenLocked() { return false; }
    }

    Item {
        id: gestureArea
        signal tapGesture()
        signal swipeUpGesture(int modifiers)
        signal swipeLeftGesture(int modifiers)
    }

    CardView {
        id: cardView
        width: 480
        height: 800
        compositorInstance: compositor
        gestureAreaInstance: gestureArea
        windowManagerInstance: windowManager
    }

    function cleanup() {
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
    }

    function shadowOf(slot) {
        for (var i = 0; i < slot.parent.children.length; ++i)
            if (slot.parent.children[i].objectName === "cardShadow")
                return slot.parent.children[i];
        return null;
    }

    // The shadow's edges, seen from the card: how far it reaches past each one.
    function compareMargins(slot, scale) {
        var shadow = shadowOf(slot);
        verify(shadow);
        var topLeft = shadow.mapToItem(slot, 0, 0);
        var bottomRight = shadow.mapToItem(slot, shadow.width, shadow.height);
        var around = Units.gu(2) * scale, down = Units.gu(0.5) * scale;
        fuzzyCompare(-topLeft.x, around, 0.01);
        fuzzyCompare(bottomRight.x - slot.width, around, 0.01);
        fuzzyCompare(-topLeft.y, around - down, 0.01);
        fuzzyCompare(bottomRight.y - slot.height, around + down, 0.01);
        // The corner tiles are the image's halves, at the card's scale.
        compare(shadow.border.left, 43);
        compare(shadow.border.top, 43);
        fuzzyCompare(shadow.scale, Units.gu(1) / 10 * scale, 0.0001);
    }

    function test_shadow_shrinks_with_the_card() {
        compositor.createFakeWindow("DummyWindow", { id: "org.test.shadow" });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        tryCompare(cardView, "state", "maximizedCard");
        var wrapper = window.userData;
        tryCompare(wrapper, "width", cardView.width);
        compareMargins(wrapper.parent, 1);

        cardView.setCurrentCardState(WindowState.Carded);
        tryVerify(function() { return wrapper.width === cardView.width * 0.6; });
        compareMargins(wrapper.parent, 0.6);
    }
}
