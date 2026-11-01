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

import "NotificationSound.js" as NotificationSound

/*
 * The sounds of apps that are no banner: what LunaSysMgr's BannerMessageHandler
 * played for PalmSystem.playSoundNotification, which reaches this from
 * WebAppMgr as luna://org.webosports.notifications/playSoundNotification, and
 * for popup alert windows (AlertWindowsArea). A banner's own sound stays with
 * the banner. Nothing here takes the name "com.webos.surfacemanager-cardshell":
 * the bus does not parse a "-" in a luna:// url, so a method there has no caller.
 */
Item {
    id: root

    // The tones the user picked: the shell's Preferences.
    property var tones

    // As LunaSysMgr's SoundPlayerPool: an app cannot pile up sounds without end.
    readonly property int maxPlayers: 5
    // How long a sound audiod plays with no limit of its own counts as playing.
    readonly property int audiodHoldMs: 5000

    property var players: []

    // luna://, for the tests to replace.
    property var callService: function(url, request, onReply) {
        client.call(url, JSON.stringify(request),
                    function(message) { if (onReply) onReply(JSON.parse(message.payload)); },
                    function(error) { if (onReply) onReply(null); });
    }
    property var fileExists: function(path) { return FileUtils.exists(path); }
    property Component playerComponent: SoundNotificationPlayer {}

    LunaService {
        id: client
        name: "com.webos.surfacemanager-cardshell"
    }

    LunaService {
        id: service
        name: "org.webosports.notifications"
        onInitialized: service.registerMethod("/", "playSoundNotification", root.handlePlay)
    }

    function handlePlay(message) {
        var request = null;
        try {
            request = JSON.parse(message.payload);
        } catch (e) {
        }
        if (!request || typeof request !== "object" || Array.isArray(request))
            return JSON.stringify({ returnValue: false, errorText: "Invalid parameters" });

        play(typeof request.soundClass === "string" ? request.soundClass : "",
             typeof request.soundFile === "string" ? request.soundFile : "",
             typeof request.duration === "number" ? request.duration : -1,
             request.wakeup === true);
        return JSON.stringify({ returnValue: true });
    }

    function toneTable() {
        var folder = Settings.lunaSystemSoundsPath || "/usr/palm/sounds";
        var alert = Settings.lunaDefaultAlertSound || "alert.wav";
        return {
            ringtone: tones ? tones.ringtoneFullPath : "",
            alerttone: tones ? tones.alerttoneFullPath : "",
            notificationtone: tones ? tones.notificationtoneFullPath : "",
            fallback: folder + "/" + alert
        };
    }

    /// Plays what soundClass and soundFile come to. Returns a handle for
    /// stop(), or null when nothing is playing for it. With alert, for a popup
    /// alert that stops it when it goes, a ringtone goes on until then; an app
    /// has no way to stop what it asked for, so for it a ringtone plays once,
    /// as with LunaSysMgr.
    function play(soundClass, soundFile, duration, wakeup, alert) {
        var sound = NotificationSound.resolve(soundClass, soundFile, toneTable(), fileExists);
        if (!sound)
            return null;

        if (sound.vibrate) {
            // As BannerPopupArea: vibrateNamedEffect is not implemented yet.
            callService("luna://com.palm.vibrate/vibrate", { period: 500, duration: 200 });
            return null;
        }

        if (players.length >= maxPlayers) {
            console.warn("NotificationSound: too many sounds playing, dropping " + sound.path);
            return null;
        }

        var maximum = Settings.notificationSoundDuration || 5000;
        var durationMs = NotificationSound.durationFor(sound.streamClass, duration, maximum);
        var looping = alert === true && NotificationSound.loopsFor(sound.streamClass);
        var player = playerComponent.createObject(root, {
            path: sound.path,
            sink: NotificationSound.sinkFor(sound.streamClass),
            looping: looping,
            durationMs: durationMs
        });
        players = players.concat([player]);

        player.finished.connect(function() { release(player, wakeup); });
        player.limitReached.connect(function() {
            // A sound audiod has stops only if a limit was asked for: the hold
            // alone is no reason to cut it off.
            if (durationMs > 0 || !player.heldByAudiod)
                stop(player);
            else
                player.finish();
        });

        if (wakeup)
            setDisplayAlert(true);

        if (looping) {
            player.playLocally();
            return player;
        }

        NotificationSound.play(sound.path, sound.streamClass,
            function(request, onReply) {
                callService("luna://com.webos.service.audio/playSound", request, function(response) {
                    if (response && response.returnValue) {
                        player.playbackId = response.playbackId || "";
                        player.heldByAudiod = true;
                        player.startLimit(durationMs > 0 ? durationMs : audiodHoldMs);
                    }
                    onReply(response);
                });
            },
            function() { player.playLocally(); });
        return player;
    }

    function stop(player) {
        if (!player || players.indexOf(player) === -1)
            return;
        if (player.playbackId)
            callService("luna://com.webos.service.audio/controlPlayback",
                        { playbackId: player.playbackId, requestType: "stop" });
        player.stop();
    }

    function release(player, wakeup) {
        players = players.filter(function(entry) { return entry !== player; });
        if (wakeup)
            setDisplayAlert(false);
        player.destroy();
    }

    // Lights the display for the sound, as DisplayManager::alert() did for it.
    function setDisplayAlert(on) {
        callService("luna://com.palm.display/control/alert",
                    { status: on ? "generic-activated" : "generic-deactivated" });
    }
}
