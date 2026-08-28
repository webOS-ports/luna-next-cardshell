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
import Qt5Compat.GraphicalEffects
import LunaNext.Common 0.1

Item {
    id: padLock

    signal unlock

    anchors.fill: parent

    // Fingerprint feedback: light the padlock up exactly like a press, tinted
    // green for a recognized finger and red for an unrecognized one.
    // Colors are the affirmative/negative pair used by the phone app
    // (org.webosports.app.phone MessageAlert.qml).
    function fingerprintFeedback(success) {
        pad.on = true;
        fpGlow.color = success ? "#2aa100" : "#be0003";
        fpGlow.visible = true;
        fpFeedbackTimer.restart();
    }

    // Shown once fingerprint unlock has been disabled for too many failed
    // reads. Cleared when the pad is dragged (a real unlock attempt) so it
    // does not linger over the pin pad.
    function showFingerprintLockout(deviceLockMode) {
        fpLockoutText.text = (deviceLockMode === "pin")
            ? "Too many attempts. Enter your PIN to unlock."
            : (deviceLockMode === "password")
                ? "Too many attempts. Enter your password to unlock."
                : "Too many attempts. Fingerprint unlock disabled.";
        fpLockoutText.visible = true;
    }

    Timer {
        id: fpFeedbackTimer
        interval: 600
        repeat: false
        onTriggered: {
            fpGlow.visible = false;
            if (!padDragArea.drag.active) {
                pad.on = false;
                unlockText.visible = false;
            }
        }
    }

    Image {
        id: targetScrim
        source: "../images/lockscreen/screen-lock-target-scrim.png"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Settings.tabletUi ? Units.gu(10) : Units.gu(1)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: pad.moving
        mipmap: true
        width: Units.gu(50)
        height: Units.gu(30)
    }

    DropArea {
        x: 75; y: 75
        width: 50; height: 50

        Rectangle {
            anchors.fill: parent
            color: "green"
            visible: parent.containsDrag
        }
    }

    Text
    {
        id: unlockText
        text: "Drag up to unlock"
        font.pixelSize: FontUtils.sizeToPixels("large")
        color: "white"
        font.bold: true
        anchors.verticalCenter: targetScrim.verticalCenter
        anchors.horizontalCenter: targetScrim.horizontalCenter
        visible: false
    }



    Image {
        id: pad
        source: pad.on ? "../images/lockscreen/screen-lock-padlock-on.png" : "../images/lockscreen/screen-lock-padlock-off.png"
        height: Units.gu(12)
        width: Units.gu(12)
        mipmap: true

        property bool on: false

        property int _basePositionX: parent.width / 2 - (pad.width / 2)
        property int _basePositionY: Settings.tabletUi ? (parent.height - pad.height - Units.gu(10)) : (parent.height - pad.height - Units.gu(1))

        x: _basePositionX
        y: _basePositionY

        function resetPosition() {
            pad.x = Qt.binding( function() { return _basePositionX; } );
            pad.y =  Qt.binding( function() { return _basePositionY; } );
        }

        function checkForUnlockPosition() {
            if ((pad.x < targetScrim.x || pad.x > targetScrim.x + targetScrim.width) ||
                (pad.y < targetScrim.y || pad.y > targetScrim.y + targetScrim.height))
                padLock.unlock();
        }

        property bool moving: padDragArea.drag.active

        Drag.active: padDragArea.drag.active
        Drag.hotSpot.x: 10
        Drag.hotSpot.y: 10

        MouseArea {
            id: padDragArea
            anchors.fill: parent
            drag.target: parent

            onReleased: {
                pad.checkForUnlockPosition();
                pad.resetPosition();
                pad.on = false;
                unlockText.visible = false;
            }
            onPressed: {
                pad.on = true;
                unlockText.visible = true;
                fpLockoutText.visible = false;
            }
        }
    }

    Text {
        id: fpLockoutText
        visible: false
        width: parent.width - Units.gu(4)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: ""
        color: "white"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: pad.top
        anchors.bottomMargin: Units.gu(3)
    }

    // Halo around the (lit) padlock; the artwork itself stays untinted.
    Glow {
        id: fpGlow
        anchors.fill: pad
        source: pad
        visible: false
        radius: Units.gu(1.6)
        samples: 33
        spread: 0.3
        color: "#2aa100"
    }
}
