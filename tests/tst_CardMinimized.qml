import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * CardView.cardMinimized: once each time the card holding the stage goes
 * to Card View - what GestureTutorial's "Dismissing Cards" note hangs on,
 * as LunaSysMgr's hung on MinimizeState::onEntry. Set up as
 * tst_FullScreenMode: luneos-components' compositor mock and a window
 * manager stub that only does what CardsArea's real one is wired to do.
 */
TestCase {
    name: "CardMinimized"
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

    SignalSpy { id: spy; target: cardView; signalName: "cardMinimized" }

    function openCard(appId) {
        compositor.createFakeWindow("DummyWindow", { id: appId });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        tryCompare(cardView, "state", "maximizedCard");
        compare(cardView.currentActiveWindow(), window);
        return window;
    }

    function init() {
        spy.clear();
    }

    function cleanup() {
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
    }

    function test_swipeUp() {
        var window = openCard("org.test.a");
        compare(spy.count, 0);
        gestureArea.swipeUpGesture(0);
        compare(cardView.state, "cardList");
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], window);
        // Already carded: nothing more
        gestureArea.swipeUpGesture(0);
        cardView.setCurrentCardState(WindowState.Carded);
        compare(spy.count, 1);
    }

    function test_tap() {
        openCard("org.test.b");
        gestureArea.tapGesture();
        compare(cardView.state, "cardList");
        compare(spy.count, 1);
        // The tap again opens it; that is not Card View
        gestureArea.tapGesture();
        compare(cardView.state, "maximizedCard");
        compare(spy.count, 1);
    }

    function test_fullscreenToo() {
        var window = openCard("org.test.c");
        verify(cardView.enableFullScreenMode("org.test.c", true));
        compare(cardView.state, "fullscreenCard");
        gestureArea.swipeUpGesture(0);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], window);
    }
}
