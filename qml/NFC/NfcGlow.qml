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
import Qt5Compat.GraphicalEffects
import LuneOS.Service 1.0
import LunaNext.Common 0.1

// Inspired by legacy webOS 3.0.5's Touch to Share glow (Src/base/visual/
// TouchToShareGlow.cpp in LunaSysMgr): the same radial gradient blob,
// growing scale 1.0->4.0 while fading opacity 1.0->0.0. Unlike the legacy
// infinite pulse loop, this plays the burst once when a tag is detected and
// smoothly collapses back to hidden if the tag is removed before the burst
// finishes, rather than looping or cutting off abruptly. NumberAnimation's
// restart() picks up the property's current value as "from" automatically,
// so an interruption mid-flight reverses cleanly from wherever it is.
// Driven by com.webos.service.nfc/getStatus's "present", which
// webos-nfc-adapter reports once a tag is actually in the field.
Item {
    id: nfcGlow

    visible: true

    property bool tagPresent: false

    onTagPresentChanged: {
        if (tagPresent) {
            // Jump straight to the "just tapped" starting look, then let
            // the animations below carry it outward from there
            pulse.scale = 1;
            pulse.opacity = 1;
            scaleAnimation.to = 4;
            opacityAnimation.to = 0;
        } else {
            // Collapse back to hidden from wherever the burst currently is
            scaleAnimation.to = 1;
            opacityAnimation.to = 0;
        }
        scaleAnimation.restart();
        opacityAnimation.restart();
    }

    // A hair under Settings.displayWidth/Height so the ripple never covers
    // the very edge of the screen at rest
    readonly property real baseRadius: Math.min(Settings.displayWidth, Settings.displayHeight) / 4

    Item {
        id: pulse

        anchors.centerIn: parent
        width: nfcGlow.baseRadius * 2
        height: width
        scale: 1
        opacity: 0

        // Qt5Compat's RadialGradient fills its whole rectangular bounds; the
        // real QPainter/QRadialGradient legacy renderer feathers past the
        // visible edge smoothly, so clip to a circle to avoid a hard square
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: pulse.width
                height: pulse.height
                radius: width / 2
            }
        }

        RadialGradient {
            anchors.fill: parent
            horizontalRadius: nfcGlow.baseRadius
            verticalRadius: nfcGlow.baseRadius

            // Exact stops from TouchToShareGlow.cpp's QGradientStops
            GradientStop { position: 0.0;  color: "#AFFFFFFF" }
            GradientStop { position: 0.25; color: "#1FFFFFFF" }
            GradientStop { position: 0.5;  color: "#FFFFFFFF" }
            GradientStop { position: 0.75; color: "#1FFFFFFF" }
            GradientStop { position: 1.0;  color: "#01FFFFFF" }
        }
    }

    // "from" deliberately left unset - each restart() picks up the
    // property's live value at that moment, which is what makes an
    // interruption mid-burst reverse smoothly instead of jumping
    NumberAnimation {
        id: scaleAnimation
        target: pulse
        property: "scale"
        duration: 1000
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: opacityAnimation
        target: pulse
        property: "opacity"
        duration: 1000
        easing.type: Easing.Linear
    }

    LunaService {
        id: nfcStatusQuery

        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            subscribe("luna://com.webos.service.nfc/getStatus",
                      JSON.stringify({"subscribe": true}),
                      nfcGlow.onNfcStatusChanged, nfcGlow.onNfcStatusError);
        }
    }

    function onNfcStatusChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue)
            return;

        nfcGlow.tagPresent = !!response.present;
    }

    function onNfcStatusError(message) {
        // com.webos.service.nfc isn't installed on every device (only
        // Halium machines with an NFC controller ship it), so this is a
        // normal, silent outcome rather than something to warn about.
        nfcGlow.tagPresent = false;
    }
}
