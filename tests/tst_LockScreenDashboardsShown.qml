import QtQuick 2.0
import QtTest 1.0
import LuneOS.System 1.0

import "../qml/LockScreen"

/*
 * When the lock screen shows the notifications, as LockWindow did: at the
 * padlock only, not for the PIN, password or pattern; not while an incoming
 * call or the alarm is over it; not during First Use; not once Settings'
 * "Show alerts when locked" is off. Run against luneos-components' mocks.
 */
Item {
    width: 480
    height: 800

    Item {
        id: windowManager
        signal switchToDockMode()
        signal switchToMaximize(var window)
        signal switchToFullscreen(var window)
        signal switchToCardView()
        signal switchToLauncherView()
        function switchToLockscreen() {}
    }

    // Settings' side of the preference store
    SystemPreferences {
        id: prefs
        keys: ["showAlertsWhenLocked"]
    }

    LockScreen {
        id: lockScreen
        anchors.fill: parent
        windowManagerInstance: windowManager
    }

    TestCase {
        name: "LockScreenDashboardsShown"
        when: windowShown

        function init() {
            tryVerify(() => prefs.loaded, 2000);
            prefs.set("showAlertsWhenLocked", true);
            tryCompare(lockScreen, "showAlertsWhenLocked", true);
            lockScreen.alertShowing = false;
            lockScreen.isFirstUse = false;
            lockScreen.state = "pad";
        }

        function cleanup() {
            lockScreen.state = "none";
        }

        function test_at_the_padlock() {
            verify(lockScreen.dashboardsShown);
        }

        function test_not_unlocked() {
            lockScreen.state = "none";
            verify(!lockScreen.dashboardsShown);
        }

        function test_not_for_the_passcode() {
            lockScreen.state = "pin-password";
            verify(!lockScreen.dashboardsShown);
            lockScreen.state = "pattern";
            verify(!lockScreen.dashboardsShown);
        }

        function test_not_under_an_alert() {
            lockScreen.alertShowing = true;
            verify(!lockScreen.dashboardsShown);
        }

        // Locked by a real lock event, which First Use does not drop (one
        // from the display manager's first snapshot it does: no lock screen).
        function test_not_during_first_use() {
            lockScreen._lockedBySnapshot = false;
            lockScreen.isFirstUse = true;
            compare(lockScreen.state, "pad");
            verify(!lockScreen.dashboardsShown);
        }

        function test_the_preference_turns_it_off() {
            prefs.set("showAlertsWhenLocked", false);
            tryCompare(lockScreen, "showAlertsWhenLocked", false);
            verify(!lockScreen.dashboardsShown);
            prefs.set("showAlertsWhenLocked", true);
            tryCompare(lockScreen, "dashboardsShown", true);
        }
    }
}
