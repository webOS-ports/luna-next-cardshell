import QtQuick 2.0
import QtTest 1.0

import "../qml/Connectors"

/*
 * GestureTutorial: the tutorial launched when first use is over, and when
 * the "Dismissing Cards" note comes, against a recorder in place of the bus.
 */
TestCase {
    id: test
    name: "GestureTutorial"

    QtObject {
        id: recorder
        property var calls: []
        property var prefsHandler: null
        function call(uri, payload, onSuccess, onError) {
            calls.push({ uri: uri, params: JSON.parse(payload) });
            onSuccess({ payload: JSON.stringify({ returnValue: true }) });
        }
        function subscribe(uri, payload, onSuccess, onError) {
            calls.push({ uri: uri, params: JSON.parse(payload) });
            prefsHandler = onSuccess;
            return { cancel: function () {} };
        }
        function prefs(reply) {
            prefsHandler({ payload: JSON.stringify(reply) });
        }
    }

    Component {
        id: hooksComponent
        GestureTutorial {
            bus: recorder
            launchDelay: 20
            hintDelay: 20
        }
    }

    SignalSpy { id: hintSpy; signalName: "showHint" }

    property var hooks: null

    function make(props) {
        recorder.calls = [];
        recorder.prefsHandler = null;
        hooks = createTemporaryObject(hooksComponent, test, props || {});
        verify(hooks !== null);
        hintSpy.clear();
        hintSpy.target = hooks;
        return hooks;
    }

    function callsTo(uri) {
        return recorder.calls.filter(function (c) { return c.uri === uri; });
    }

    readonly property string launch: "luna://com.webos.service.applicationmanager/launch"
    readonly property string setPrefs: "luna://com.webos.service.systemservice/setPreferences"

    function test_subscribes() {
        make({ shellState: "normal" });
        compare(recorder.calls[0].uri, "luna://com.webos.service.systemservice/getPreferences");
        compare(recorder.calls[0].params, { keys: ["cardDismissHintShown", "gestureTutorialDone"], subscribe: true });
    }

    function test_launchAfterFirstUse() {
        make({ shellState: "firstuse" });
        hooks.shellState = "normal";
        compare(callsTo(launch).length, 0, "not at once");
        tryVerify(function () { return callsTo(launch).length === 1; }, 2000, "launched once");
        compare(callsTo(launch)[0].params, { id: "org.webosports.app.tutorial", params: { firstUse: true } });
    }

    function test_noLaunchOnANormalBoot() {
        make({ shellState: "normal" });
        wait(60);
        compare(callsTo(launch).length, 0);
        // bootmgr saying "normal" again
        hooks.shellState = "";
        hooks.shellState = "normal";
        wait(60);
        compare(callsTo(launch).length, 0);
    }

    function test_hintOnce() {
        make({ shellState: "normal" });
        recorder.prefs({ returnValue: true });
        hooks.cardMinimized("org.webosports.app.phone");
        tryCompare(hintSpy, "count", 1);
        compare(callsTo(setPrefs).length, 1);
        compare(callsTo(setPrefs)[0].params, { cardDismissHintShown: true });
        hooks.cardMinimized("org.webosports.app.phone");
        wait(60);
        compare(hintSpy.count, 1, "once");
    }

    function test_notBeforeThePrefsAnswer() {
        make({ shellState: "normal" });
        hooks.cardMinimized("org.webosports.app.phone");
        wait(60);
        compare(hintSpy.count, 0);
    }

    function test_notTwice_data() {
        return [
            { tag: "shown before", reply: { returnValue: true, cardDismissHintShown: true } },
            { tag: "tutorial done", reply: { returnValue: true, gestureTutorialDone: true } }
        ];
    }

    function test_notTwice(data) {
        make({ shellState: "normal" });
        recorder.prefs(data.reply);
        verify(hooks.prefsKnown);
        hooks.cardMinimized("org.webosports.app.phone");
        wait(60);
        compare(hintSpy.count, 0);
        compare(callsTo(setPrefs).length, 0);
    }

    function test_notForTheTutorial() {
        make({ shellState: "normal" });
        recorder.prefs({ returnValue: true });
        hooks.cardMinimized("org.webosports.app.tutorial");
        wait(60);
        compare(hintSpy.count, 0);
        // and still there for the next app
        hooks.cardMinimized("org.webosports.app.photos");
        tryCompare(hintSpy, "count", 1);
    }

    function test_notDuringFirstUse() {
        make({ shellState: "firstuse" });
        recorder.prefs({ returnValue: true });
        hooks.cardMinimized("org.webosports.app.firstuse");
        wait(60);
        compare(hintSpy.count, 0);
    }

    // The launcher opened over the card in the meantime: kept for later.
    function test_blockedMeanwhile() {
        make({ shellState: "normal" });
        recorder.prefs({ returnValue: true });
        hooks.cardMinimized("org.webosports.app.phone");
        hooks.blocked = true;
        wait(60);
        compare(hintSpy.count, 0);
        verify(!hooks.hintShown);
        hooks.blocked = false;
        hooks.cardMinimized("org.webosports.app.phone");
        tryCompare(hintSpy, "count", 1);
    }

    // Done elsewhere while running: a change comes with only that key.
    function test_tutorialDoneLater() {
        make({ shellState: "normal" });
        recorder.prefs({ returnValue: true });
        recorder.prefs({ returnValue: true, gestureTutorialDone: true });
        verify(hooks.tutorialDone);
        hooks.cardMinimized("org.webosports.app.phone");
        wait(60);
        compare(hintSpy.count, 0);
    }

    function test_errorReplyIsNotAnAnswer() {
        make({ shellState: "normal" });
        recorder.prefs({ returnValue: false, errorText: "no" });
        verify(!hooks.prefsKnown);
    }
}
