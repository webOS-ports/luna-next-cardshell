/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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
import LunaNext 0.1

import "../Utils"

import "WindowManagerServices.js" as WindowManagerServices

Item {
    id: windowManager

    signal switchToDashboard
    signal switchToCardView
    signal switchToMaximize(Item window)
    signal switchToFullscreen(Item window)
    signal switchToLauncherView

    // utility functions that may be useful when we have dashboard apps
    function nbRegisteredTapActions() {
        return WindowManagerServices.nbRegisteredTapActions();
    }

    function addTapAction(actionID, actionFct, actionData) {
        return WindowManagerServices.addTapAction(actionID, actionFct, actionData);
    }

    function removeTapAction(actionID) {
        return WindowManagerServices.removeTapAction(actionID);
    }

    function doNextTapAction() {
        return WindowManagerServices.doNextTapAction();
    }
}
