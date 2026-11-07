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
import LuneOS.System 1.0
import WebOSCoreCompositor 1.0

import "HeadsetButton.js" as HeadsetButton

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
 *
 * Back, HomePage and Menu are also the keycodes of an Android phone's capacitive
 * back/home/recents keys - tissot's touchscreen reports exactly those - which
 * LuneOS has never used and which stay unlit there. So the defaults for those
 * three only apply while navigationKeysEnabled, which the shell ties to a tweak
 * that by default follows whether a hardware keyboard is present. A device's
 * own override of one of them always applies: it was asked for.
 *
 * Media keys go to mediacontroller, whatever has focus: the play/pause button
 * of a wired headset reaches the compositor as Key_MediaTogglePlayPause, and
 * handed to the focused window it only worked with the music app in front.
 * mediacontroller passes them to the session that last started playing, as
 * it does a Bluetooth headset's. The headset button counts presses, as
 * webOS 2.x did: one is play/pause, two the next track, three the previous
 * one; a hold is left free. During a call they are left alone, as before,
 * so a press cannot start the music under the call.
 *
 * A key can also have a second action for a long press. The camera key of
 * the Xperia XA2 opens Camera when held; the assistant button of the FLX1s
 * does whatever its owner picks. A key with a hold action acts on release
 * when let go before holdMs, and runs the hold action once holdMs has passed
 * with the key still down; a key without one acts on the press, as before.
 *
 * Which keys a user may set up is the device's call: an entry of
 * /etc/luneos/hardware-keys.json with a "label" is one, shown in Settings >
 * Buttons under that label. What the user picks there arrives as
 * userActions, the shell's hardwareKeyActions tweak, and applies on top of
 * the device's own defaults - only for the keys the device offers, so a
 * choice saved on one phone cannot remap the volume keys of another.
 *
 * Keys are bound per device and never by a default here, because a keycode
 * says little about the hardware behind it: the FLX1s reports its camera
 * *privacy switch* as KEY_CAMERA, held down for as long as the camera is
 * blocked, and a default "hold the camera key to open Camera" would open the
 * camera at the very moment its owner switched it off.
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

    //! A media key went to mediacontroller as keyEvent.
    signal mediaKeySent(string keyEvent)

    //! What WebOSKeyFilter::Result is worth. The enum is not registered for QML,
    //! so these have to be the numbers - and getting them wrong decides the fate
    //! of every key in the system, not just ours.
    readonly property int resultAccepted: 1     //!< ours; goes no further
    readonly property int resultNextPolicy: 2   //!< not ours; carry on

    //! Where a device may override the defaults. Written by
    //! luneos-device-config from deviceinfo_key_actions, absent otherwise.
    property string overridePath: "/etc/luneos/hardware-keys.json"

    //! The user's choices, as Settings > Buttons writes them to the
    //! hardwareKeyActions tweak: JSON text such as
    //! {"Key_Launch2": {"press": "torch.toggle", "hold": "app.camera"}}.
    property string userActions: ""

    //! How long a key with a hold action has to stay down for it.
    property int holdMs: 600

    //! The actions this understands. "shell.back" is a deliberate no-op: see _act().
    //! "app.launch:<appId>" launches any application and is checked by isKnownAction().
    readonly property var knownActions: [
        "call.answer", "call.hangup", "shell.launcher", "shell.back",
        "audio.mute", "display.sleep", "media.headset", "media.play",
        "media.pause", "media.stop", "media.next", "media.previous",
        "app.camera", "torch.toggle", "none"
    ]

    //! The Camera application, for "app.camera".
    readonly property string cameraAppId: "org.webosports.app.camera"

    //! An application was asked for by a key. For tests: the launch itself
    //! goes through the application manager.
    signal appLaunchRequested(string appId)

    //! Qt key name -> keycode, for reading the override file. Only the keys a
    //! toolbelt actually produces; an unknown name is reported rather than
    //! silently ignored.
    readonly property var keyNames: ({
        "Key_Call": Qt.Key_Call,
        "Key_Hangup": Qt.Key_Hangup,
        "Key_HomePage": Qt.Key_HomePage,
        "Key_Menu": Qt.Key_Menu,
        "Key_Back": Qt.Key_Back,
        "Key_VolumeMute": Qt.Key_VolumeMute,
        "Key_MediaTogglePlayPause": Qt.Key_MediaTogglePlayPause,
        "Key_MediaPlay": Qt.Key_MediaPlay,
        "Key_MediaPause": Qt.Key_MediaPause,
        "Key_MediaStop": Qt.Key_MediaStop,
        "Key_MediaNext": Qt.Key_MediaNext,
        "Key_MediaPrevious": Qt.Key_MediaPrevious,
        // Camera and programmable keys, in the keymap since qt-features-webos
        // 0006: KEY_CAMERA and Sony's 766, KEY_CAMERA_FOCUS, KEY_MACRO (the
        // FLX1s assistant button) and KEY_PROG1.
        "Key_Camera": Qt.Key_Camera,
        "Key_CameraFocus": Qt.Key_CameraFocus,
        "Key_Launch0": Qt.Key_Launch0,
        "Key_Launch1": Qt.Key_Launch1,
        "Key_Launch2": Qt.Key_Launch2
    })

    //! What a key does when pressed, keycode -> action.
    readonly property var actions: _loaded.actions

    //! What a key does when held for holdMs, keycode -> action. Keys with no
    //! hold action are absent.
    readonly property var holdActions: _loaded.holdActions

    //! The keys a user may set up, for Settings: [{name, label, press, hold}]
    //! with the device's own defaults, before the user's choices.
    readonly property var configurableKeys: _loaded.configurable

    //! A call is up (audiod's inCall): the media keys are left to the focused
    //! window, as they were before there was anywhere else for them to go.
    property bool inCall: false

    //! Whether the default actions of Back, HomePage and Menu apply.
    property bool navigationKeysEnabled: true

    //! The three keys navigationKeysEnabled is about.
    readonly property var navigationKeys: [Qt.Key_Back, Qt.Key_HomePage, Qt.Key_Menu]

    //! Keycodes the device override names, which navigationKeysEnabled leaves alone.
    readonly property var _overridden: _loaded.overridden

    readonly property var _loaded: _loadActions(overridePath, userActions)

    //! The key being held towards its hold action, -1 for none, and whether
    //! that action has already run for this press.
    property int _holdKey: -1
    property bool _holdFired: false

    //! Audio mute is a toggle and com.palm.audio has no "toggle", so the state is
    //! tracked here. It starts false rather than being read back: there is no
    //! getter in the audio API's mute group, and a wrong first press is cheaper
    //! than a subscription this module would otherwise not need.
    property bool _muted: false
    property bool _installed: false

    //! The headset button's presses so far; see HeadsetButton.js.
    property var _headset: HeadsetButton.initial()

    LunaService {
        id: service
        name: "com.webos.surfacemanager.cardshell"

        onInitialized: hardwareKeys._install()
    }

    KeyFilter { id: hardwareKeyFilter }

    Timer {
        id: headsetTimer
        repeat: false
        onTriggered: hardwareKeys._headsetStep(HeadsetButton.timeout(hardwareKeys._headset, Date.now()))
    }

    Timer {
        id: holdTimer
        repeat: false
        interval: hardwareKeys.holdMs
        onTriggered: hardwareKeys._holdReached()
    }

    AppLauncher {
        id: appLauncher
        clientName: "com.webos.surfacemanager.cardshell"
    }

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
        d[Qt.Key_MediaTogglePlayPause] = "media.headset";
        d[Qt.Key_MediaPlay] = "media.play";
        d[Qt.Key_MediaPause] = "media.pause";
        d[Qt.Key_MediaStop] = "media.stop";
        d[Qt.Key_MediaNext] = "media.next";
        d[Qt.Key_MediaPrevious] = "media.previous";
        return d;
    }

    //! Whether action is one this understands, "app.launch:<appId>" included.
    function isKnownAction(action) {
        if (typeof action !== "string")
            return false;
        if (hardwareKeys.knownActions.indexOf(action) >= 0)
            return true;
        return /^app\.launch:[A-Za-z0-9][A-Za-z0-9._-]*$/.test(action);
    }

    /*!
     * \brief The actions in force: the defaults, the device's file, the user's choices.
     *
     * An entry of the device's file is either an action, which is the key's
     * press action as it always was, or an object:
     *
     *   "Key_Launch2": { "label": "Assistant button", "press": "none", "hold": "none" }
     *
     * where press and hold are both optional, and a label makes the key one the
     * user may set up. userActions then gives press and hold for those keys and
     * no others.
     */
    function _loadActions(path, user) {
        var merged = hardwareKeys._defaultActions();
        var hold = {};
        var overridden = {};
        var configurable = [];
        var offered = {};
        var text = hardwareKeys._readFile(path);

        // Takes one slot of one key, if its action is one we know.
        function take(name, code, slot, action, where) {
            if (!hardwareKeys.isKnownAction(action)) {
                console.warn("HardwareKeys: unknown action '" + action + "' for " + name + " in " + where);
                return;
            }
            if (slot === "hold") {
                if (action === "none")
                    delete hold[code];
                else
                    hold[code] = action;
            } else {
                merged[code] = action;
            }
            overridden[code] = true;
        }

        if (text) {
            try {
                const override = JSON.parse(text);
                for (const name in override) {
                    const code = hardwareKeys.keyNames[name];
                    if (code === undefined) {
                        console.warn("HardwareKeys: unknown key name '" + name + "' in " + path);
                        continue;
                    }
                    const entry = override[name];
                    if (typeof entry === "string") {
                        take(name, code, "press", entry, path);
                        continue;
                    }
                    if (!entry || typeof entry !== "object") {
                        console.warn("HardwareKeys: cannot read the entry for " + name + " in " + path);
                        continue;
                    }
                    if (entry.press !== undefined)
                        take(name, code, "press", entry.press, path);
                    if (entry.hold !== undefined)
                        take(name, code, "hold", entry.hold, path);
                    if (typeof entry.label === "string" && entry.label !== "") {
                        offered[code] = true;
                        configurable.push({
                            name: name,
                            label: entry.label,
                            press: merged[code] !== undefined ? merged[code] : "none",
                            hold: hold[code] !== undefined ? hold[code] : "none"
                        });
                    }
                }
            } catch (e) {
                console.warn("HardwareKeys: cannot parse " + path + ": " + e);
            }
        }

        if (user) {
            try {
                const chosen = JSON.parse(user);
                for (const name in chosen) {
                    const code = hardwareKeys.keyNames[name];
                    // Saved for a key this device does not offer: another
                    // phone's choice, or one the device has since withdrawn.
                    if (code === undefined || !offered[code])
                        continue;
                    const choice = chosen[name];
                    if (!choice || typeof choice !== "object")
                        continue;
                    if (choice.press !== undefined)
                        take(name, code, "press", choice.press, "the hardwareKeyActions tweak");
                    if (choice.hold !== undefined)
                        take(name, code, "hold", choice.hold, "the hardwareKeyActions tweak");
                }
            } catch (e) {
                console.warn("HardwareKeys: cannot parse the hardwareKeyActions tweak: " + e);
            }
        }

        return { actions: merged, holdActions: hold, overridden: overridden, configurable: configurable };
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

        // typeof, because outside the shell there is no compositor to be null:
        // the name is not defined at all, and testing it would throw.
        if (typeof compositor === "undefined" || !compositor) {
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

    //! The action a key has right now, "none" for a navigation key that is off.
    function actionFor(keycode) {
        var action = hardwareKeys.actions[keycode];

        if (!hardwareKeys.navigationKeysEnabled
                && !hardwareKeys._overridden[keycode]
                && hardwareKeys.navigationKeys.indexOf(keycode) >= 0)
            return "none";

        return action;
    }

    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        if (hardwareKeys.holdActions[keycode] !== undefined)
            return hardwareKeys._onHoldKey(keycode, pressed, autoRepeat);

        var action = hardwareKeys.actionFor(keycode);

        if (action === undefined || action === "none")
            return hardwareKeys.resultNextPolicy;

        if (action.indexOf("media.") === 0) {
            // During a call the media keys are the focused window's, but the
            // headset button is the call's: mediacontroller hands it to the
            // Phone app, which answers, hangs up or rejects with it.
            if (hardwareKeys.inCall && action !== "media.headset")
                return hardwareKeys.resultNextPolicy;
            if (!autoRepeat)
                hardwareKeys._media(action, pressed, Date.now());
            return hardwareKeys.resultAccepted;
        }

        // Act on the press. A release is the same event twice and an auto-repeat
        // would answer a call or toggle mute for as long as the key is held.
        if (pressed && !autoRepeat)
            hardwareKeys._act(action);

        // Consume press and release together. Letting the release through on its
        // own gives whatever has focus half an event.
        return hardwareKeys._consumes(action) ? hardwareKeys.resultAccepted
                                              : hardwareKeys.resultNextPolicy;
    }

    /*!
     * \brief A key with a hold action.
     *
     * Nothing happens on the press itself: the timer decides. Held to the end
     * of it, the hold action runs, once; let go before, the press action runs
     * on the release. The key is consumed either way, press, repeats and
     * release, since what it means is not known until it is let go.
     */
    function _onHoldKey(keycode, pressed, autoRepeat) {
        if (pressed) {
            if (!autoRepeat && hardwareKeys._holdKey !== keycode) {
                hardwareKeys._holdKey = keycode;
                hardwareKeys._holdFired = false;
                holdTimer.restart();
            }
            return hardwareKeys.resultAccepted;
        }

        if (hardwareKeys._holdKey === keycode) {
            holdTimer.stop();
            const fired = hardwareKeys._holdFired;
            hardwareKeys._holdKey = -1;
            hardwareKeys._holdFired = false;
            if (!fired)
                hardwareKeys._run(hardwareKeys.actionFor(keycode));
        }
        return hardwareKeys.resultAccepted;
    }

    function _holdReached() {
        if (hardwareKeys._holdKey < 0 || hardwareKeys._holdFired)
            return;
        hardwareKeys._holdFired = true;
        hardwareKeys._run(hardwareKeys.holdActions[hardwareKeys._holdKey]);
    }

    //! Runs an action at once, media ones included: for a key with a hold
    //! action, which has no press and release of its own to count.
    function _run(action) {
        if (action === undefined || action === "none")
            return;
        if (action.indexOf("media.") === 0) {
            hardwareKeys._sendMediaKey(action === "media.headset" ? "playPause"
                                                                  : action.substring("media.".length));
            return;
        }
        hardwareKeys._act(action);
    }

    //! Launches an application for a key.
    function _launch(appId) {
        hardwareKeys.appLaunchRequested(appId);
        appLauncher.launch(appId, {}, undefined, function (error) {
            console.warn("HardwareKeys: cannot launch " + appId + ": " + error);
        });
    }

    //! A media key: the headset button is counted on press and release, the
    //! others go on the press.
    function _media(action, pressed, now) {
        if (action === "media.headset") {
            hardwareKeys._headsetStep(pressed ? HeadsetButton.press(hardwareKeys._headset, now)
                                              : HeadsetButton.release(hardwareKeys._headset, now));
            return;
        }
        if (pressed)
            hardwareKeys._sendMediaKey(action.substring("media.".length));
    }

    //! Acts on what a step of the headset button's count decided, and runs its timer.
    function _headsetStep(step) {
        headsetTimer.stop();
        if (step.timerMs > 0) {
            headsetTimer.interval = step.timerMs;
            headsetTimer.start();
        }
        // "hold" too: during a call it rejects (the Phone app, through
        // mediacontroller); with none, nothing takes it.
        if (step.action !== "")
            hardwareKeys._sendMediaKey(step.action);
    }

    function _sendMediaKey(keyEvent) {
        hardwareKeys.mediaKeySent(keyEvent);
        hardwareKeys._call("luna://com.webos.service.mediacontroller/injectMediaKeyEvent",
                           hardwareKeys._mediaKeyPayload(keyEvent));
    }

    //! The phone has one display; mediacontroller hands the key to the
    //! session on it that last started playing.
    function _mediaKeyPayload(keyEvent) {
        return JSON.stringify({ displayId: 0, keyEvent: keyEvent });
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
            hardwareKeys._sendBack();
            break;

        case "app.camera":
            hardwareKeys._launch(hardwareKeys.cameraAppId);
            break;

        case "torch.toggle":
            hardwareKeys._call("luna://org.webosports.service.torch/toggle", "{}");
            break;

        default:
            if (action.indexOf("app.launch:") === 0)
                hardwareKeys._launch(action.substring("app.launch:".length));
            break;
        }
    }

    /*!
     * \brief Go back, as the shell's own back gesture does.
     *
     * By sending Escape to whatever has focus. That is not a guess: CardView's
     * onSwipeLeftGesture - the back gesture - does exactly this, and webOS
     * applications take Escape as back.
     *
     * Two earlier attempts here were wrong and are worth recording. Letting
     * Qt::Key_Back through to the application did nothing, because nothing in the
     * stack acts on it. Calling the gesture area's tapGesture() *minimised* the
     * app instead, because a tap toggles Maximized/Carded; it is swipe-left, not
     * tap, that means back.
     *
     * No recursion risk: Escape is not in the action map, so the filter passes it
     * straight through on the way back in.
     */
    function _sendBack() {
        if (!compositor || !compositor.defaultSeat) {
            console.warn("HardwareKeys: no seat to send back to");
            return;
        }

        const seat = compositor.defaultSeat;
        seat.sendKeyEvent(Qt.Key_Escape, true);
        seat.sendKeyEvent(Qt.Key_Escape, false);
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
