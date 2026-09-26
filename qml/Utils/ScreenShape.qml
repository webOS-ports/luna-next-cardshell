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

    /* The panel at rotation 0, which is the space cutouts is expressed in. */
    readonly property int panelWidth: Settings.displayWidth
    readonly property int panelHeight: Settings.displayHeight

    readonly property bool hasCutouts: cutouts.length > 0
    readonly property bool hasRoundedCorners: cornerRadii.length === 4 &&
                                              (cornerRadii[0] > 0 || cornerRadii[1] > 0 ||
                                               cornerRadii[2] > 0 || cornerRadii[3] > 0)
    readonly property bool known: hasCutouts || hasRoundedCorners

    /*
     * The shape turned into the orientation the shell is laying out in.
     *
     * OrientationHelper rotates the whole scene by -orientationAngle, so at a
     * quarter turn the panel's left edge is the top of what the user sees and
     * every rectangle here has to be turned to match. This was punted at first -
     * phosh bails out unless its monitor transform is NORMAL and Lomiri's cutout
     * model returns nothing outside portrait, both with a TODO here - and the
     * result was visible on radon the moment the device was turned: the bar
     * stopped insetting its ends and the indicators ran into the corner curve.
     *
     * Reasoning it out for a = 90 (the sensor's LeftUp, the device's left side
     * up, scene rotated a quarter turn anticlockwise to compensate):
     *
     *     scene top    is the panel's LEFT edge
     *     scene right  is the panel's TOP edge
     *     scene bottom is the panel's RIGHT edge
     *     scene left   is the panel's BOTTOM edge
     *
     * so scene x runs along the panel from bottom to top - x = H - y - h - and
     * scene y runs along it from left to right - y = x. Width and height swap,
     * as the scene itself does (OrientationHelper's "rotated" state is
     * height: parent.width, width: parent.height). 270 is the mirror of that,
     * and 180 needs no swap, only both edges reflected.
     */
    function normalizedAngle(angle) {
        return ((Math.round(angle / 90) * 90) % 360 + 360) % 360;
    }

    function rotateRect(r, angle) {
        var a = normalizedAngle(angle);
        if (a === 90)
            return { "x": panelHeight - r.y - r.height, "y": r.x,
                     "width": r.height, "height": r.width };
        if (a === 180)
            return { "x": panelWidth - r.x - r.width, "y": panelHeight - r.y - r.height,
                     "width": r.width, "height": r.height };
        if (a === 270)
            return { "x": r.y, "y": panelWidth - r.x - r.width,
                     "width": r.height, "height": r.width };
        return { "x": r.x, "y": r.y, "width": r.width, "height": r.height };
    }

    function sceneWidth(angle) {
        var a = normalizedAngle(angle);
        return (a === 90 || a === 270) ? panelHeight : panelWidth;
    }

    function sceneHeight(angle) {
        var a = normalizedAngle(angle);
        return (a === 90 || a === 270) ? panelWidth : panelHeight;
    }

    function rectsFor(angle) {
        var out = [];
        for (var i = 0; i < cutouts.length; i++)
            out.push(rotateRect(cutouts[i], angle));
        return out;
    }

    /*
     * The radius of a corner of the rotated scene, naming corners 0..3 as
     * cornerRadii does - top-left, top-right, bottom-right, bottom-left,
     * clockwise. A quarter turn moves every corner one place along that cycle,
     * so the scene's corner i was the panel's corner (i - angle/90).
     *
     *     a=90    scene TL,TR,BR,BL  <-  panel BL,TL,TR,BR
     *     a=180                      <-  panel BR,BL,TL,TR
     *     a=270                      <-  panel TR,BR,BL,TL
     */
    function radiusAt(corner, angle) {
        if (!hasRoundedCorners)
            return 0;
        var shift = normalizedAngle(angle) / 90;
        return cornerRadii[((corner - shift) % 4 + 4) % 4];
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
        if (!known)
            return defaultHeight;

        var h = defaultHeight;
        var rects = rectsFor(angle);
        for (var i = 0; i < rects.length; i++) {
            var c = rects[i];
            if (c.y > 0)
                continue;
            h = Math.max(h, c.y + c.height);
        }
        return h;
    }

    /*
     * How far up from the bottom edge something anchored there has to start to
     * clear the hardware.
     *
     * The mirror of topBarHeight, and needed for the same reason at a different
     * rotation: turn radon upside down and its notch is against the bottom edge,
     * directly under the gesture area. The gesture area is Units.gu(4) - 60px -
     * and the notch is 102px deep, so the handle and the whole touch strip end up
     * inside the camera hole.
     *
     * A margin rather than a taller area, unlike the status bar: the bar is
     * chrome that can absorb the cutout behind it, whereas the gesture area has
     * to be somewhere the finger can actually land. Lifting it clear is the only
     * thing that helps.
     */
    function bottomInset(angle) {
        if (!known)
            return 0;

        var inset = 0;
        var bottom = sceneHeight(angle);
        var rects = rectsFor(angle);
        for (var i = 0; i < rects.length; i++) {
            var c = rects[i];
            if (c.y + c.height < bottom)
                continue;
            inset = Math.max(inset, bottom - c.y);
        }
        return inset;
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
        return cornerInset(radiusAt(0, angle), contentTop);
    }

    function topRightInset(contentTop, angle) {
        return cornerInset(radiusAt(1, angle), contentTop);
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
        if (!known)
            return out;

        var rects = rectsFor(angle);
        for (var i = 0; i < rects.length; i++) {
            var c = rects[i];
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
