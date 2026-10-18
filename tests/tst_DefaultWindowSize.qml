import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"

/*
 * CardView tells the compositor the size a new window's card will give it
 * (WebOSCoreCompositor.defaultWindowSize), so that an xdg_shell window starts
 * at that size instead of the output's and is not resized straight after it
 * opens. Run against luneos-components' compositor mock; the one with the
 * property declares it, as the compositor has it, and the other is an older
 * compositor without it.
 */
TestCase {
    name: "DefaultWindowSize"
    width: 480
    height: 800

    Compositor {
        id: compositor
        property size defaultWindowSize
    }

    Compositor { id: olderCompositor }

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
        maximizedCardTopMargin: 24
        compositorInstance: compositor
        gestureAreaInstance: gestureArea
        windowManagerInstance: windowManager
    }

    Component {
        id: olderCardViewComponent
        CardView {
            width: 480
            height: 800
            compositorInstance: olderCompositor
            gestureAreaInstance: gestureArea
            windowManagerInstance: windowManager
        }
    }

    function cleanup() {
        cardView.width = 480;
        cardView.height = 800;
        cardView.maximizedCardTopMargin = 24;
    }

    // The size a maximized card gets: the card view less the top margin.
    function test_the_compositor_gets_the_card_size() {
        compare(compositor.defaultWindowSize, Qt.size(480, 776));
    }

    // And follows the card view, e.g. when the screen rotates.
    function test_follows_the_card_view() {
        cardView.width = 800;
        cardView.height = 480;
        compare(compositor.defaultWindowSize, Qt.size(800, 456));

        cardView.maximizedCardTopMargin = 0;
        compare(compositor.defaultWindowSize, Qt.size(800, 480));
    }

    // A compositor that has no such property is left alone, without a
    // warning about it.
    function test_an_older_compositor_is_left_alone() {
        failOnWarning(/defaultWindowSize/);
        var olderCardView = createTemporaryObject(olderCardViewComponent, this);
        verify(olderCardView);
        compare(olderCompositor.defaultWindowSize, undefined);
    }
}
