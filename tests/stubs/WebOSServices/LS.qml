/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma Singleton
import QtQuick 2.0

QtObject {
    property string appId: "com.webos.surfacemanager"
    property var adhoc: ({ call: function () {} })
}
