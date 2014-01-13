/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
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
import LunaNext 0.1

/// The status bar can be divided in three main regions: app menu, title, system indicators/system menu
/// [-- app menu -- |   --- title ---    |  -- indicators --]

Image {
    id: statusBarItem

    property Item windowManagerInstance

    source: "../images/statusbar/status-bar-background.png"

    /// general title
    Item {
        id: titleItem
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.horizontalCenter: statusBarItem.horizontalCenter

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        implicitWidth: titleText.contentWidth

        Text {
            id: titleText
            anchors.fill: parent

            horizontalAlignment: Text.AlignHCenter

            color: "white"
            font.family: Settings.fontStatusBar
            font.pixelSize: parent.height;
            font.bold: true
            text: Qt.formatDateTime(new Date(), "dd.MM.yyyy")
        }
    }

    /// app menu/cellular network provider
    Loader {
        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.left: statusBarItem.left

        anchors.topMargin: statusBarItem.height * 0.2
        anchors.bottomMargin: statusBarItem.height * 0.2

        visible: false

        Component {
            id: networkNameComponent
            Item {
                width: networkNameText.contentWidth

                Text {
                    id: networkNameText
                    anchors.fill: parent

                    horizontalAlignment: Text.AlignHCenter

                    color: "white"
                    font.family: Settings.fontStatusBar
                    font.pixelSize: parent.height;
                    font.bold: true
                    text: "myNetwork"
                }
            }
        }

        Component {
            id: appMenuComponent
            StatusBarAppMenu {
                id: appMenuItem
            }
        }

        sourceComponent: statusBarItem.state === "appSpecific" ? appMenuComponent : networkNameComponent
    }

    /// system indicators
    SystemIndicators {
        id: systemIndicatorsStatusBarItem

        anchors.top: statusBarItem.top
        anchors.bottom: statusBarItem.bottom
        anchors.right: statusBarItem.right
    }

    state: "genericStatus"

    states: [
        State {
            name: "hidden"
            PropertyChanges { target: statusBarItem; visible: false }
        },
        State {
            name: "genericStatus"
            PropertyChanges { target: statusBarItem; visible: true }
        },
        State {
            name: "appSpecific"
            PropertyChanges { target: statusBarItem; visible: true }
        }
    ]

    Connections {
        target: windowManagerInstance
        onSwitchToDashboard: {
            state = "genericStatus";
        }
        onSwitchToMaximize: {
            state = "appSpecific";
        }
        onSwitchToFullscreen: {
            state = "hidden";
        }
        onSwitchToCardView: {
            state = "genericStatus";
        }
        onSwitchToLauncherView: {
            state = "appSpecific";
        }
    }
}
