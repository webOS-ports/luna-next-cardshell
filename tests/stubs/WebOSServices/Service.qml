/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0

/*
 * WebOSServices.Service for the desktop: every call is accepted and answered
 * by nobody, except that a server-status registration reports the server up
 * straight away, so whatever waits for it carries on.
 */
QtObject {
    property string appId
    property string service
    property string method

    signal response(string method, string payload, int token)

    property int _lastToken: 0

    function callService(payload) {
        return ++_lastToken;
    }

    function call(service, method, payload) {
        return ++_lastToken;
    }

    function cancel(token) {
    }

    Component.onCompleted: {
        if (method === "signal/registerServerStatus")
            Qt.callLater(function () { response(method, '{"connected":true}', 0); });
    }
}
