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
import LunaNext.Common 0.1
import LuneOS.System 1.0

/*
 * How notifications look and where they are, from Settings' Notifications page.
 *
 * notificationStyle is "phone", "tablet" or "auto": the rows as webOS 2.2.4
 * drew them on a phone - an icon pill and a text pill - or as webOS 3.0 did
 * on the TouchPad, one card. notificationLocationPortrait and
 * notificationLocationLandscape are "bottom", "top" or "auto": the list above
 * the gesture area, as on a phone, or dropping from the status bar, as on a
 * tablet. Their banners go with the list.
 *
 * "auto", and anything else, is what the device is: TabletUi. Except that a
 * phone held sideways has its notifications at the top, as Lunacy (the webOS
 * look on Android) has them: across a landscape screen a list over the
 * gesture area takes height the cards are short of.
 *
 * A singleton so that one subscription serves the rows, the two areas and
 * the dismiss area, which are scattered across the tree.
 */
QtObject {
    id: notificationLayout

    // Set by CardsArea, which is the space that turns with the screen.
    property bool landscape: false

    readonly property string style: _string(_prefs.values.notificationStyle)
    readonly property string location: _string(landscape ? _prefs.values.notificationLocationLandscape
                                                          : _prefs.values.notificationLocationPortrait)

    readonly property bool tabletStyle: resolveTabletStyle(style, Settings.tabletUi)
    readonly property bool atTop: resolveAtTop(location, Settings.tabletUi, landscape)

    function resolveTabletStyle(style, tabletUi) {
        if (style === "tablet")
            return true;
        if (style === "phone")
            return false;
        return !!tabletUi;
    }

    function resolveAtTop(location, tabletUi, landscape) {
        if (location === "top")
            return true;
        if (location === "bottom")
            return false;
        return !!tabletUi || !!landscape;
    }

    /*
     * Whether the screen is held sideways. A screen that is wider than it is
     * high is; on a square one, which is the same either way, it is turned a
     * quarter from how it is made (OrientationHelper's 90 or 270). The angle
     * animates as the shell turns, so it counts as turned from halfway.
     */
    function isLandscape(width, height, angle) {
        if (width !== height)
            return width > height;
        return Math.abs(Math.round((angle || 0) / 90)) % 2 === 1;
    }

    function _string(value) {
        return typeof value === "string" ? value : "auto";
    }

    property var _prefs: SystemPreferences {
        clientName: "com.webos.surfacemanager.cardshell"
        keys: ["notificationStyle", "notificationLocationPortrait", "notificationLocationLandscape"]

        onError: (message) => console.log("NotificationLayout: failed to read the notification preferences: " + message)
    }
}
