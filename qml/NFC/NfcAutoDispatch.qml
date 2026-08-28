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

import QtQuick 2.5
import LuneOS.Service 1.0

// Tap-and-go: when a tag with a dispatchable NDEF record comes into range,
// act on it immediately (open a link, call a number, ...) instead of only
// showing it in Settings. Runs system-wide, alongside NfcGlow, since a tap
// should work no matter what app is in the foreground.
Item {
    id: nfcAutoDispatch

    property bool tagWasPresent: false

    LunaService {
        id: nfcStatusQuery

        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            subscribe("luna://com.webos.service.nfc/getTagInfo",
                      JSON.stringify({"subscribe": true}),
                      nfcAutoDispatch.onTagInfoChanged, nfcAutoDispatch.onTagInfoError);
        }
    }

    LunaService {
        id: appLauncher
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: notificationService
        name: "com.webos.surfacemanager-cardshell"
    }

    function onTagInfoChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue)
            return;

        var present = !!response.present;
        var tag = response.tag !== undefined ? response.tag : null;

        // Fire once per tap, the moment records actually show up - not on
        // every incremental update (MIFARE Classic publishes progress as
        // each sector is read, all under the same present:true tap)
        if (present && !nfcAutoDispatch.tagWasPresent &&
            tag && tag.records && tag.records.length > 0) {
            nfcAutoDispatch.dispatch(tag.records[0]);
        }

        nfcAutoDispatch.tagWasPresent = present;
    }

    function onTagInfoError(message) {
        // com.webos.service.nfc isn't installed on every device - not an error
    }

    function dispatch(record) {
        if (record.kind === "uri" && record.uri)
            nfcAutoDispatch.dispatchUri(record.uri);
        // vCard/Wi-Fi/Bluetooth records are readable (see NfcPage.qml) but
        // not auto-dispatched yet - each needs its own target flow (add
        // contact, join network, pair device) rather than a generic launch.
    }

    function dispatchUri(uri) {
        var appId, label;

        if (uri.indexOf("tel:") === 0) {
            appId = "org.webosports.app.phone";
            label = "Calling " + uri.substring(4);
        } else if (uri.indexOf("mailto:") === 0) {
            appId = "com.palm.app.email";
            label = "Composing email to " + uri.substring(7);
        } else if (uri.indexOf("geo:") === 0) {
            appId = "org.webosports.app.atlas";
            label = "Opening location";
        } else if (uri.indexOf("http://") === 0 || uri.indexOf("https://") === 0) {
            appId = "com.webos.app.enactbrowser";
            label = "Opening " + uri;
        } else {
            return;
        }

        appLauncher.call("luna://com.webos.service.applicationManager/launch",
                          JSON.stringify({"id": appId, "params": {"target": uri}}),
                          function () {}, function () {});

        nfcAutoDispatch.showToast(label);
    }

    function showToast(message) {
        notificationService.call("luna://com.webos.notification/createToast",
                                  JSON.stringify({"sourceId": "com.webos.surfacemanager-cardshell",
                                                  "message": message}),
                                  function () {}, function () {});
    }
}
