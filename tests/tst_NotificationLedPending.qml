import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"

/*
 * The LED shows the colour of the application with the newest toast still
 * waiting; "light" toasts leave nothing behind and do not count.
 */
Item {
    width: 480
    height: 800

    ListModel { id: toasts }

    NotificationLed {
        id: led
        notificationModel: toasts
    }

    ListModel { id: otherToasts }

    TestCase {
        name: "NotificationLedPending"
        when: windowShown

        function cleanup() {
            toasts.clear();
            otherToasts.clear();
            led.notificationModel = toasts;
        }

        function test_nothing_waiting() {
            compare(led.activeAppId, "");
        }

        function test_follows_the_newest_toast() {
            toasts.append({ sourceId: "org.webosports.app.phone", type: "standard" });
            compare(led.activeAppId, "org.webosports.app.phone");
            toasts.append({ sourceId: "org.webosports.app.messaging", type: "standard" });
            compare(led.activeAppId, "org.webosports.app.messaging");
            toasts.remove(1);
            compare(led.activeAppId, "org.webosports.app.phone");
            toasts.remove(0);
            compare(led.activeAppId, "");
        }

        function test_an_app_with_several_toasts_moves_to_its_newest() {
            toasts.append({ sourceId: "a", type: "standard" });
            toasts.append({ sourceId: "b", type: "standard" });
            toasts.append({ sourceId: "a", type: "standard" });
            compare(led._pendingAppIds, ["b", "a"]);
        }

        function test_light_toasts_do_not_count() {
            toasts.append({ sourceId: "a", type: "light" });
            compare(led.activeAppId, "");
        }

        function test_follows_a_new_model() {
            otherToasts.append({ sourceId: "c", type: "standard" });
            led.notificationModel = otherToasts;
            compare(led.activeAppId, "c");
        }
    }
}
