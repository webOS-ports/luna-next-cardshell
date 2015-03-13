/*
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext.Compositor 0.1

// The compositor is exposed by the LunaNext module.
// It manages the creation/destruction of windows
// in accordance with the lifecycle of the apps.
Compositor {
    id: compositor

    width: Settings.displayWidth
    height: Settings.displayHeight

    Component.onCompleted: {
        compositor.show();
    }

    OrientationHelper {
        id: orientationHelper
        automaticOrientation: false
        transitionEnabled: false

        Loader {
            id: mainShellLoader

            property QtObject compositor: compositor
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
