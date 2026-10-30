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
import LuneOS.Components 1.0
import LuneOS.Service 1.0
import LuneOS.System 1.0

/*
 * "Allow USB debugging?" for a computer adbd does not know yet.
 *
 * adbd asks org.webosports.service.devmode, which puts the question to the
 * shell on adbAuthRequests: {"request": {"fingerprint", "timeoutMs"}}, or
 * {"request": null} once it is no longer open (answered, timed out, the
 * screen locked, adbd went). The user's answer goes back with
 * respondAdbAuth; the prompt saying nothing in time is a Deny, and the
 * service refuses at its own deadline as well.
 *
 * Only the shell may do either: the service checks the caller is
 * com.webos.surfacemanager* running /usr/bin/surface-manager, so the
 * calls go out under the shell's own name.
 *
 * Subscribed to straight away, which starts the service if USB debugging
 * left it stopped, and again whenever the service (re)appears on the bus.
 */
Item {
    id: area

    readonly property string busName: "com.webos.surfacemanager-cardshell"
    readonly property string devmode: "luna://org.webosports.service.devmode"

    //! The question shown, "" when none.
    readonly property string fingerprint: prompt.fingerprint

    property var _subscription: null

    // Dialog dims all of it, and takes the presses on it, while asking.
    anchors.fill: parent

    function subscribe() {
        unsubscribe();
        _subscription = lunaService.subscribe(devmode + "/adbAuthRequests",
                                              JSON.stringify({ "subscribe": true }),
                                              handleRequests, handleError);
    }

    function unsubscribe() {
        if (_subscription && typeof _subscription.cancel === "function")
            _subscription.cancel();
        _subscription = null;
    }

    function handleRequests(message) {
        var reply;
        try {
            reply = JSON.parse(message.payload);
        } catch (e) {
            return;
        }
        if (!reply || reply.returnValue === false || !reply.hasOwnProperty("request"))
            return;
        var request = reply.request;
        if (request && typeof request.fingerprint === "string" && request.fingerprint !== "")
            prompt.ask(request.fingerprint, request.timeoutMs);
        else
            prompt.withdraw();
    }

    function handleError(message) {
        console.warn("UsbDebuggingPromptArea: adbAuthRequests: " + message.payload);
    }

    function respond(fingerprint, allow, always) {
        lunaService.call(devmode + "/respondAdbAuth",
                         JSON.stringify({ "fingerprint": fingerprint, "allow": allow, "always": always }),
                         function (message) {},
                         function (message) {
                             console.warn("UsbDebuggingPromptArea: respondAdbAuth: " + message.payload);
                         });
    }

    LunaService {
        id: lunaService
        name: area.busName
        onInitialized: area.subscribe()
    }

    ServiceStatus {
        id: devmodeStatus
        serviceName: "org.webosports.service.devmode"
        clientName: area.busName
        onAvailableChanged: {
            if (available) {
                area.subscribe();
            } else {
                // A service that went knows none of its questions any more.
                prompt.withdraw();
            }
        }
    }

    UsbDebuggingPrompt {
        id: prompt
        onAnswered: (fingerprint, allow, always) => area.respond(fingerprint, allow, always)
    }
}
