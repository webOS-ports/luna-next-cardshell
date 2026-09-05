/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org>
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
import LunaNext.Common 0.1

Item {
    id: lockScreen

    visible: locked

    property Item windowManagerInstance;

    property bool isFirstUse: false
    property bool locked: false;

    property bool needKeyboard: pinPasswordLock.visible && deviceLockMode === "password"

    property string deviceLockMode: "none"

    // Fingerprint unlock, backed by com.webos.service.fingerprint
    // (webos-fingerprint-adapter -> droidian-fpd -> Android biometrics HAL).
    // While the lockscreen is shown and fingerprints are enrolled we keep an
    // identify request pending; a match unlocks the display just like a
    // correct passcode. After maxFingerprintAttempts failed reads we stop
    // listening until the next lock, forcing the PIN/password path.
    property bool fingerprintAvailable: false
    property int fingerprintCount: 0
    property int fingerprintFailedAttempts: 0
    readonly property int maxFingerprintAttempts: 5

    // Settings' Fingerprint Unlock switch, in case someone wants their
    // enrolled prints kept for something else (unlocking an app, say)
    // without the lock screen itself trying them. Defaults to on so devices
    // that already had prints enrolled before this preference existed keep
    // behaving the way they always did.
    property bool fingerprintUnlockEnabled: true

    readonly property bool fingerprintActive: locked && fingerprintAvailable &&
                                              fingerprintUnlockEnabled &&
                                              fingerprintCount > 0 &&
                                              fingerprintFailedAttempts < maxFingerprintAttempts
    property var _identifyCall: null

    onFingerprintActiveChanged: {
        if (fingerprintActive)
            startFingerprintIdentify();
        else
            stopFingerprintIdentify();
    }

    function startFingerprintIdentify() {
        if (_identifyCall)
            return;
        _identifyCall = service.subscribe("luna://com.webos.service.fingerprint/identify",
                                          "{\"subscribe\":true}",
                                          handleFingerprintIdentify, handleFingerprintError);
    }

    function stopFingerprintIdentify() {
        identifyRestartTimer.stop();
        if (_identifyCall) {
            _identifyCall.cancel();
            _identifyCall = null;
            // make sure the sensor isn't left armed
            service.call("luna://com.webos.service.fingerprint/abort", "{}", null, null);
        }
    }

    function _endIdentify() {
        // Never cancel the subscription synchronously from inside its own
        // result callback - defer to the next event loop turn.
        var call = _identifyCall;
        _identifyCall = null;
        if (call)
            Qt.callLater(function() { call.cancel(); });
    }

    function handleFingerprintIdentify(message) {
        var response = JSON.parse(message.payload);
        if (response.identified === true) {
            _endIdentify();
            fingerprintFailedAttempts = 0;
            // flash the padlock green, then unlock just after so the
            // feedback is actually visible
            padLock.fingerprintFeedback(true);
            unlockFeedbackTimer.restart();
        }
        else if (response.identified === false && response.finished === false) {
            // A rejected touch: fpd stays armed, so DON'T cancel/re-arm.
            // Flash red every time, but rate-limit the lockout counter so
            // several captures within one press don't burn attempts.
            padLock.fingerprintFeedback(false);
            if (!missCooldown.running) {
                fingerprintFailedAttempts++;
                missCooldown.restart();
                if (fingerprintFailedAttempts >= maxFingerprintAttempts)
                    padLock.showFingerprintLockout(deviceLockMode);
            }
        }
        else if (response.identified === false) {
            // Terminal end (cancel / 30s timeout, errorText "Aborted"): not a
            // failed read, just re-arm if we are still meant to be listening.
            _endIdentify();
            if (fingerprintActive)
                identifyRestartTimer.restart();
        }
    }

    function handleFingerprintError(message) {
        console.log("Fingerprint identify error: " + message.payload);
        _endIdentify();
        if (fingerprintActive)
            identifyRestartTimer.restart();
    }

    // Face unlock, backed by com.webos.service.faceunlock (luneos-faced ->
    // com.webos.service.camera2 -> libfart).
    //
    // Deliberately unlike fingerprint: the sensor there stays armed and the
    // subscription lives for as long as the lock screen does. A camera cannot
    // work that way - holding it open drains the battery, heats the device and
    // stops the camera app from using it. So each identify is one time-boxed
    // attempt (luneos-faced budgets 3s), and we make at most maxFaceAttempts of
    // them with a gap in between, then stop until the next lock.
    //
    // NOTE: this is a *third* independent attempt counter, next to
    // fingerprintFailedAttempts here and s_defaultMaxRetries in luna-sysmgr's
    // Security.cpp. None of the three knows about the others. That is the
    // defect luna-authmanager is meant to fix by owning one budget across every
    // factor; until it lands, face unlock should stay out of the default image.
    property bool faceAvailable: false
    property bool faceEnrolled: false
    property int faceFailedAttempts: 0
    readonly property int maxFaceAttempts: 5

    // Enrolling a face is itself the opt-in, so this defaults on - same as
    // fingerprint. Settings can still turn it off without dropping the template.
    property bool faceUnlockEnabled: true

    // Whether the panel is actually lit. Without this the whole attempt budget
    // gets spent in the dark: locking the device turns the screen off, faceActive
    // goes true immediately, and five identify attempts run at whatever the phone
    // happens to be lying on. By the time the user wakes it and looks, there is
    // nothing left. Face unlock only makes sense while the user can see the
    // screen, which is also when they are in front of the camera.
    property bool displayOn: true

    readonly property bool faceActive: locked && displayOn && faceAvailable &&
                                       faceUnlockEnabled && faceEnrolled &&
                                       faceFailedAttempts < maxFaceAttempts
    property var _faceIdentifyCall: null

    onFaceActiveChanged: {
        if (faceActive)
            startFaceIdentify();
        else
            stopFaceIdentify();
    }

    function startFaceIdentify() {
        if (_faceIdentifyCall)
            return;
        // Each attempt restarts the vendor camera HAL, so there is a couple of
        // seconds before anything can happen. Without a word on screen that
        // reads as face unlock simply not working, and the user reaches for the
        // PIN while an attempt is still in flight.
        padLock.showBiometricStatus("Looking for your face\u2026");
        _faceIdentifyCall = service.subscribe("luna://com.webos.service.faceunlock/identify",
                                              "{\"subscribe\":true}",
                                              handleFaceIdentify, handleFaceError);
    }

    function stopFaceIdentify() {
        faceRetryTimer.stop();
        padLock.clearBiometricStatus();
        if (_faceIdentifyCall) {
            _faceIdentifyCall.cancel();
            _faceIdentifyCall = null;
            // make sure the camera is released rather than left streaming
            service.call("luna://com.webos.service.faceunlock/abort", "{}", null, null);
        }
    }

    function _endFaceIdentify() {
        // Never cancel the subscription synchronously from inside its own
        // result callback - defer to the next event loop turn.
        var call = _faceIdentifyCall;
        _faceIdentifyCall = null;
        if (call)
            Qt.callLater(function() { call.cancel(); });
    }

    function handleFaceIdentify(message) {
        var response = JSON.parse(message.payload);

        // Frames are flowing but nothing has matched yet. Distinct from
        // "Looking for your face...", which covers bringing the camera up: this
        // says the user is in frame and being worked on, which is most of the
        // perceived wait while auto-exposure settles.
        if (response.scanning === true) {
            padLock.showBiometricStatus("Checking\u2026");
            return;
        }

        if (response.recognized === true) {
            _endFaceIdentify();
            faceFailedAttempts = 0;
            padLock.clearBiometricStatus();
            padLock.biometricFeedback(true);
            unlockFeedbackTimer.restart();
            return;
        }

        if (response.recognized === false) {
            _endFaceIdentify();

            // "noFace" means nobody was in front of the camera - the user is
            // not even trying yet, so it must not burn an attempt or the
            // budget is gone before they pick the phone up. Only a real
            // rejection counts.
            let reason = response.reason !== undefined ? response.reason : "";

            // Deliberately specific: "not recognized" and "no face" mean very
            // different things to someone standing there wondering whether to
            // keep looking at the phone or give up and type the PIN.
            padLock.showBiometricStatus(
                reason === "noFace"          ? "No face detected"
                : reason === "multipleFaces" ? "More than one face detected"
                : reason === "aborted"       ? ""
                                             : "Face not recognized");

            if (reason !== "noFace" && reason !== "aborted") {
                padLock.biometricFeedback(false);
                faceFailedAttempts++;
                if (faceFailedAttempts >= maxFaceAttempts) {
                    padLock.showBiometricLockout(deviceLockMode, "face");
                    return;
                }
            }

            if (faceActive)
                faceRetryTimer.restart();
            return;
        }

        // returnValue false, e.g. the camera app holds the device. Fail soft:
        // stay quiet and let the passcode path carry the unlock.
        if (response.returnValue === false) {
            _endFaceIdentify();
            // Usually the camera is busy elsewhere. Say so rather than leaving
            // "Looking for your face..." on screen until it times out.
            padLock.showBiometricStatus("Face unlock unavailable");
            console.log("Face unlock unavailable: " + message.payload);
        }
    }

    function handleFaceError(message) {
        console.log("Face identify error: " + message.payload);
        _endFaceIdentify();
        if (faceActive)
            faceRetryTimer.restart();
    }

    Timer {
        id: faceStatusRetry
        interval: 3000
        repeat: false
        onTriggered: service.subscribeFaceStatus()
    }

    // Gap between attempts. Long enough that the camera is not effectively
    // held open, short enough that looking at the phone feels responsive.
    Timer {
        id: faceRetryTimer
        interval: 2500
        repeat: false
        onTriggered: if (lockScreen.faceActive) lockScreen.startFaceIdentify();
    }

    Timer {
        id: fingerprintStatusRetry
        interval: 3000
        repeat: false
        onTriggered: service.subscribeFingerprintStatus()
    }

    Timer {
        id: missCooldown
        interval: 1200
        repeat: false
    }

    Timer {
        id: unlockFeedbackTimer
        interval: 300
        repeat: false
        onTriggered: lockScreen.unlockDisplay()
    }

    Timer {
        id: identifyRestartTimer
        interval: 500
        repeat: false
        onTriggered: if (lockScreen.fingerprintActive) lockScreen.startFingerprintIdentify();
    }

    onLockedChanged: {
        if(!locked) {
            if( _stateBeforeLock === "dockmode" ) windowManagerInstance.switchToDockMode();
            else if( _stateBeforeLock === "minimize" ) windowManagerInstance.switchToMaximize(null);
            else if( _stateBeforeLock === "fullscreen" ) windowManagerInstance.switchToFullscreen(null);
            else if( _stateBeforeLock === "cardview" ) windowManagerInstance.switchToCardView();
            else if( _stateBeforeLock === "launcherview" ) windowManagerInstance.switchToLauncherView();
        }
        else {
            fingerprintFailedAttempts = 0;
            faceFailedAttempts = 0;
            windowManagerInstance.switchToLockscreen();
        }
    }
    property string _stateBeforeLock: "cardview"
    Connections {
        target: windowManagerInstance
        function onSwitchToDockMode() {
            _stateBeforeLock = "dockmode";
        }
        function onSwitchToMaximize(window) {
            _stateBeforeLock = "minimize";
        }
        function onSwitchToFullscreen(window) {
            _stateBeforeLock = "fullscreen";
        }
        function onSwitchToCardView() {
            _stateBeforeLock = "cardview";
        }
        function onSwitchToLauncherView() {
            _stateBeforeLock = "launcherview";
        }
    }

    function lockDisplay() {
        service.call("luna://com.palm.display/control/setLockStatus", "{\"status\":\"lock\"}",
                     null, function(message) { console.warn("setLockStatus lock failed: " + message.payload); });
    }

    function unlockDisplay() {
        service.call("luna://com.palm.display/control/setLockStatus", "{\"status\":\"unlock\"}",
                     function(message) { console.warn("setLockStatus unlock reply: " + message.payload); },
                     function(message) { console.warn("setLockStatus unlock failed: " + message.payload); });
    }

    function padUnlock() {
        // if we don't have a lock mode set directly unlock the display
        if (deviceLockMode === "none")
            unlockDisplay()
        else if (deviceLockMode === "pin" || deviceLockMode === "password")
            lockScreen.state = "pin-password";
        else if (deviceLockMode === "pattern")
            lockScreen.state = "pattern";
        else {
            console.log("Invalid device lock mode '" + deviceLockMode + "'");
            lockDisplay();
        }
    }

    Clock
    {
        id: lockScreenClock
        // Fills the whole screen (see Clock.qml), so left unconditionally
        // visible it sat behind/over whichever pad was actually showing -
        // PIN, password or pattern. Only the swipe-up padlock screen wants
        // the clock; entering a passcode does not.
        visible: lockScreen.state === "pad"
    }


    Image {
        anchors.top: parent.top
        source: "../images/lockscreen/screen-lock-wallpaper-mask-top.png"
        width: parent.width
        height: Units.gu(11.7)
        mipmap: true
        fillMode: Image.TileHorizontally
    }

    Image {
        anchors.bottom: parent.bottom
        source: "../images/lockscreen/screen-lock-wallpaper-mask-bottom.png"
        width: parent.width
        height: Units.gu(25)
        mipmap: true
        fillMode: Image.TileHorizontally
    }


    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
        onInitialized: {
            service.subscribe("luna://com.palm.systemmanager/getDeviceLockMode", "{\"subscribe\":true}", handleDeviceLockMode, handleError);
            service.subscribe("luna://com.palm.display/control/lockStatus", "{\"subscribe\":true}", handleLockStatus, handleError);
            service.subscribe("luna://com.palm.display/control/status", "{\"subscribe\":true}", handleDisplayStatus, handleError);
            service.subscribe("luna://com.palm.systemservice/getPreferences",
                              "{\"keys\":[\"enableFingerprintUnlock\",\"enableFaceUnlock\"],\"subscribe\":true}",
                              handleBiometricPreferences, handleError);
            // webos-fingerprint-adapter is only present on devices with a
            // fingerprint sensor; on others this subscription simply fails
            // and fingerprintAvailable stays false.
            subscribeFingerprintStatus();
            // luneos-faced is only present on devices with a usable front
            // camera; elsewhere this subscription simply fails and
            // faceAvailable stays false.
            subscribeFaceStatus();
        }

        function subscribeFingerprintStatus() {
            service.subscribe("luna://com.webos.service.fingerprint/getStatus", "{\"subscribe\":true}", handleFingerprintStatus, handleFingerprintStatusError);
        }

        function subscribeFaceStatus() {
            service.subscribe("luna://com.webos.service.faceunlock/getStatus", "{\"subscribe\":true}", handleFaceStatus, handleFaceStatusError);
        }

        function handleBiometricPreferences(message) {
            var response = JSON.parse(message.payload);
            if (response.enableFingerprintUnlock !== undefined)
                lockScreen.fingerprintUnlockEnabled = response.enableFingerprintUnlock;
            if (response.enableFaceUnlock !== undefined)
                lockScreen.faceUnlockEnabled = response.enableFaceUnlock;
        }

        function handleFaceStatus(message) {
            var response = JSON.parse(message.payload);
            if (response.returnValue === false) {
                lockScreen.faceAvailable = false;
                faceStatusRetry.restart();
                return;
            }
            lockScreen.faceAvailable = (response.available === true);
            lockScreen.faceEnrolled = (response.enrolled === true);
        }

        function handleFaceStatusError(message) {
            console.log("Face unlock service not available: " + message);
            lockScreen.faceAvailable = false;
            faceStatusRetry.restart();
        }

        function handleFingerprintStatus(message) {
            var response = JSON.parse(message.payload);
            if (response.returnValue === false) {
                lockScreen.fingerprintAvailable = false;
                // the adapter went away (e.g. it was restarted); retry so
                // fingerprint unlock comes back on its own rather than staying
                // dead until the next shell restart
                fingerprintStatusRetry.restart();
                return;
            }
            lockScreen.fingerprintAvailable = (response.available === true);
            lockScreen.fingerprintCount = response.fingerprints ? response.fingerprints.length : 0;
        }

        function handleFingerprintStatusError(message) {
            console.log("Fingerprint service not available: " + message);
            lockScreen.fingerprintAvailable = false;
            fingerprintStatusRetry.restart();
        }

        function handleLockStatus(message) {
            console.warn("Got lock status " + message.payload);
            var response = JSON.parse(message.payload);

            if (response.lockState === "locked")
                lockScreen.state = "pad";
            else if (response.lockState === "unlocked" || response.lockState === "dockmode")
                lockScreen.state = "none";
        }

        function handleDisplayStatus(message) {
            var response = JSON.parse(message.payload);
            if (response.state === undefined)
                return;

            var nowOn = (response.state === "on");
            // Each time the screen comes back on the user is deliberately looking
            // at the phone, so give face unlock a fresh budget rather than making
            // them find the PIN because earlier attempts were spent unseen.
            if (nowOn && !lockScreen.displayOn)
                lockScreen.faceFailedAttempts = 0;
            lockScreen.displayOn = nowOn;
        }

        function handleDeviceLockMode(message) {
            console.log("Got device lock mode " + message.payload);

            var response = JSON.parse(message.payload);
            lockScreen.deviceLockMode = response.lockMode;
        }

        function handleError(message) {
            console.log("Service error: " + message);
        }
    }

    state: "none"
    states: [
        State {
            name: "none"
            PropertyChanges { target: lockScreen; locked: false }
        },
        State {
            name: "pad"
            PropertyChanges { target: lockScreen; locked: true }
        },
        State {
            name: "pin-password"
            PropertyChanges { target: lockScreen; locked: true }
        },
        State {
            name: "pattern"
            PropertyChanges { target: lockScreen; locked: true }
        }
    ]

    PadLock {
        id: padLock

        visible: lockScreen.state === "pad"

        onUnlock: padUnlock()
    }

    PinPasswordLock {
        id: pinPasswordLock

        isPINEntry: deviceLockMode == "pin"

        visible: lockScreen.state === "pin-password"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (Qt.inputMethod.keyboardRectangle.height/2)*-1

        onUnlock: unlockDisplay()
        onCanceled: {
            lockScreen.state = "pad";
        }
    }

    PatternLock {
        id: patternLock

        visible: lockScreen.state === "pattern"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        onUnlock: unlockDisplay()
        onCanceled: {
            lockScreen.state = "pad";
        }
    }
}
