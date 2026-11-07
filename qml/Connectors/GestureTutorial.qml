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

/*
 * The shell's two parts in teaching the gestures, as legacy webOS had them:
 *
 *  - The Gesture Tutorial (org.webosports.app.tutorial) once first use is
 *    over. Legacy webOS 2.x ran it as the last part of first use; here first
 *    use ends when bootmgr leaves its "firstuse" state, which kills the first
 *    use app, and the shell's gestures only work from "normal" on. So it is
 *    launched from here, on that change, with {"firstUse": true}. A device
 *    that boots straight into "normal" (first use done before) gets nothing.
 *    The app then keeps its own reminders, should it be skipped.
 *
 *  - "Dismissing Cards", webOS 3.0's note the first time a card went to Card
 *    View (CardWindowManager::firstCardAlert, remembered in
 *    /var/luna/preferences/used-first-card). cardMinimized() is told of
 *    each card going there; hintDelay later, when Card View is still what
 *    is on the screen (not blocked: opening the launcher from an app cards
 *    it too), showHint() asks for the note. Remembered in the system
 *    preference "cardDismissHintShown".
 *    Not shown once the tutorial has been gone through
 *    ("gestureTutorialDone"), which teaches the same, nor for the
 *    tutorial's own card, which is in Card View because the tutorial asked.
 *
 * Until the preferences have answered, nothing is shown: better to show the
 * note one card later than twice.
 *
 * Everything goes through bus.call()/bus.subscribe(), the shell's
 * LunaService on the device; the tests put a recorder in its place.
 */
Item {
    id: gestureTutorial

    //! The shell's boot state, "firstuse" or "normal", from bootmgr.
    property string shellState: ""
    //! Something of the shell's own is in front of Card View (the launcher,
    //! say): not the moment for the note.
    property bool blocked: false
    //! How long after first use the tutorial is launched: the launcher and
    //! the boot time apps come up then too.
    property int launchDelay: 2000
    //! How long a card has to stay in Card View before the note comes.
    property int hintDelay: 400

    readonly property string tutorialAppId: "org.webosports.app.tutorial"

    readonly property bool prefsKnown: _prefsKnown
    readonly property bool hintShown: _hintShown
    readonly property bool tutorialDone: _tutorialDone

    signal showHint()

    property var bus: LunaService {
        name: "com.webos.surfacemanager.cardshell"
    }

    property bool _prefsKnown: false
    property bool _hintShown: false
    property bool _tutorialDone: false
    property string _lastState: ""
    property string _pendingAppId: ""
    property var _subscription: null

    readonly property string _prefs: "luna://com.webos.service.systemservice"

    //! Whether the note would come now, for a card of appId.
    function wouldShow(appId) {
        return _prefsKnown && !_hintShown && !_tutorialDone && !blocked
                && shellState === "normal" && appId !== tutorialAppId;
    }

    function cardMinimized(appId) {
        if (!wouldShow(appId))
            return;
        _pendingAppId = appId;
        hintTimer.restart();
    }

    function _maybeShowHint() {
        if (!wouldShow(_pendingAppId))
            return;
        // Taken as shown at once: the next card must not bring it again
        // while the answer is on its way.
        _hintShown = true;
        bus.call(_prefs + "/setPreferences", JSON.stringify({ "cardDismissHintShown": true }),
                 function (message) {},
                 function (message) {
                     console.warn("GestureTutorial: cannot store cardDismissHintShown: " + message.payload);
                 });
        showHint();
    }

    function launchTutorial() {
        bus.call("luna://com.webos.service.applicationmanager/launch",
                 JSON.stringify({ "id": tutorialAppId, "params": { "firstUse": true } }),
                 function (message) {},
                 function (message) {
                     // Not installed, say: first use is over all the same.
                     console.warn("GestureTutorial: cannot launch " + tutorialAppId + ": " + message.payload);
                 });
    }

    function handlePrefs(message) {
        var reply;
        try {
            reply = JSON.parse(message.payload);
        } catch (e) {
            return;
        }
        if (!reply || reply.returnValue === false)
            return;
        // A key comes in the first answer, and then each time it changes.
        if (reply.hasOwnProperty("cardDismissHintShown"))
            _hintShown = _hintShown || reply.cardDismissHintShown === true;
        if (reply.hasOwnProperty("gestureTutorialDone"))
            _tutorialDone = reply.gestureTutorialDone === true;
        _prefsKnown = true;
    }

    function subscribe() {
        if (_subscription && typeof _subscription.cancel === "function")
            _subscription.cancel();
        _subscription = bus.subscribe(_prefs + "/getPreferences",
                                      JSON.stringify({ "keys": ["cardDismissHintShown", "gestureTutorialDone"],
                                                       "subscribe": true }),
                                      handlePrefs,
                                      function (message) {
                                          console.warn("GestureTutorial: cannot watch the preferences: " + message.payload);
                                      });
    }

    onShellStateChanged: {
        if (_lastState === "firstuse" && shellState === "normal")
            launchTimer.start();
        _lastState = shellState;
    }

    Timer {
        id: hintTimer
        interval: gestureTutorial.hintDelay
        onTriggered: gestureTutorial._maybeShowHint()
    }

    Timer {
        id: launchTimer
        interval: gestureTutorial.launchDelay
        onTriggered: gestureTutorial.launchTutorial()
    }

    Component.onCompleted: {
        _lastState = shellState;
        subscribe();
    }
}
