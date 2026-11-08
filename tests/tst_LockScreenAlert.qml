import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/Notifications"

/*
 * An alert opened with clickableWhenLocked (LuneOS_clickablewhenlocked, as
 * WAM sets it for the Clock's alarm) is shown over the lock screen, as
 * LunaSysMgr's LockWindow showed the active popup alert there. Other alerts
 * still wait for the unlock, and unlike a call this one still goes with
 * closeAll(). Run against luneos-components' compositor mock.
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
        name: "LockScreenAlert"
        when: windowShown

        function openAlert(height, props) {
            var all = { "LuneOS_window": "popupalert" };
            for (var k in props)
                all[k] = props[k];
            var window = alertWindow.createObject(compositor, { height: height, windowProperties: all });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function windows() {
            var list = [];
            for (var i = 0; i < compositor.surfaceModel.count; ++i)
                list.push(compositor.surfaceModel.get(i).obj);
            return list;
        }

        // The alertItem the Repeater made for a window: the window's parent.
        function shown(window) {
            return window.parent !== null && window.parent.visible;
        }

        function cleanup() {
            area.screenLocked = false;
            var list = windows();
            for (var i = 0; i < list.length; ++i)
                compositor.closeWindow(list[i]);
        }

        function test_the_alarm_shows_over_the_lock_screen() {
            area.screenLocked = true;
            var alarm = openAlert(110, { "LuneOS_clickablewhenlocked": "true" });
            verify(area.lockScreenAlertShowing);
            verify(!area.callAlertShowing);
            compare(area.maxHeight, 110);
            tryVerify(function() { return shown(alarm); });
        }

        function test_other_alerts_still_wait_for_the_unlock() {
            area.screenLocked = true;
            var other = openAlert(220, {});
            var alarm = openAlert(110, { "LuneOS_clickablewhenlocked": "true" });
            compare(area.maxHeight, 110);
            tryVerify(function() { return shown(alarm); });
            verify(!shown(other));
            area.screenLocked = false;
            compare(area.maxHeight, 220);
            tryVerify(function() { return shown(other); });
        }

        function test_false_is_not_over_the_lock_screen() {
            area.screenLocked = true;
            openAlert(110, { "LuneOS_clickablewhenlocked": "false" });
            verify(!area.lockScreenAlertShowing);
            compare(area.maxHeight, 0);
        }

        function test_a_call_counts_as_a_lock_screen_alert() {
            openAlert(800, { "LuneOS_overLockScreen": "true" });
            verify(area.lockScreenAlertShowing);
        }

        function test_close_all_closes_the_alarm_but_not_a_call() {
            openAlert(110, { "LuneOS_clickablewhenlocked": "true" });
            openAlert(800, { "LuneOS_overLockScreen": "true" });
            area.closeAll();
            compare(windows().length, 1);
            verify(area.callAlertShowing);
        }
    }
}
