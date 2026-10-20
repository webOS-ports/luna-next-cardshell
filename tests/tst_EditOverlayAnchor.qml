import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * The spelling pill hangs above the misspelled word: anchorTopY is the word's
 * top while it shows suggestions for it, and anchorY again once it is gone.
 */
Item {
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

    Item {
        id: app
        x: 0
        y: 100
        width: 480
        height: 700
    }

    EditOverlay {
        id: overlay
        anchors.fill: parent
        keyboardService: keyboard
        foregroundWindow: function() { return app; }
    }

    TestCase {
        name: "EditOverlayAnchor"
        when: windowShown

        function cleanup() {
            overlay.hide();
            keyboard.spellingRect = null;
        }

        function test_at_the_word() {
            keyboard.spellingRect = Qt.rect(50, 200, 80, 30);
            overlay.showSuggestionsAtWord(70, 215);
            verify(overlay.visible);
            compare(overlay.anchorY, 330);
            compare(overlay.anchorTopY, 300);
        }

        function test_at_the_tap_without_the_word() {
            overlay.showSuggestionsAtWord(70, 215);
            verify(overlay.visible);
            compare(overlay.anchorTopY, 215);
        }

        function test_at_the_tap_after_a_word() {
            keyboard.spellingRect = Qt.rect(50, 200, 80, 30);
            overlay.showSuggestionsAtWord(70, 215);
            keyboard.spellingRect = null;
            overlay.showSuggestionsAtWord(70, 600);
            compare(overlay.anchorTopY, 600);
            overlay.showAt(10, 500);
            compare(overlay.anchorTopY, 500);
        }

        function test_follows_anchorY_again_once_hidden() {
            keyboard.spellingRect = Qt.rect(50, 200, 80, 30);
            overlay.showSuggestionsAtWord(70, 215);
            overlay.hide();
            overlay.showAt(10, 500);
            compare(overlay.anchorTopY, 500);
        }
    }
}
