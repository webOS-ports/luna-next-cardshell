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
 * What a volume key asks audiod for, kept apart from the bus so it can be
 * tested.
 *
 * During a call the keys move the call's volume, which audiod keeps for each
 * route (earpiece, loudspeaker, wired headset, Bluetooth headset) apart from
 * the master volume. The master volume is the music's, the ringtones' and
 * the alerts', and the call never heard it: a call turned "up" with it left
 * the music loud afterwards and the call as it was. Legacy webOS did the
 * same: its audiod moved the phone scenario's volume while the phone module
 * was current.
 *
 * Outside a call they set the master volume of the output it is on, in
 * steps of ten (audiod's own master/volumeUp moves it by one).
 */

var step = 10;

//! { uri, payload, volume } for one key press; up is true for volume up.
//! volume is what the master volume is now taken to be, or -1 in a call,
//! where audiod answers with the volume and tells /phone/status.
function forKey(up, inCall, soundOutput, currentVolume) {
    if (inCall) {
        return {
            uri: "luna://com.palm.audio/phone/offsetVolume",
            payload: { offset: up ? step : -step },
            volume: -1
        };
    }

    var volume = currentVolume + (up ? step : -step);
    if (volume < 0)
        volume = 0;
    if (volume > 100)
        volume = 100;
    // soundOutput is required by audiod's schema (REQUIRED_2(soundOutput, volume)).
    return {
        uri: "luna://com.webos.service.audio/master/setVolume",
        payload: { soundOutput: soundOutput, volume: volume },
        volume: volume
    };
}

//! Whether a /phone/status payload says a call is up. Without inCall
//! (an older audiod) nothing changes: the keys stay on the master volume.
function inCallOf(payload) {
    return payload !== null && typeof payload === "object" && payload.inCall === true;
}
