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
 * The shell takes the files a Bluetooth device sends: it holds bluetooth2's
 * opp/awaitTransferRequest while Bluetooth is up (and takes it back from
 * another client), asks the user, answers with the request's id, declines
 * what nobody answers, follows an accepted file on opp/monitorTransfer, and
 * says with a toast when it is in or did not come; tapping the first opens
 * the file, in Explorer when no app takes it.
 * The bus is a stand-in that records calls and subscriptions and lets the
 * test answer them as bluetooth2 does; LuneOS.Bluetooth is luneos-components'
 * stand-in, for whether Bluetooth is up.
 */
Item {
    id: page
    width: 480
    height: 800

    property Item area: null

    readonly property var push: ({"requestId": "001", "adapterAddress": "d8:3e:ef:00:d3:d9",
                                  "address": "bc:38:98:a8:38:64", "name": "herrie-desktop",
                                  "fileName": "r1-opp-test.png", "fileSize": 9416})

    Component {
        id: busComponent
        QtObject {
            property var subscriptions: []
            property var calls: []
            function subscribe(uri, args, ok, err) {
                var s = {"uri": uri, "args": JSON.parse(args), "ok": ok, "err": err, "cancelled": false};
                s.cancel = function () { s.cancelled = true; };
                subscriptions = subscriptions.concat([s]);
                return s;
            }
            function call(uri, args, ok, err) {
                var c = {"uri": uri, "args": JSON.parse(args), "ok": ok, "err": err};
                calls = calls.concat([c]);
                return {"cancel": function () {}};
            }
            function open(method) {
                return subscriptions.filter(function (s) { return s.uri.endsWith(method) && !s.cancelled; });
            }
            function send(method, reply) {
                var subs = open(method);
                subs[subs.length - 1].ok({"payload": JSON.stringify(reply)});
            }
            function made(method) {
                return calls.filter(function (c) { return c.uri.endsWith(method); });
            }
        }
    }

    Component {
        id: areaComponent
        BluetoothTransferPromptArea {}
    }

    TestCase {
        name: "BluetoothTransferPrompt"
        when: windowShown

        property QtObject bus: null

        function init() {
            BluetoothManager.btManager.bluetoothOperational = true;
            bus = createTemporaryObject(busComponent, page);
            page.area = createTemporaryObject(areaComponent, page, {"bus": bus, "retryIntervalMs": 50});
            verify(page.area !== null);
            prompt().armDelayMs = 100;
            bus.send("awaitTransferRequest", {"returnValue": true, "subscribed": true, "adapterAddress": push.adapterAddress});
        }

        function prompt() { return findChild(page.area, "bluetoothTransferPrompt"); }
        function child(name) {
            var c = findChild(page.area, name);
            verify(c !== null, name);
            return c;
        }
        function toasts() {
            return bus.made("createToast").map(function (c) { return c.args.title + "|" + c.args.message; });
        }
        function ask() {
            bus.send("awaitTransferRequest", {"request": page.push});
            verify(prompt().opened);
        }
        // The accepted push comes in whole: the shell then asks which app
        // takes it.
        function receiveIt() {
            acceptIt();
            bus.send("monitorTransfer", {"transfers": [{"requestId": "001", "transferred": 9416, "fileSize": 9416}]});
            var asks = bus.made("getHandlerForUrl");
            compare(asks.length, 1);
            return asks[0];
        }
        function lastToast() {
            var t = bus.made("createToast");
            verify(t.length > 0, "no toast");
            return t[t.length - 1].args;
        }
        function acceptIt() {
            ask();
            tryVerify(function () { return prompt().armed; }, 1000);
            mouseClick(child("bluetoothTransferAccept"));
        }

        // ---- Holding the subscriptions.

        function test_subscribesWhileBluetoothIsUp() {
            compare(bus.open("awaitTransferRequest").length, 1);
            compare(bus.open("awaitTransferRequest")[0].args.subscribe, true);
            compare(bus.open("monitorTransfer").length, 1);
            verify(page.area.waiting);
            BluetoothManager.btManager.bluetoothOperational = false;
            compare(bus.open("awaitTransferRequest").length, 0, "kept with Bluetooth off");
            compare(bus.open("monitorTransfer").length, 0);
            verify(!page.area.waiting);
            BluetoothManager.btManager.bluetoothOperational = true;
            compare(bus.open("awaitTransferRequest").length, 1);
            compare(bus.subscriptions.length, 4);
        }

        function test_notWithBluetoothOff() {
            BluetoothManager.btManager.bluetoothOperational = false;
            var b = createTemporaryObject(busComponent, page);
            createTemporaryObject(areaComponent, page, {"bus": b, "retryIntervalMs": 50});
            wait(150);
            compare(b.subscriptions.length, 0);
        }

        // Another client had it: bluetooth2 allows one.
        function test_takesItBackFromAnotherClient() {
            bus.send("awaitTransferRequest", {"returnValue": false, "errorCode": 104, "errorText": "Only one subscription allowed"});
            verify(!page.area.waiting);
            tryVerify(function () { return bus.open("awaitTransferRequest").length === 1; }, 1000);
            compare(bus.subscriptions.filter(function (s) { return s.uri.endsWith("awaitTransferRequest"); }).length, 2);
        }

        // ---- The question.

        function test_aFileIsAsked() {
            ask();
            compare(child("bluetoothTransferFile").text, "r1-opp-test.png");
            compare(child("bluetoothTransferSize").text, "9.2 KB");
            verify(prompt().message.indexOf("herrie-desktop") >= 0, prompt().message);
            verify(!child("bluetoothTransferAccept").enabled, "Accept before the file could be read");
        }

        function test_acceptedWithItsId() {
            acceptIt();
            var accepts = bus.made("acceptTransferRequest");
            compare(accepts.length, 1);
            compare(accepts[0].args.requestId, "001");
            compare(accepts[0].args.adapterAddress, push.adapterAddress);
            compare(bus.made("rejectTransferRequest").length, 0);
            verify(!prompt().opened);
            verify(page.area.receiving["001"] !== undefined);
        }

        function test_acceptWaitsUntilItCanBeRead() {
            ask();
            prompt()._answer(true);
            compare(bus.made("acceptTransferRequest").length, 0);
            verify(prompt().opened);
        }

        function test_declined() {
            ask();
            mouseClick(child("bluetoothTransferDecline"));
            compare(bus.made("rejectTransferRequest").length, 1);
            compare(bus.made("rejectTransferRequest")[0].args.requestId, "001");
            compare(bus.made("acceptTransferRequest").length, 0);
            compare(Object.keys(page.area.receiving).length, 0);
            compare(toasts().length, 0);
        }

        // Before BlueZ's agent stops waiting.
        function test_unansweredIsDeclined() {
            prompt().timeoutMs = 150;
            ask();
            tryVerify(function () { return bus.made("rejectTransferRequest").length === 1; }, 1000);
            verify(!prompt().opened);
        }

        // ---- Following it in.

        function test_aFileThatCameInIsSaid() {
            acceptIt();
            bus.send("monitorTransfer", {"returnValue": true, "subscribed": true,
                                          "transfers": [{"requestId": "001", "transferred": 4096, "fileSize": 9416}]});
            compare(toasts().length, 0, "said before it was in");
            bus.send("monitorTransfer", {"returnValue": true, "subscribed": true,
                                          "transfers": [{"requestId": "001", "transferred": 9416, "fileSize": 9416}]});
            compare(bus.made("getHandlerForUrl").length, 1);
            bus.made("getHandlerForUrl")[0].ok({"payload": JSON.stringify({"returnValue": true, "appId": "org.webosports.app.photos"})});
            compare(toasts().length, 1);
            compare(lastToast().title, "Received r1-opp-test.png");
            compare(lastToast().message, "Tap to open it \u00b7 from herrie-desktop");
            compare(Object.keys(page.area.receiving).length, 0);
            compare(bus.made("createToast")[0].args.sourceId, "com.webos.surfacemanager.cardshell");
        }

        // ---- Tapping it.

        function test_aTapOpensTheFileInItsApp() {
            var ask = receiveIt();
            compare(ask.args.url, "file:///media/internal/r1-opp-test.png");
            compare(toasts().length, 0, "said before the app was known");
            ask.ok({"payload": JSON.stringify({"returnValue": true, "appId": "org.webosports.app.photos",
                                               "mimeType": "image/png"})});
            var t = lastToast();
            compare(t.onclick.appId, "org.webosports.app.photos");
            compare(t.onclick.params.target, "file:///media/internal/r1-opp-test.png");
            verify(t.message.indexOf("Tap to open it") === 0, t.message);
        }

        // "No handler found for url": Explorer shows where it is.
        function test_aFileNoAppTakesIsShownInExplorer() {
            var ask = receiveIt();
            ask.ok({"payload": JSON.stringify({"returnValue": false, "errorText": "No handler found for url"})});
            var t = lastToast();
            compare(t.onclick.appId, "com.palm.stark.files");
            compare(t.onclick.params.target, "file:///media/internal/r1-opp-test.png");
            verify(t.message.indexOf("Tap to see it in Explorer") === 0, t.message);
            compare(toasts().length, 1);
        }

        function test_anUnansweredLookupStillSaysIt() {
            var ask = receiveIt();
            ask.err({"payload": JSON.stringify({"returnValue": false, "errorCode": -1})});
            compare(toasts().length, 1);
            compare(lastToast().onclick.appId, "com.palm.stark.files");
        }

        // Nothing to open.
        function test_aLostFileHasNothingToTap() {
            acceptIt();
            BluetoothManager.btManager.bluetoothOperational = false;
            compare(toasts().length, 1);
            compare(lastToast().onclick, undefined);
            compare(bus.made("getHandlerForUrl").length, 0);
        }

        // Someone else's transfer is not ours to report.
        function test_otherTransfersAreLeftAlone() {
            acceptIt();
            bus.send("monitorTransfer", {"transfers": [{"requestId": "007", "transferred": 9416, "fileSize": 9416}]});
            compare(toasts().length, 0);
            verify(page.area.receiving["001"] !== undefined);
        }

        // bluetooth2 says nothing more of a transfer that broke off.
        function test_aFileThatStallsIsSaidLost() {
            page.area.stalledMs = 150;
            acceptIt();
            bus.send("monitorTransfer", {"transfers": [{"requestId": "001", "transferred": 4096, "fileSize": 9416}]});
            tryVerify(function () { return toasts().length === 1; }, 1000);
            compare(lastToast().title, "Not received: r1-opp-test.png");
            compare(lastToast().message, "The transfer did not complete \u00b7 from herrie-desktop");
            compare(Object.keys(page.area.receiving).length, 0);
        }

        function test_progressKeepsItAlive() {
            page.area.stalledMs = 200;
            acceptIt();
            for (var i = 1; i <= 4; i++) {
                wait(120);
                bus.send("monitorTransfer", {"transfers": [{"requestId": "001", "transferred": i * 1000, "fileSize": 9416}]});
            }
            compare(toasts().length, 0, "lost while it was coming in");
        }

        function test_aRefusedAcceptIsSaidLost() {
            acceptIt();
            var a = bus.made("acceptTransferRequest")[0];
            a.err({"payload": JSON.stringify({"returnValue": false, "errorCode": 165})});
            compare(toasts().length, 1);
            compare(lastToast().title, "Not received: r1-opp-test.png");
            compare(Object.keys(page.area.receiving).length, 0);
        }

        function test_bluetoothOffLosesWhatIsComingIn() {
            acceptIt();
            BluetoothManager.btManager.bluetoothOperational = false;
            compare(toasts().length, 1);
            compare(lastToast().title, "Not received: r1-opp-test.png");
        }

        function test_sizes_data() {
            return [
                {tag: "0", bytes: 0, text: "0 bytes"},
                {tag: "1023", bytes: 1023, text: "1023 bytes"},
                {tag: "1.5 KB", bytes: 1536, text: "1.5 KB"},
                {tag: "5 MB", bytes: 5 * 1024 * 1024, text: "5.0 MB"},
                {tag: "20 MB", bytes: 20 * 1024 * 1024, text: "20 MB"},
                {tag: "no size", bytes: undefined, text: ""},
            ];
        }
        function test_sizes(data) {
            compare(prompt().sizeText(data.bytes), data.text);
        }
    }
}
