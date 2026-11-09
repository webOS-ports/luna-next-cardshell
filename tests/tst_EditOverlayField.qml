import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * The pill is for the text field, not for a press anywhere in an application
 * that has one focused. The compositor knows where the field's caret is, and a
 * press on the field puts the caret on the line it pressed.
 */
Item {
    id: root

    width: 480
    height: 800

    QtObject {
        id: keyboard
        property bool inputFocus: true
        property bool inputHasSelection: false
        property bool inputSelectionKnown: true
        property bool inputHasText: true
        property var spellingSuggestions: ["their"]
        property bool spellingCanLearn: false
        property string spellingWord: "thier"
        property var spellingRect: null
    }

    // The compositor's input method: the caret, already in the overlay's
    // coordinates, or undefined when the application never said.
    QtObject {
        id: inputMethod

        property var caret: undefined
        signal cursorRectangleChanged()

        function cursorRectangleIn(item) {
            return caret;
        }

        function moveCaret(rect) {
            caret = rect;
            cursorRectangleChanged();
        }
    }

    QtObject {
        id: compositor
        property QtObject inputMethod: inputMethod
        property bool clipboardHasText: true
    }

    EditOverlay {
        id: overlay
        anchors.fill: parent
        keyboardService: keyboard
        compositorInstance: compositor
    }

    TestCase {
        name: "EditOverlayField"
        when: windowShown

        // A one-line field's caret, 30 px tall, at y 200.
        readonly property rect line: Qt.rect(100, 200, 2, 30)

        function cleanup() {
            overlay.hide();
            inputMethod.caret = undefined;
        }

        function test_anywhere_when_the_caret_is_unknown() {
            overlay.showAt(240, 600);
            verify(overlay.visible);
        }

        function test_on_the_caret_line() {
            inputMethod.caret = line;
            overlay.showAt(300, 215);
            verify(overlay.visible);
        }

        // Past the end of the text, the caret stays where it was: the press is
        // still on the field.
        function test_anywhere_across_the_line() {
            inputMethod.caret = line;
            overlay.showAt(470, 215);
            verify(overlay.visible);
        }

        function test_a_finger_at_the_edge_of_the_line() {
            inputMethod.caret = line;
            overlay.showAt(300, 190);
            verify(overlay.visible);
            overlay.hide();
            overlay.showAt(300, 240);
            verify(overlay.visible);
        }

        function test_not_elsewhere_in_the_application() {
            inputMethod.caret = line;
            overlay.showAt(240, 600);
            verify(!overlay.visible);
            overlay.showAt(240, 100);
            verify(!overlay.visible);
        }

        // A hold elsewhere in the same field: the application moves the caret
        // to it a moment later, and the pill follows.
        function test_hold_waits_for_the_caret() {
            inputMethod.caret = line;
            overlay.showForHold(240, 400);
            verify(!overlay.visible);

            inputMethod.moveCaret(Qt.rect(200, 390, 2, 30));
            verify(overlay.visible);
            compare(overlay.anchorX, 201);
            compare(overlay.anchorY, 420);
            compare(overlay.anchorTopY, 390);
        }

        // A hold outside any field: the caret does not come, and the wait ends.
        function test_hold_elsewhere_gives_up() {
            inputMethod.caret = line;
            overlay.showForHold(240, 600);
            verify(!overlay.visible);

            wait(1100);
            inputMethod.moveCaret(Qt.rect(200, 590, 2, 30));
            verify(!overlay.visible);
        }

        // The caret moving somewhere else is not the hold's caret arriving.
        function test_hold_ignores_a_caret_moving_elsewhere() {
            inputMethod.caret = line;
            overlay.showForHold(240, 600);
            inputMethod.moveCaret(Qt.rect(100, 300, 2, 30));
            verify(!overlay.visible);
        }

        // A new press ends the wait.
        function test_a_new_press_stops_the_wait() {
            inputMethod.caret = line;
            overlay.showForHold(240, 600);
            overlay.stopWaitingForCaret();
            inputMethod.moveCaret(Qt.rect(200, 590, 2, 30));
            verify(!overlay.visible);
        }

        // Suggestions point at the caret, which the tap put in the word, rather
        // than at the finger.
        function test_suggestions_at_the_caret() {
            inputMethod.caret = Qt.rect(150, 200, 2, 30);
            overlay.showSuggestionsAtWord(160, 220);
            verify(overlay.visible);
            compare(overlay.anchorX, 151);
            compare(overlay.anchorY, 230);
            compare(overlay.anchorTopY, 200);
        }

        // The pill points at the text the press was on, not at the finger: it
        // hangs under the selection, its arrow on the selection's bottom edge,
        // and covers none of it.
        function test_under_the_selection_not_on_it() {
            inputMethod.caret = Qt.rect(50, 460, 130, 34);
            overlay.showAt(160, 470);
            verify(overlay.visible);
            compare(overlay.anchorX, 115);

            var pill = findChild(overlay, "editPill");
            verify(pill.below);
            compare(pill.y + pill.barTop, 494 + pill.textGap);
            verify(pill.textGap > 0);
        }

        // With no room underneath, over the selection's top edge instead.
        function test_over_the_selection_without_room_under_it() {
            inputMethod.caret = Qt.rect(50, 760, 130, 34);
            overlay.showAt(160, 770);
            verify(overlay.visible);

            var pill = findChild(overlay, "editPill");
            verify(!pill.below);
            compare(pill.y + pill.height - pill.barTop, 760 - pill.textGap);
        }

        // Held off the screen's edge, the pill still points its arrow at the
        // text rather than at its own middle.
        function test_arrow_at_the_text_near_the_edge() {
            inputMethod.caret = Qt.rect(60, 200, 2, 30);
            overlay.showAt(70, 215);
            verify(overlay.visible);

            var pill = findChild(overlay, "editPill");
            verify(pill.x > 0);
            verify(pill.x + pill.width / 2 > overlay.anchorX);
            compare(pill.x + pill.arrowCentre, overlay.anchorX);
        }

        // A hold on the application's own buttons takes the focus off the field
        // before it is over: no pill, and certainly not a greyed-out one.
        function test_not_once_the_field_lost_the_focus() {
            keyboard.inputFocus = false;
            overlay.showForHold(240, 560);
            verify(!overlay.visible);
            keyboard.inputFocus = true;
        }
    }
}
