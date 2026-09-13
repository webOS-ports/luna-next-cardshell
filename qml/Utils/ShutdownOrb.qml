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

/*
 * Clean-room redraw of the legacy webOS shutdown orb.
 *
 * Nothing here is derived from HP/Palm pixels -- it is drawn from primitives
 * (radial/linear gradients, a circle, a clipped ellipse and two tapered arc
 * strokes). The proportions were measured off the original artwork and are
 * expressed as multiples of `orbRadius`, so this scales to any DPI instead of
 * being locked to the original 302x302 bitmap.
 *
 * Geometry recovered from flashing-static.tga / flashing-activity.tga:
 *
 *   disc      circle, radius R, centred, shaded by a dome gradient centred
 *             at +0.60R (fit residual 0.89/255)
 *   ellipse   superellipse (n=2.8), centre (-0.295R, 0), semi-axes
 *             0.698R x 0.884R -- shorter than
 *             the disc, so its top and bottom stay rounded rather than being
 *             clipped flat. Flat ~87.5/255 fill whose alpha ramps 1 -> 0 from
 *             its left extreme to its boundary (fitted), so the dome shows
 *             through progressively and the join is seamless
 *   glow      broad elliptical glow (2.965R x 3.232R) plus TWO rim terms,
 *             f(r)*g(theta) each: a bright halo, and a contact shadow the
 *             disc casts to its right. Rank-2 alternating fit, rms 0.63/255.
 *   arcs      two comets 180 deg apart, centreline r = 0.629R, stroke 0.0343R,
 *             each spanning 75 deg, alpha climbing ~linearly 0.065 -> 0.62
 *             from tail to head
 *   motion    9 deg per frame, 20 frames = 180 deg; with the two-fold symmetry
 *             that reads as a continuous 1 s revolution at 20 fps
 */
