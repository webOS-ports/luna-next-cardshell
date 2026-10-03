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
 * The bar every entry in the phone notification area sits on, in legacy
 * webOS's dashboard look - measured off a Pre3 (480 px wide): a soft vertical
 * gradient from #262626 to #363636, corners rounded by about a sixth of the
 * bar's height.
 *
 * Shared by toasts (NotificationItem) and dashboards: LunaSysMgr drew this bar
 * itself behind every dashboard, whose windows were transparent, so a
 * dashboard looks right only if the shell draws it here too.
 */
Rectangle {
    radius: height / 6
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#262626" }
        GradientStop { position: 1.0; color: "#363636" }
    }
}
