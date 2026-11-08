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
import LunaNext.Common 0.1

/*
 * The brief image shown when audio moves to or away from headphones: plugged
 * into the jack, or a Bluetooth headset connecting or dropping out.
 *
 * Deliberately the volume alert's look rather than the privacy switches':
 * this is about where sound goes, so it sits on the same dark panel as the
 * volume level and the muted bell, and its glyphs are drawn the way
 * bell_off.png draws the bell - the status bar's headphone shape, dim grey,
 * with bell_off's blue slash when the headphones go away.
 */
Item {
    id: root

    visible: false
    anchors.centerIn: parent
    width: image.width + Units.gu(1)
    height: image.height

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: root.visible = false
    }

    /* Emitted each time the alert comes up, for CentreAlertSlot. */
    signal shown()

    /* Takes the alert down before its time, when another one takes the
     * centre of the screen. */
    function dismiss() {
        hideTimer.stop();
        root.visible = false;
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
        radius: 4
    }

    Image {
        id: image
        anchors.centerIn: parent
        mipmap: true
        width: Units.gu(9.6)
        height: Units.gu(9.6)
    }

    /*
     * kind is "wired" or "bluetooth", as AudioOutputService reports it.
     *
     * Losing either kind shows the same struck-through headphones: what the
     * user needs to know is that audio has left their ears, and the
     * Bluetooth rune does not survive being struck through at this size.
     */
    function showOutput(kind, connected) {
        var base;
        if (!connected)
            base = "headset_off";
        else if (kind === "bluetooth")
            base = "bt_headset_on";
        else if (kind === "wired")
            base = "headset_on";
        else
            return;

        image.source = "../images/" + base + ".png";

        root.visible = true;
        hideTimer.restart();
        root.shown();
    }
}
