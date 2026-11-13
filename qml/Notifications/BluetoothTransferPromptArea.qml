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
import LuneOS.Service 1.0
import LuneOS.Bluetooth 0.2

/*
 * Files a Bluetooth device sends (Object Push), asked and followed by the
 * shell whatever app is open.
 *
 * com.webos.service.bluetooth2 offers a push only to the one client
 * subscribed to opp/awaitTransferRequest, and drops it while there is none
 * (BlueZ's agent then refuses it). This subscribes while Bluetooth is up,
 * again when it comes back, and every retryIntervalMs while another client
 * holds it (bluetooth2 refuses a second one).
 *
 * Each request ({"requestId", "name", "address", "fileName", "fileSize"})
 * goes to BluetoothTransferPrompt; the answer goes back with
 * opp/acceptTransferRequest or opp/rejectTransferRequest. An accepted file
 * is followed on opp/monitorTransfer ("transfers": the open ones with
 * "transferred"), and a toast says when it is in, or that it did not come:
 * bluetooth2 says nothing more of a transfer that broke off, so one that
 * goes stalledMs without news is taken as lost. The notification of a
 * file that came in opens it when tapped.
 *
 * The files land in obexd's root, /media/internal (bluetooth-sil-bluez5's
 * OPP_RECEIVE_FOLDER). The calls go out under the shell's name, which holds
 * bluetooth2's bluetooth.management group.
 */
