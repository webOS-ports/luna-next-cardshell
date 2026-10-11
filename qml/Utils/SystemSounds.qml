/*
 * Copyright (C) 2026 LuneOS contributors
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

pragma Singleton

import QtQuick 2.0
import LuneOS.System 1.0

/*
 * The "System Sounds" switch from Settings' Sounds & Alerts page.
 *
 * It is the systemSounds preference, and it is what LunaSysMgr checked in
 * SoundPlayerPool::playFeedback() before asking audiod to play a feedback
 * sound: with the switch off, nothing on the feedback stream plays. Only the
 * feedback sounds - the ringtone, the alert and notification tones, and the
 * boot and shutdown sounds are not part of it.
 *
 * A singleton so that one subscription serves every FeedbackSound in the
 * shell; there is one per sound and they are scattered across the tree.
 */
QtObject {
    id: systemSounds

    // Default on, as LunaSysMgr's Preferences did, so a sound still plays if
    // the preference has never been written or cannot be read.
    property bool enabled: true

    property var _prefs: SystemPreferences {
        clientName: "com.webos.surfacemanager-cardshell"
        keys: ["systemSounds"]

        onUpdated: (response) => {
            if (response.hasOwnProperty("systemSounds"))
                systemSounds.enabled = response.systemSounds;
        }
        onError: (message) => console.log("SystemSounds: failed to read the systemSounds preference: " + message)
    }
}
