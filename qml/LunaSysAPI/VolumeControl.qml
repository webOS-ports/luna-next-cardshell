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
import LunaNext.Common 0.1

Item {
    id: volumeControl

    Keys.onVolumeUpPressed: {
        volumeControl.volumeUp();
    }

    Keys.onVolumeDownPressed: {
        volumeControl.volumeDown();
    }

    function volumeUp() {
        audioService.call("luna://org.webosports.audio/volumeUp", "{}", null, null);
    }

    function volumeDown() {
        audioService.call("luna://org.webosports.audio/volumeDown", "{}", null, null);
    }

    LunaService {
        id: audioService
        name: "org.webosports.luna"
        usePrivateBus: true
    }
}
