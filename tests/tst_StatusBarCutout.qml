import QtQuick 2.0
import QtTest 1.0
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import Utils 1.0

import "../qml/StatusBar"

/*
 * The status bar on brax3 with all four SIM slots up: nothing it draws may sit
 * behind the camera.
 *
 * brax3's notch is a 161px teardrop at 280..441 of 720 and 46px deep, against a
 * 48px bar - so the bar does not grow for it, and the notch is right in the
 * content band. One SIM's indicators fit to its right; four do not, and they
 * were drawn straight across the lens. This builds the real StatusBar on that
 * panel, with four SIMs from the telephony stand-in, and checks every visible
 * piece of the bar against the cutout.
 *
 * Unlike tst_ScreenShape, Units is used freely here: it follows
 * Settings.setProfile() (luneos-components' UnitsStub), so the bar is laid out
 * at brax3's GridUnit 16 as on the phone.
 */
Item {
    id: root
    width: 720
    height: 1612

    // What CardShell and CardsArea give the status bar by name.
    // Items, not QtObjects: StatusBar declares both as Item.
    Item {
        id: windowManagerStandIn
        property string state: "normal"
        property bool gesturesEnabled: true
        height: 1612
        property Item gestureAreaInstance: null
        signal switchToLockscreen()
        signal switchToDockMode()
        signal switchToMaximize(var window)
        signal switchToFullscreen(var window)
        signal switchToCardView()
        signal switchToLauncherView()
    }
    property Item windowManagerInstance: windowManagerStandIn
    property QtObject orientationHelper: QtObject {
        property int orientationAngle: 0
        property real height: 1612
    }
    property QtObject lockScreen: QtObject {
        property bool locked: false
        property bool visible: false
    }
    property QtObject dockMode: QtObject { property bool visible: false }
    Item {
        id: gestureHandlerStandIn
        signal screenEdgeFlickEdgeTop(bool timeout, point pos)
    }
    property Item gestureHandlerInstance: gestureHandlerStandIn
    property QtObject compositor: null
    property QtObject airplaneModeService: QtObject {
        property bool active: false
        property bool inProgress: false
        function toggle() {}
    }
    property QtObject preferences: QtObject {
        property bool rotationLock: false
        property bool rotationInvalid: false
        property int rotationLockAngle: 0
        property bool muteSound: false
    }
    property QtObject launcherInstance: QtObject {
        property bool fullLauncherVisible: false
        property bool justTypeLauncherActive: false
        function launchApplication(id, params) {}
    }

    Component {
        id: statusBarComponent
        StatusBar {
            width: root.width
            height: barHeight
            windowManagerInstance: root.windowManagerInstance
            gestureHandlerInstance: root.gestureHandlerInstance
        }
    }

    TestCase {
        name: "StatusBarCutout"
        when: windowShown

        property Item bar: null

        /*
         * The profile has to be in place before anything reads ScreenShape, which
         * binds Settings once, and before the bar is built - see
         * tst_ScreenShape.
         */
        function initTestCase() {
            verify(Settings.setProfile("brax3"))
            compare(ScreenShape.cutouts.length, 1)
            compare(Units.gu(1), 16, "Units does not follow the profile; the bar would be desktop-sized")

            /*
             * One bar for the whole case, and the SIM count changed under it,
             * which is also how it happens on the phone. A second bar would
             * not do: the telephony stand-in keeps every subscriber it was
             * ever given, and posting to a destroyed bar's throws.
             */
            bar = statusBarComponent.createObject(root);
            verify(bar !== null);
        }

        function cleanupTestCase() {
            DualSim.setSimCount(2);
        }

        function setSims(count) {
            verify(DualSim.setSimCount(count));
            tryVerify(function () { return simIndicatorCount() === count; }, 2000,
                      "the SIM slots did not each get an indicator (" + count + " wanted)");
            // let the indicators' show/hide width animations settle
            wait(500);
        }

        function cutout() {
            return ScreenShape.rotateRect(ScreenShape.cutouts[0], 0);
        }

        function overlaps(item, r) {
            var p = item.mapToItem(bar, 0, 0);
            return p.x < r.x + r.width && p.x + item.width > r.x
                    && p.y < r.y + r.height && p.y + item.height > r.y;
        }

        function describe(item) {
            var p = item.mapToItem(bar, 0, 0);
            return (item.objectName || String(item)) + " at " + p.x + "," + p.y
                    + " " + item.width + "x" + item.height;
        }

        function shown(item) {
            return item.visible && item.opacity > 0 && item.width > 0 && item.height > 0;
        }

        /*
         * The pieces of the indicator row that draw something: each indicator,
         * not the row, whose box also covers the spacing between them. An
         * indicator is the outermost *Indicator type below the row, or else an
         * item with nothing visible inside it.
         */
        function indicatorLeaves(item, out) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i];
                if (!shown(c))
                    continue;
                var visibleChildren = 0;
                for (var j = 0; j < c.children.length; j++)
                    if (shown(c.children[j]))
                        visibleChildren++;
                if (visibleChildren === 0 || /Indicator_QML/.test(c.toString()))
                    out.push(c);
                else
                    indicatorLeaves(c, out);
            }
            return out;
        }

        // Every piece of text the bar shows: carrier names, clock, date.
        function texts(item, out) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i];
                if (!shown(c))
                    continue;
                if (/^QQuickText/.test(c.toString()) && c.text !== "")
                    out.push(c);
                texts(c, out);
            }
            return out;
        }

        function find(item, pred) {
            if (pred(item))
                return item;
            for (var i = 0; i < item.children.length; i++) {
                var hit = find(item.children[i], pred);
                if (hit)
                    return hit;
            }
            return null;
        }

        function simIndicatorCount() {
            var leaves = indicatorLeaves(find(bar, function (i) {
                return /^SystemIndicators_QML/.test(i.toString());
            }), []);
            var n = 0;
            for (var i = 0; i < leaves.length; i++)
                if (leaves[i].toString().indexOf("TelephonySignalIndicator") === 0)
                    n++;
            return n;
        }

        function test_four_sims_stay_off_the_camera() {
            setSims(4);
            var r = cutout();

            var indicators = find(bar, function (i) {
                return /^SystemIndicators_QML/.test(i.toString());
            });
            verify(indicators !== null);

            /*
             * Not a test of anything unless four SIMs really cannot share a row
             * with this camera: the indicator block, right-aligned, has to reach
             * past the cutout's right edge.
             */
            verify(indicators.width > bar.width - (r.x + r.width),
                   "the indicators fit beside the camera anyway (" + indicators.width
                   + "px); this profile no longer exercises the overflow");

            var leaves = indicatorLeaves(indicators, []);
            verify(leaves.length > 0);
            for (var i = 0; i < leaves.length; i++)
                verify(!overlaps(leaves[i], r), describe(leaves[i]) + " is behind the camera");

            /*
             * Text is measured by what it draws, not by its box: the carrier
             * name's box runs up to the clock however short the name is.
             */
            var t = texts(bar, []);
            verify(t.length > 0);
            for (var k = 0; k < t.length; k++) {
                var ink = Qt.rect(0, 0, Math.min(t[k].width, t[k].contentWidth), t[k].height);
                if (t[k].horizontalAlignment === Text.AlignRight)
                    ink.x = t[k].width - ink.width;
                else if (t[k].horizontalAlignment === Text.AlignHCenter)
                    ink.x = (t[k].width - ink.width) / 2;
                var p = t[k].mapToItem(bar, ink.x, 0);
                verify(!(p.x < r.x + r.width && p.x + ink.width > r.x
                         && p.y < r.y + r.height && p.y + ink.height > r.y),
                       "\"" + t[k].text + "\" at " + p.x + "," + p.y + " " + ink.width + "x"
                       + ink.height + " is behind the camera");
            }
        }

        /*
         * The other half: with one SIM there is room beside the camera, and the
         * bar must stay one row - the plain 48px it is on every other phone.
         */
        function test_one_sim_keeps_one_row() {
            setSims(1);
            compare(bar.barHeight, Units.gu(3));
        }
    }
}
