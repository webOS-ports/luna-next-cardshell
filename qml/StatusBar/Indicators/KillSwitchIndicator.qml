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
 * One engaged hardware privacy switch, drawn the way the ringer switch used to
 * be: an icon that is simply there while the hardware is off.
 *
 * Driven by switch id rather than by a property per device, because the devices
 * that have these do not agree on which switches exist - see KillSwitchService.
 */
BaseIndicator {
    id: killSwitchIndicator

    /* Switch id as the killswitch service reports it. */
    property string switchId: ""

    imageSource: __iconFor(switchId)

    /*
     * Only ids we actually have artwork for light up. An id we do not know
     * draws nothing rather than a placeholder: a privacy indicator that shows
     * the wrong hardware is worse than one that shows none, and silence here
     * is a missing icon rather than a missing switch.
     */
    function __iconFor(id) {
        switch (id) {
        case "camera":        return "../../images/statusbar/icon-camera-blocked.png";
        case "camera-front":  return "../../images/statusbar/icon-camera-front-blocked.png";
        case "camera-rear":   return "../../images/statusbar/icon-camera-rear-blocked.png";
        case "cellular":
        case "modem":         return "../../images/statusbar/icon-network-blocked.png";
        case "microphone":    return "../../images/statusbar/icon-mic-blocked.png";
        case "wifi-bt":
        case "wifi":          return "../../images/statusbar/icon-wifi-bt-blocked.png";
        case "headphone":     return "../../images/statusbar/icon-headphone-blocked.png";
        }
        return "";
    }

    /*
     * BaseIndicator is "visible: enabled" and takes its width from the image,
     * so an unknown id collapses to nothing on its own once enabled is false -
     * no width or visible override here, which would fight those bindings.
     */
    enabled: imageSource.length > 0
}
