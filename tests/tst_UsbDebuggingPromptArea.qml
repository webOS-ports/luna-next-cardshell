import QtQuick 2.0
import QtTest 1.0

import "../qml/Notifications"
import "../../luneos-components/test/imports/LuneOS/Service/devmode.js" as DevMode

/*
 * The shell shows devmode's adbAuthRequests and answers with respondAdbAuth:
 * the fingerprint it was told, Allow / Always / Deny as the user said, Deny
 * when nobody answers, and a question the service closed taken away.
 * DevMode is the same stand-in LuneOS.Service's LunaService mock answers
 * from (luneos-components' test/imports, found as COMPONENTS is by
 * run-tests.sh).
 */
Item {
    id: page
    width: 480
    height: 800

    property Item area: null

    Component {
        id: areaComponent
        UsbDebuggingPromptArea {}
    }

    TestCase {
        name: "UsbDebuggingPromptArea"
        when: windowShown

        readonly property string fp: "SHA256:47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU"

        function init() {
            DevMode.resetAccess();
            page.area = createTemporaryObject(areaComponent, page);
            verify(page.area !== null);
        }


        // Allow takes a tap only a second after each question (UsbDebuggingPrompt).
        function waitArmed() {
            tryVerify(function() { return findChild(page.area, "usbDebuggingAllow").enabled; }, 3000);
        }

        function child(name) {
            var c = findChild(page.area, name);
            verify(c !== null, name);
            return c;
        }

        function test_subscribes_at_once() {
            verify(DevMode.authSubscribers.length >= 1);
            compare(page.area.fingerprint, "");
        }

        // Not on the bus yet (USB debugging was off at boot): subscribing is what starts it.
        function test_subscribes_to_a_service_not_running_yet() {
            DevMode.resetAccess();
            DevMode.running = false;
            var shell = createTemporaryObject(areaComponent, page);
            compare(DevMode.authSubscribers.length, 1);
            DevMode.ask(fp, 30000);
            compare(shell.fingerprint, fp);
        }

        // The service only lets the shell's own name ask and answer.
        function test_asks_as_the_shell() {
            compare(DevMode.authSubscribers.length >= 1, true);
            DevMode.ask(fp, 30000);
            waitArmed();
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 1);
        }

        function test_a_question_is_shown() {
            DevMode.ask(fp, 30000);
            compare(page.area.fingerprint, fp);
            // Shown in groups of four; the same characters, in order.
            compare(child("usbDebuggingFingerprint").text.replace(/\s/g, ""), fp);
            verify(child("usbDebuggingAllow").visible);
        }

        function test_one_open_when_the_shell_starts_is_shown() {
            DevMode.ask(fp, 30000);
            var second = createTemporaryObject(areaComponent, page);
            compare(second.fingerprint, fp);
        }

        function test_allow_once() {
            DevMode.ask(fp, 30000);
            waitArmed();
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 1);
            compare(DevMode.responses[0].fingerprint, fp);
            compare(DevMode.responses[0].allow, true);
            compare(DevMode.responses[0].always, false);
            compare(page.area.fingerprint, "");
        }

        function test_allow_always() {
            DevMode.ask(fp, 30000);
            waitArmed();
            mouseClick(child("usbDebuggingAlways"));
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 1);
            compare(DevMode.responses[0].allow, true);
            compare(DevMode.responses[0].always, true);
        }

        function test_deny() {
            DevMode.ask(fp, 30000);
            waitArmed();
            mouseClick(child("usbDebuggingAlways"));
            mouseClick(child("usbDebuggingDeny"));
            compare(DevMode.responses.length, 1);
            compare(DevMode.responses[0].allow, false);
            compare(DevMode.responses[0].always, false);
        }

        // A tap already on its way when the question appears answers nothing.
        function test_a_tap_as_the_question_appears_lets_nobody_in() {
            DevMode.ask(fp, 30000);
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 0);
            compare(page.area.fingerprint, fp);
            // Still not half a second on.
            wait(400);
            verify(!child("usbDebuggingAllow").enabled);
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 0);
        }

        // Another computer's question in its place waits the whole second again.
        function test_another_computer_waits_again() {
            DevMode.ask(fp, 30000);
            waitArmed();
            DevMode.ask("SHA256:other", 30000);
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 0);
            waitArmed();
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses.length, 1);
            compare(DevMode.responses[0].fingerprint, "SHA256:other");
        }

        function test_no_answer_is_deny() {
            DevMode.ask(fp, 150);
            tryVerify(function() { return DevMode.responses.length === 1; }, 3000);
            compare(DevMode.responses[0].fingerprint, fp);
            compare(DevMode.responses[0].allow, false);
            compare(page.area.fingerprint, "");
        }

        function test_a_closed_question_goes_without_an_answer() {
            DevMode.ask(fp, 30000);
            DevMode.closeRequest();
            compare(page.area.fingerprint, "");
            compare(DevMode.responses.length, 0);
        }

        function test_a_newer_question_replaces_the_one_shown() {
            DevMode.ask(fp, 30000);
            DevMode.ask("SHA256:other", 30000);
            compare(page.area.fingerprint, "SHA256:other");
            waitArmed();
            mouseClick(child("usbDebuggingAllow"));
            compare(DevMode.responses[0].fingerprint, "SHA256:other");
        }

        function test_errors_and_junk_change_nothing() {
            DevMode.ask(fp, 30000);
            page.area.handleRequests({ payload: JSON.stringify({ "returnValue": false, "errorCode": "ACCESS_DENIED" }) });
            page.area.handleRequests({ payload: JSON.stringify({ "returnValue": false, "request": null }) });
            page.area.handleRequests({ payload: "not json" });
            page.area.handleRequests({ payload: JSON.stringify({ "returnValue": true }) });
            compare(page.area.fingerprint, fp);
            page.area.handleRequests({ payload: JSON.stringify({ "returnValue": true, "request": { "fingerprint": "" } }) });
            compare(page.area.fingerprint, "");
        }

        function test_the_service_going_takes_the_question_away() {
            DevMode.ask(fp, 30000);
            var status = null;
            for (var i = 0; i < page.area.data.length; i++)
                if (page.area.data[i].hasOwnProperty("serviceName"))
                    status = page.area.data[i];
            verify(status !== null);
            status._available = false;
            compare(page.area.fingerprint, "");
            compare(DevMode.responses.length, 0);
            var before = DevMode.authSubscribers.length;
            status._available = true;
            compare(DevMode.authSubscribers.length, before + 1);
        }
    }
}
