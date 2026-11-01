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

// The folders an app's sound may come from. LunaSysMgr played any regular file
// an app named. Here the name reaches a media player in the shell from any app,
// so it has to be a sound where sounds live - the system's, an app's own, or
// the user's media - and not, say, a device node or a file of another's.
var soundFolders = [
    "/usr/palm/sounds/",
    "/usr/share/systemsounds/",
    "/usr/palm/applications/",
    "/media/cryptofs/apps/usr/palm/applications/",
    "/media/internal/"
];

/// Whether an app's `path` may be played. Goes by the name alone.
function isPlayablePath(path) {
    if (typeof path !== "string" || path.length === 0 || path.length > 4096)
        return false;
    if (/[\x00-\x1f\x7f]/.test(path) || /(^|\/)\.\.(\/|$)/.test(path))
        return false;
    if (!/\.(wav|pcm|mp3|ogg|oga|opus|flac|aac|m4a|amr|wma)$/i.test(path))
        return false;
    return soundFolders.some(function(folder) {
        return path.indexOf(folder) === 0;
    });
}

/**
 * What an app's soundClass and soundFile come to, as LunaSysMgr's
 * BannerMessageHandler::playSound and AlertWindow::extractSoundParams worked it
 * out: nothing (null), a vibration ({vibrate: true}), or a file on a stream
 * ({path, streamClass}). A file that cannot be played gives way to the tone the
 * user picked for the class, and that to the system's alert tone.
 *
 * tones is {ringtone, alerttone, notificationtone, fallback}; fileExists(path)
 * says whether a file is there.
 *
 * LunaSysMgr also played a popup alert that named no sound at all, on the
 * notification tone; asked for nothing here, nothing plays: LuneOS's own alerts
 * (the incoming call, the alarm) sound for themselves. Its popups also turned
 * the class "vibrate" into a notification tone, which Calendar's vibrate choice
 * cannot have meant.
 */
function resolve(soundClass, soundFile, tones, fileExists) {
    if (!soundClass && !soundFile)
        return null;
    if (soundClass === "none")
        return null;
    if (soundClass === "vibrate")
        return { vibrate: true };

    var streamClass = streamClassFor(soundClass);
    if (soundFile && isPlayablePath(soundFile) && fileExists(soundFile))
        return { path: soundFile, streamClass: streamClass };

    var tone;
    if (streamClass === "ringtones")
        tone = tones.ringtone;
    else if (streamClass === "alerts" || streamClass === "alarm" || streamClass === "calendar")
        tone = tones.alerttone;
    else
        tone = tones.notificationtone;

    var path = tone && fileExists(tone) ? tone : tones.fallback;
    if (!path || !fileExists(path))
        return null;
    return { path: path, streamClass: streamClass };
}

/// How long a sound plays, in ms; -1 for the length of the file. A notification
/// is cut off at the system's maximum, as LunaSysMgr did.
function durationFor(streamClass, duration, notificationMaximum) {
    if (duration > 0)
        return duration;
    return streamClass === "notifications" ? notificationMaximum : -1;
}

/// A ringtone goes on until it is stopped, as a popup alert's did.
function loopsFor(streamClass) {
    return streamClass === "ringtones";
}

/// `path` as the url a media player takes.
function urlFor(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

/**
 * Keeps the alert windows' sounds in step with the windows that are up: each
 * window sounds once, when it first shows, and is stopped when it goes. known
 * holds what the last call returned.
 *
 * start(window) returns a handle for stop(handle), or null when it played
 * nothing.
 */
function trackAlerts(windows, known, start, stop) {
    var tracked = [];
    known.forEach(function(entry) {
        if (windows.indexOf(entry.window) !== -1)
            tracked.push(entry);
        else if (entry.handle)
            stop(entry.handle);
    });
    windows.forEach(function(window) {
        var seen = tracked.some(function(entry) { return entry.window === window; });
        if (!seen)
            tracked.push({ window: window, handle: start(window) });
    });
    return tracked;
}
