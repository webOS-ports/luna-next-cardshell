import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * An icon asked for (here a dashboard window's, which always takes a lookup
 * of the application's folder) before IconPathServices' service is on the bus: the call
 * waits for it rather than going nowhere, which left the icon blank - what an
 * area made while the shell runs had for every entry already listed.
 */
Item {
    id: root

    // a dashboard window as the areas hand it over: the application's id,
    // and the icon it named, which needs the application's folder
    property var window: ({ "appId": "com.example.app",
                            "windowProperties": { "LuneOS_icon": "icon.png" } })

    Component {
        id: pathsComponent
        IconPathServices {}
    }

    TestCase {
        name: "IconPathServices"

        function test_aLookupBeforeTheServiceIsUpWaitsForIt() {
            var paths = createTemporaryObject(pathsComponent, root);
            // as it is while its creation has not completed
            paths._ready = false;

            var got = [];
            paths.setIconUrlFromWindow(root.window, function (url) { got.push(String(url)); });
            compare(got.length, 0, "nothing yet");
            compare(paths._waiting.length, 1, "the lookup waits");

            paths.service.initialized();
            compare(paths._waiting.length, 0);
            tryVerify(() => got.length === 1, 1000, "the icon is set once the service is up");
        }

        function test_aLookupOnceTheServiceIsUpGoesStraightOut() {
            var paths = createTemporaryObject(pathsComponent, root);
            verify(paths._ready);
            var got = [];
            paths.setIconUrlFromWindow(root.window, function (url) { got.push(String(url)); });
            compare(paths._waiting.length, 0);
            tryVerify(() => got.length === 1, 1000);
        }
    }
}
