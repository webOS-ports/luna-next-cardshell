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

    // Laid out for the orientation it is turning to from the first moment,
    // centred on the screen and turned about its own centre: a quarter turn
    // of a height x width item centred there covers the screen exactly.
    readonly property bool __sideways: orientationAngle % 180 !== 0
    width: __sideways ? parent.height : parent.width
    height: __sideways ? parent.width : parent.height
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    property real __lockedRotationAngle: 0
    property bool automaticOrientation: false
    property int orientationAngle: !locked ? sensor.angle : __lockedRotationAngle;
    property bool transitionEnabled: false
    property bool rotationLock: false
    property bool locked: rotationLock || preferences.rotationLock

    // What is on screen. orientationAngle is where the shell is going and
    // changes once; this follows it with the animation. Everything else
    // (status bar insets, the rotation lock) wants the destination, and used
    // to be fed every angle in between as well.
    property real visualAngle: 0

    transform: Rotation { origin.x: width / 2; origin.y: height / 2; angle: -visualAngle }

    // Swapping width and height relays the whole shell and every card, and on
    // sargo that frame takes ~450 ms. It used to land in the middle of the
    // animation (the item fell back to its base geometry while the angle was
    // in between, then took the new one at the end), so the turn stopped
    // around 45 degrees. Now the size changes at once and the turn starts
    // after the first frame at the new size is on screen, so the expensive
    // frame is out of the way before anything moves.
    property bool __turnPending: false
    // A frame already being drawn when the angle changed can still swap;
    // the one at the new size is the next.
    property int __framesToWait: 0

    onOrientationAngleChanged: {
        publishTimer.restart();
        if (!displayOn || !Window.window || !Window.window.visible) {
            turnAnimation.stop();
            __turnPending = false;
            visualAngle = orientationAngle;
            return;
        }
        __framesToWait = 2;
        __turnPending = true;
        turnFallback.restart();
    }

    function __startTurn() {
        if (!__turnPending)
            return;
        __turnPending = false;
        turnFallback.stop();
        turnAnimation.to = orientationAngle;
        turnAnimation.restart();
    }

    Connections {
        target: orientationHelperItem.Window.window
        enabled: orientationHelperItem.__turnPending
        function onFrameSwapped() {
            if (--orientationHelperItem.__framesToWait <= 0)
                orientationHelperItem.__startTurn();
        }
    }

    // In case no frame comes (nothing to redraw), turn anyway.
    Timer {
        id: turnFallback
        interval: 500
        onTriggered: orientationHelperItem.__startTurn()
    }

    // Quick, and decelerating, so the turn starts at once and settles. At
    // 500 ms linear it lagged well behind the hand.
    RotationAnimation {
        id: turnAnimation
        target: orientationHelperItem
        property: "visualAngle"
        duration: 250
        easing.type: Easing.OutCubic
        direction: RotationAnimation.Shortest
        // Shortest can finish on an equivalent angle (360 for 0); settle on
        // the real one. finished, not stopped: restart() stops too.
        onFinished: orientationHelperItem.visualAngle = turnAnimation.to % 360
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

    function setOrientation(angle) {
        if (locked) return;
        orientationAngle = angle;
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
