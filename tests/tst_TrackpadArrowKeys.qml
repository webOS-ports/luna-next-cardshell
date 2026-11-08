import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * Arrow keys from the hardware count only on a device with a hardware keyboard.
 * Without one they come from things that are no pointer - the Pixel 3a's
 * fingerprint sensor sends Up/Down/Left/Right on a touch - and are dropped
 * before the shell or an application sees them.
 *
 * Keys are fed to _onKey(), the function TrackpadScroll registers with the
 * compositor's key filter. No application is in front (active stays false), so
 * a key that is not dropped goes on its way untouched.
 */
TestCase {
    name: "TrackpadArrowKeys"

    // TrackpadScroll looks the compositor up by name; none in this test.
    property var compositor: null

    Component {
        id: trackpadComponent
        TrackpadScroll {}
    }

    function test_arrows_data() {
        return [
            { tag: "left",  key: Qt.Key_Left },
            { tag: "right", key: Qt.Key_Right },
            { tag: "up",    key: Qt.Key_Up },
            { tag: "down",  key: Qt.Key_Down }
        ];
    }

    function test_arrows(data) {
        const pad = createTemporaryObject(trackpadComponent, null, { arrowKeysWanted: false });
        compare(pad._onKey(data.key, true, false, 0), pad.resultAccepted, "press dropped");
        compare(pad._onKey(data.key, false, false, 0), pad.resultAccepted, "release dropped");

        pad.arrowKeysWanted = true;
        compare(pad._onKey(data.key, true, false, 0), pad.resultNextPolicy, "passed on with a keyboard");
    }

    function test_otherKeysPassWithoutKeyboard() {
        const pad = createTemporaryObject(trackpadComponent, null, { arrowKeysWanted: false });
        compare(pad._onKey(Qt.Key_Back, true, false, 0), pad.resultNextPolicy);
        compare(pad._onKey(Qt.Key_Return, true, false, 0), pad.resultNextPolicy);
        compare(pad._onKey(Qt.Key_A, true, false, 0), pad.resultNextPolicy);
    }
}
