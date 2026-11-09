import QtQuick 2.0
import QtTest 1.0

import "../qml"
import "../qml/WindowManager"

/*
 * The edit pill and the on-screen keyboard. The keyboard is drawn under the
 * pill, so the pill must never come up on it, never hang over it, and never
 * take a key press for itself.
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
        property var spellingSuggestions: []
        property bool spellingCanLearn: false
        property string spellingWord: ""
        property var spellingRect: null
    }

    // What the compositor offers: the input method's panel rectangle, in the
    // panel window's coordinates.
    QtObject {
        id: inputMethod
        property rect panelRect: Qt.rect(0, 0, 0, 0)
    }

    QtObject {
        id: compositor
        property ListModel surfaceModel: ListModel {}
        property QtObject inputMethod: inputMethod
    }

    // Stands in for the application: what a press reaches when nothing above
    // it takes it.
    MouseArea {
        id: below
        anchors.fill: parent
        property int presses: 0
        onPressed: below.presses++
    }

    // Laid out as in CardsArea: under the status bar.
    KeyboardOverlay {
        id: keyboardOverlay
        y: 30
        width: parent.width
        height: parent.height - 30
        compositorInstance: compositor
    }

    // The keyboard's own window: screen-sized, keys drawn in a strip of it.
    Item {
        id: panelWindow
        property bool isPopup: false
        property QtObject surface: QtObject {
            property bool hasContent: false
        }
        function changeSize(size) {}
    }

    EditOverlay {
        id: overlay
        anchors.fill: parent
        keyboardService: keyboard
        keyboardRect: Qt.rect(keyboardOverlay.x + keyboardOverlay.keyboardRect.x,
                              keyboardOverlay.y + keyboardOverlay.keyboardRect.y,
                              keyboardOverlay.keyboardRect.width,
                              keyboardOverlay.keyboardRect.height)
    }

    TestCase {
        name: "EditOverlayKeyboard"
        when: windowShown

        // The keys: a 300 px strip at the bottom of the panel window, which is
        // screen y 470..770.
        readonly property rect keys: Qt.rect(0, 440, 480, 300)

        function initTestCase() {
            keyboardOverlay.appendKeyboardWindow(panelWindow);
        }

        function showKeyboard() {
            inputMethod.panelRect = keys;
            panelWindow.surface.hasContent = true;
        }

        function cleanup() {
            overlay.hide();
            inputMethod.panelRect = Qt.rect(0, 0, 0, 0);
            panelWindow.surface.hasContent = false;
            below.presses = 0;
        }

        function test_no_keyboard_no_rect() {
            compare(keyboardOverlay.keyboardRect.height, 0);
        }

        function test_rect_while_shown() {
            showKeyboard();
            compare(overlay.keyboardRect, Qt.rect(0, 470, 480, 300));
        }

        // Hiding unmaps the window and leaves the last rectangle behind.
        function test_stale_rect_once_hidden() {
            showKeyboard();
            panelWindow.surface.hasContent = false;
            compare(keyboardOverlay.keyboardRect.height, 0);
        }

        // The keyboard with nothing to show masks itself to a single pixel.
        function test_one_pixel_mask_is_no_keyboard() {
            showKeyboard();
            inputMethod.panelRect = Qt.rect(0, 709, 1, 1);
            compare(keyboardOverlay.keyboardRect.height, 0);
        }

        function test_never_shown_on_the_keys() {
            showKeyboard();
            overlay.showAt(240, 600);
            verify(!overlay.visible);
        }

        function test_shown_on_the_same_spot_without_a_keyboard() {
            overlay.showAt(240, 600);
            verify(overlay.visible);
        }

        function test_hangs_above_the_keys_not_over_them() {
            showKeyboard();
            overlay.showAt(240, 450);
            verify(overlay.visible);

            var pill = findChild(overlay, "editPill");
            verify(pill !== null);
            verify(!pill.below);
            verify(pill.y + pill.height <= 470);
        }

        function test_keyboard_coming_up_moves_the_pill_above_it() {
            overlay.showAt(240, 450);
            var pill = findChild(overlay, "editPill");
            verify(pill.below);

            showKeyboard();
            verify(overlay.visible);
            verify(!pill.below);
            verify(pill.y + pill.height <= 470);
        }

        function test_keyboard_coming_up_over_the_text_hides_the_pill() {
            overlay.showAt(240, 600);
            verify(overlay.visible);
            showKeyboard();
            verify(!overlay.visible);
        }

        // The press that takes the pill away is a key press as well.
        function test_key_press_dismisses_and_reaches_the_keys() {
            showKeyboard();
            overlay.showAt(240, 200);
            verify(overlay.visible);

            mousePress(root, 240, 600);
            mouseRelease(root, 240, 600);
            verify(!overlay.visible);
            compare(below.presses, 1);
        }

        // Elsewhere it stays what legacy's was: the press only dismisses.
        function test_press_elsewhere_only_dismisses() {
            showKeyboard();
            overlay.showAt(240, 200);
            verify(overlay.visible);

            mousePress(root, 240, 400);
            mouseRelease(root, 240, 400);
            verify(!overlay.visible);
            compare(below.presses, 0);
        }
    }
}
