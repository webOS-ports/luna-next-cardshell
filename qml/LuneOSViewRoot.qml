/*
 * Copyright (C) 2022 Christophe Chapuis <chris.chapuis@gmail.com>
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

import QtQuick 2.6

import LunaNext.Common 0.1
import WebOSCompositorBase 1.0

Item {
    OrientationHelper {
        id: orientationHelper
        automaticOrientation: false
        transitionEnabled: false

        Loader {
            id: mainShellLoader

            property string cardShellState: mainShellLoader.state

            anchors.fill: parent

            focus: true
            onSourceChanged: Keys.forwardTo = [ mainShellLoader.item ]
        }

        BootLoader {
            shellLoader: mainShellLoader

            anchors.fill: parent
            z: 1 // above the main shell
        }
    }
}
