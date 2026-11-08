import QtQuick 2.0
import QtTest 1.0
import WebOSCoreCompositor 1.0

import "../qml/Notifications"

/*
 * The alert bar is as tall as its tallest window alert, and while a
 * notification alert is up in the phone's bar, as tall as that alert.
 * Run against luneos-components' compositor mock.
 */
Item {
    width: 480
    height: 800

    Compositor { id: compositor }

    // A popup alert window, as the filter in AlertWindowsArea takes them.
    Component {
        id: alertWindow
        Item {
            property string type: "_WEBOS_WINDOW_TYPE_SYSTEM_UI"
            property var windowProperties: { "LuneOS_window": "popupalert" }
            function changeSize(size) {}
        }
    }

    AlertWindowsArea {
        id: area
        width: 480
        compositorInstance: compositor
    }

    TestCase {
        name: "AlertAreaHeight"
        when: windowShown

        function openAlert(height) {
            var window = alertWindow.createObject(compositor, { height: height });
            compositor.surfaceModel.append({ obj: window });
            return window;
        }

        function windows() {
            var list = [];
            for (var i = 0; i < compositor.surfaceModel.count; ++i)
                list.push(compositor.surfaceModel.get(i).obj);
            return list;
        }

        function notificationAlerts() {
            for (var i = 0; i < area.children.length; ++i)
                if (typeof area.children[i].handleAlertMessage === "function")
                    return area.children[i];
            return null;
        }

        function cleanup() {
            var list = windows();
            for (var i = 0; i < list.length; ++i)
                compositor.closeWindow(list[i]);
            notificationAlerts().handleAlertMessage({ alertAction: "closeAll" });
        }

        function test_empty() {
            compare(area.maxHeight, 0);
        }

        function test_tallest_window_alert() {
            var first = openAlert(60);
            openAlert(90);
            compare(area.maxHeight, 90);

            first.height = 120;
            compare(area.maxHeight, 120);

            compositor.closeWindow(first);
            compare(area.maxHeight, 90);
        }

        function test_notification_alert_in_front() {
            openAlert(90);
            var alerts = notificationAlerts();
            alerts.handleAlertMessage({ alertAction: "open", timestamp: "1",
                                        alertInfo: { message: "Allow?", buttons: [] } });
            verify(alerts.showing);
            verify(alerts.height > 0);
            compare(area.maxHeight, alerts.height);

            alerts.handleAlertMessage({ alertAction: "closeAll" });
            compare(area.maxHeight, 90);
        }
    }
}
