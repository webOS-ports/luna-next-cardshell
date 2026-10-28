import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"
import "../qml/WindowStateStub.js" as WindowState

/*
 * Moving cards around the card view by holding and dragging them, end to end
 * with real mouse input: CardWindowWrapper's MouseArea, the DropAreas of
 * CardGroupListView and the group model.
 *
 * The invariant that matters to the user: whatever happens during a drag,
 * afterwards every card is back in exactly one slot of a group, with that
 * slot's shadow under it. A card left in the drag container, or a slot left
 * without its card, is the "card and its shadow came apart" bug - and
 * throwing the empty shadow away closed the card that belonged to it.
 */
TestCase {
    id: testCase
    name: "CardDrag"
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

    function test_drag_card_onto_a_neighbour_joins_its_group() {
        openCards(["a", "b", "c"]);
        compare(layout(), "[a] | [b] | [c]");
        compare(list.listView.currentIndex, 2);

        var from = cardCentre(2, 0);
        holdAt(from);
        // Onto the part of b's card that shows left of c, clear of the
        // edge where the list scrolls.
        var over = cardCentre(1, 0);
        var bRight = over.x + list.cardWindowWidth / 2;
        verify(bRight > cardView.width * 0.1 + 10, "b is not in view");
        dragTo(from, Qt.point((cardView.width * 0.1 + bRight) / 2, from.y));
        mouseRelease(cardView);

        compare(layout(), "[a] | b [c]");
        checkSettled();
    }

    function test_drag_within_a_group_changes_its_place() {
        var w = openCards(["a", "b", "c"]);
        // One group "a b c", c on top
        verify(groups.moveWindow(w["b"], 0, 1));
        verify(groups.moveWindow(w["c"], 0, 2));
        compare(layout(), "a b [c]");
        list.listView.currentIndex = 0;
        waitForCards();

        // Hold c, the top card, and move it left to where a is the only
        // card: c goes right above a.
        var group = list.listView.itemAtIndex(0);
        var step = group.cardSpread * list.cardWindowWidth;
        var from = cardCentre(0, 2);
        var to = group.mapToItem(cardView, step / 2, group.height / 2);
        holdAt(from);
        dragTo(from, to);
        mouseRelease(cardView);

        compare(layout(), "a [c] b");
        checkSettled();
    }

    function test_drag_out_past_the_end_makes_a_group() {
        var w = openCards(["a", "b"]);
        verify(groups.moveWindow(w["b"], 0, 1));
        compare(layout(), "a [b]");
        waitForCards();

        var from = cardCentre(0, 1);
        holdAt(from);
        dragTo(from, Qt.point(cardView.width - 5, from.y));
        mouseRelease(cardView);

        compare(layout(), "[a] | [b]");
        checkSettled();
    }

    function test_release_puts_the_card_back_where_it_was() {
        openCards(["a", "b"]);
        var from = cardCentre(1, 0);
        holdAt(from);
        // A little way up, over nothing new
        dragTo(from, Qt.point(from.x, from.y - 60));
        mouseRelease(cardView);

        compare(layout(), "[a] | [b]");
        checkSettled();
    }

    function test_closing_the_dragged_card_ends_the_drag() {
        var w = openCards(["a", "b", "c"]);
        var from = cardCentre(2, 0);
        holdAt(from);
        mouseMove(cardView, from.x - 30, from.y);

        compositor.closeWindow(w["c"]);
        tryCompare(list, "draggedWindow", null);
        mouseRelease(cardView);

        compare(layout(), "[a] | [b]");
        checkSettled();
    }

    function test_a_new_card_ends_the_drag() {
        openCards(["a", "b"]);
        var from = cardCentre(1, 0);
        holdAt(from);
        mouseMove(cardView, from.x - 30, from.y);

        openCard("n");
        compare(list.draggedWindow, null);
        mouseRelease(cardView);
        cardView.setCurrentCardState(WindowState.Carded);
        checkSettled();
    }

    function test_leaving_the_card_view_ends_the_drag() {
        var w = openCards(["a", "b"]);
        var from = cardCentre(1, 0);
        holdAt(from);
        mouseMove(cardView, from.x - 30, from.y);

        windowManager.switchToLockscreen();
        compare(list.draggedWindow, null);
        mouseRelease(cardView);
        windowManager.switchToCardView();
        checkSettled();
    }

    function test_drag_is_refused_when_there_is_nowhere_to_go() {
        openCards(["a"]);
        var from = cardCentre(0, 0);
        mousePress(cardView, from.x, from.y);
        wait(1000);
        compare(list.draggedWindow, null);
        mouseRelease(cardView);
        checkSettled();

        openCard("b");
        cardView.setCurrentCardState(WindowState.Carded);
        list.enableDragnDrop = false;
        from = cardCentre(1, 0);
        mousePress(cardView, from.x, from.y);
        wait(1000);
        compare(list.draggedWindow, null);
        mouseRelease(cardView);
        checkSettled();
    }

    // An open app that goes away takes the card view back to its cards,
    // and its group with it, without the layout fighting itself.
    function test_closing_an_open_card() {
        var w = openCards(["a", "b"]);
        cardView.setCurrentCard(w["b"]);
        cardView.setCurrentCardState(WindowState.Maximized);
        tryCompare(cardView, "state", "maximizedCard");
        compositor.closeWindow(w["b"]);
        tryCompare(cardView, "state", "cardList");
        compare(layout(), "[a]");
        waitForCards();
        checkSettled();
    }

    // A window can be in the card list before its wrapper exists: the
    // group's delegate has to pick the wrapper up when it comes.
    function test_wrapper_made_after_the_card_is_listed() {
        openCards(["a"]);
        var window = earlyWindow.createObject(cardView, { appId: "late" });
        compositor.surfaceModel.append({ obj: window });
        wait(50);
        compositor.surfaceMapped(window);
        tryCompare(cardView, "state", "maximizedCard");
        cardView.setCurrentCardState(WindowState.Carded);
        compare(layout(), "[a] | [late]");
        checkSettled();
        compositor.surfaceModel.remove(compositor.surfaceModel.count - 1);
        window.destroy();
    }
}
