import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * The bar behind an entry rounds its corners by a sixth of a standard entry's
 * height. A dashboard that asks for more height (dashHeight) keeps those
 * corners rather than a sixth of its own height, as legacy webOS's fixed
 * 52 px art did.
 */
Item {
    width: 320
    height: 480

    NotificationBar {
        id: standard
        width: 300
        height: 60
    }

    NotificationBar {
        id: tall
        width: 300
        height: 180
        cornerHeight: 60
    }

    NotificationBar {
        id: low
        width: 300
        height: 30
        cornerHeight: 60
    }

    TestCase {
        name: "NotificationBar"
        when: windowShown

        function test_standardEntryIsASixthOfItsHeight() {
            compare(standard.radius, 10);
        }

        function test_tallDashboardKeepsAStandardEntrysCorners() {
            compare(tall.radius, 10);
        }

        // Never rounder than the entry itself allows.
        function test_shorterThanStandardRoundsByItsOwnHeight() {
            compare(low.radius, 5);
        }

        // The layers that draw the bar all take that radius.
        function test_everyLayerTakesTheRadius() {
            for (var i = 0; i < tall.children.length; ++i)
                compare(tall.children[i].radius, 10, "layer " + i);
        }
    }
}