Item {
    id: root

    /* Radius of the solid disc. Everything else is derived from it.

       The default assumes this item spans the screen, and reproduces the
       legacy proportion: a 43px disc on the TouchPad's 768-tall panel, so
       43/768 of the short edge. (302 is the artwork *tile*, not the screen --
       sizing against that makes the orb about 2.5x too big.) Callers that
       want a fixed physical size, as the shell does, should just set this.

       Note it is a *drawing* size, not a transform: enlarging the item
       repaints the vector sharply, whereas putting a `scale` on it would
       stretch the already-rasterised canvas and look pixelated. */
    property real orbRadius: Math.min(width, height) * (43 / 768)

    property int fps: 20
    property bool running: true
    property int frameCount: 20
    property real degreesPerFrame: 9

    /* Step in 9 deg jumps like the original, or rotate continuously. */
    property bool stepped: true

    property int currentFrame: 0

    readonly property real glowRadius: orbRadius * 3.372

    /* --- the static part: glow, disc, ellipse ------------------------- */
    Canvas {
        id: orbCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var R = root.orbRadius;
            var cx = width / 2;
            var cy = height / 2;

            /* Everything outside the disc, from a rank-2 separable fit of
               the original (rms 0.63/255):

                   value(r, th) = BASE(r / Re(th))
                                + F1(r) * G1(th)
                                + F2(r) * G2(th)

               BASE is the broad elliptical glow (semi-axes 2.965R x 3.232R).
               The two F*G terms are the rim lighting. One term is not enough:
               G2 is negative towards 0 deg and positive near 90 deg, which is
               the contact shadow the disc casts to its right -- a thick dark
               band hugging the rim on the lit side, with the bright halo
               beyond it. A single rim term averages that away and fills the
               gap in.

               Because G2 goes negative, this cannot be painted as additive
               layers. Instead each wedge gets one radial gradient holding the
               combined profile, which for a fixed angle is a function of r
               alone. */
            var GA = 2.965 * R, GB = 3.232 * R;
            var RMAXF = 1.90 * R;

            /* The leading bins carry no data -- those radii are behind the
               disc everywhere, so the fit never saw them. Held flat at the
               first measured value; leaving them at zero makes the
               interpolation ramp down into the rim and darkens the top and
               bottom edges of the disc. */
            var BASE = [
                39.6, 39.6, 39.6, 39.6, 39.6, 39.6, 39.6, 39.6, 39.6, 39.6, 39.6,
                39.6, 39.6, 39.6, 36.7, 39.6, 40.9, 41.2, 40.9, 39.9, 38.4, 36.7,
                35.1, 33.4, 31.7, 30.0, 28.1, 26.3, 24.4, 22.5, 20.7, 18.8, 16.9,
                15.1, 13.3, 11.5, 9.8, 8.1, 6.6, 5.1, 3.7, 2.4, 1.2, 0.0
            ];
            var F1 = [
                -0.033, -0.065, -0.001, 0.073, 0.166, 0.265, 0.380, 0.519, 0.667, 0.798, 0.872, 0.963,
                1.000, 0.996, 0.986, 0.950, 0.898, 0.817, 0.742, 0.664, 0.576, 0.489, 0.406, 0.321,
                0.249, 0.167, 0.124, 0.068, 0.045, 0.026, 0.003, -0.003, -0.006, 0.000, 0.000, 0.000,
                0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
                0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000
            ];
            var F2 = [
                0.303, 0.346, 0.532, 0.664, 0.880, 1.000, 0.941, 0.808, 0.584, 0.364, 0.149, -0.044,
                -0.120, -0.187, -0.233, -0.287, -0.279, -0.240, -0.205, -0.189, -0.178, -0.119, -0.093, -0.072,
                -0.049, 0.027, 0.036, 0.057, 0.016, 0.008, 0.012, 0.023, 0.010, 0.000, 0.000, 0.000,
                0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
                0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000
            ];
            var G1 = [
                25.60, 25.55, 25.15, 24.34, 22.89, 19.97, 15.82, 10.37, 5.47,
                1.31, -3.03, -7.31, -11.20, -14.30, -16.15, -17.29, -18.20, -18.50
            ];
            var G2 = [
                -8.54, -7.33, -4.78, -1.05, 4.12, 7.24, 9.29, 9.18, 8.44,
                6.72, 3.74, 0.62, -2.63, -4.50, -4.13, -3.72, -3.89, -3.85
            ];

            /* The fitted tables are bin averages, so entry k is the value at
               (k + 0.5) / n -- interpolate about the bin centres, not the
               end points, or everything lands half a bin out. */
            function tbl(arr, u) {
                var n = arr.length;
                var z = u * n - 0.5;
                var i = Math.floor(z), fr = z - i;
                var lo = arr[Math.max(0, Math.min(n - 1, i))];
                var hi = arr[Math.max(0, Math.min(n - 1, i + 1))];
                return lo + fr * (hi - lo);
            }
            function angTbl(arr, deg) {
                var a = deg % 360;
                if (a < 0) a += 360;
                if (a > 180) a = 360 - a;
                return tbl(arr, a / 180);
            }

            var wedges = 180;
            ctx.save();
            for (var kw = 0; kw < wedges; ++kw) {
                var d0 = kw * 360 / wedges, d1 = (kw + 1) * 360 / wedges;
                var dm = (d0 + d1) / 2;
                var ct = Math.cos(dm * Math.PI / 180), st2 = Math.sin(dm * Math.PI / 180);
                var Re = 1 / Math.sqrt((ct / GA) * (ct / GA) + (st2 / GB) * (st2 / GB));
                var Rw = 1.05 * Re;
                var g1v = angTbl(G1, dm), g2v = angTbl(G2, dm);

                var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, Rw);
                var NS = 56;
                for (var q3 = 0; q3 <= NS; ++q3) {
                    var tt2 = q3 / NS;
                    var rr = tt2 * Rw;
                    var val = tbl(BASE, (rr / Re) / 1.05);
                    if (rr >= R && rr < RMAXF) {
                        var u2 = (rr - R) / (RMAXF - R);
                        val += tbl(F1, u2) * g1v + tbl(F2, u2) * g2v;
                    }
                    if (val < 0) val = 0;
                    grad.addColorStop(tt2, Qt.rgba(1, 1, 1, val / 255));
                }
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, Rw, d0 * Math.PI / 180, d1 * Math.PI / 180);
                ctx.closePath();
                ctx.fill();
            }
            ctx.restore();

            /* The disc. A dome whose centre sits right of the disc centre;
               fitted against the original, residual sd 0.89/255. */
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, R, 0, 2 * Math.PI);
            ctx.clip();

            var dome = ctx.createRadialGradient(cx + 0.60 * R, cy, 0,
                                                cx + 0.60 * R, cy, 1.6 * R);
            var domeStops = [
                [0.000, 76.3], [0.058, 75.6], [0.116, 74.2], [0.174, 72.3],
                [0.233, 70.1], [0.291, 67.8], [0.349, 65.2], [0.407, 62.7],
                [0.465, 60.0], [0.523, 57.1], [0.581, 54.5], [0.640, 52.2],
                [0.698, 49.7], [1.000, 37.2]
            ];
            for (var k = 0; k < domeStops.length; ++k) {
                var dv = domeStops[k][1] / 255;
                dome.addColorStop(domeStops[k][0], Qt.rgba(dv, dv, dv, 1));
            }
            ctx.fillStyle = dome;
            ctx.fillRect(cx - R, cy - R, 2 * R, 2 * R);

            /* The lit ellipse. Fitting the disc interior as
               dome + alpha*(colour - dome) by alternating least squares says
               the colour is essentially flat (~89/255) and all of the shading
               across the ellipse comes from its alpha ramping from 1 at the
               left extreme down to 0 at the right boundary, letting the dome
               show through progressively. That is also seamless by
               construction: alpha reaches zero exactly on the boundary, so no
               terminator or feather fudge is needed. */
            var ecx = cx - 0.295 * R;
            var ea = 0.698 * R;
            /* Shorter than the disc radius, so the shape's top and bottom stay
               rounded inside the disc. Taller than R and the disc clips them
               flat, which is what makes the shadow read as the wrong shape. */
            var eb = 0.884 * R;
            /* And it is a superellipse, not an ellipse: |u|^n + |v|^n = 1 with
               n = 2.8. A plain ellipse is too pointed at the top and bottom --
               the original is noticeably fuller there. */
            var eN = 2.8;

            var EC = 88.6 / 255;

            /* Fitted alpha against the ellipse scale parameter (1 = boundary,
               0 = pinned left extreme). */
            var aStops = [
                [0.000, 1.000], [0.173, 1.000], [0.250, 0.959], [0.327, 0.889],
                [0.404, 0.828], [0.481, 0.745], [0.558, 0.662], [0.635, 0.572],
                [0.712, 0.479], [0.788, 0.349], [0.827, 0.270], [0.865, 0.049],
                [0.904, 0.000], [1.000, 0.000]
            ];
            /* Painted one scanline at a time rather than as nested shapes.

               With the vertical semi-axis held constant, the contour through a
               point has a closed form: for a row at |v| = V,
                   w  = (1 - V^n)^(1/n)          -- constant along that row
                   sc = (x - XL) / (ea * (1 + w))
               which is *linear in x*. So each row is exactly one horizontal
               linear gradient carrying the alpha profile, with no polygon
               approximation anywhere.

               The nested-shape version this replaces had two visible faults.
               A superellipse has no Canvas primitive, so it had to be walked
               as a polyline, and those segments showed as jagged, faceted
               edges when the orb was enlarged. And the contours do not
               strictly nest near the top and bottom, which kinked the shape
               there. Both are gone here: the gradient is smooth in x at any
               size, and the rounded left edge comes from the disc clip. */
            var tStops = [
                [0.00, 1.000], [0.25, 0.995], [0.45, 0.975], [0.60, 0.960],
                [0.70, 0.930], [0.78, 0.900], [0.86, 0.820], [0.93, 0.700],
                [0.97, 0.430], [1.00, 0.000]
            ];
            function vTaper(V) {
                for (var z = 1; z < tStops.length; ++z) {
                    if (V <= tStops[z][0]) {
                        var f = (V - tStops[z - 1][0])
                                / (tStops[z][0] - tStops[z - 1][0]);
                        return tStops[z - 1][1]
                               + f * (tStops[z][1] - tStops[z - 1][1]);
                    }
                }
                return 0;
            }

            var XL = ecx - ea;
            var y0 = Math.floor(cy - eb), y1 = Math.ceil(cy + eb);
            for (var yy = y0; yy <= y1; ++yy) {
                var V = Math.abs(yy + 0.5 - cy) / eb;
                if (V >= 1)
                    continue;
                var wr = Math.pow(1 - Math.pow(V, eN), 1 / eN);
                var xEnd = XL + ea * (1 + wr);
                /* Vertical taper. Without it the contour degenerates to a
                   horizontal line at |v| = 1 and the lobe ends in a flat cut
                   across its top and bottom; the original fades out there
                   instead. Measured as the peak alpha per row in the
                   original, normalised to the mid-line. */
                var tv = vTaper(V);
                var rg = ctx.createLinearGradient(XL, 0, xEnd, 0);
                for (var n3 = 0; n3 < aStops.length; ++n3) {
                    rg.addColorStop(aStops[n3][0],
                                    Qt.rgba(EC, EC, EC, aStops[n3][1] * tv));
                }
                ctx.fillStyle = rg;
                ctx.fillRect(XL, yy, xEnd - XL, 1);
            }

            /* Rim light along the disc's left edge: the original runs up to
               ~101/255 in the outermost pixel or two there, against ~91 just
               inside. Faded out towards the top and bottom so it does not
               wrap onto the unlit side. */
            var rimSegs = 36;
            ctx.lineWidth = 0.055 * R;
            for (var m = 0; m < rimSegs; ++m) {
                var f0 = m / rimSegs, f1 = (m + 1) / rimSegs;
                /* 100..260 degrees, brightest at 180. */
                var d0 = 100 + f0 * 160, d1 = 100 + f1 * 160;
                var mid = (d0 + d1) / 2;
                var fade = Math.sin((mid - 100) / 160 * Math.PI);
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.055 * fade * fade);
                ctx.beginPath();
                ctx.arc(cx, cy, R - 0.028 * R, d0 * Math.PI / 180, d1 * Math.PI / 180);
                ctx.stroke();
            }

            ctx.restore();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onOrbRadiusChanged() { orbCanvas.requestPaint(); }
        }
    }

    /* --- the moving part: two tapered comets, rotated as a unit --------- */
    Canvas {
        id: arcCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        rotation: root.stepped
                  ? root.currentFrame * root.degreesPerFrame
                  : continuousAngle

        property real continuousAngle: 0

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var R = root.orbRadius;
            var cx = width / 2;
            var cy = height / 2;

            var arcR = 0.629 * R;
            var startDeg = 104;
            var spanDeg = 75;

            /* Alpha along the comet, measured off the original by integrating
               the arc's excess over the static orb at each angle. It climbs
               almost linearly the whole way rather than reaching a plateau
               early, then the head stops abruptly. */
            var aProf = [
                [0.00, 0.048], [0.05, 0.106], [0.10, 0.158], [0.20, 0.206],
                [0.30, 0.331], [0.40, 0.418], [0.50, 0.446], [0.60, 0.528],
                [0.70, 0.576], [0.80, 0.619], [0.90, 0.653], [1.00, 0.643]
            ];
            function arcAlpha(t) {
                for (var z = 1; z < aProf.length; ++z) {
                    if (t <= aProf[z][0]) {
                        var f = (t - aProf[z - 1][0])
                                / (aProf[z][0] - aProf[z - 1][0]);
                        return aProf[z - 1][1]
                               + f * (aProf[z][1] - aProf[z - 1][1]);
                    }
                }
                return aProf[aProf.length - 1][1];
            }

            /* Enough segments that each is sub-pixel at whatever size we are
               drawn at, so the alpha ramp reads as continuous. A fixed count
               bands visibly once the orb is scaled up. */
            var arcLen = spanDeg * Math.PI / 180 * arcR;
            var segments = Math.max(48, Math.ceil(arcLen * 1.5));

            ctx.lineWidth = 0.0343 * R;
            ctx.lineCap = "butt";

            for (var arc = 0; arc < 2; ++arc) {
                var base = startDeg + arc * 180;
                for (var s = 0; s < segments; ++s) {
                    var t0 = s / segments;
                    var t1 = (s + 1) / segments;
                    var a = arcAlpha((t0 + t1) / 2);

                    /* Butt the segments up exactly rather than overlapping
                       them. Overlapping double-composites the shared band --
                       1-(1-a)^2 instead of a -- which shows up as bright
                       stripes along the arc as soon as the orb is scaled up. */
                    var a0 = (base + t0 * spanDeg) * Math.PI / 180;
                    var a1 = (base + t1 * spanDeg) * Math.PI / 180;

                    ctx.beginPath();
                    ctx.arc(cx, cy, arcR, a0, a1);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, a);
                    ctx.stroke();
                }
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onOrbRadiusChanged() { arcCanvas.requestPaint(); }
        }
    }

    Timer {
        interval: root.fps > 0 ? 1000 / root.fps : 1000
        running: root.running
        repeat: true
        onTriggered: {
            root.currentFrame = (root.currentFrame + 1) % root.frameCount;
            if (!root.stepped)
                arcCanvas.continuousAngle += root.degreesPerFrame;
        }
    }
}
