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

// Which stream a banner's sound plays on. webOS 2.x played a notification's
// sound on its own class - alerts, notifications, ringtones - and audiod
// lowered the music while an alert or a ringtone played. Played through
// QtMultimedia the sound lands on the default stream with the music, so
// audiod cannot tell it apart; audiod's playSound opens it on the class's
// sink instead.

.pragma library

/// The stream class for a toast's soundClass, as LunaSysMgr named them.
function streamClassFor(soundClass) {
    var streamClass = soundClass;

    if (streamClass === "alert")
        streamClass = "alerts";
    else if (streamClass === "notification")
        streamClass = "notifications";
    else if (streamClass === "ringtone")
        streamClass = "ringtones";

    if (streamClass !== "alerts" &&
            streamClass !== "alarm" &&
            streamClass !== "calendar" &&
            streamClass !== "notifications" &&
            streamClass !== "ringtones" &&
            streamClass !== "feedback")
        streamClass = "notifications";

    return streamClass;
}

/**
 * The audiod sink a stream class plays on. palm-policy routes pnotifications
 * and pcalendar as alerts and palarm as a ringtone, but audiod's playSound only
 * takes the sinks it knows by name, so they are asked for by what they are
 * routed as.
 */
function sinkFor(streamClass) {
    if (streamClass === "ringtones" || streamClass === "alarm")
        return "pringtones";
    if (streamClass === "feedback")
        return "pfeedback";
    return "palerts";
}

/// Whether audiod's playSound takes the file: it plays WAV and raw PCM only.
function playsThroughAudiod(path) {
    return /\.(wav|pcm)$/.test(path || "");
}

/**
 * The playSound request for `path`. A WAV file says its own format; a raw
 * .pcm file is taken to be a system sound's, 16-bit mono at 44.1 kHz.
 */
function playSoundRequest(path, streamClass) {
    var request = { fileName: path, sink: sinkFor(streamClass) };
    if (/\.pcm$/.test(path)) {
        request.format = "PA_SAMPLE_S16LE";
        request.sampleRate = 44100;
        request.channels = 1;
    }
    return request;
}

/**
 * Plays `path`: through audiod on its class's sink when audiod takes the file,
 * otherwise - or when audiod turns it down - with `playLocally`, the banner's
 * own player, as before.
 *
 * callAudiod(request, onReply) sends the request; onReply(response) gets the
 * parsed reply, or null when the call itself failed.
 */
function play(path, streamClass, callAudiod, playLocally) {
    if (!path)
        return;

    if (!playsThroughAudiod(path)) {
        playLocally();
        return;
    }

    callAudiod(playSoundRequest(path, streamClass), function(response) {
        if (response && response.returnValue)
            return;
        console.warn("NotificationSound: audiod did not play " + path + " (" +
                     (response ? response.errorText : "no reply") +
                     "), playing it on the default stream");
        playLocally();
    });
}
