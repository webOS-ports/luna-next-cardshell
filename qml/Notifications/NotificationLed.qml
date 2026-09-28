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
import LunaNext.Common 0.1

/*
 * Blinks the notification LED while notifications are waiting and the screen is
 * off, in the colour configured for the application that posted the newest one.
 *
 * This is what legacy LunaSysMgr's CoreNaviManager did, rebuilt on what the
 * card shell already knows. The parts differ:
 *
 *  - There, applications registered an explicit LED request through
 *    PalmSystem and CoreNaviManager kept a queue of them, lighting the LED for
 *    the front of that queue. Nothing on LuneOS posts such a request any more,
 *    so the waiting toasts are the queue: whatever is still in the
 *    notification list is still waiting to be seen.
 *  - There, the LED was a single white one and only its brightness varied.
 *    nyx now takes a colour per effect, so each application can have its own.
 *
 * Everything below the QML is already in place: LunaNext.Common's Leds
 * singleton -> CoreNaviLeds -> nyx's LED controller, which drives either the
 * Android lights HAL or /sys/class/leds depending on the device. nyx scales
 * the colour by the effect's brightness, so both are always passed together.
 */
Item {
    id: notificationLed

    /*
     * NotificationService's toastModel. Rows are appended as toasts arrive, so
     * the last row is the newest, and removed when a toast is withdrawn or
     * dismissed - which is exactly the "still waiting" list this needs.
     */
    property var notificationModel: null

    /*
     * Brightness nyx scales the colour by, 0-100.
     *
     * One value, where CoreNaviManager picked between 15, 25, 50 and 100 from
     * the ambient light sensor and the time of day. The sensor part is not
     * worth reviving for an LED that only ever lights with the screen off, and
     * the time-of-day part never worked: it tested `tm_hour > 6 || tm_hour <
     * 22`, which is true at every hour, so the night-time values it computed
     * were dead code and every device shipped the indoor 50.
     */
    property int brightness: 50

    // Milliseconds lit and dark per blink. nyx's LED_PULSATE effect takes these
    // as its fade-in and fade-out, and both backends use them as a plain
    // on/off pattern that repeats until the LED is stopped.
    property int blinkOnDuration: 1000
    property int blinkOffDuration: 3000

    // Colour used for an application with nothing configured. Also what the
    // reserved "*" entry in the preference overrides; see resolveColor().
    property color defaultColor: "#ffffff"

    /*
     * Preferences, both owned elsewhere and only read here:
     *
     *  - BlinkNotifications is the on/off switch, and it is the same one webOS
     *    used: legacy Preferences.cpp read this key into m_ledThrobberEnabled,
     *    which is exactly the flag CoreNaviManager::startStandbyLeds() checked
     *    before lighting the LED. Screen & Lock has had a switch for it since
     *    that page was ported; until now it changed nothing.
     *
     *    Note it is not the LEDThrobberEnabled key, which sits next to it in
     *    /etc/palm/defaultPreferences.txt and looks like the obvious one.
     *    Nothing in legacy ever read that key, and nothing reads it now: it is
     *    left alone rather than honoured as a second gate, which would give the
     *    user two switches in two panels for one LED.
     *
     *  - notificationLedColors is new: an object of application id to colour
     *    string, written by the Notifications panel in Settings.
     *
     * Both start at the default the device ships so that a screen going off
     * before the first reply behaves as configured rather than staying dark.
     */
    property bool blinkNotifications: true
    property var appColors: ({})

    // Whether com.palm.display reports the panel as lit. Starts true so that
    // nothing blinks at a user who is looking at the screen while the display
    // manager has yet to answer.
    property bool displayOn: true

    /*
     * Application id whose colour is showing, or "" when nothing is waiting.
     *
     * Recomputed from the model rather than tracked incrementally: an
     * application can have several toasts outstanding, they are withdrawn in
     * any order, and parseModelData() also rewrites rows in place. Deriving
     * the answer from the model each time cannot drift out of step with it.
     */
    readonly property string activeAppId: _pendingAppIds.length > 0 ? _pendingAppIds[_pendingAppIds.length - 1] : ""

    readonly property bool ledShouldBlink: blinkNotifications && !displayOn &&
                                           activeAppId !== ""

    property var _pendingAppIds: []

    // What was last handed to nyx, so that an unchanged state is not re-sent.
    // A toast arriving while the screen is on changes activeAppId but must not
    // restart the effect, and each setColor()/ledPulsate() pair is a write to
    // the LED device.
    property string _appliedAppId: ""
    property color _appliedColor: "transparent"
    property bool _appliedBlink: false

    /*
     * Distinct source ids of the toasts still waiting, oldest first.
     *
     * "light" toasts are skipped for the same reason NotificationsMergedModel
     * does not give them a sticky entry: they are transient status messages
     * that leave nothing behind to go back to, so there is nothing for the LED
     * to point at.
     */
    function _recomputePending() {
        var ids = [];

        if (notificationModel) {
            for (var i = 0; i < notificationModel.count; i++) {
                var notif = notificationModel.get(i);
                if (!notif || !notif.sourceId)
                    continue;
                if (notif.type === "light")
                    continue;

                // Keep the newest position for an application that has several
                // waiting, so activeAppId follows its most recent toast.
                var existing = ids.indexOf(notif.sourceId);
                if (existing !== -1)
                    ids.splice(existing, 1);

                ids.push(notif.sourceId);
            }
        }

        _pendingAppIds = ids;
    }

    /*
     * Colour configured for an application, falling back to the reserved "*"
     * entry and then to defaultColor.
     *
     * "*" cannot collide with an application id - those are reverse-DNS names -
     * which is why the preference stays a flat map instead of growing a nested
     * object for the one global value.
     */
    function resolveColor(appId) {
        if (appColors) {
            if (appId !== "" && appColors.hasOwnProperty(appId))
                return appColors[appId];
            if (appColors.hasOwnProperty("*"))
                return appColors["*"];
        }

        return defaultColor;
    }

    function _apply() {
        if (!ledShouldBlink) {
            if (_appliedBlink) {
                Leds.stopAll();
                _appliedBlink = false;
                _appliedAppId = "";
                _appliedColor = "transparent";
            }
            return;
        }

        var color = resolveColor(activeAppId);

        if (_appliedBlink && _appliedAppId === activeAppId && Qt.colorEqual(_appliedColor, color))
            return;

        // Order matters: the colour is a property of the controller that the
        // next effect picks up, so it has to be set before the effect starts.
        Leds.setColor(color);
        Leds.ledPulsate(Leds.notificationLed, brightness,
                        0 /* startDelay */,
                        blinkOnDuration, blinkOffDuration,
                        0 /* fadeOutDelay */,
                        0 /* repeatDelay */,
                        1 /* repeat */);

        _appliedBlink = true;
        _appliedAppId = activeAppId;
        _appliedColor = color;
    }

    onLedShouldBlinkChanged: _apply()
    onActiveAppIdChanged: _apply()
    onAppColorsChanged: _apply()

    /*
     * count covers both directions: the model appends on arrival and removes on
     * withdrawal, and parseModelData()'s in-place set() cannot change which
     * applications are waiting. Using it avoids having to read a row that
     * rowsAboutToBeRemoved has not taken out yet.
     */
    onNotificationModelChanged: _recomputePending()

    Connections {
        target: notificationLed.notificationModel
        ignoreUnknownSignals: true
        function onCountChanged() { notificationLed._recomputePending(); }
    }

    // Leaving the LED lit after the shell goes away would strand it on, with
    // nothing left to turn it off.
    Component.onDestruction: Leds.stopAll()

    LunaService {
        id: ledService
        name: "com.webos.surfacemanager-cardshell"

        readonly property var keysToWatch: ["BlinkNotifications", "notificationLedColors"]

        onInitialized: {
            ledService.subscribe("luna://com.webos.service.systemservice/getPreferences",
                                 JSON.stringify({"keys": keysToWatch, "subscribe": true}),
                                 notificationLed.handlePreferences,
                                 function (error) {
                                     console.warn("NotificationLed: preference subscription failed: " + JSON.stringify(error));
                                 });

            ledService.subscribe("luna://com.palm.display/control/status",
                                 JSON.stringify({"subscribe": true}),
                                 notificationLed.handleDisplayStatus,
                                 function (error) {
                                     console.warn("NotificationLed: display status subscription failed: " + JSON.stringify(error));
                                 });
        }
    }

    function handlePreferences(message) {
        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("BlinkNotifications"))
            blinkNotifications = response.BlinkNotifications;

        /*
         * Written by Settings as an object, but a preference is whatever was
         * last stored: a hand-edited string, or a value left over from an
         * earlier shape, would otherwise throw from resolveColor() on every
         * notification. Anything that is not an object is treated as nothing
         * configured.
         */
        if (response.hasOwnProperty("notificationLedColors")) {
            var colors = response.notificationLedColors;

            if (typeof colors === "string") {
                try {
                    colors = JSON.parse(colors);
                } catch (e) {
                    console.warn("NotificationLed: notificationLedColors is not valid JSON: " + colors);
                    colors = null;
                }
            }

            appColors = (colors && typeof colors === "object") ? colors : ({});
        }
    }

    /*
     * The first reply carries "state" ("on", "dimmed", "off", ...); later
     * pushes carry only "event": displayOn, displayDimmed, displayOff, plus
     * blockedDisplay/unblockedDisplay and the like, which say nothing about the
     * panel. Handled the same way as in OrientationHelper, including treating
     * "dimmed" as lit: the user is still looking at the screen, and the LED
     * belongs to a screen that has gone dark.
     */
    function handleDisplayStatus(message) {
        var response = JSON.parse(message.payload);
        if (response.state !== undefined)
            displayOn = (response.state !== "off");
        else if (response.event === "displayOff")
            displayOn = false;
        else if (response.event === "displayOn" || response.event === "displayDimmed")
            displayOn = true;
    }
}