Item {
    id: area

    readonly property string busName: "com.webos.surfacemanager.cardshell"
    readonly property string opp: "luna://com.webos.service.bluetooth2/opp/"
    //! Where obexd puts what it receives (bluetooth-sil-bluez5's
    //! OPP_RECEIVE_FOLDER).
    readonly property string receiveFolder: "/media/internal"
    readonly property string explorerId: "com.palm.stark.files"

    //! The bus: a LunaService; a stand-in in the tests.
    property QtObject bus: lunaService
    property int retryIntervalMs: 10000
    property int stalledMs: 30000
    //! Whether bluetooth2 offers pushes here now.
    readonly property bool waiting: _waiting
    //! The request on screen, null when none.
    readonly property var request: prompt.request
    //! The accepted files not in yet, by requestId.
    readonly property var receiving: _receiving

    property var _await: null
    property var _monitor: null
    property bool _waiting: false
    property var _receiving: ({})

    // Dialog dims all of it, and takes the presses on it, while asking.
    anchors.fill: parent

    function _parse(message) {
        try {
            return JSON.parse(message.payload) || {};
        } catch (e) {
            return {};
        }
    }

    function start() {
        if (!BluetoothManager.bluetoothOperational)
            return;
        if (_await === null)
            _await = bus.subscribe(opp + "awaitTransferRequest", JSON.stringify({"subscribe": true}),
                                   _onRequest, _onAwaitError) || null;
        if (_monitor === null)
            _monitor = bus.subscribe(opp + "monitorTransfer", JSON.stringify({"subscribe": true}),
                                     _onTransfers, _onMonitorError) || null;
    }

    function _cancel(subscription) {
        if (subscription && typeof subscription.cancel === "function")
            subscription.cancel();
    }

    function stop() {
        _dropAwait();
        _cancel(_monitor);
        _monitor = null;
        prompt.withdraw();
        // A transfer still open has gone with Bluetooth.
        for (var id in _receiving)
            _failed(_receiving[id]);
        _receiving = {};
        stall.stop();
    }

    function _dropAwait() {
        _cancel(_await);
        _await = null;
        _waiting = false;
    }

    function _onRequest(message) {
        var reply = _parse(message);
        if (reply.returnValue === false) {
            // Another client has it (bluetooth2 allows one), or Bluetooth
            // went: tried again while Bluetooth is up.
            console.warn("BluetoothTransferPromptArea: awaitTransferRequest: " + message.payload);
            _dropAwait();
            return;
        }
        if (reply.subscribed === true)
            _waiting = true;
        if (reply.request && reply.request.requestId !== undefined)
            prompt.ask(reply.request);
    }

    function _onAwaitError(message) {
        console.warn("BluetoothTransferPromptArea: awaitTransferRequest: " + (message ? message.payload : ""));
        _dropAwait();
    }

    function _onMonitorError(message) {
        console.warn("BluetoothTransferPromptArea: monitorTransfer: " + (message ? message.payload : ""));
        _cancel(_monitor);
        _monitor = null;
    }

    function answer(request, accept) {
        var args = {"requestId": String(request.requestId)};
        if (request.adapterAddress)
            args.adapterAddress = request.adapterAddress;
        if (accept) {
            var receiving = _receiving;
            receiving[args.requestId] = {"requestId": args.requestId,
                                         "name": String(request.name || request.address || "A device"),
                                         "fileName": String(request.fileName || "a file"),
                                         "fileSize": Number(request.fileSize) || 0,
                                         "transferred": 0};
            _receiving = receiving;
            stall.restart();
        }
        bus.call(opp + (accept ? "acceptTransferRequest" : "rejectTransferRequest"), JSON.stringify(args),
                 function (message) {
                     if (accept && area._parse(message).returnValue === false)
                         area._lost(args.requestId);
                 }, function (message) {
                     console.warn("BluetoothTransferPromptArea: " + (accept ? "accept" : "reject")
                                  + "TransferRequest: " + (message ? message.payload : ""));
                     if (accept)
                         area._lost(args.requestId);
                 });
    }

    function _onTransfers(message) {
        var reply = _parse(message);
        if (!Array.isArray(reply.transfers))
            return;
        var receiving = _receiving;
        var news = false;
        for (var i = 0; i < reply.transfers.length; i++) {
            var t = reply.transfers[i];
            var mine = t && t.requestId !== undefined ? receiving[String(t.requestId)] : undefined;
            if (!mine)
                continue;
            news = true;
            mine.transferred = Number(t.transferred) || 0;
            if (mine.fileSize > 0 && mine.transferred >= mine.fileSize) {
                delete receiving[mine.requestId];
                _received(mine);
            }
        }
        _receiving = receiving;
        if (news)
            stall.restart();
        if (Object.keys(_receiving).length === 0)
            stall.stop();
    }

    function _lost(requestId) {
        var receiving = _receiving;
        var file = receiving[requestId];
        if (!file)
            return;
        delete receiving[requestId];
        _receiving = receiving;
        _failed(file);
    }

    // A notification with a title, which stays in the notification list:
    // the title says which file, the line under it what a tap does and from
    // whom - in that order, as a row shows one line under its title and
    // cuts off what does not fit. A tap opens the file in the app that takes its type, as the app
    // manager says (Photos for an image); a file no app takes is shown in
    // Explorer, which opens its folder with the file first.
    function _received(file) {
        var url = "file://" + area.receiveFolder + "/" + file.fileName;
        var title = "Received " + file.fileName;
        var from = " \u00b7 from " + file.name;
        var inExplorer = function () {
            toast(title, "Tap to see it in Explorer" + from, {"appId": area.explorerId, "params": {"target": url}});
        };
        bus.call("luna://com.palm.applicationManager/getHandlerForUrl", JSON.stringify({"url": url}),
                 function (message) {
                     var reply = area._parse(message);
                     if (reply.appId)
                         toast(title, "Tap to open it" + from, {"appId": String(reply.appId), "params": {"target": url}});
                     else
                         inExplorer();
                 }, inExplorer);
    }

    function _failed(file) {
        toast("Not received: " + file.fileName, "The transfer did not complete \u00b7 from " + file.name);
    }

    //! onclick: {"appId", "params"}, launched when it is tapped.
    function toast(title, message, onclick) {
        var args = {"sourceId": area.busName, "title": title, "message": message};
        if (onclick)
            args.onclick = onclick;
        bus.call("luna://com.webos.notification/createToast", JSON.stringify(args),
                 function () {}, function () {});
    }

    LunaService {
        id: lunaService
        name: area.busName
        onInitialized: area.start()
    }

    Connections {
        target: BluetoothManager
        function onBluetoothOperationalChanged() {
            if (BluetoothManager.bluetoothOperational)
                area.start();
            else
                area.stop();
        }
    }

    Component.onCompleted: start()

    Timer {
        interval: area.retryIntervalMs
        repeat: true
        running: BluetoothManager.bluetoothOperational && (area._await === null || area._monitor === null)
        onTriggered: area.start()
    }

    // No news of the accepted files for stalledMs: they broke off.
    Timer {
        id: stall
        interval: area.stalledMs
        onTriggered: {
            var ids = Object.keys(area._receiving);
            for (var i = 0; i < ids.length; i++)
                area._lost(ids[i]);
        }
    }

    BluetoothTransferPrompt {
        id: prompt
        objectName: "bluetoothTransferPrompt"
        onAnswered: (request, accept) => area.answer(request, accept)
    }
}
