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
import LunaNext.Common 0.1
import LuneOS.Passcode 1.0

/*
 * The lock screen's half of Pattern unlock, alongside PinPasswordLock.
 *
 * Settings draws the same nine dots when a pattern is chosen or changed
 * (org.webosports.app.settings PatternLockGrid.qml); this is its counterpart
 * for entering one at the lock screen, over com.palm.systemmanager -
 * matchDevicePasscode, exactly as PinPasswordLock uses it. A pattern is not a
 * new kind of secret to that call: the nine dots visited, joined by index
 * ("0-1-2-5-8"), is the same opaque passCode string a PIN or a password would
 * be.
 */
Item {
    id: patternLock

    property int edgeOffset: Units.gu(11/10)
    property int margin: Units.gu(6/10)
    property int topOffset: Units.gu(4/10)
    property string queuedTitle: ""

    signal canceled
    signal unlock

    width: Units.gu(320/10) + 2 * patternLock.edgeOffset
    height: buttonGrid.y + buttonGrid.height + patternLock.edgeOffset + patternLock.margin
    focus: true

    function queueUpTitle(newTitle) {
        queuedTitle = newTitle;
    }

    function fade(fadeIn, fadeDuration) {
        fadeAnim.duration = fadeDuration;
        opacity = fadeIn ? 1.0 : 0.0;
    }

    // visible is actually driven by LockScreen's "lockScreen.state ===
    // 'pattern'" binding, not by opacity/fade below (nothing calls fade()
    // for pattern) - so this, not onOpacityChanged, is what runs every time
    // the pad is shown again. Without it the drawn trace from whatever was
    // entered last - a correct pattern in green, a wrong one in red - just
    // sat there through the next lock, showing the real pattern's shape.
    onVisibleChanged: {
        if (visible)
            resetEntry();
    }

    function resetEntry() {
        titleText.text = "Device Locked";
        hintText.text = "Draw your pattern";
        queuedTitle = "";
        grid.reset();
    }

    onOpacityChanged: {
        visible = opacity > 0.0;
        if (opacity === 0.0)
            grid.reset();
    }

    Behavior on opacity {
        NumberAnimation { id: fadeAnim; duration: 300 }
    }

    BorderImage {
        source: "../images/popup-bg.png"
        width: parent.width
        height: parent.height
        border { left: 35; top: 40; right: 35; bottom: 40 }
        smooth: true
    }

    Text {
        id: titleText
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("large")
        font.bold: true
        color: "#FFF"
        anchors.horizontalCenter: parent.horizontalCenter
        y: patternLock.edgeOffset + patternLock.margin + patternLock.topOffset
        text: "Device Locked"
    }

    Text {
        id: hintText
        font.family: "Prelude"
        font.pixelSize: FontUtils.sizeToPixels("small")
        color: "#CCC"
        anchors.horizontalCenter: parent.horizontalCenter
        y: titleText.y + titleText.height + Units.gu(4/10)
        text: "Draw your pattern"
    }

    /*
     * The nine-dot grid: LuneOS.Passcode's, the same one Settings draws when
     * a pattern is chosen, so both turn a drawn pattern into the same
     * passCode string.
     */
    PatternLockGrid {
        id: grid
        // Fills the card the same width the Cancel button below it does,
        // rather than the arbitrary narrower square this started as.
        width: Units.gu(320/10) - 2 * patternLock.margin
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: hintText.y + hintText.height + Units.gu(8/10)

        dotColor: "#FFFFFF"
        dotOpacity: 0.6
        selectedColor: "#2aa100"
        errorColor: "#be0003"
        nodeSize: 0.1

        // Every new attempt starts clean, regardless of whether the last
        // one was still mid-mismatchTimer - not just on first showing the
        // pad.
        onStarted: {
            mismatchTimer.stop();
            hintText.text = "Draw your pattern";
        }
        onPatternDrawn: (encoded) => patternLock.submitPattern(encoded)
        onTooShort: grid.reset()
    }

    Grid {
        id: buttonGrid
        width: Units.gu(320/10) - 2 * patternLock.margin
        x: patternLock.edgeOffset + patternLock.margin
        anchors.top: grid.bottom
        anchors.topMargin: Units.gu(6/10)

        columns: 1
        rows: 1
        spacing: patternLock.margin + 1

        ActionButton {
            caption: "Cancel"
            width: buttonGrid.width
            height: Units.gu(52/10)
            onAction: canceled()
        }
    }

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"
    }

    // A tap elsewhere in the system counts as activity because it is a
    // discrete press/release; one continuous drag across the grid - which is
    // all drawing a pattern ever is - never generates that, so nothing reset
    // the display's own off-timer and the screen could go dark mid-pattern.
    // control/setState "on" is the same call a real tap's activity ends up
    // making; firing it every couple of seconds while the finger is still
    // down keeps the countdown from ever elapsing during a slow draw.
    Timer {
        id: keepAwakeTimer
        interval: 2000
        repeat: true
        running: grid.drawing
        triggeredOnStart: true
        onTriggered: service.call("luna://com.palm.display/control/setState",
                                  "{\"state\":\"on\"}", null, null)
    }

    function submitPattern(encoded) {
        service.call("luna://com.palm.systemmanager/matchDevicePasscode",
                     JSON.stringify({"passCode": encoded}),
                     handlePatternResult,
                     handleServiceError);
    }

    function handlePatternResult(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue) {
            patternLock.unlock();
        } else {
            grid.showError();
            mismatchTimer.restart();
        }
    }

    function handleServiceError(message) {
        console.log("Service error: " + message);
    }

    Timer {
        id: mismatchTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (queuedTitle !== "") {
                titleText.text = queuedTitle;
                queuedTitle = "";
            }
            hintText.text = "Pattern incorrect. Try again.";
            grid.reset();
        }
    }
}
