/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import QtTest 1.0
import LuneOS.Bluetooth 0.2

import "../qml/Notifications"

/*
 * The shell asks the pairings a Bluetooth device starts: it holds the
 * agent's subscription while Bluetooth is up (and takes it back from
 * another client), shows each question with its code, answers through the
 * request only once Pair can be read, says when a pairing did not work, and
 * takes a question away when the pairing ends.
 * LuneOS.Bluetooth is luneos-components' stand-in (test/imports): its agent
 * emits what the real one does, and the requests here record the answer.
 */
Item {
    id: page
    width: 480
    height: 800

    property Item area: null

    readonly property var desktop: ({"name": "herrie-desktop", "address": "BC:38:98:A8:38:64"})

    Component {
        id: areaComponent
        BluetoothPairingPromptArea {}
    }

    Component {
        id: requestComponent
        QtObject {
            property var accepted: undefined
            property int accepts: 0
            property int rejects: 0
            function accept(value) { accepts++; accepted = value; }
            function reject() { rejects++; }
        }
    }

    TestCase {
        name: "BluetoothPairingPrompt"
        when: windowShown

        function init() {
            BluetoothManager.btManager.bluetoothOperational = true;
            page.area = createTemporaryObject(areaComponent, page, {"retryIntervalMs": 50});
            verify(page.area !== null);
            findChild(page.area, "bluetoothPairingPrompt").armDelayMs = 200;
        }

        function agent() { return findChild(page.area, "bluetoothPairingAgent"); }
        function prompt() { return findChild(page.area, "bluetoothPairingPrompt"); }
        function child(name) {
            var c = findChild(page.area, name);
            verify(c !== null, name);
            return c;
        }
        function request() { return createTemporaryObject(requestComponent, page); }
        function waitArmed() { tryVerify(function () { return prompt().armed; }, 2000); }

        // ---- Holding the subscription.

        function test_registersOnceBluetoothIsUp() {
            BluetoothManager.btManager.bluetoothOperational = false;
            var area = createTemporaryObject(areaComponent, page, {"retryIntervalMs": 50});
            var a = findChild(area, "bluetoothPairingAgent");
            wait(150);
            compare(a.registerCalls, 0, "registered with Bluetooth off");
            BluetoothManager.btManager.bluetoothOperational = true;
            compare(a.registerCalls, 1);
            verify(area.registered);
            wait(150);
            compare(a.registerCalls, 1, "registered again while it held the subscription");
        }

        // Another client had it (104), or the subscription went: tried again.
        function test_takesTheSubscriptionBack() {
            compare(agent().registerCalls, 1);
            agent().registered = false;
            tryVerify(function () { return agent().registerCalls >= 2; }, 1000);
            verify(page.area.registered);
        }

        // ---- The questions.

        function test_aCodeToCompareIsShownAndPaired() {
            var r = request();
            agent().requestConfirmationFromUser(page.desktop, "042201", r);
            verify(prompt().opened);
            compare(page.area.kind, "confirmation");
            compare(child("bluetoothPairingCode").text, "042201");
            verify(child("bluetoothPairingCode").visible);
            verify(prompt().message.indexOf("herrie-desktop") >= 0, prompt().message);
            compare(child("bluetoothPairingPair").text, "Pair");
            waitArmed();
            mouseClick(child("bluetoothPairingPair"));
            compare(r.accepts, 1);
            compare(r.rejects, 0);
            verify(!prompt().opened);
            compare(page.area.kind, "");
        }

        function test_pairWaitsUntilItCanBeRead() {
            var r = request();
            agent().requestConfirmationFromUser(page.desktop, "042201", r);
            verify(!child("bluetoothPairingPair").enabled);
            prompt()._pair();
            compare(r.accepts, 0, "paired before the code could be read");
            waitArmed();
            // A new question starts the wait again.
            var r2 = request();
            agent().requestConfirmationFromUser(page.desktop, "111111", r2);
            prompt()._pair();
            compare(r2.accepts, 0);
        }

        function test_cancelRefuses() {
            var r = request();
            agent().requestAuthorizationFromUser(page.desktop, r);
            compare(child("bluetoothPairingPair").text, "Allow");
            verify(!child("bluetoothPairingCode").visible);
            mouseClick(child("bluetoothPairingCancel"));
            compare(r.rejects, 1);
            compare(r.accepts, 0);
            verify(!prompt().opened);
        }

        function test_aPinIsTypedAndSupplied() {
            var r = request();
            agent().requestPinCodeFromUser(page.desktop, r);
            compare(page.area.kind, "pinCode");
            verify(child("bluetoothPairingField").visible);
            waitArmed();
            verify(!child("bluetoothPairingPair").enabled, "Pair with no PIN");
            child("bluetoothPairingField").textInput.forceActiveFocus();
            keyClick(Qt.Key_0); keyClick(Qt.Key_0); keyClick(Qt.Key_0); keyClick(Qt.Key_0);
            compare(child("bluetoothPairingField").text, "0000");
            mouseClick(child("bluetoothPairingPair"));
            compare(r.accepted, "0000");
        }

        function test_aPasskeyTakesDigitsOnly() {
            var r = request();
            agent().requestPasskeyFromUser(page.desktop, r);
            child("bluetoothPairingField").textInput.forceActiveFocus();
            keyClick(Qt.Key_1); keyClick(Qt.Key_A); keyClick(Qt.Key_2);
            for (var i = 0; i < 6; i++)
                keyClick(Qt.Key_9);
            compare(child("bluetoothPairingField").text, "129999");
            waitArmed();
            keyClick(Qt.Key_Return);
            compare(r.accepted, "129999");
        }

        function test_aCodeToTypeElsewhereHasNoPair() {
            agent().displayPasskeyToUser(page.desktop, "000007", "");
            compare(page.area.kind, "displayPasskey");
            compare(child("bluetoothPairingCode").text, "000007");
            verify(!child("bluetoothPairingPair").visible);
            compare(child("bluetoothPairingCancel").text, "Close");
            verify(prompt().message.indexOf("herrie-desktop") >= 0);
            // The device says when it is done.
            agent().cancel();
            verify(!prompt().opened);
        }

        function test_theQuestionGoesWhenThePairingEnds() {
            var r = request();
            agent().requestConfirmationFromUser(page.desktop, "042201", r);
            agent().cancel();
            verify(!prompt().opened);
            compare(r.accepts + r.rejects, 0, "answered a pairing that had ended");
        }

        // ---- Saying it did not work.

        function test_aFailedPairingIsSaid() {
            var r = request();
            agent().requestPinCodeFromUser(page.desktop, r);
            child("bluetoothPairingField").textInput.forceActiveFocus();
            keyClick(Qt.Key_1);
            waitArmed();
            mouseClick(child("bluetoothPairingPair"));
            agent().pairingFailed(page.desktop, "The device disconnected before it was paired");
            verify(prompt().opened);
            compare(page.area.kind, "failed");
            compare(prompt().title, "Pairing failed");
            verify(prompt().message.indexOf("herrie-desktop") >= 0, prompt().message);
            verify(!child("bluetoothPairingPair").visible);
            // The end of the pairing that comes after does not take it away.
            agent().cancel();
            verify(prompt().opened);
            compare(child("bluetoothPairingCancel").text, "OK");
            mouseClick(child("bluetoothPairingCancel"));
            verify(!prompt().opened);
            compare(r.accepts, 1);
            compare(r.rejects, 0, "OK on the note refused the pairing");
        }

        function test_aNamelessDeviceIsCalledByItsAddress() {
            agent().requestAuthorizationFromUser({"name": "", "address": "BC:38:98:A8:38:64"}, request());
            verify(prompt().message.indexOf("BC:38:98:A8:38:64") >= 0, prompt().message);
        }
    }
}
