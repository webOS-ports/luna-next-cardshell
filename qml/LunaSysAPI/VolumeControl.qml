/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
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
import LunaNext.Shell 0.1

Item {
    id: volumeControl

    VolumeKeys {
        onVolumeUp: handleVolumeUp()
        onVolumeDown: handleVolumeDown()
    }

    function handleVolumeUp() {
        audioService.call("luna://org.webosports.service.audio/volumeUp", "{}", null, null);
    }

    function handleVolumeDown() {
        audioService.call("luna://org.webosports.service.audio/volumeDown", "{}", null, null);
    }

    function setMute(mute) {
        audioService.call("luna://org.webosports.service.audio/setMute", JSON.stringify({"mute":mute}), null, null);
    }

    LunaService {
        id: audioService
        name: "org.webosports.luna"
        usePrivateBus: true
    }
}
