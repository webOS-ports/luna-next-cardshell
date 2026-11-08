import QtQuick 2.0
import QtTest 1.0

import "../qml"

/*
 * BootLoader hands every state bootmgr reports to BootStateWatchdog. Only
 * "normal" and "firstuse" give the shell a state; anything else that lasts
 * past the grace period is logged, as the shell then runs with its gestures
 * and the system menu off and says nothing about it. No answer at all is
 * logged too: the shell is then never loaded.
 */
TestCase {
    name: "BootStateWatchdog"

    Component {
        id: watchdogComponent
        BootStateWatchdog { graceMs: 100 }
    }

    property var watchdog: null

    SignalSpy { id: stuckSpy; signalName: "stuck" }

    function init() {
        watchdog = createTemporaryObject(watchdogComponent, this);
        stuckSpy.target = watchdog;
        stuckSpy.clear();
    }

    // stuck in "startup": one warning naming the state and the likely cause
    function test_stuckInStartupWarns() {
        ignoreWarning(new RegExp("bootmgr still reports \"startup\" after 0 s.*com\\.webos\\.surfacemanager\\.cardshell"));
        watchdog.report("startup");
        stuckSpy.wait(1000);
        compare(stuckSpy.count, 1);
        compare(stuckSpy.signalArguments[0][0], "startup");
    }

    // bootmgr never answers: the period runs from the start
    function test_noAnswerWarns() {
        ignoreWarning(new RegExp("no boot state from org\\.webosports\\.bootmgr after 0 s"));
        stuckSpy.wait(1000);
        compare(stuckSpy.count, 1);
        compare(stuckSpy.signalArguments[0][0], "");
    }

    function test_runStates_data() {
        return [ { tag: "normal", state: "normal" }, { tag: "firstuse", state: "firstuse" } ];
    }

    // the usual boot: "startup" first, then a state the shell runs in
    function test_runStates(data) {
        watchdog.report("startup");
        watchdog.report(data.state);
        wait(300);
        compare(stuckSpy.count, 0);
        compare(watchdog.lastState, data.state);
    }

    // straight to a run state, as on a shell restart with bootmgr already up
    function test_normalAloneIsQuiet() {
        watchdog.report("normal");
        wait(300);
        compare(stuckSpy.count, 0);
    }

    // a repeated "startup" does not restart the grace period
    function test_repeatsDoNotPostpone() {
        ignoreWarning(new RegExp("bootmgr still reports \"startup\""));
        watchdog.report("startup");
        wait(60);
        watchdog.report("startup");
        wait(60);
        compare(stuckSpy.count, 1);
    }

    // back to "startup" later (the shell went away and came back): watched again
    function test_watchedAgainAfterNormal() {
        watchdog.report("normal");
        ignoreWarning(new RegExp("bootmgr still reports \"startup\""));
        watchdog.report("startup");
        stuckSpy.wait(1000);
        compare(stuckSpy.count, 1);
    }
}
