/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
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

/*
 * The applications exhibition mode is currently hosting.
 *
 * An exhibition application ought to carry its own window type
 * (_WEBOS_WINDOW_TYPE_DOCK), which keeps it out of the card stack on its own.
 * Not every application will: the type is set by the client, so one launched
 * by a runtime that doesn't know about dock mode still comes up as an
 * ordinary card. This list lets the card views drop those too, so exhibition
 * mode never leaves a stray card behind either way.
 */
QtObject {
    id: exhibitionState

    // Window type an exhibition application should carry. Kept here so the
    // carousel and the card views agree on the spelling.
    readonly property string dockWindowType: "_WEBOS_WINDOW_TYPE_DOCK"

    // appIds exhibition mode currently owns.
    property var ownedAppIds: []

    // Bumped whenever ownedAppIds changes, so window models can re-filter -
    // assigning a JS array doesn't reliably notify on its own.
    property int revision: 0

    function own(appId) {
        if (!appId || exhibitionState.ownedAppIds.indexOf(appId) >= 0)
            return;

        var updated = exhibitionState.ownedAppIds.slice();
        updated.push(appId);
        exhibitionState.ownedAppIds = updated;
        exhibitionState.revision++;
    }

    function release(appId) {
        var index = exhibitionState.ownedAppIds.indexOf(appId);
        if (index < 0)
            return;

        var updated = exhibitionState.ownedAppIds.slice();
        updated.splice(index, 1);
        exhibitionState.ownedAppIds = updated;
        exhibitionState.revision++;
    }

    function releaseAll() {
        if (exhibitionState.ownedAppIds.length === 0)
            return;

        exhibitionState.ownedAppIds = [];
        exhibitionState.revision++;
    }

    function owns(appId) {
        return exhibitionState.ownedAppIds.indexOf(appId) >= 0;
    }

    // True for a surface the card views should leave alone: either it carries
    // the dock window type, or it belongs to an application exhibition mode
    // is currently hosting.
    function isExhibitionWindow(surfaceItem) {
        if (!surfaceItem)
            return false;

        return surfaceItem.type === exhibitionState.dockWindowType ||
               exhibitionState.owns(surfaceItem.appId);
    }
}
