/*
 * Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.0

/*
 * WebOSCoreCompositor's KeyFilter, which the luneos-components stubs do not
 * have; without it KeyboardActivity, and with it the whole shell, fails to
 * load on the desktop. run-tests.sh adds this to a copy of their module.
 */
QtObject {
    property var _filters: ({})

    function addKeyFilter(filter, name) {
        _filters[name] = filter;
    }

    function removeKeyFilter(name) {
        delete _filters[name];
    }
}
