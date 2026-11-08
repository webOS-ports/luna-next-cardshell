import QtQuick 2.0
import QtTest 1.0

import "../qml/LunaSysAPI" as LunaSysAPI
import "../qml/LaunchBar"

/*
 * ApplicationModel against a stand-in for SAM that holds every listLaunchPoints
 * call until the test answers it. An install or a removal makes SAM post dozens
 * of launch point changes in a row; the shell asked for the whole list at each
 * one (258 lists for one removal on a mindphone, with 63 launch points), which
 * froze it for seconds. A burst gets one list now.
 */
TestCase {
    name: "ApplicationModel"

    QtObject {
        id: sam
        property var calls: []
        function call(uri, args, onReply, onError) {
            calls.push({ uri: uri, onReply: onReply, onError: onError });
        }
        function subscribe(uri, args, onReply, onError) {}
        function answer(launchPoints) {
            var c = calls[calls.length - 1];
            c.onReply({ payload: JSON.stringify({ returnValue: true, launchPoints: launchPoints }) });
        }
        function fail() {
            calls[calls.length - 1].onError("SAM said no");
        }
    }

    LunaSysAPI.ApplicationModel {
        id: model
        lunaNextLS2Service: sam
    }

    readonly property var launchPoints: [
        { id: "com.palm.app.calendar", launchPointId: "com.palm.app.calendar_default", title: "Calendar" },
        { id: "com.palm.app.email", launchPointId: "com.palm.app.email_default", title: "Email" },
        { id: "org.webosports.app.music", launchPointId: "org.webosports.app.music_default", title: "Music" }
    ]

    // A change SAM posts to listLaunchPoints' subscribers: one launch point, no list.
    function postChange() {
        model.handleLaunchPointsPosted({ payload: JSON.stringify({ subscribed: true, returnValue: true,
                                                                   launchPoint: launchPoints[0], change: "updated" }) });
    }

    function init() {
        // Settle what an earlier test left going, then start counting.
        wait(model.refreshMaxDelay + 200);
        while (model._listing)
            sam.answer(launchPoints);
        sam.calls = [];
    }

    function test_1_a_burst_of_changes_is_one_list() {
        for (var i = 0; i < 43; i++)
            postChange();
        compare(sam.calls.length, 0, "asked before the burst was over");
        tryVerify(function() { return sam.calls.length === 1; }, 2000);
        compare(sam.calls[0].uri, "luna://com.webos.service.applicationManager/listLaunchPoints");
        sam.answer(launchPoints);
        compare(model.count, 3);
        compare(model.get(2).title, "Music");
        wait(model.refreshDelay * 3);
        compare(sam.calls.length, 1);
    }

    function test_2_changes_while_the_list_comes_ask_once_more() {
        postChange();
        tryVerify(function() { return sam.calls.length === 1; }, 2000);
        // Not answered yet: changes now must not send a second request alongside.
        for (var i = 0; i < 5; i++)
            postChange();
        wait(model.refreshMaxDelay + 200);
        compare(sam.calls.length, 1, "a second list asked while the first was on its way");
        sam.answer(launchPoints);
        // The changes may have come after SAM made that list: one more.
        tryVerify(function() { return sam.calls.length === 2; }, 2000);
        sam.answer(launchPoints);
        wait(model.refreshMaxDelay + 200);
        compare(sam.calls.length, 2);
    }

    function test_3_changes_that_keep_coming_do_not_hold_the_list_back() {
        var started = Date.now();
        while (sam.calls.length === 0 && Date.now() - started < 3000) {
            postChange();
            wait(50);
        }
        verify(sam.calls.length === 1, "no list during 3 s of changes");
        verify(Date.now() - started <= model.refreshMaxDelay + model.refreshDelay + 300,
               "the list waited " + (Date.now() - started) + " ms");
        sam.answer(launchPoints);
    }

    function test_4_a_failed_list_still_asks_again_for_later_changes() {
        postChange();
        tryVerify(function() { return sam.calls.length === 1; }, 2000);
        postChange();
        wait(model.refreshMaxDelay + 200); // its list is due while the first is still out
        compare(sam.calls.length, 1);
        sam.fail();
        tryVerify(function() { return sam.calls.length === 2; }, 2000);
        sam.answer(launchPoints);
        compare(model.count, 3);
    }

    function test_5_a_post_with_the_list_needs_no_call() {
        model.handleLaunchPointsPosted({ payload: JSON.stringify({ subscribed: true, returnValue: true,
                                                                   launchPoints: launchPoints.slice(0, 2) }) });
        compare(model.count, 2);
        wait(model.refreshDelay * 3);
        compare(sam.calls.length, 0);
    }

    function test_6_filter_still_applies() {
        model.applyFilter({ title: "Email" });
        tryVerify(function() { return sam.calls.length === 1; }, 2000);
        sam.answer(launchPoints);
        compare(model.count, 1);
        compare(model.get(0).id, "com.palm.app.email");
        model.filter = undefined;
    }

    // A tab takes the launcher's shared model; it builds none of its own, each of
    // which would have asked SAM for the list at every change too.
    function test_7_a_tab_builds_no_model_of_its_own() {
        var tab = Qt.createQmlObject('import "../qml/LaunchBar"; TabApplicationModel { launcherTab: "apps"; isDefaultTab: true }',
                                     model, "tab");
        compare(tab.appsModel, null);
        tab.refreshConfig(); // nothing to show, and no error
        compare(tab.count, 0);
        tab.appsModel = model;
        tab.refreshConfig();
        verify(tab.count > 0);
        tab.destroy();
    }
}
