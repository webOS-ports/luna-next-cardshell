import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/CardView"

/*
 * CardGroupModel on its own: where a card goes, which card is current after a
 * removal, and moving cards within and between groups. After every operation
 * each window is in exactly one group and no group is empty - a window in no
 * group, or in two, is a card drawn without its shadow, or a shadow that
 * closes another card when it is thrown away.
 */
TestCase {
    name: "CardGroupModel"

    // CardGroupModel's WindowModel reads the compositor by this id, as in the shell.
    Compositor { id: compositor }

    CardGroupModel { id: model }

    Component {
        id: fakeWindow
        Item {
            property string name
            property int winId
            property int parentWinId: 0
            property string type: "_WEBOS_WINDOW_TYPE_CARD"
        }
    }

    property var windows: ({})

    function w(name) {
        if (!windows[name])
            windows[name] = fakeWindow.createObject(null, { name: name, winId: Object.keys(windows).length + 1 });
        return windows[name];
    }

    // The model as a string: groups separated by "|", the current card in [].
    function layout() {
        var groups = [];
        for (var g = 0; g < model.count; ++g) {
            var group = model.get(g), cards = [];
            for (var c = 0; c < group.windowList.count; ++c) {
                var n = group.windowList.get(c).window.name;
                cards.push(c === group.currentCardInGroup ? "[" + n + "]" : n);
            }
            groups.push(cards.join(" "));
        }
        return groups.join(" | ");
    }

    function checkInvariants() {
        var seen = {};
        for (var g = 0; g < model.count; ++g) {
            var group = model.get(g);
            verify(group.windowList.count > 0, "group " + g + " is empty");
            verify(group.currentCardInGroup >= 0 && group.currentCardInGroup < group.windowList.count,
                   "group " + g + " current card " + group.currentCardInGroup + " out of range");
            for (var c = 0; c < group.windowList.count; ++c) {
                var n = group.windowList.get(c).window.name;
                verify(!seen[n], n + " is in two places");
                seen[n] = true;
            }
        }
    }

    function build(spec) {
        // "a b | c" -> groups [a,b] and [c], current card the last of each
        model.clear();
        var groups = spec.split("|");
        for (var g = 0; g < groups.length; ++g) {
            var names = groups[g].trim().split(/\s+/);
            model.createNewGroup(w(names[0]), g);
            for (var c = 1; c < names.length; ++c)
                model.get(g).windowList.append({ "window": w(names[c]) });
            model.get(g).currentCardInGroup = names.length - 1;
        }
        checkInvariants();
    }

    function init() {
        model.clear();
        model.activeGroupIndex = -1;
    }

    function test_new_card_goes_right_after_the_active_group() {
        build("a | b | c");
        model.activeGroupIndex = 0;
        model.addWindow(w("d"));
        compare(layout(), "[a] | [d] | [b] | [c]");

        model.activeGroupIndex = -1;
        model.addWindow(w("e"));
        compare(layout(), "[a] | [d] | [b] | [c] | [e]");

        // Twice is still once.
        model.addWindow(w("e"));
        compare(layout(), "[a] | [d] | [b] | [c] | [e]");
        checkInvariants();
    }

    function test_child_window_joins_its_parent_on_top() {
        build("a b | c");
        model.get(0).currentCardInGroup = 0;
        var child = fakeWindow.createObject(null, { name: "k", winId: 99, parentWinId: w("a").winId });
        windows["k"] = child;
        model.addWindow(child);
        compare(layout(), "a b [k] | [c]");
        checkInvariants();
    }

    function test_remove_keeps_the_right_card_current() {
        // Removing a card before the current one must not shift "current" onto a neighbour.
        build("a b c d");
        model.get(0).currentCardInGroup = 2;     // c
        model.removeWindow(w("a"));
        compare(layout(), "b [c] d");

        // Removing the current card makes the one on its left current.
        model.removeWindow(w("c"));
        compare(layout(), "[b] d");
        model.removeWindow(w("b"));
        compare(layout(), "[d]");

        // Removing after the current one changes nothing.
        build("a b c");
        model.get(0).currentCardInGroup = 0;
        model.removeWindow(w("c"));
        compare(layout(), "[a] b");
        checkInvariants();
    }

    function test_last_card_takes_its_group_along() {
        build("a | b | c");
        model.removeWindow(w("b"));
        compare(layout(), "[a] | [c]");
        model.removeWindow(w("unknown"));
        compare(layout(), "[a] | [c]");
        checkInvariants();
    }

    function test_move_within_a_group() {
        build("a b c d");
        verify(model.moveWindow(w("a"), 0, 4));    // to the top
        compare(layout(), "b c d [a]");
        verify(model.moveWindow(w("a"), 0, 0));    // to the bottom
        compare(layout(), "[a] b c d");
        verify(model.moveWindow(w("b"), 0, 3));    // in front of d, as counted before the move
        compare(layout(), "a c [b] d");
        verify(model.moveWindow(w("b"), 0, 2));    // onto its own place
        compare(layout(), "a c [b] d");
        checkInvariants();
    }

    function test_move_between_groups() {
        build("a b | c | d e");
        verify(model.moveWindow(w("a"), 2, 1));
        compare(layout(), "[b] | [c] | d [a] e");
        // The last card of a group: the group goes, and indexes after it shift.
        verify(model.moveWindow(w("c"), 0, 0));
        compare(layout(), "[c] b | d [a] e");
        verify(!model.moveWindow(w("c"), 5, 0));
        verify(!model.moveWindow(w("unknown"), 0, 0));
        checkInvariants();
    }

    function test_move_to_a_new_group() {
        build("a b | c");
        compare(model.moveWindowToNewGroup(w("b"), 0), 0);
        compare(layout(), "[b] | [a] | [c]");
        compare(model.moveWindowToNewGroup(w("a"), 3), 2);   // to the end, as counted before
        compare(layout(), "[b] | [c] | [a]");
        // Alone already, next to where it would go: nothing moves.
        compare(model.moveWindowToNewGroup(w("a"), 2), 2);
        compare(model.moveWindowToNewGroup(w("a"), 3), 2);
        compare(layout(), "[b] | [c] | [a]");
        // Alone, but further away: the old group goes.
        compare(model.moveWindowToNewGroup(w("a"), 0), 0);
        compare(layout(), "[a] | [b] | [c]");
        checkInvariants();
    }

    function test_set_current_card() {
        build("a b | c");
        compare(model.setCurrentCard(w("a")), 0);
        compare(layout(), "[a] b | [c]");
        compare(model.setCurrentCard(w("unknown")), -1);
        compare(model.getCurrentCardOfGroup(model.get(0)), w("a"));
    }
}
