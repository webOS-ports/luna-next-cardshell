import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * Where the card view puts its groups. LunaSysMgr slid the active group to
 * the middle of the screen after every change (CardWindowManager::
 * slideAllGroups, the active group at x = 0), so a card left on its own, or
 * the stack being looked at, is always in the middle - never left at one
 * side after the cards next to it are closed or moved away.
 */
TestCase {
    id: testCase
    name: "CardCentring"
    width: 480
    height: 800
    // A TestCase is hidden by default, and a hidden MouseArea gets no input.
    visible: true
    when: windowShown

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

    readonly property Item list: findChild(cardView, "cardGroupListView")
    readonly property var groups: list ? list.cardGroupModel : null

    function init() {
        failOnWarning(/TypeError|ReferenceError|Unable to assign|Binding loop detected for property "cardSpread"/);
    }

    function cleanup() {
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


    // How far the middle of the current group is from the middle of the view
    function offCentre() {
        var group = list.listView.currentItem;
        verify(group, "no current group");
        var p = group.mapToItem(cardView, group.width / 2, 0);
        return p.x - cardView.width / 2;
    }

    function checkCentred(what) {
        waitForCards();
        verify(Math.abs(offCentre()) < 1, what + ": the current group is " + offCentre().toFixed(1) + " px off the middle");
    }

    function test_new_cards_are_centred() {
        openCards(["a"]);
        checkCentred("one card");
        openCard("b");
        cardView.setCurrentCardState(WindowState.Carded);
        checkCentred("second card");
    }

    function test_last_card_left_is_centred_data() {
        return [
            { tag: "close the last", open: ["a", "b"], close: ["b"] },
            { tag: "close the first", open: ["a", "b"], close: ["a"] },
            { tag: "close two of three from the right", open: ["a", "b", "c"], close: ["c", "b"] },
            { tag: "close two of three from the left", open: ["a", "b", "c"], close: ["a", "b"] },
            { tag: "close the middle then the last", open: ["a", "b", "c"], close: ["b", "c"] },
        ];
    }
    function test_last_card_left_is_centred(data) {
        var w = openCards(data.open);
        for (var i = 0; i < data.close.length; ++i) {
            compositor.closeWindow(w[data.close[i]]);
            checkCentred("after closing " + data.close.slice(0, i + 1).join(", "));
        }
    }

    function test_a_stack_is_centred_as_a_whole() {
        var w = openCards(["a", "b", "c"]);
        verify(groups.moveWindow(w["b"], 0, 1));
        verify(groups.moveWindow(w["c"], 0, 2));
        list.listView.currentIndex = 0;
        checkCentred("a stack of three");
    }

    function test_moving_to_another_group_centres_it() {
        openCards(["a", "b", "c"]);
        list.listView.currentIndex = 0;
        checkCentred("first group");
        list.listView.currentIndex = 2;
        checkCentred("last group");
    }
}
