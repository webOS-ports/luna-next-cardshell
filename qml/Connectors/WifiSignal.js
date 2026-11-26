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

.pragma library

/*
 * How many bars a Wi-Fi network's strength (connman's 0-100) is drawn with,
 * in the status bar and in the system menu's network list alike. The two
 * used to count differently - the menu a bar per 25, the status bar this
 * scale - so the network you were on showed 2 bars in the menu and 3 up top.
 *
 * This is the status bar's scale: any signal at all is at least one bar, and
 * it tops out at the 3 the icons go to (the menu's strength/25 asked for a
 * wifi-4.png that does not exist at full strength).
 */
function bars(strength) {
    if (strength >= 50)
        return 3;
    if (strength >= 34)
        return 2;
    if (strength > 0)
        return 1;
    return 0;
}
