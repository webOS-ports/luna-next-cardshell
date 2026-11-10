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

/*
 * Which way up the screen should be, from one accelerometer sample.
 *
 * sensorfw's OrientationSensor flips as soon as the side-to-side tilt passes
 * 25 degrees (20 back to portrait), and it measures that as an elevation
 * against the horizontal, not as a turn in the plane of the screen. Held at an
 * ordinary reading angle, leaning back, the "stay portrait" test fails almost
 * at once and a small wobble turns the shell sideways.
 *
 * This works the way phones usually do it: take the direction of gravity in
 * the plane of the screen, and only change orientation once that is well past
 * half way to the next one - HYSTERESIS degrees beyond the 45 degree mark, so
 * 60 degrees of turn to leave and 30 to come back. Lying (nearly) flat, or
 * being shaken, there is no usable direction and the current one is kept.
 *
 * Angles use OrientationHelper's convention: 0 top up, 90 left edge up,
 * 180 upside down, 270 right edge up. Accelerometer axes are Qt's, as the
 * sensorfw plugin passes them through: x to the right, y to the top, reading
 * +g along whichever way is up.
 */
.pragma library

var GRAVITY = 9.80665;

// Degrees past the 45 degree mark before switching.
var HYSTERESIS = 15;

// Below this share of g in the screen plane the device is too close to flat
// (about 20 degrees) for the in-plane direction to mean anything.
var MIN_IN_PLANE = 0.35;

// Total acceleration outside 1 g +/- this share means it is being moved, not
// held, and the sample says little about which way is down.
var MAX_MAGNITUDE_DEVIATION = 0.4;

/*
 * Direction of "up" in the screen plane, in degrees [0, 360), or -1 when the
 * sample is not usable (flat, or accelerating).
 */
function inPlaneAngle(x, y, z) {
    var magnitude = Math.sqrt(x * x + y * y + z * z);
    if (Math.abs(magnitude - GRAVITY) > MAX_MAGNITUDE_DEVIATION * GRAVITY)
        return -1;
    if (Math.sqrt(x * x + y * y) < MIN_IN_PLANE * magnitude)
        return -1;
    var angle = Math.atan2(-x, y) * 180 / Math.PI;
    return angle < 0 ? angle + 360 : angle;
}

// Shortest distance between two angles, in degrees [0, 180].
function angleDistance(a, b) {
    var d = Math.abs(a - b) % 360;
    return d > 180 ? 360 - d : d;
}

/*
 * The orientation to use after this sample: one of 0, 90, 180, 270. Returns
 * current unchanged unless the sample is clearly in another one.
 */
function orientationFor(x, y, z, current) {
    var angle = inPlaneAngle(x, y, z);
    if (angle < 0)
        return current;
    if (angleDistance(angle, current) <= 45 + HYSTERESIS)
        return current;
    return (Math.round(angle / 90) % 4) * 90;
}
