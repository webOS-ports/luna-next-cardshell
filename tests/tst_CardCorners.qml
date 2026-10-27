import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * The rounded corners of a card (CardWindowWrapper) must survive the card
 * being maximized and carded again. Two ways they did not, both on the device:
 *  - the mask's layer was switched off for a maximized window and on again for
 *    the card, and MultiEffect kept sampling the old layer: square corners on
 *    every card that had been opened once;
 *  - MultiEffect's own paddingRect sized the padded window from before the
 *    resize: a squeezed window in the card.
 * The test runs on the software renderer, which draws no shader effects, so
 * it pins down the item setup that the device grabs showed to work.
 */
TestCase {
    name: "CardCorners"
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

    function openCard(appId) {
        compositor.createFakeWindow("DummyWindow", { id: appId });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        tryCompare(cardView, "state", "maximizedCard");
        return window;
    }

    function cleanup() {
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
    }

    function checkCarded(wrapper) {
        var mask = findChild(wrapper, "cornerShaderMask");
        var padded = findChild(wrapper, "paddedWindow");
        verify(mask && padded);

        tryCompare(wrapper, "useShaderCorner", true);
        verify(mask.layer.enabled);
        // The window, one transparent pixel bigger all round, at the card's
        // current size and not at the size it had when maximized.
        verify(padded.sourceItem !== null);
        tryVerify(function() { return wrapper.width < cardView.width; });
        tryVerify(function() {
            var r = padded.sourceRect;
            return r.x === -1 && r.y === -1 &&
                   r.width === wrapper.width + 2 && r.height === wrapper.height + 2;
        }, 1000, "padded source follows the card's size");
        compare(padded.width, wrapper.width + 2);
        compare(padded.height, wrapper.height + 2);
    }

    function test_corners_survive_maximize_and_card() {
        var window = openCard("org.test.corners");
        var wrapper = window.userData;
        var mask = findChild(wrapper, "cornerShaderMask");
        var padded = findChild(wrapper, "paddedWindow");

        // Maximized: no corner effect, and nothing drawn off screen for it,
        // but the mask keeps its layer.
        tryCompare(wrapper, "useShaderCorner", false);
        verify(mask.layer.enabled);
        compare(padded.sourceItem, null);

        for (var i = 0; i < 3; ++i) {
            cardView.setCurrentCardState(WindowState.Carded);
            compare(cardView.state, "cardList");
            checkCarded(wrapper);

            cardView.setCurrentCardState(WindowState.Maximized);
            compare(cardView.state, "maximizedCard");
            tryCompare(wrapper, "useShaderCorner", false);
            verify(mask.layer.enabled);
            compare(padded.sourceItem, null);
        }
    }

    function test_fullscreen_round_trip() {
        var window = openCard("org.test.corners.fs");
        var wrapper = window.userData;
        verify(cardView.enableFullScreenMode("org.test.corners.fs", true));
        compare(cardView.state, "fullscreenCard");
        tryCompare(wrapper, "useShaderCorner", false);

        cardView.setCurrentCardState(WindowState.Carded);
        checkCarded(wrapper);
    }
}
