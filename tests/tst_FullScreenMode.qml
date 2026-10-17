import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * An app asks for its card to cover the status bar with the window property
 * "LuneOS_fullscreen" (CardWindowWrapper), or with enableFullScreenMode().
 * Run against luneos-components' compositor mock and its fake windows; the
 * window manager is a stub that only does what CardsArea's real one is wired
 * to do with the switchTo* signals here, which is set CardView's state.
 */
TestCase {
    name: "FullScreenMode"
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

    // The shape of the mock's FakeWindowBase, which its qmldir does not export.
    Component {
        id: earlyWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_CARD"
            property string appId
            property var windowProperties
            property var userData
            signal exposedChanged(bool exposed)
            function takeFocus() { focus = true; }
            function changeSize(size) { width = size.width; height = size.height; }
        }
    }

    function openCard(appId) {
        compositor.createFakeWindow("DummyWindow", { id: appId });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        // A new card is selected, and so opened, 10 ms after it is inserted.
        tryCompare(cardView, "state", "maximizedCard");
        compare(cardView.currentActiveWindow(), window);
        return window;
    }

    function cleanup() {
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
    }

    function test_property_switches_an_open_card() {
        var window = openCard("org.test.a");

        window.windowProperties = { "appId": "org.test.a", "LuneOS_fullscreen": "true" };
        compare(cardView.state, "fullscreenCard");
        compare(window.userData.windowState, WindowState.Fullscreen);
        compare(window.height, 800);

        window.windowProperties = { "appId": "org.test.a", "LuneOS_fullscreen": "false" };
        compare(cardView.state, "maximizedCard");
        compare(window.userData.windowState, WindowState.Maximized);
    }

    // A client's pending properties can arrive before the surface is mapped:
    // the card opens fullscreen straight away.
    function test_property_set_before_the_card_is_wrapped() {
        var window = earlyWindow.createObject(cardView, { appId: "org.test.early",
                                                          windowProperties: { "LuneOS_fullscreen": "true" } });
        compositor.surfaceModel.append({ obj: window });
        compositor.surfaceMapped(window);

        tryCompare(cardView, "state", "fullscreenCard");
        verify(window.userData.isFullScreenMode);
        compare(cardView.currentActiveWindow(), window);
    }

    function test_other_properties_leave_the_mode_alone() {
        var window = openCard("org.test.b");
        verify(cardView.enableFullScreenMode("org.test.b", true));
        compare(cardView.state, "fullscreenCard");

        // A new title, say: the signal comes for every property.
        window.windowProperties = { "appId": "org.test.b", "title": "New" };
        compare(cardView.state, "fullscreenCard");
    }

    function test_enable_is_not_a_toggle() {
        openCard("org.test.c");

        verify(cardView.enableFullScreenMode("org.test.c", false));
        compare(cardView.state, "maximizedCard");
        verify(cardView.enableFullScreenMode("org.test.c", true));
        compare(cardView.state, "fullscreenCard");
        verify(cardView.enableFullScreenMode("org.test.c", true));
        compare(cardView.state, "fullscreenCard");
        verify(cardView.enableFullScreenMode("org.test.c", false));
        compare(cardView.state, "maximizedCard");
        verify(!cardView.enableFullScreenMode("org.test.unknown", true));
    }

    function test_carded_card_reopens_fullscreen() {
        var window = openCard("org.test.d");
        window.windowProperties = { "LuneOS_fullscreen": "true" };
        compare(cardView.state, "fullscreenCard");

        cardView.setCurrentCardState(WindowState.Carded);
        compare(cardView.state, "cardList");

        // A carded card keeps the mode, and does not leave the card view.
        window.windowProperties = { "LuneOS_fullscreen": "false" };
        compare(cardView.state, "cardList");
        window.windowProperties = { "LuneOS_fullscreen": "true" };
        compare(cardView.state, "cardList");

        // Opened again with a tap on the gesture area.
        gestureArea.tapGesture();
        compare(cardView.state, "fullscreenCard");
    }

    // Brought up by focusApplication() from behind another card.
    function test_focused_card_opens_fullscreen() {
        var window = openCard("org.test.e");
        window.windowProperties = { "LuneOS_fullscreen": "true" };
        openCard("org.test.f");
        compare(cardView.state, "maximizedCard");

        verify(cardView.focusApplication("org.test.e"));
        compare(cardView.state, "fullscreenCard");
        compare(cardView.currentActiveWindow(), window);
    }
}
