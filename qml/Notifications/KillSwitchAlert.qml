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
 * The brief image legacy webOS showed when the ringer switch was flipped, for
 * the hardware privacy switches.
 *
 * Built like VolumeControlAlert, which is the surviving port of that same
 * behaviour (VolumeControlAlertWindow in LunaSysMgr): a centred icon, gone
 * after a couple of seconds, so a switch feels like the ringer switch did
 * rather than like a notification.
 *
 * It follows the legacy artwork rather than VolumeControlAlert's presentation
 * where the two differ - no background panel, and the icon itself translucent
 * with a blue slash. See the note on the scrim below.
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

    /*
     * No scrim, matching legacy. VolumeControlAlertWindow painted no
     * background at all - its only fillRect is commented out - and bell_off.png
     * carries none either: its corners are fully transparent. The look was a
     * bright blue slash over a translucent ghost of the icon, straight on the
     * wallpaper, and a dark panel behind it reads as a dialog instead.
     *
     * The icons carry the translucency themselves (the glyph is drawn at 60%),
     * so there is nothing to fade here.
     */

    /*
     * Sized by HEIGHT, with the width following the source aspect.
     *
     * These glyphs are not all the same shape - a camera is wide and short
     * where a microphone is tall and narrow - so fitting each into one square
     * box made the wide ones look shrunken: the camera's glyph only reached
     * 65% of the box height while the mic reached 96%. Matching heights gives
     * them the same visual weight, which is what "the same size" means here.
     */
    Image {
        id: image
        anchors.centerIn: parent
        opacity: 1.0
        mipmap: true
        fillMode: Image.PreserveAspectFit
        width: implicitHeight > 0 ? Math.round(implicitWidth * (height / implicitHeight))
                                  : height
    }

    /*
     * Show the switch that just moved, in either direction - the engaged icon
     * when it is flipped on and the plain one when it is released, the way the
     * ringer switch showed a struck-through bell against an intact one. Being
     * told the hardware came back matters as much as being told it went away,
     * and on a switch you cannot see from the front of the phone it is the
     * only confirmation there is.
     *
     * "unknown" is never shown: there is nothing to tell the user, and a flash
     * would imply something changed when all we know is that we cannot see it.
     */
    function showSwitch(id, state) {
        if (state !== "blocked" && state !== "open")
            return;

        var source = __imageFor(id, state);
        if (source.length === 0)
            return;

        image.source = source;
        /* Height only - width comes from the source aspect, see the Image. */
        image.height = Units.gu(9.6);

        root.visible = true;
        hideTimer.restart();
    }

    /*
     * "_off" is the struck-through icon shown while the hardware is cut,
     * "_on" the plain one shown when it comes back.
     */
    function __imageFor(id, state) {
        var suffix = (state === "blocked") ? "_off" : "_on";
        var base = "";

        switch (id) {
        case "camera":        base = "camera";       break;
        case "camera-front":  base = "camera_front"; break;
        case "camera-rear":   base = "camera_rear";  break;
        case "cellular":
        case "modem":         base = "network";      break;
        case "microphone":    base = "mic";          break;
        case "wifi-bt":
        case "wifi":          base = "wifi_bt";      break;
        case "headphone":     base = "headphone";    break;
        default:              return "";
        }

        return "../images/" + base + suffix + ".png";
    }
}
