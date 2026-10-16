/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0

/*
 * The compositor's defaultSeat, which the luneos-components stub does not
 * have: it records the keys the shell sends to applications instead of
 * sending them, as [qtKey, pressed] pairs.
 */
QtObject {
    property var sentKeys: []

    function sendKeyEvent(qtKey, pressed) {
        sentKeys = sentKeys.concat([[qtKey, pressed]]);
    }
}
