import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/Notifications"

/*
 * An incoming call's alert (LuneOS_overLockScreen) is fitted into the free
 * space like any alert, is the only alert counted while the screen is locked,
 * and is not closed by closeAll(), which a tap outside the alerts and the
 * gesture area's tap run. Run against luneos-components' compositor mock.
 */
Item {
    width: 480
    height: 800

    Compositor { id: compositor }

    Component {
        id: alertWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_SYSTEM_UI"
            property var windowProperties: { "LuneOS_window": "popupalert" }
            property size askedFor: Qt.size(0, 0)
            function changeSize(size) { askedFor = size; }
        }
    }

    AlertWindowsArea {
        id: area
        width: 480
        maxAlertHeight: 600
        compositorInstance: compositor
    }

    TestCase {
        name: "CallAlert"
        when: windowShown

        function openAlert(height, call) {
            var props = { "LuneOS_window": "popupalert" };
            if (call)
                props["LuneOS_overLockScreen"] = "true";
            var window = alertWindow.createObject(compositor, { height: height, windowProperties: props });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function windows() {
            var list = [];
            for (var i = 0; i < compositor.surfaceModel.count; ++i)
                list.push(compositor.surfaceModel.get(i).obj);
            return list;
        }

        function cleanup() {
            area.screenLocked = false;
            area.maxAlertHeight = 600;
            var list = windows();
            for (var i = 0; i < list.length; ++i)
                compositor.closeWindow(list[i]);
        }

        function test_max_height_is_never_negative() {
            area.maxAlertHeight = -40;
            openAlert(90, false);
            compare(area.maxHeight, 0);
        }

        function test_a_call_is_fitted_into_the_free_space() {
            var call = openAlert(800, true);
            compare(area.maxHeight, 600);
            tryCompare(call, "askedFor", Qt.size(480, 600));
        }

        function test_close_all_leaves_the_call() {
            openAlert(90, false);
            openAlert(800, true);
            verify(area.callAlertShowing);
            area.closeAll();
            compare(windows().length, 1);
            verify(area.callAlertShowing);
            compare(area.maxHeight, 600);
        }

        function test_only_the_call_shows_while_locked() {
            openAlert(300, false);
            area.screenLocked = true;
            compare(area.maxHeight, 0);
            verify(!area.callAlertShowing);
            openAlert(200, true);
            verify(area.callAlertShowing);
            compare(area.maxHeight, 200);
        }

        function test_ordinary_alerts_still_close() {
            openAlert(90, false);
            verify(!area.callAlertShowing);
            area.closeAll();
            compare(windows().length, 0);
        }
    }
}
