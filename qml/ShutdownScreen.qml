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
import LuneOS.Service 1.0
import LunaNext.Common 0.1
import "Utils"

/*
 * The shutdown / reboot animation, brought back from legacy webOS.
 *
 * On legacy webOS this was not drawn by the shell at all: rc0.d stopped
 * LunaSysMgr and then ran `fbprogress -f battery-only`, which painted the orb
 * straight to /dev/fb0. That is not available to us -- luna-surfacemanager
 * drives the panel through the Android hwcomposer HAL via libhybris, so the
 * framebuffer node is either absent or not scanned out. The animation
 * therefore lives here, and covers the window between the device being told
 * to go down and the compositor being torn down.
 *
 * It listens to powerd rather than to whoever asked for the shutdown. There
 * is more than one way to power this device off -- the QML power menu in the
 * shell, and com.palm.systemui's PowerdAlerts, which is what the hardware
 * power button actually reaches -- and hooking any one of those misses the
 * others. sleepd's /shutdown/shutdownApplicationsRegister notifies every
 * registered client once shutdown begins, whichever path started it.
 *
 * Registering makes sleepd wait for our ack before it proceeds, so the ack is
 * deliberately short: long enough for a revolution of the spinner to be seen,
 * far short of sleepd's "Shutdown apps timed out". If the service is missing
 * or the call fails, nothing registers and shutdown behaves exactly as before.
 *
 * Two bus channels are involved, and they must not be confused:
 *
 *  - shutdownApplicationsRegister is a subscription whose only reply is the
 *    registration itself ({clientId, returnValue:true}). sleepd never pushes
 *    anything else on it. What it does push is the hub's cancel notice when
 *    sleepd goes away ({returnValue:false, ...}) - every sleepd restart, for
 *    instance. Treating "anything after the registration" as a shutdown put
 *    the orb on screen with nothing going down behind it, which looks exactly
 *    like a device stuck shutting down and gets it hard-reset.
 *
 *  - The real notification is the shutdownApplications *signal* on the
 *    /shutdown category, broadcast by sleepd's state machine once shutdown
 *    begins. That is what starts the animation. Its payload is {} and carries
 *    no returnValue, which is how it is told apart from the addmatch reply
 *    that arrives on the same subscription.
 */
Item {
    id: root

    anchors.fill: parent
    visible: opacity > 0
    opacity: 0

    /* Disc diameter as a fraction of the screen's short edge -- the one knob
       worth tuning here.

       Legacy scaled by screen share, not by physical size: the same artwork
       came in two sizes, an 86px disc for the TouchPad (1024x768) and a 51px
       disc for the phones (Pre2/Pre3, 480x800), which are 11.2% and 10.6% of
       the short edge respectively. (The Veer reused the phone artwork on a
       320x400 panel and so came out at 15.9% -- the outlier, not the rule.)

       0.11 is therefore the legacy-faithful value. We deliberately run larger:
       on a 1080x2220 phone the legacy share is a 119px disc, which is lost on
       a screen this tall. */
    property real discFraction: 0.25

    property real orbRadius: Math.min(width, height) * discFraction / 2

    /* Held so the animation is actually seen before the device goes down. */
    property int ackDelayMs: 1200

    property string shutdownClientId: ""

    function start() {
        if (opacity > 0)
            return;
        orb.running = true;
        root.opacity = 1;
    }

    /* Nothing is going down after all -- used when the register/ack path
       reports failure, so the shell is not left behind an animation that
       never ends and swallows all input. */
    function cancel() {
        root.opacity = 0;
        orb.running = false;
    }

    LunaService {
        id: shutdownWatch

        name: "com.webos.surfacemanager-cardshell"

        onInitialized: {
            /* The signal is what matters; register second so sleepd waits
               for our ack before tearing things down. */
            shutdownWatch.subscribe(
                "luna://com.palm.bus/signal/addmatch",
                JSON.stringify({ "category": "/shutdown",
                                 "method": "shutdownApplications" }),
                handleShutdownSignal, handleError);
            register();
        }

        function register() {
            root.shutdownClientId = "";
            shutdownWatch.subscribe(
                "luna://com.webos.service.sleep/shutdown/shutdownApplicationsRegister",
                JSON.stringify({ "clientName": "com.webos.surfacemanager-cardshell",
                                 "subscribe": true }),
                handleRegisterMessage, handleRegisterError);
        }

        function handleRegisterMessage(message) {
            var response = JSON.parse(message.payload);

            if (response.returnValue === true
                    && response.hasOwnProperty("clientId")) {
                root.shutdownClientId = response.clientId;
                console.warn("ShutdownScreen: registered with powerd as "
                            + response.clientId);
                return;
            }

            /* Anything else on this subscription is the hub telling us the
               registration is gone (sleepd stopped or restarted). Forget the
               id and register again once it is back. */
            console.warn("ShutdownScreen: powerd registration dropped: "
                        + message.payload);
            root.shutdownClientId = "";
            reregisterTimer.restart();
        }

        function handleRegisterError(message) {
            console.warn("ShutdownScreen: could not register with powerd: "
                        + message);
            root.shutdownClientId = "";
            reregisterTimer.restart();
        }

        function handleShutdownSignal(message) {
            var response = JSON.parse(message.payload);

            /* The addmatch reply carries returnValue; the signal does not. */
            if (response.hasOwnProperty("returnValue")) {
                if (response.returnValue !== true)
                    console.warn("ShutdownScreen: shutdown signal watch failed: "
                                + message.payload);
                return;
            }

            console.warn("ShutdownScreen: shutdown starting, showing animation");
            root.start();
            ackTimer.restart();
        }

        function handleError(message) {
            console.warn("ShutdownScreen: bus error: " + message);
        }

        function ack() {
            if (root.shutdownClientId === "")
                return;
            shutdownWatch.call(
                "luna://com.webos.service.sleep/shutdown/shutdownApplicationsAck",
                JSON.stringify({ "clientId": root.shutdownClientId }),
                undefined, handleError);
        }
    }

    /* sleepd restarted underneath us: give it a moment to come back up. */
    Timer {
        id: reregisterTimer
        interval: 3000
        repeat: false
        onTriggered: shutdownWatch.register()
    }

    Timer {
        id: ackTimer
        interval: root.ackDelayMs
        repeat: false
        onTriggered: shutdownWatch.ack()
    }

    /* Swallow everything. The device is going down; nothing below should
       react to stray touches while the animation is up. */
    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        preventStealing: true
        onClicked: { }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    ShutdownOrb {
        id: orb
        anchors.fill: parent
        orbRadius: root.orbRadius
        running: false
    }
}
