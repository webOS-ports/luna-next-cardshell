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

.pragma library

/*
 * What the volume overlay shows, kept apart from the bus so it can be
 * tested.
 *
 * The master volume shows the music indicator. The call volume, which
 * audiod reports on com.palm.audio/phone/status with "changed":["volume"]
 * when the user changed it, shows the phone indicator: a loudspeaker
 * with the same bar, as legacy webOS showed the phone volume with its own
 * image (LunaSysMgr VolumeControlAlertWindow, notification-volume-indicator).
 */

//! The bar's step, 0 to 90, for a volume of 0 to 100: nine pills.
function level(volume) {
    var normalized = 0;
    if (volume > 0)
        normalized = Math.round(volume / 11) * 10;
    if (normalized < 0)
        normalized = 0;
    if (normalized > 90)
        normalized = 90;
    return normalized;
}

function musicImage(volume) {
    return "../images/notification-music-indicator-" + level(volume) + ".png";
}

function phoneImage(volume) {
    return "../images/notification-phone-indicator-" + level(volume) + ".png";
}

//! Whether a /phone/status payload is the call volume changed by the user,
//! not a route change, the call starting or the microphone muted.
function isCallVolumeChange(payload) {
    if (payload === null || typeof payload !== "object")
        return false;
    if (!Array.isArray(payload.changed) || payload.changed.indexOf("volume") < 0)
        return false;
    return typeof payload.volume === "number";
}
