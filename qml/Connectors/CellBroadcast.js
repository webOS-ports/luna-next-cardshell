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

// Which cell broadcasts are public warnings, and which sound the attention
// tone. voicecall-manager decides the tone against its channel catalog, so the
// country's channels and the user's categories are its business: a broadcast
// it wants sounded carries the attention properties, and it leaves them off
// when the tone file is not there. The warning has to reach the screen either
// way, hence the second test here.

.pragma library

// Channels whose tone sounds through the mute: 4371, which NL-Alert uses for
// every alert, and 4372. Android's Dutch configuration marks the same two
// override_dnd. Not tied to the country, so a mute abroad gives way as well.
var throughMuteTopics = [4371, 4372];

// 3GPP TS 23.041 9.4.1.2.2: ETWS from 0x1100, CMAS and EU-Alert up to 0x112F.
// Past that are the geo-fencing trigger (4400), which is no message for people,
// and identifiers not assigned yet.
var firstWarningTopic = 4352;
var lastWarningTopic = 4399;

/// The tone file voicecall-manager wants played for this broadcast, or "".
function attentionSoundFile(properties) {
    var file = properties ? properties.CellBroadcastAttentionSoundFile : "";
    return file ? String(file) : "";
}

/// Whether this broadcast's tone sounds even with the phone muted.
function soundsThroughMute(properties) {
    return !!properties && throughMuteTopics.indexOf(properties.Topic) !== -1;
}

/// Whether a broadcast is a warning for the screen, not an ordinary one.
function isPublicWarning(properties) {
    if (!properties)
        return false;
    if (attentionSoundFile(properties).length > 0)
        return true;
    // ofono's EmergencyBroadcast (ETWS) names a type and has no topic.
    if (properties.EmergencyType !== undefined)
        return true;
    var topic = properties.Topic;
    return topic >= firstWarningTopic && topic <= lastWarningTopic;
}

/**
 * Whether this one was seen less than windowMs ago, noting it if not.
 *
 * A warning is repeated by the network as long as it holds, and a dual SIM
 * phone hears it on both modems. `seen` is a map of key to time, which this
 * also prunes. The topic is part of the key because the local language and
 * the additional language go out as separate messages.
 */
function isRepeat(seen, topic, text, now, windowMs) {
    for (var old in seen) {
        if (now - seen[old] >= windowMs)
            delete seen[old];
    }
    var key = topic + "\n" + text;
    if (seen[key] !== undefined)
        return true;
    seen[key] = now;
    return false;
}
