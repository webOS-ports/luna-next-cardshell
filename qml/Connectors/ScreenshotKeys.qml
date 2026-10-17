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
import WebOSCoreCompositor 1.0

/*!
 * \brief Power + Volume Down takes a screenshot, timed the way legacy's
 * Home + Power was.
 *
 * Legacy (WindowServer::sysmgrEventFilter, Key_Power and Key_CoreNavi_Home):
 * hold one key and tap the other. The screenshot is taken when the tapped key
 * is released, if it was down for no more than 500 ms while the other was
 * held; the tapped key's release and the held key's later release are then
 * both swallowed. Either key can be the one held. Volume Down stands in for
 * Home, which phones here do not have.
 *
 * Swallowing the power key is not up to the shell: luna-displaymanager reads
 * it on its own (nyx), and turns the screen off on its *release*. So while
 * Volume Down is held - the only time a power release can be part of the
 * chord - the display manager is asked to leave the power key alone
 * (control/setProperty powerKeyBlock, held for as long as the subscription
 * lives). It then only reports the release, and the block is let go once it
 * has. A power press that is not part of a screenshot in that window - held
 * for more than 500 ms with Volume Down down - is therefore lost rather than
 * turning the screen off; holding it for the power menu still works, that
 * goes by press time. Nothing is armed while the display is off, so power
 * always wakes it.
 *
 * Volume Down's own volume step is held back by VolumeControl while the
 * chord is armed, and dropped once volumeDownTaken says the press took a
 * screenshot: no step, no click, no indicator in the shot. Volume Down
 * never reaches a key filter - LunaNext.Shell's VolumeKeys takes both volume
 * keys application-wide - so it is passed in through volumeKey() from
 * VolumeKeys' keyPressed/keyReleased. Power comes through the compositor's key
 * filter.
 */
