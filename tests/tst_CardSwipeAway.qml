import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * Throwing a card away, when the app takes its time to close or does not
 * close at all. The mock compositor closes a window the moment it is asked;
 * here CardView talks to a stand-in that only remembers the request, and the
 * test closes the window when it chooses.
 *
 * LunaSysMgr took the card out of its group as soon as it was thrown away.
 * Left in its group until the surface went, the card sat there out of sight
 * as the current, centred group, and the card next to it - perhaps the only
 * one left - was off to one side.
 */
TestCase {
    id: testCase
    name: "CardSwipeAway"
    width: 480
    height: 800
    // A TestCase is hidden by default, and a hidden MouseArea gets no input.
    visible: true
    when: windowShown

    Compositor { id: compositor }

    // What CardView sees: the mock's windows, but a close only asked for.
    QtObject {
        id: slowCompositor
        property ListModel surfaceModel: compositor.surfaceModel
        property var closeRequests: []
        signal surfaceMapped(variant window)
        signal surfaceUnmapped(variant window)
        function closeWindow(window) { closeRequests.push(window); }
    }
    Connections {
        target: compositor
        function onSurfaceMapped(window) { slowCompositor.surfaceMapped(window); }
        function onSurfaceUnmapped(window) { slowCompositor.surfaceUnmapped(window); }
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
        compositorInstance: slowCompositor
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

    readonly property Item list: findChild(cardView, "cardGroupListView")
    readonly property var groups: list ? list.cardGroupModel : null

    function init() {
        failOnWarning(/TypeError|ReferenceError|Unable to assign|Binding loop detected for property "cardSpread"/);
    }

    function cleanup() {
        slowCompositor.closeRequests = [];
        mouseRelease(cardView);
        list.cancelCardDrag();
        while (compositor.surfaceModel.count > 0)
            compositor.closeWindow(compositor.surfaceModel.get(0).obj);
        windowManager.switchToCardView();
        list.enableDragnDrop = true;
    }

    function openCard(appId) {
        compositor.createFakeWindow("DummyWindow", { id: appId });
        var window = compositor.surfaceModel.get(compositor.surfaceModel.count - 1).obj;
        // A new card is selected, and so opened, 10 ms after it is inserted.
        tryVerify(function() { return cardView.currentActiveWindow() === window; }, 1000, appId + " did not come forward");
        tryCompare(cardView, "state", "maximizedCard");
        return window;
    }

    //! Open cards in order and leave the card view showing, the last one current
    function openCards(appIds) {
        var windows = {};
        for (var i = 0; i < appIds.length; ++i)
            windows[appIds[i]] = openCard(appIds[i]);
        cardView.setCurrentCardState(WindowState.Carded);
        compare(cardView.state, "cardList");
        waitForCards();
        return windows;
    }

    // Every card carded and done shrinking into its slot
    function waitForCards() {
        for (var i = 0; i < compositor.surfaceModel.count; ++i) {
            var wrapper = compositor.surfaceModel.get(i).obj.userData;
            tryCompare(wrapper, "windowState", WindowState.Carded);
            tryCompare(wrapper, "width", list.cardWindowWidth);
        }
        // and done sliding into its place in the stack: a press on a card
        // that moves under it is not a press-and-hold.
        var last = "";
        tryVerify(function() {
            var now = [];
            for (var i = 0; i < compositor.surfaceModel.count; ++i) {
                var p = compositor.surfaceModel.get(i).obj.userData.mapToItem(cardView, 0, 0);
                now.push(Math.round(p.x) + "," + Math.round(p.y));
            }
            now = now.join(" ");
            var still = now === last;
            last = now;
            wait(50);
            return still;
        }, 5000, "the cards did not stop moving");
        waitForRendering(cardView);
    }

    // The groups as a string: "a b | c", the current card of each in [].
    function layout() {
        var out = [];
        for (var g = 0; g < groups.count; ++g) {
            var group = groups.get(g), cards = [];
            for (var c = 0; c < group.windowList.count; ++c) {
                var n = group.windowList.get(c).window.appId;
                cards.push(c === group.currentCardInGroup ? "[" + n + "]" : n);
            }
            out.push(cards.join(" "));
        }
        return out.join(" | ");
    }

    // Every card in one slot, the slot's shadow showing, nothing being dragged.
    function checkSettled() {
        compare(list.draggedWindow, null);
        verify(list.listView.interactive, "the list is still frozen");
        var inModel = 0;
        for (var g = 0; g < groups.count; ++g)
            inModel += groups.get(g).windowList.count;
        compare(inModel, compositor.surfaceModel.count, "cards in the groups vs windows");

        for (var i = 0; i < compositor.surfaceModel.count; ++i) {
            var window = compositor.surfaceModel.get(i).obj;
            var wrapper = window.userData;
            verify(wrapper, window.appId + " has no wrapper");
            verify(!wrapper.Drag.active, window.appId + " is still being dragged");
            tryVerify(function() { return wrapper.parent && wrapper.parent.objectName === "cardSlot"; },
                      1000, window.appId + " is not in a slot");
            // The slot's delegate is the one for this window, and shows its shadow.
            var delegate = wrapper.parent.parent;
            compare(delegate.windowUserData, wrapper);
            compare(delegate.anchorWindowUserData, true);
            compare(wrapper.x, 0);
            compare(wrapper.y, 0);
        }
    }

    // Centre of card `card` of group `group`, in cardView's coordinates.
    function cardCentre(group, card) {
        var item = list.listView.itemAtIndex(group);
        verify(item, "group " + group + " has no delegate");
        var cardWidth = list.cardWindowWidth;
        var x = item.cardSpread * cardWidth * card + cardWidth / 2;
        return item.mapToItem(cardView, x, item.height / 2);
    }

    function holdAt(p) {
        mousePress(cardView, p.x, p.y);
        // Past the MouseArea's press-and-hold interval
        wait(1000);
        verify(list.draggedWindow !== null, "press and hold did not start a drag");
    }

    function dragTo(from, to) {
        var steps = 12;
        for (var i = 1; i <= steps; ++i) {
            mouseMove(cardView, from.x + (to.x - from.x) * i / steps, from.y + (to.y - from.y) * i / steps);
            wait(20);
        }
        // Let the reorder step settle and the last position be taken.
        wait(500);
        mouseMove(cardView, to.x, to.y);
        wait(400);
    }


    function offCentre() {
        var group = list.listView.currentItem;
        verify(group, "no current group");
        return group.mapToItem(cardView, group.width / 2, 0).x - cardView.width / 2;
    }

    function swipeAway(window) {
        var w = window.userData;
        var p = w.mapToItem(cardView, w.width / 2, w.height / 2);
        mousePress(cardView, p.x, p.y);
        for (var i = 1; i <= 8; ++i) {
            mouseMove(cardView, p.x + 4 * i, p.y - 50 * i);
            wait(10);
        }
        mouseRelease(cardView, p.x + 32, p.y - 400);
        tryVerify(function() { return slowCompositor.closeRequests.indexOf(window) >= 0; }, 3000, "no close was asked for");
    }

    function test_the_card_left_is_centred_before_the_app_closes_data() {
        return [ { tag: "the current card", away: "b", left: "a" }, { tag: "the other card", away: "a", left: "b" } ];
    }
    function test_the_card_left_is_centred_before_the_app_closes(data) {
        var w = openCards(["a", "b"]);
        list.listView.currentIndex = data.away === "a" ? 0 : 1;
        waitForCards();
        swipeAway(w[data.away]);

        // The app has not closed yet
        compare(compositor.surfaceModel.count, 2);
        compare(layout(), "[" + data.left + "]");
        waitForCards2([w[data.left]]);
        verify(Math.abs(offCentre()) < 1, "the card left is " + offCentre().toFixed(1) + " px off the middle");
        compare(w[data.away].userData.visible, false);

        // Then it does
        compositor.closeWindow(w[data.away]);
        compare(layout(), "[" + data.left + "]");
        checkSettled();
    }

    function test_a_card_whose_app_does_not_close_comes_back() {
        var w = openCards(["a", "b"]);
        swipeAway(w["b"]);
        compare(layout(), "[a]");
        // closingTimeout
        tryCompare(groups, "count", 2, 7000, "the card did not come back");
        compare(cardView.state, "cardList");
        compare(w["b"].userData.windowState, WindowState.Carded);
        waitForCards();
        checkSettled();
    }

    function test_launching_a_closing_app_brings_its_card_back() {
        var w = openCards(["a", "b"]);
        swipeAway(w["b"]);
        compare(layout(), "[a]");
        cardView.focusApplication("b");
        tryCompare(cardView, "state", "maximizedCard");
        compare(cardView.currentActiveWindow(), w["b"]);
        cardView.setCurrentCardState(WindowState.Carded);
        waitForCards();
        checkSettled();
    }

    // Like waitForCards(), for some of the windows only
    function waitForCards2(windows) {
        for (var i = 0; i < windows.length; ++i)
            tryCompare(windows[i].userData, "width", list.cardWindowWidth);
        wait(1200);
    }
}
