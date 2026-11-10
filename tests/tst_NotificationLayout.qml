import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import LuneOS.System 1.0

import "../qml/Utils"
import "../qml/Notifications"

/*
 * Settings' Notifications page: the look of the rows (phone or tablet) and
 * where the list is (bottom or top), each portrait and landscape, "auto" being
 * the device's own. Run on the default profile, a phone.
 */
Item {
    id: root
    width: 600
    height: 200

    // The Settings page's side: writes go to the mock preference store, which
    // tells every subscriber, the singleton's included.
    SystemPreferences {
        id: page
        keys: ["notificationStyle", "notificationLocationPortrait", "notificationLocationLandscape"]
    }

    Component {
        id: itemComponent
        NotificationItem {
            width: 500
            height: 52
            title: "a title"
            body: "a body"
            count: 1
        }
    }

    // As CardsArea makes the bottom area: the source set once, the item made
    // and unmade as the location changes, a bound property kept bound.
    property real boundValue: 10
    Loader {
        id: loader
        property bool atBottom: true
        active: atBottom
        Component.onCompleted: setSource("data/LoaderProbe.qml",
                                         { "probe": Qt.binding(() => root.boundValue) })
    }

    TestCase {
        name: "NotificationLayout"
        when: windowShown

        function init() {
            tryVerify(() => page.loaded);
            page.setMany({ "notificationStyle": "auto",
                           "notificationLocationPortrait": "auto",
                           "notificationLocationLandscape": "auto" });
            NotificationLayout.landscape = false;
            tryCompare(NotificationLayout, "style", "auto");
            tryCompare(NotificationLayout, "location", "auto");
        }

        function test_autoIsTheDevice() {
            compare(NotificationLayout.resolveTabletStyle("auto", true), true);
            compare(NotificationLayout.resolveTabletStyle("auto", false), false);
            compare(NotificationLayout.resolveTabletStyle(undefined, false), false);
            compare(NotificationLayout.resolveAtTop("auto", true, false), true);
            compare(NotificationLayout.resolveAtTop("auto", false, false), false);
        }

        function test_aPhoneOnItsSideHasThemAtTheTop() {
            compare(NotificationLayout.resolveAtTop("auto", false, true), true);
            compare(NotificationLayout.resolveAtTop("bottom", false, true), false);
            compare(NotificationLayout.resolveAtTop("bottom", true, true), false);
        }

        // The Titan Pocket's 720 by 720: only the angle says which way up it is.
        function test_aSquareScreenIsLandscapeWhenTurned_data() {
            return [ { tag: "upright",        w: 720, h: 720, angle: 0,   landscape: false },
                     { tag: "left",           w: 720, h: 720, angle: 90,  landscape: true },
                     { tag: "upside down",    w: 720, h: 720, angle: 180, landscape: false },
                     { tag: "right",          w: 720, h: 720, angle: 270, landscape: true },
                     { tag: "turning, early", w: 720, h: 720, angle: 30,  landscape: false },
                     { tag: "turning, late",  w: 720, h: 720, angle: 60,  landscape: true },
                     { tag: "no angle",       w: 720, h: 720, angle: undefined, landscape: false } ];
        }
        function test_aSquareScreenIsLandscapeWhenTurned(data) {
            compare(NotificationLayout.isLandscape(data.w, data.h, data.angle), data.landscape);
        }

        // Elsewhere the size says it, as OrientationHelper swaps it when turned.
        function test_aScreenWiderThanHighIsLandscape_data() {
            return [ { tag: "phone upright",  w: 1080, h: 2340, angle: 0,  landscape: false },
                     { tag: "phone turned",   w: 2340, h: 1080, angle: 90, landscape: true },
                     { tag: "tablet as made", w: 1280, h: 800,  angle: 0,  landscape: true },
                     { tag: "tablet turned",  w: 800,  h: 1280, angle: 90, landscape: false } ];
        }
        function test_aScreenWiderThanHighIsLandscape(data) {
            compare(NotificationLayout.isLandscape(data.w, data.h, data.angle), data.landscape);
        }

        function test_aChoiceOverridesTheDevice() {
            compare(NotificationLayout.resolveTabletStyle("tablet", false), true);
            compare(NotificationLayout.resolveTabletStyle("phone", true), false);
            compare(NotificationLayout.resolveAtTop("top", false, false), true);
            compare(NotificationLayout.resolveAtTop("bottom", true, false), false);
        }

        function test_followsThePreferences() {
            compare(Settings.tabletUi, false);
            compare(NotificationLayout.tabletStyle, false);
            compare(NotificationLayout.atTop, false);

            page.set("notificationStyle", "tablet");
            tryCompare(NotificationLayout, "tabletStyle", true);
            page.set("notificationLocationPortrait", "top");
            tryCompare(NotificationLayout, "atTop", true);
        }

        function test_eachWayRoundHasItsOwnLocation() {
            page.setMany({ "notificationLocationPortrait": "top",
                           "notificationLocationLandscape": "bottom" });
            tryCompare(NotificationLayout, "atTop", true);
            NotificationLayout.landscape = true;
            compare(NotificationLayout.atTop, false);
            NotificationLayout.landscape = false;
            compare(NotificationLayout.atTop, true);
        }

        function test_landscapeAutoIsTopOnAPhone() {
            NotificationLayout.landscape = true;
            compare(NotificationLayout.atTop, true);
        }

        function test_aRowChangesItsLookWithTheStyle() {
            var item = createTemporaryObject(itemComponent, root);
            verify(item);
            compare(item.tablet, false);
            page.set("notificationStyle", "tablet");
            tryCompare(item, "tablet", true);
            page.set("notificationStyle", "phone");
            tryCompare(item, "tablet", false);
        }

        function test_anAreaMadeAgainKeepsItsBindings() {
            tryVerify(() => loader.item);
            compare(loader.item.probe, 10);
            loader.atBottom = false;
            compare(loader.item, null);
            root.boundValue = 20;
            loader.atBottom = true;
            tryVerify(() => loader.item);
            compare(loader.item.probe, 20);
            root.boundValue = 30;
            compare(loader.item.probe, 30);
        }
    }
}
