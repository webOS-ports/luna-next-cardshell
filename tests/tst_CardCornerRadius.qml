import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * A card's corner radius is LunaSysMgr's: 25 px in window pixels at a grid
 * unit of 10, so 2.5 grid units for a window at full size, shrinking with the
 * card - instead of a fixed 20 px whatever the screen density or card size.
 */
TestCase {
    name: "CardCornerRadius"
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

    function test_radius_follows_the_card() {
        compare(cardView.cornerRadius, Units.gu(2.5));

        compositor.createFakeWindow("DummyWindow", { id: "org.test.radius" });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        tryCompare(cardView, "state", "maximizedCard");
        var wrapper = window.userData;

        // Maximized, the window is screen wide: the full radius.
        tryCompare(wrapper, "width", cardView.width);
        compare(wrapper.cornerRadius, Units.gu(2.5));

        // Carded, it is a scaled-down picture of the window.
        cardView.setCurrentCardState(WindowState.Carded);
        tryVerify(function() { return wrapper.width < cardView.width; });
        tryVerify(function() { return wrapper.width === cardView.width * 0.6; });
        fuzzyCompare(wrapper.cornerRadius, Units.gu(2.5) * 0.6, 0.001);
    }
}
