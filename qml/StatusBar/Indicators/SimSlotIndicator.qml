/*
 * Copyright (C) 2013-2026 Herman van Hazendonk <github.com@herrie.org>
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

import QtQuick 2.5
import LunaNext.Common 0.1

/*
 * Small numeric badge that tells the signal bars next to it which SIM slot
 * they belong to. Only shown on devices with more than one slot, so a single
 * SIM device keeps exactly the status bar it had before.
 */
Item {
    id: simSlotIndicator

    property string label: ""
    property bool enabled: true
    // the slot currently carrying packet data is drawn solid, the other dimmed
    property bool highlighted: false

    readonly property bool __shown: enabled && label.length > 0

    width: __shown ? labelText.contentWidth + Units.gu(0.2) : 0
    visible: __shown
    clip: true

    Text {
        id: labelText

        anchors.centerIn: parent

        text: simSlotIndicator.label
        color: simSlotIndicator.highlighted ? "white" : "#AAA"
        font.family: Settings.fontStatusBar
        font.bold: simSlotIndicator.highlighted
        font.pixelSize: Math.max(1, Math.round(simSlotIndicator.height * 0.95))
    }

    Behavior on width {
        NumberAnimation { duration: 200 }
    }
}
