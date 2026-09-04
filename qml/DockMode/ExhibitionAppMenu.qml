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

import QtQuick 2.0
import QtQuick.Window 2.2
import LunaNext.Common 0.1

import "../StatusBar/SystemMenu"

/*
 * The exhibition mode application menu: the clocks first, then every
 * exhibition-enabled application, dropping down from the top left under the
 * status bar.
 *
 * Laid out after the original (webOS 3.0.5 exhibition mode): the panel hangs
 * flush against the left edge directly below the status bar, and each row is
 * a large icon with the application's exhibition name beside it.
 * DockModeMenuManager placed it at boundingRect().x() and swapped the status
 * bar's title for "Choose an App" while it was open, restoring the current
 * application's name on close - which is what DockMode drives here.
 *
 * Which applications appear is chosen in Settings' Exhibition page, which
 * drives luna-appmanager's dock-mode launch points; this menu only switches
 * between them and deliberately has no add/remove of its own.
 */
Item {
    id: exhibitionAppMenu

    property var enabledApps: []
    property int currentIndex: 0

    signal pageSelected(int index)

    // Entries mirror the carousel's pages exactly, so an index here is an
    // index there.
    readonly property var entries: [{"appId": "", "title": "Time", "icon": ""}].concat(enabledApps)

    readonly property bool isOpen: state === "visible"

    // The original was a fixed 320px against a 1024px panel; keep near that
    // proportion without swallowing a narrow phone screen.
    width: Math.min(Units.gu(30), Screen.width * 0.72)
    height: Math.min(menuColumn.height + Units.gu(1.2), Screen.height - Units.gu(8))

    state: "hidden"
    visible: false
    // The list slides out from behind the status bar, so it has to be clipped
    // to the panel.
    clip: true

    function toggle() {
        // With no application enabled there is only the clock page, so there
        // is nothing to switch between.
        if (entries.length < 2)
            return;

        state = (state === "visible") ? "hidden" : "visible";
    }

    function close() {
        state = "hidden";
    }

    BorderImage {
        anchors.fill: parent
        source: "../images/menu-dropdown-bg.png"
        border { left: 30; top: 10; right: 30; bottom: 30 }
    }

    Column {
        id: menuColumn

        y: Units.gu(0.4)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Units.gu(0.4)
        anchors.rightMargin: Units.gu(0.4)

        Repeater {
            model: exhibitionAppMenu.entries

            delegate: Column {
                id: entryColumn
                width: menuColumn.width

                readonly property bool isClock: modelData.appId.length === 0

                // The same divider the system menu uses, but with the asset
                // resolved from this file: MenuDivider carries a relative
                // source that resolves against the importing directory, which
                // lands outside the image folder from here.
                Image {
                    visible: index > 0
                    width: parent.width - Units.gu(0.4)
                    height: Units.gu(0.2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: Qt.resolvedUrl("../images/menu-divider.png")
                }

                MenuListEntry {
                    // Taller than a system menu row: the original gave each
                    // entry a 48px icon in a row half again as tall.
                    height: Units.gu(6)
                    forceSelected: index === exhibitionAppMenu.currentIndex
                    menuPosition: index === 0 ? 1
                                  : (index === exhibitionAppMenu.entries.length - 1 ? 2 : 0)

                    content: Item {
                        width: menuColumn.width
                        height: Units.gu(5)

                        Image {
                            id: entryIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Units.gu(1)
                            width: Units.gu(4)
                            height: Units.gu(4)
                            fillMode: Image.PreserveAspectFit
                            source: entryColumn.isClock
                                    ? Qt.resolvedUrl("../images/dockmode/time-icon-48x48.png")
                                    : (modelData.icon && modelData.icon.length > 0
                                       ? modelData.icon
                                       : Qt.resolvedUrl("../images/default-app-icon.png"))
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: entryIcon.right
                            anchors.leftMargin: Units.gu(1)
                            anchors.right: parent.right
                            anchors.rightMargin: Units.gu(1)
                            text: modelData.title
                            color: "#FFFFFF"
                            font.family: "Prelude"
                            font.pixelSize: Units.gu(1.8)
                            elide: Text.ElideRight
                        }
                    }

                    onAction: {
                        exhibitionAppMenu.pageSelected(index);
                        exhibitionAppMenu.close();
                    }
                }
            }
        }
    }

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: exhibitionAppMenu; visible: false }
            PropertyChanges { target: menuColumn; y: -menuColumn.height }
        },
        State {
            name: "visible"
            PropertyChanges { target: exhibitionAppMenu; visible: true }
            PropertyChanges { target: menuColumn; y: Units.gu(0.4) }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"; to: "visible"
            SequentialAnimation {
                PropertyAction { target: exhibitionAppMenu; property: "visible" }
                NumberAnimation { target: menuColumn; property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
        },
        Transition {
            from: "visible"; to: "hidden"
            SequentialAnimation {
                NumberAnimation { target: menuColumn; property: "y"; duration: 200; easing.type: Easing.InCubic }
                PropertyAction { target: exhibitionAppMenu; property: "visible" }
            }
        }
    ]
}
