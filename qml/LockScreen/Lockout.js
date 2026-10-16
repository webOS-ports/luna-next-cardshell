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
 * After five wrong passcodes in a row, luna-authmanager refuses
 * matchDevicePasscode for a while - 30 seconds, doubling with each further
 * wrong one up to an hour - and says so in the reply: lockedOut true, and
 * lockoutSeconds left. While locked out it does not even check what is
 * entered, so the lock screens stop taking input and count the time down.
 */

// The seconds to wait from a matchDevicePasscode reply, 0 if not locked out.
// An older authmanager sends lockedOut without lockoutSeconds; its lockout
// was 15 seconds.
function secondsFrom(response) {
    if (!response.lockedOut)
        return 0;
    return response.lockoutSeconds > 0 ? response.lockoutSeconds : 15;
}

function waitText(seconds) {
    if (seconds < 60)
        return "Try again in " + seconds + (seconds === 1 ? " second" : " seconds");
    var minutes = Math.ceil(seconds / 60);
    return "Try again in " + minutes + (minutes === 1 ? " minute" : " minutes");
}
