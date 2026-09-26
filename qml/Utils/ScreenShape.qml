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

pragma Singleton

import QtQuick 2.0
import LunaNext.Common 0.1

/*
 * What shape the panel is, and what that costs a top bar.
 *
 * The raw data comes from the device's Tier 1 adaptation by way of
 * /etc/palm/luna-platform.conf - a list of avoidance rectangles and the four
 * corner radii, in physical pixels, origin top-left. See Settings.h for the
 * format and luneos-device-config's 50-luna-platform for where the numbers come
 * from and how a sideways-mounted panel is corrected before they get here.
 *
 * The answers, not the data, are what callers should want: a bar asks how tall
 * it has to be and how far in from each end it can draw, and gets a number. The
 * policy lives here once so that the status bar, the lock screen and anything
 * else that has to dodge the camera all dodge it the same way.
 *
 * Everything here degrades to "an ordinary rectangular panel" when no adaptation
 * declared a shape, which is every device but radon today. A caller that uses
 * these functions unconditionally therefore behaves exactly as before on those
 * devices - there is no need to branch at the call site.
 */
QtObject {
    id: screenShape

    /* The avoidance rectangles: notch, punch hole, island. Each has x, y, width
     * and height. Not the rounded corners - those come as radii below, because a
     * corner expressed as a rectangle is only correct for the one bar height it
     * was written for, and the whole point of this file is that the bar height
     * is not known in advance. */
    readonly property var cutouts: fromSettings("displayCutouts")

    /* Four radii: top-left, top-right, bottom-right, bottom-left. The order
     * gmobile's GmCornerPosition uses, so a panel definition lifted from there
     * transcribes without reshuffling. Empty when the panel has square corners
     * or nobody has measured them. */
    readonly property var cornerRadii: fromSettings("displayCornerRadii")

    /*
     * Read a list off Settings without assuming it is there.
     *
     * This is not paranoia about the config, it is about version skew between
     * this QML and the C++ plugin that feeds it. The shell's QML is a directory of
     * files and LunaNext.Common is a compiled plugin, so the two get updated
     * separately - pushing the QML to a device whose plugin predates
     * displayCutouts is the normal way to try a shell change, and that is exactly
     * when the property does not exist. An older plugin then reads as "no shape
     * declared" and the shell behaves as it did before, instead of every binding
     * in this file failing and leaving the status bar half-configured.
     *
     * try/catch rather than a !== undefined test because how a QObject singleton
     * answers for a property its metaobject does not carry is not something to
     * bet a boot on: undefined is the likely answer and a throw is a possible
     * one, and both have to end up as an empty list.
     */
    function fromSettings(name) {
        try {
            var v = Settings[name];
            return (v === undefined || v === null) ? [] : v;
        } catch (e) {
            return [];
        }
    }

    readonly property bool hasCutouts: cutouts.length > 0
    readonly property bool hasRoundedCorners: cornerRadii.length === 4 &&
                                              (cornerRadii[0] > 0 || cornerRadii[1] > 0 ||
                                               cornerRadii[2] > 0 || cornerRadii[3] > 0)
    readonly property bool known: hasCutouts || hasRoundedCorners

    /*
     * Whether the declared shape can be trusted at this rotation.
     *
     * The rectangles describe the panel as the shell lays it out at rotation 0.
     * OrientationHelper rotates the whole scene by -orientationAngle, so at a
     * quarter turn the notch is against what is now a side edge and every number
     * here would have to be turned to match.
     *
     * That turn is deliberately not done. Phosh bails out unless its monitor
     * transform is NORMAL and Lomiri's cutout model returns nothing unless the
     * orientation is portrait; both ship with a TODO where this sentence is. The
     * reason to follow them rather than do better is narrower than theirs: the
     * only thing this would buy is a landscape shell, and LuneOSViewRoot sets
     * automaticOrientation false, so a rotated shell happens only when an app
     * asks or someone presses F6-F9. Getting the sign of the transform wrong is
     * easy and would put the inset on the wrong side, which is worse than the
     * square-panel behaviour every device has today.
     *
     * So: at a quarter turn, and upside down, every function below answers as if
     * the panel were rectangular - which is exactly what the shell did before any
     * of this existed.
     */
    function appliesAt(angle) {
        return known && ((angle % 360) + 360) % 360 === 0;
    }

    /*
     * How tall a bar across the top of the screen has to be for the hardware to
     * fall entirely inside it.
     *
     * Only cutouts against the top edge count. One further down the panel is not
     * a top bar's problem, and one at the bottom (an under-screen sensor, a
     * second notch) would otherwise make the bar absurd.
     *
     * This is what stops maximized apps being drawn under the camera: every
     * surface in CardsArea anchors below the bar, so the bar absorbing the notch
     * insets all of them at once. Android does the same thing through a
     * per-device status_bar_height_portrait, and Lomiri through
     * CollapsedPanelHeight; deriving it from the cutout means one less number to
     * keep in step by hand.
     */
    function topBarHeight(defaultHeight, angle) {
        if (!appliesAt(angle))
            return defaultHeight;

        var h = defaultHeight;
        for (var i = 0; i < cutouts.length; i++) {
            var c = cutouts[i];
            if (c.y > 0)
                continue;
            h = Math.max(h, c.y + c.height);
        }
        return h;
    }

    /*
     * How much horizontal room a rounded corner of this radius costs something
     * whose topmost pixel is at contentTop.
     *
     *     +--------------------------
     *     |\                     ^
     *     | \                    | contentTop
     *     |  \                   v
     *     +---*----------------- content starts here
     *     | inset
     *
     * The corner is an arc of radius r centred at (r, r), so the leftmost visible
     * x at height y is r - sqrt(r^2 - (r - y)^2). The worst case over the
     * content's vertical span is at its top edge, because the arc only moves
     * outward above that.
     *
     * Insetting by the full radius instead - the obvious thing, and what a first
     * attempt tends to do - throws away far more than the curve actually takes:
     * on radon, 75px of a 720px-wide panel per side rather than the 3px the
     * geometry asks for. Phosh computes the same chord for the same reason; the
     * UBports docs publish an approximation of it.
     */
    function cornerInset(radius, contentTop) {
        if (radius <= 0 || contentTop >= radius)
            return 0;

        var dy = radius - contentTop;
        return Math.ceil(radius - Math.sqrt(Math.max(0, radius * radius - dy * dy)));
    }

    /* The two that a top bar wants, by name, so call sites do not index into
     * cornerRadii and get the order wrong. */
    function topLeftInset(contentTop, angle) {
        return appliesAt(angle) && hasRoundedCorners ? cornerInset(cornerRadii[0], contentTop) : 0;
    }

    function topRightInset(contentTop, angle) {
        return appliesAt(angle) && hasRoundedCorners ? cornerInset(cornerRadii[1], contentTop) : 0;
    }

    /*
     * The cutouts that overlap a horizontal band, as {x, width} pairs sorted by
     * x - the obstacles something laid out in that band has to route around.
     *
     * A band rather than the whole bar because the bar can be taller than its own
     * content: on radon the notch is 102px deep and the content sits in the
     * bottom 54px of it, so asking "what is in the way of the content" and "what
     * is in the way of the bar" have different answers.
     */
    function obstaclesInBand(top, height, angle) {
        var out = [];
        if (!appliesAt(angle))
            return out;

        for (var i = 0; i < cutouts.length; i++) {
            var c = cutouts[i];
            if (c.y + c.height <= top || c.y >= top + height)
                continue;
            out.push({ "x": c.x, "width": c.width });
        }

        out.sort(function(a, b) { return a.x - b.x; });
        return out;
    }

    /*
     * Move an item of itemWidth off any obstacle it overlaps, keeping it within
     * [minX, maxX] and moving it as little as possible.
     *
     * When neither side of an obstacle has room the item is left where it was
     * rather than shoved somewhere arbitrary: a clock a few pixels under the lens
     * is bad, a clock pushed off screen or on top of the indicators is worse.
     * Phosh makes the same call, and logs, so this does too.
     */
    function shiftClear(x, itemWidth, obstacles, minX, maxX) {
        for (var i = 0; i < obstacles.length; i++) {
            var o = obstacles[i];
            if (x >= o.x + o.width || x + itemWidth <= o.x)
                continue;

            var toLeft = o.x - itemWidth;
            var toRight = o.x + o.width;
            var leftFits = toLeft >= minX;
            var rightFits = toRight + itemWidth <= maxX;

            if (leftFits && rightFits)
                x = (x - toLeft) <= (toRight - x) ? toLeft : toRight;
            else if (leftFits)
                x = toLeft;
            else if (rightFits)
                x = toRight;
            else
                console.warn("ScreenShape: no room either side of the cutout at " +
                             o.x + "+" + o.width + " for an item " + itemWidth +
                             "px wide in [" + minX + ", " + maxX + "]; leaving it put");
        }

        return x;
    }
}
