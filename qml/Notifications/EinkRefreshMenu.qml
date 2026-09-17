/*
 * Copyright (C) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.0
import LunaNext.Common 0.1
import "../Utils"

/*
 * The E Ink refresh menu: the panel's refresh speeds and a full refresh, in
 * the shape of the power menu. Opened by holding the refresh key (see
 * EinkRefresh), the way stock Android opens Minimal's quick settings.
 */
Item {
    id: root

    // The EinkRefresh connector this menu drives.
    property var eink

    visible: false

    property real contentMargin: Units.gu(2)
    height: menuColumn.height + contentMargin

    function show() {
        root.visible = true;
    }

    Rectangle {
        radius: 10
        color: "black"
        opacity: 0.8
        anchors.centerIn: menuColumn
        width: root.width
        height: root.height
    }

    Column {
        id: menuColumn
        property real buttonsHeight: Units.gu(4)

        anchors.top: root.top
        width: root.width - contentMargin

        Text {
            width: menuColumn.width
            height: menuColumn.buttonsHeight
            text: "Refresh Speed"
            color: "white"
            font.pixelSize: FontUtils.sizeToPixels("medium")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root.eink ? root.eink.modes : []

            Column {
                width: menuColumn.width

                ActionButton {
                    width: menuColumn.width
                    height: menuColumn.buttonsHeight
                    caption: modelData.label
                    // The current speed is the one drawn as the affirmative
                    // (highlighted) button.
                    affirmative: root.eink && root.eink.mode === modelData.id
                    alternative: !affirmative
                    onAction: {
                        root.visible = false;
                        root.eink.setMode(modelData.id);
                    }
                }
                Item {
                    height: Units.gu(1) / 2
                    width: menuColumn.width
                }
            }
        }

        ActionButton {
            width: menuColumn.width
            height: menuColumn.buttonsHeight
            caption: "Refresh Screen Now"
            onAction: {
                root.visible = false;
                root.eink.refresh();
            }
        }
        Item {
            height: Units.gu(1) / 2
            width: menuColumn.width
        }
        ActionButton {
            width: menuColumn.width
            height: menuColumn.buttonsHeight
            caption: "Cancel"
            negative: true
            onAction: root.visible = false
        }
    }
}
