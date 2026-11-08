/*
 * Copyright (C) 2026 alan-morford <alan-morford@users.noreply.github.com>
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

/*
 * Collapses the expanded (phone) notification area on a tap anywhere above it.
 *
 * Opening it registers a tap action, but tap actions only run for a tap on
 * the gesture area - a tap anywhere else left the notifications expanded
 * until that was found. The press is taken, so what is underneath does not
 * also react to a tap that only meant "close the notifications"; the area
 * exists only while they are expanded.
 *
 * Swiping up for the launcher, or into Just Type, does not go through this
 * area at all - those collapse it too, rather than leave the notifications
 * expanded under the launcher.
 *
 * The tablet's notification area lives in the status bar and closes on an
 * outside tap by itself (its InverseMouseArea); notificationArea is null there
 * and this stays off.
 */
MouseArea {
    id: dismissArea

    // the phone NotificationArea, or null
    property Item notificationArea: null
    // the Launcher, for fullLauncherVisible and justTypeLauncherActive
    property Item launcher: null

    // Item.visible reads as false while the Loader holding the area is hidden
    // (under the lock screen).
    enabled: notificationArea !== null && notificationArea.state === "open" &&
             notificationArea.visible
    visible: enabled

    onPressed: dismissArea.collapse()

    // NotificationArea drops its tap action itself when it leaves "open".
    function collapse() {
        if (notificationArea && notificationArea.state === "open")
            notificationArea.minimizeNotificationArea();
    }

    Connections {
        target: dismissArea.launcher
        function onFullLauncherVisibleChanged() {
            if (dismissArea.launcher.fullLauncherVisible)
                dismissArea.collapse();
        }
        function onJustTypeLauncherActiveChanged() {
            if (dismissArea.launcher.justTypeLauncherActive)
                dismissArea.collapse();
        }
    }
}
