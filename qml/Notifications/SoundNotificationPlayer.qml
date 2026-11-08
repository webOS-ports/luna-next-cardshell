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
import QtMultimedia 6.3

import "NotificationSound.js" as NotificationSound

/*
 * One sound SoundNotifications is playing. A file audiod cannot play, an MP3
 * above all, plays here on the sink of its class, as the Phone app's ringtone
 * does: the sink is how the audio policy knows what a stream is, and so what
 * its volume and mute are. On the default sink it would be one more media
 * stream.
 */
QtObject {
    id: root

    property string path
    property string sink
    property bool looping: false
    // How long to play for, in ms; -1 for the length of the file.
    property int durationMs: -1
    readonly property int safetyLimitMs: 5 * 60 * 1000
    // Set when audiod plays it instead; then only the time limit runs here.
    property string playbackId: ""
    property bool heldByAudiod: false

    signal finished()

    function playLocally() {
        var outputs = mediaDevices.audioOutputs;
        var found = false;
        for (var i = 0; i < outputs.length && !found; i++) {
            found = String(outputs[i].id) === sink;
            if (found)
                output.device = outputs[i];
        }
        if (!found)
            console.warn("NotificationSound: no sink " + sink + ", playing on the default one");
        player.loops = looping ? MediaPlayer.Infinite : 1;
        player.source = NotificationSound.urlFor(path);
        playing = true;
        player.play();
        if (durationMs > 0)
            startLimit(durationMs);
        else if (!looping)
            startLimit(safetyLimitMs);
    }

    // limitReached() after |ms|. For a file played here it also stands in for
    // the end of the file, should the player never report one: a player that
    // hangs would hold on to one of the few there are for good.
    function startLimit(ms) {
        if (ms > 0) {
            limit.interval = ms;
            limit.start();
        }
    }

    function stop() {
        limit.stop();
        if (playing)
            player.stop();
        finish();
    }

    function finish() {
        if (done)
            return;
        done = true;
        finished();
    }

    property bool playing: false
    property bool done: false

    property list<QtObject> resources: [
        MediaDevices { id: mediaDevices },
        AudioOutput { id: output },
        MediaPlayer {
            id: player
            audioOutput: output
            onPlaybackStateChanged: {
                if (root.playing && playbackState === MediaPlayer.StoppedState)
                    root.finish();
            }
            onErrorOccurred: (error, errorString) => {
                console.warn("NotificationSound: cannot play " + root.path + ": " + errorString);
                root.finish();
            }
        },
        Timer {
            id: limit
            onTriggered: root.limitReached()
        }
    ]

    signal limitReached()
}
