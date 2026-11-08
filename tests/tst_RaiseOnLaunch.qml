import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * SAM's "launch" life event brings forward a card that already carries the app
 * id: the window of an app whose process was started again - a Waydroid app,
 * whose window belongs to the hwcomposer and outlives the launcher script.
 * Run against luneos-components' compositor mock; SAM is a stub with the one
 * signal of LS.applicationManager that CardView listens to.
 */
TestCase {
    name: "RaiseOnLaunch"
    width: 480
    height: 800

    Compositor { id: compositor }

    QtObject {
        id: applicationManager
        signal appLifeEventsChanged(string appId, string event, string title,
                                    bool showSpinner, bool showSplash, string splashBackground)
    }

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
        appLifeEvents: applicationManager
    }

    function openCard(appId) {
        compositor.createFakeWindow("DummyWindow", { id: appId });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        // A new card is selected, and so opened, 10 ms after it is inserted.
        tryCompare(cardView, "state", "maximizedCard");
        tryVerify(function() { return cardView.currentActiveWindow() === window; });
        return window;
    }

    function lifeEvent(appId, event) {
        applicationManager.appLifeEventsChanged(appId, event, "", false, false, "");
    }

    function cleanup() {
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
    }

    // The bug: launching the app again left its card in the card view.
    function test_launch_opens_the_carded_card() {
        var window = openCard("waydroid.org.test.a");
        cardView.setCurrentCardState(WindowState.Carded);
        compare(cardView.state, "cardList");

        lifeEvent("waydroid.org.test.a", "launch");
        compare(cardView.state, "maximizedCard");
        compare(cardView.currentActiveWindow(), window);
    }

    // And over another app's card, which is what a tap on the icon of an app
    // in the stack does while a different one is open.
    function test_launch_brings_the_card_over_another() {
        var a = openCard("waydroid.org.test.a");
        var b = openCard("waydroid.org.test.b");
        compare(cardView.currentActiveWindow(), b);

        lifeEvent("waydroid.org.test.a", "launch");
        compare(cardView.state, "maximizedCard");
        compare(cardView.currentActiveWindow(), a);
    }

    // The other events of a launch, and a close, leave the cards alone.
    function test_other_events_do_nothing() {
        var a = openCard("waydroid.org.test.a");
        var b = openCard("waydroid.org.test.b");
        cardView.setCurrentCardState(WindowState.Carded);

        var events = ["splash", "preload", "foreground", "background", "close", "stop"];
        for (var i = 0; i < events.length; i++) {
            lifeEvent("waydroid.org.test.a", events[i]);
            compare(cardView.state, "cardList", events[i]);
            compare(cardView.currentActiveWindow(), b, events[i]);
        }
    }

    // An app with no card yet - every ordinary first launch - changes nothing:
    // its window opens a card of its own when it is mapped.
    function test_launch_without_a_card_does_nothing() {
        var a = openCard("org.test.a");
        cardView.setCurrentCardState(WindowState.Carded);

        lifeEvent("org.test.new", "launch");
        compare(cardView.state, "cardList");
        compare(cardView.currentActiveWindow(), a);

        lifeEvent("", "launch");
        compare(cardView.state, "cardList");
    }
}
