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

    function play() {
        call(JSON.stringify({"name": soundName}));
    }
}
