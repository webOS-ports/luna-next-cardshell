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
import WebOSCoreCompositor 1.0

/*!
 * \brief Gives a phone's hardware call keys something to do.
 *
 * A device with a physical toolbelt - the BlackBerry-style answer, menu, back and
 * hangup row - delivers those as ordinary Qt keys once they are in the keymap,
 * and then nothing happens to them, because the shell has never had anywhere to
 * act on them.
 *
 * Which key means what is deliberately not decided here beyond a sane default,
 * because the keycode a toolbelt key emits is whatever its keyboard controller
 * was told to send and bears no fixed relation to the label on the key. The
 * Zinwa Q25 is the cautionary example: its *hangup* key emits KEY_HOMEPAGE and
 * its *menu* key emits KEY_APPSELECT, so a shell that hardcoded "HomePage means
 * home" would put that phone to sleep when the user wanted the launcher. So the
 * defaults below read each key at face value and a device may override them.
 */
Item {
    id: hardwareKeys

    /*!
     * \brief Show or hide the launcher.
     *
     * The launcher lives inside CardsArea and is not reachable from a connector,
     * so this is wired up where both are in scope.
     */
    signal launcherToggleRequested()

    /*!
     * \brief Go back.
     *
     * Wired to the gesture area, not to the focused application: in webOS "back"
     * is a tap in the gesture area rather than a key, so passing Qt::Key_Back
     * through to the app - which is what this did first - reached nothing that
     * acts on it.
     */
    signal backRequested()

    //! What WebOSKeyFilter::Result is worth. The enum is not registered for QML,
    //! so these have to be the numbers - and getting them wrong decides the fate
    //! of every key in the system, not just ours.
    readonly property int resultAccepted: 1     //!< ours; goes no further
    readonly property int resultNextPolicy: 2   //!< not ours; carry on

    //! Where a device may override the defaults. Written by
    //! luneos-device-config from deviceinfo_key_actions, absent otherwise.
    property string overridePath: "/etc/luneos/hardware-keys.json"

    //! The actions this understands. "shell.back" is a deliberate no-op: see _act().
    readonly property var knownActions: [
        "call.answer", "call.hangup", "shell.launcher", "shell.back",
        "audio.mute", "display.sleep", "none"
    ]

    //! Qt key name -> keycode, for reading the override file. Only the keys a
    //! toolbelt actually produces; an unknown name is reported rather than
    //! silently ignored.
    readonly property var keyNames: ({
        "Key_Call": Qt.Key_Call,
        "Key_Hangup": Qt.Key_Hangup,
        "Key_HomePage": Qt.Key_HomePage,
        "Key_Menu": Qt.Key_Menu,
        "Key_Back": Qt.Key_Back,
        "Key_VolumeMute": Qt.Key_VolumeMute
    })

    property var actions: ({})

    //! Audio mute is a toggle and com.palm.audio has no "toggle", so the state is
    //! tracked here. It starts false rather than being read back: there is no
    //! getter in the audio API's mute group, and a wrong first press is cheaper
    //! than a subscription this module would otherwise not need.
    property bool _muted: false
    property bool _installed: false

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: hardwareKeys._install()
    }

    KeyFilter { id: hardwareKeyFilter }

    Component.onCompleted: hardwareKeys._loadActions()

    /*!
     * \brief The default mapping: each key read at face value.
     *
     * Key_Menu goes to the launcher because that is the useful reading of a menu
     * key on a phone, and Key_HomePage does too because that is what "home"
     * means here. A device whose keys say otherwise overrides them.
     */
    function _defaultActions() {
        var d = {};
        d[Qt.Key_Call] = "call.answer";
        d[Qt.Key_Hangup] = "call.hangup";
        d[Qt.Key_HomePage] = "shell.launcher";
        d[Qt.Key_Menu] = "shell.launcher";
        d[Qt.Key_Back] = "shell.back";
        d[Qt.Key_VolumeMute] = "audio.mute";
        return d;
    }

    function _loadActions() {
        var merged = hardwareKeys._defaultActions();
        var text = hardwareKeys._readFile(hardwareKeys.overridePath);

        if (text) {
            try {
                const override = JSON.parse(text);
                for (const name in override) {
                    const code = hardwareKeys.keyNames[name];
                    if (code === undefined) {
                        console.warn("HardwareKeys: unknown key name '" + name + "' in " + hardwareKeys.overridePath);
                        continue;
                    }
                    if (hardwareKeys.knownActions.indexOf(override[name]) < 0) {
                        console.warn("HardwareKeys: unknown action '" + override[name] + "' for " + name);
                        continue;
                    }
                    merged[code] = override[name];
                }
            } catch (e) {
                console.warn("HardwareKeys: cannot parse " + hardwareKeys.overridePath + ": " + e);
            }
        }

        hardwareKeys.actions = merged;
    }

    //! Synchronous on purpose: this has to be settled before the first key press,
    //! and the file is a few hundred bytes on local storage.
    function _readFile(path) {
        var xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", "file://" + path, false);
            xhr.send();
            // A missing local file gives status 0 rather than 404.
            if (xhr.status === 200 || xhr.status === 0)
                return xhr.responseText;
        } catch (e) {
            // No override on this device, which is the normal case.
        }
        return "";
    }

    function _install() {
        if (hardwareKeys._installed)
            return;

        if (!compositor) {
            console.warn("HardwareKeys: no compositor, hardware keys will do nothing");
            return;
        }

        // Reuse whichever filter is already installed - KeyboardActivity may have
        // put one there - so the two do not fight over compositor.keyFilter.
        if (!compositor.keyFilter)
            compositor.keyFilter = hardwareKeyFilter;

        compositor.keyFilter.addKeyFilter(hardwareKeys._onKey, "hardwareKeys");
        hardwareKeys._installed = true;
    }

    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        var action = hardwareKeys.actions[keycode];

        if (action === undefined || action === "none")
            return hardwareKeys.resultNextPolicy;

        // Act on the press. A release is the same event twice and an auto-repeat
        // would answer a call or toggle mute for as long as the key is held.
        if (pressed && !autoRepeat)
            hardwareKeys._act(action);

        // Consume press and release together. Letting the release through on its
        // own gives whatever has focus half an event.
        return hardwareKeys._consumes(action) ? hardwareKeys.resultAccepted
                                              : hardwareKeys.resultNextPolicy;
    }

    //! Every action we handle swallows its key: having acted on it, letting it
    //! through as well would give whatever has focus a second, duplicate go.
    function _consumes(action) {
        return true;
    }

    function _act(action) {
        switch (action) {
        case "call.answer":
            hardwareKeys._call("luna://com.palm.telephony/answer", "{}");
            break;

        case "call.hangup":
            // No call-state check, because hangup already is one: it fails when
            // there is nothing to hang up, and that is exactly when the End key
            // should sleep the phone instead. One call rather than a
            // subscription this module would otherwise not need.
            //
            // The verdict arrives in the *reply*, not the error handler. An LS2
            // call that reaches the service and is refused by it is a successful
            // bus message carrying "returnValue": false, so onError never runs -
            // which is why an earlier version of this, passing undefined for the
            // reply, hung up nothing and then failed to sleep either. onError is
            // still worth having for the case where the service is not there at
            // all, which on a device with no telephony is every press.
            service.call("luna://com.palm.telephony/hangup", "{}",
                         function (message) {
                             if (!hardwareKeys._succeeded(message))
                                 hardwareKeys._act("display.sleep");
                         },
                         function (error) {
                             hardwareKeys._act("display.sleep");
                         });
            break;

        case "shell.launcher":
            hardwareKeys.launcherToggleRequested();
            break;

        case "audio.mute":
            hardwareKeys._muted = !hardwareKeys._muted;
            hardwareKeys._call("luna://com.palm.audio/setMuted",
                               JSON.stringify({ muted: hardwareKeys._muted }));
            break;

        case "display.sleep":
            hardwareKeys._call("luna://com.palm.display/control/setState",
                               JSON.stringify({ state: "off" }));
            hardwareKeys._call("luna://com.palm.display/control/setLockStatus",
                               JSON.stringify({ status: "lock" }));
            break;

        case "shell.back":
            hardwareKeys.backRequested();
            break;
        }
    }

    function _call(uri, payload) {
        service.call(uri, payload,
                     function (message) {
                         // Same reasoning as call.hangup: a refusal comes back as
                         // a reply, so without this a denied call is silent.
                         if (!hardwareKeys._succeeded(message))
                             console.warn("HardwareKeys: " + uri + " refused: " + message.payload);
                     },
                     function (error) {
                         console.warn("HardwareKeys: " + uri + " failed: " + error);
                     });
    }

    //! True when a reply says the service did what was asked. A reply with no
    //! returnValue at all is taken as success: some webOS services answer a
    //! void call with an empty payload.
    function _succeeded(message) {
        if (!message || !message.payload)
            return true;

        try {
            const reply = JSON.parse(message.payload);
            return reply.returnValue === undefined || reply.returnValue === true;
        } catch (e) {
            return true;
        }
    }
}