Item {
    id: screenshotKeys

    //! Take the screenshot.
    signal screenshotRequested()

    //! Only armed while the display is on.
    property bool displayOn: true

    //! Whose key filter to join.
    property var compositorInstance: null

    //! How long the tapped key may be down. (legacy: 500 ms)
    property int tapWindowMs: 500

    //! Volume Down may be the start of a chord: VolumeControl holds its step
    //! back while this is true.
    readonly property bool armed: displayOn

    //! The Volume Down press under way took a screenshot - as the held key
    //! or the tapped one - so it must change nothing. Until the next press.
    readonly property bool volumeDownTaken: _volumeDownTaken

    //! What WebOSKeyFilter::Result is worth (see HardwareKeys).
    readonly property int resultAccepted: 1
    readonly property int resultNextPolicy: 2

    property bool _powerDown: false
    property bool _volumeDown: false
    property real _powerDownAt: 0
    property real _volumeDownAt: 0
    property bool _eatPowerUp: false
    property bool _eatVolumeUp: false
    property bool _volumeDownTaken: false

    //! The powerKeyBlock subscription while it is held, else null.
    property var _powerBlock: null
    //! A power release happened under the block, and the display manager has
    //! not said yet that it saw it: letting go now could beat it there.
    property bool _awaitingBlockedRelease: false
    property bool _installed: false

    //! Where the power key block is asked for; a test puts a fake here.
    property var displayService: service

    LunaService {
        id: service
        name: "com.webos.surfacemanager-cardshell"

        onInitialized: screenshotKeys._install()
    }

    KeyFilter { id: screenshotKeyFilter }

    //! Never wait for the display manager's word for longer than this.
    Timer {
        id: blockReleaseFallback
        interval: 1000
        onTriggered: {
            screenshotKeys._awaitingBlockedRelease = false;
            screenshotKeys._maybeUnblockPower();
        }
    }

    function _install() {
        if (screenshotKeys._installed)
            return;

        var comp = screenshotKeys.compositorInstance;
        if (!comp) {
            console.warn("ScreenshotKeys: no compositor, Power + Volume Down will do nothing");
            return;
        }

        // Share whichever filter is already installed, as HardwareKeys does.
        if (!comp.keyFilter)
            comp.keyFilter = screenshotKeyFilter;

        comp.keyFilter.addKeyFilter(screenshotKeys._onKey, "screenshotKeys");
        screenshotKeys._installed = true;
    }

    function _blockPower() {
        if (screenshotKeys._powerBlock !== null)
            return;

        // A call that could not be made returns nothing; treat it as no block,
        // so no chord is taken without one.
        screenshotKeys._powerBlock = screenshotKeys.displayService.subscribe(
            "luna://com.palm.display/control/setProperty",
            JSON.stringify({ powerKeyBlock: true, client: "screenshotKeys", subscribe: true }),
            function (message) {
                var reply = JSON.parse(message.payload);
                if (reply.powerKey === "released") {
                    screenshotKeys._awaitingBlockedRelease = false;
                    blockReleaseFallback.stop();
                    screenshotKeys._maybeUnblockPower();
                }
            },
            function (message) {
                console.warn("ScreenshotKeys: cannot block the power key: " + message.payload);
            }) || null;
    }

    function _maybeUnblockPower() {
        if (screenshotKeys._powerBlock === null || screenshotKeys._volumeDown ||
                screenshotKeys._powerDown || screenshotKeys._awaitingBlockedRelease)
            return;

        screenshotKeys._powerBlock.cancel();
        screenshotKeys._powerBlock = null;
    }

    //! A volume key went down or came up, as VolumeKeys reports it (no
    //! auto-repeat).
    function volumeKey(keycode, pressed) {
        screenshotKeys._key(keycode, pressed, false);
    }

    function _onKey(keycode, pressed, autoRepeat, nativeModifiers) {
        return screenshotKeys._key(keycode, pressed, autoRepeat);
    }

    function _key(keycode, pressed, autoRepeat) {
        var power = (keycode === Qt.Key_PowerOff);
        if (!power && keycode !== Qt.Key_VolumeDown)
            return screenshotKeys.resultNextPolicy;

        // A held key repeats; that is still the same press.
        if (autoRepeat)
            return screenshotKeys.resultNextPolicy;

        var now = Date.now();

        if (pressed) {
            if (power) {
                screenshotKeys._powerDown = true;
                screenshotKeys._eatPowerUp = false;
                screenshotKeys._powerDownAt = now;
            } else {
                screenshotKeys._volumeDown = true;
                screenshotKeys._eatVolumeUp = false;
                screenshotKeys._volumeDownTaken = false;
                screenshotKeys._volumeDownAt = now;
                if (screenshotKeys.displayOn)
                    screenshotKeys._blockPower();
            }
            return screenshotKeys.resultNextPolicy;
        }

        var eat = false;
        if (power) {
            if (screenshotKeys._powerBlock !== null) {
                screenshotKeys._awaitingBlockedRelease = true;
                blockReleaseFallback.restart();
            }
            if (screenshotKeys._eatPowerUp) {
                screenshotKeys._eatPowerUp = false;
                eat = true;
            } else if (screenshotKeys._volumeDown && screenshotKeys._powerBlock !== null &&
                       now - screenshotKeys._powerDownAt <= screenshotKeys.tapWindowMs) {
                screenshotKeys._volumeDownTaken = true;
                screenshotKeys.screenshotRequested();
                screenshotKeys._eatVolumeUp = true;
                eat = true;
            }
            screenshotKeys._powerDown = false;
            screenshotKeys._powerDownAt = 0;
        } else {
            if (screenshotKeys._eatVolumeUp) {
                screenshotKeys._eatVolumeUp = false;
                eat = true;
            } else if (screenshotKeys._powerDown && screenshotKeys._powerBlock !== null &&
                       now - screenshotKeys._volumeDownAt <= screenshotKeys.tapWindowMs) {
                screenshotKeys._volumeDownTaken = true;
                screenshotKeys.screenshotRequested();
                screenshotKeys._eatPowerUp = true;
                eat = true;
            }
            screenshotKeys._volumeDown = false;
            screenshotKeys._volumeDownAt = 0;
        }

        screenshotKeys._maybeUnblockPower();
        return eat ? screenshotKeys.resultAccepted : screenshotKeys.resultNextPolicy;
    }
}
