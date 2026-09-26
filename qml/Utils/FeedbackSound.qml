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

import QtQuick 2.0
import LuneOS.Service 1.0

// A named system feedback sound, as LunaSysMgr's
// SoundPlayerPool::playFeedback() played them: audiod looks the name up in
// /usr/share/systemsounds (<name>.pcm) and plays it on its feedback stream,
// at the feedback volume.
LunaService {
    name: "com.webos.surfacemanager-cardshell"
    service: "luna://com.webos.service.audio"
    method: "systemsounds/playFeedback"

    // The name under /usr/share/systemsounds, without ".pcm".
    property string soundName

    /*
     * Settings' "System Sounds" switch, which LunaSysMgr checked in
     * playFeedback() itself. Held as a property rather than read inside
     * play(): a QML singleton is created when something first reads it, and
     * reading it here means its subscription is up from the moment the shell
     * loads, instead of the first sound playing before the preference has
     * been read.
     */
    readonly property bool feedbackSoundsEnabled: SystemSounds.enabled

    function play() {
        if (!feedbackSoundsEnabled)
            return;

        call(JSON.stringify({"name": soundName}));
    }
}
