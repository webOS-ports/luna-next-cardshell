/*
 * Copyright (C) 2015 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.12
import QtQuick.Window 2.2
import LuneOS.Service 1.0
import LuneOS.System 1.0
import "LunaSysAPI"

Item {
    Preferences {
        id: preferences
    }

    // Whether com.palm.display reports the panel as lit. Starts true so a
    // shell that comes up before the display manager answers behaves as
    // before; the subscription below corrects it on the first reply.
    property bool displayOn: true

    // Which way the phone is held, by OrientationFilter.js's rule (in
    // LuneOS.System, shared with apps that need the phone's own turn).
    DeviceOrientation {
        id: sensor

        // Rotation only matters while the screen is on. sensorfwd keeps the
        // accelerometer streaming in the SLPI for as long as this channel is
        // running, and on Halium every sample is an ADSP glink interrupt plus
        // an IPCRTR_lpass_rx wakeup (~10/s on the Pixel 3a, day and night).
        // luna-displaymanager already stops its ALS channel when it blanks
        // the screen; this was the last always-on UI sensor client. Bind the
        // sensor to the display state instead of start()ing it once: the
        // channel stops with the screen and comes back, with a fresh
        // reading, when it is lit again.
        active: orientationHelperItem.displayOn
    }

    id: orientationHelperItem

    // Laid out for visualAngle, centred on the screen and turned about its
    // own centre: a quarter turn
    // of a height x width item centred there covers the screen exactly.
    readonly property bool __sideways: visualAngle % 180 !== 0
    width: __sideways ? parent.height : parent.width
    height: __sideways ? parent.width : parent.height
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    property real __lockedRotationAngle: 0
    property bool automaticOrientation: false
    // An angle set by hand (F6-F9 through setOrientation), kept until the
    // phone is turned; -1 when there is none.
    property int __manualAngle: -1
    property int orientationAngle: locked ? __lockedRotationAngle
                                          : (__manualAngle >= 0 ? __manualAngle : sensor.angle)
    property bool transitionEnabled: false
    property bool rotationLock: false
    property bool locked: rotationLock || preferences.rotationLock

    // The orientation the shell is laid out and turned for. orientationAngle
    // is where it is going; this follows it once the snapshot of the old
    // screen is taken. Everything else (status bar insets, the rotation lock)
    // reads orientationAngle.
    property int visualAngle: 0
    Component.onCompleted: visualAngle = orientationAngle

    transform: Rotation { origin.x: width / 2; origin.y: height / 2; angle: -visualAngle }

    /*
     * The turn, as LunaSysMgr drew it (WindowServer::rotateUi,
     * Rotation_RotateAndCrossFade): a snapshot of the screen before, and one
     * after the UI is laid out for the new orientation, over black. The old
     * one turns away and fades out while the new one turns in from the same
     * side and fades in, 400 ms InOutCubic (lunaAnimations.conf
     * rotationAnimationDuration). The UI itself is hidden meanwhile, and a
     * change of orientation during the turn waits until it is done.
     *
     * 0 idle, 1 taking the snapshot of the old screen, 2 laid out for the new
     * one and waiting for it to be drawn, 3 turning.
     */
    property int __turnPhase: 0
    property int __framesToWait: 0
    property int __fromAngle: 0
    property int __toAngle: 0
    // How far the screen turns, clockwise, in LunaSysMgr's terms: its
    // angles run the other way round from ours (it turns its root item by
    // +angle, this item turns by -angle), and new - old is wrapped into
    // -180..180 with both ends kept, so a half turn goes the way it did.
    property int __turnDelta: 0
    property real __turnProgress: 0
    property size __fromSize: Qt.size(0, 0)

    function __legacyDelta(from, to) {
        var d = ((360 - to) % 360) - ((360 - from) % 360);
        if (d > 180)
            d -= 360;
        else if (d < -180)
            d += 360;
        return d;
    }

    onOrientationAngleChanged: {
        publishTimer.restart();
        if (!displayOn || !Window.window || !Window.window.visible) {
            __endTurn();
            visualAngle = orientationAngle;
            return;
        }
        if (__turnPhase === 0)
            __beginTurn();
    }

    function __beginTurn() {
        if (orientationAngle === visualAngle)
            return;
        __fromAngle = visualAngle;
        __toAngle = orientationAngle;
        __turnDelta = __legacyDelta(__fromAngle, __toAngle);
        __fromSize = Qt.size(width, height);
        __turnProgress = 0;
        __turnPhase = 1;
        beforeSnapshot.scheduleUpdate();
        __framesToWait = 1;
        turnFallback.restart();
        // Ask for the frames being waited for. When the turn changes no size
        // (a square screen such as the Titan's) nothing else redraws, and the
        // turn used to start only from the fallback, half a second late.
        Window.window.update();
    }

    function __nextPhase() {
        turnFallback.stop();
        if (__turnPhase === 1) {
            // The old screen is in the snapshot: lay out for the new one,
            // under it.
            visualAngle = __toAngle;
            __turnPhase = 2;
            // A frame already in flight can come first.
            __framesToWait = 2;
            turnFallback.restart();
        } else if (__turnPhase === 2) {
            __turnPhase = 3;
            turnAnimation.restart();
        }
    }

    function __endTurn() {
        turnAnimation.stop();
        turnFallback.stop();
        if (__turnPhase === 1)
            visualAngle = __toAngle;
        __turnPhase = 0;
        __turnProgress = 0;
    }

    Connections {
        target: orientationHelperItem.Window.window
        enabled: orientationHelperItem.__turnPhase === 1 || orientationHelperItem.__turnPhase === 2
        function onFrameSwapped() {
            if (--orientationHelperItem.__framesToWait <= 0)
                orientationHelperItem.__nextPhase();
            else
                orientationHelperItem.Window.window.update();
        }
    }

    // In case no frame comes at all, go on anyway.
    Timer {
        id: turnFallback
        interval: 500
        onTriggered: orientationHelperItem.__nextPhase()
    }

    NumberAnimation {
        id: turnAnimation
        target: orientationHelperItem
        property: "__turnProgress"
        from: 0
        to: 1
        duration: 400
        easing.type: Easing.InOutCubic
        onFinished: {
            orientationHelperItem.__endTurn();
            // LunaSysMgr kept the newest orientation pending and turned again
            // once the animation was over.
            if (orientationHelperItem.orientationAngle !== orientationHelperItem.visualAngle)
                orientationHelperItem.__beginTurn();
        }
    }

    // Drawn over the shell, in screen coordinates, only while turning.
    Item {
        id: turnOverlay
        parent: orientationHelperItem.parent
        anchors.fill: parent
        z: 10000
        visible: orientationHelperItem.__turnPhase > 0

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        // The new screen, live, turning in from where the old one started.
        ShaderEffectSource {
            id: afterSnapshot
            sourceItem: orientationHelperItem.__turnPhase >= 2 ? orientationHelperItem : null
            hideSource: true
            live: true
            width: orientationHelperItem.width
            height: orientationHelperItem.height
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            rotation: -orientationHelperItem.__toAngle
                      - orientationHelperItem.__turnDelta * (1 - orientationHelperItem.__turnProgress)
            opacity: orientationHelperItem.__turnProgress
        }

        // The old screen, taken once, turning away.
        ShaderEffectSource {
            id: beforeSnapshot
            sourceItem: orientationHelperItem.__turnPhase >= 1 ? orientationHelperItem : null
            live: false
            width: orientationHelperItem.__fromSize.width
            height: orientationHelperItem.__fromSize.height
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            rotation: -orientationHelperItem.__fromAngle
                      + orientationHelperItem.__turnDelta * orientationHelperItem.__turnProgress
            opacity: 1 - orientationHelperItem.__turnProgress
        }

        // The UI was hidden during the turn; nothing below takes input.
        MouseArea {
            anchors.fill: parent
        }
    }

    Connections {
        target: preferences;
        function onRotationLockChanged() {
            if( preferences.rotationLock ) __lockedRotationAngle = orientationAngle;
        }
    }

    // Tell WebAppMgr where the device is pointing.
    //
    // LunaSysMgr held the shell and the web application host in one process and
    // set this directly (WebAppMgrProxy::setOrientation). They are separate
    // processes now, so nothing was telling WAM anything and
    // PalmSystem.screenOrientation stayed at its hard-coded "up" - which is why
    // Enyo's ApplicationEvents onWindowRotated never fires
    // (luneos-testing#13). enyo.sendOrientationChange() compares that property
    // against its own last value, so a constant means no rotation is ever
    // dispatched.
    //
    // The names are LunaSysMgr's, and the angles follow its convention:
    // HostBase::setOrientation rotated the UI by 90 for "right" and 270 for
    // "left", and this item rotates its content by -orientationAngle, so
    // RightUp (270) is "right" and LeftUp (90) is "left".
    function orientationName(angle) {
        switch (angle % 360) {
        case 90:  return "left";
        case 180: return "down";
        case 270: return "right";
        default:  return "up";
        }
    }

    property string __lastPublishedOrientation: ""

    function publishOrientation() {
        var name = orientationName(orientationAngle);
        if (name === __lastPublishedOrientation)
            return;
        __lastPublishedOrientation = name;
        console.log("OrientationHelper: orientation " + orientationAngle + " -> " + name);
        webAppMgrService.call("luna://com.palm.webappmanager/setOrientation",
                              JSON.stringify({"orientation": name}),
                              function (message) {
                                  // A rejected call comes back here with
                                  // returnValue false, not through the error
                                  // callback below, so it has to be checked or
                                  // a failure is silent. console.log is not
                                  // routed to the journal, only warnings are.
                                  var response = JSON.parse(message.payload);
                                  if (!response.returnValue)
                                      console.warn("OrientationHelper: setOrientation rejected: " + message.payload);
                              },
                              function(error) {
                                  console.warn("OrientationHelper: setOrientation failed: " + JSON.stringify(error));
                              });
    }

    // Publish where it settled, not a quick back-and-forth.

    Timer {
        id: publishTimer
        interval: 100
        onTriggered: orientationHelperItem.publishOrientation()
    }

    LunaService {
        id: webAppMgrService
        name: "com.webos.surfacemanager.cardshell"
        onInitialized: {
            orientationHelperItem.publishOrientation();
            webAppMgrService.subscribe("luna://com.palm.display/control/status",
                                       JSON.stringify({"subscribe": true}),
                                       orientationHelperItem.handleDisplayStatus,
                                       function (error) {
                                           console.warn("OrientationHelper: display status subscription failed: " + JSON.stringify(error));
                                       });
        }
    }

    // The first reply carries "state" ("on", "dimmed", "off", ...); later
    // pushes carry only "event": displayOn, displayDimmed, displayOff, plus
    // blockedDisplay/unblockedDisplay and the like, which say nothing about
    // the panel. Only "off" releases the sensor: "dimmed" still shows the
    // UI. Anything else leaves the current value alone.
    function handleDisplayStatus(message) {
        var response = JSON.parse(message.payload);
        if (response.state !== undefined)
            displayOn = (response.state !== "off");
        else if (response.event === "displayOff")
            displayOn = false;
        else if (response.event === "displayOn" || response.event === "displayDimmed")
            displayOn = true;
    }

    // Turns the screen by hand, for keyboards and testing. This used to
    // assign orientationAngle, which in QML replaces its binding for good:
    // after one F6-F9 the shell no longer followed the sensor at all, and
    // the screen stayed where the key left it until the shell restarted.
    // The angle now holds until the phone itself is turned.
    function setOrientation(angle) {
        if (locked) return;
        __manualAngle = ((angle % 360) + 360) % 360;
    }

    Connections {
        target: sensor
        function onAngleChanged() { orientationHelperItem.__manualAngle = -1; }
    }

    function setLocked(lock) {
        if (lock) __lockedRotationAngle = orientationAngle;
        rotationLock = lock;
    }

    // Map a raw gesture position into this item's coordinate system.
    //
    // GestureHandler (LunaNext.Shell) reports touchPoint.screenPos(), i.e. a
    // position in the window's own, unrotated space. Mapping it from our parent
    // would skip every transform above it - including the output rotation that
    // surface-manager applies to its views (compositorWindow.outputRotation, the
    // "r" of com.webos.surfacemanager.compositorGeometry). On a panel mounted a
    // quarter turn off, such as the MP01 (r270), that put taps on the wrong
    // side or off screen. Mapping from global coordinates applies the whole
    // chain: that rotation as well as our own sensor rotation.
    function convertRawPos(pos) {
        return mapFromGlobal(pos.x, pos.y);
    }
}
