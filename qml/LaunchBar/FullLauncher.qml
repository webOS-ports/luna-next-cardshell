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
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import LunaNext.Common 0.1

import "../LunaSysAPI" as LunaSysAPI


Image {
    id: fullLauncher

    property real iconSize: 64
    property real bottomMargin: 80

    function calculateAppIconHMargin(_parent, appIconWidth) {
        var nbCellsPerLine = Math.floor(_parent.width / (appIconWidth + 10));
        var remainingHSpace = _parent.width - nbCellsPerLine * appIconWidth;
        return Math.floor(remainingHSpace / nbCellsPerLine);
    }

    property real appIconWidth: iconSize*1.5
    property real appIconHMargin: calculateAppIconHMargin(fullLauncher, appIconWidth)

    property real cellWidth: appIconWidth + appIconHMargin
    property real cellHeight: iconSize + iconSize*0.4*2 // we give margin for two lines of text

    signal startLaunchApplication(string appId, string appParams)

    state: "hidden"
    visible: false
    anchors.top: parent.bottom

    source: "../images/launcher/launcher-bg.png"
    fillMode: Image.Tile

    states: [
        State {
            name: "hidden"
            AnchorChanges { target: fullLauncher; anchors.top: parent.bottom; anchors.bottom: undefined }
            PropertyChanges { target: fullLauncher; visible: false }
        },
        State {
            name: "visible"
            AnchorChanges { target: fullLauncher; anchors.top: parent.top; anchors.bottom: parent.bottom }
            PropertyChanges { target: fullLauncher; visible: true }
        }
    ]

    transitions: [
        Transition {
            to: "visible"
            reversible: true

            SequentialAnimation {
                PropertyAction { target: fullLauncher; property: "visible" }
                AnchorAnimation { easing.type:Easing.InOutQuad;  duration: 150 }
            }
        }
    ]

    ListView {
        id: tabRowList
        anchors.top: parent.top
        width: parent.width
        height: Units.gu(4)        
        orientation: ListView.Horizontal
        onCurrentIndexChanged: tabContentList.currentIndex = currentIndex
        delegate: Button {
            id: tabRowDelegate
            width: Units.gu(20)
            height: tabRowList.height
            checked: tabRowDelegate.ListView.isCurrentItem
            style: ButtonStyle {
                id: tabButtonStyle
                property string neutralButtonImage: Qt.resolvedUrl("../images/systemui/palm-notification-button.png");
                property string neutralButtonImagePressed: Qt.resolvedUrl("../images/systemui/palm-notification-button-press.png");

                background: Image {
                    source: tabButtonStyle.control.checked ? neutralButtonImagePressed: neutralButtonImage;
                    fillMode: Image.Stretch
                }
                label: Text {
                    color: "white"
                    text: tabButtonStyle.control.text
                    font.family: Settings.fontStatusBar
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            onClicked: {
                tabRowDelegate.ListView.view.currentIndex = index;
            }
            text: model.text
        }
        model: ListModel {
            ListElement { text: "Apps"; color: "green" }
            ListElement { text: "Downloads"; color: "red" }
            ListElement { text: "Favorites"; color: "green" }
            ListElement { text: "Settings"; color: "red" }
        }
    }

    ListView {
        id: tabContentList
        anchors.top: tabRowList.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: fullLauncher.bottomMargin
        width: fullLauncher.width
        clip: true
        orientation: ListView.Horizontal
        cacheBuffer: fullLauncher.width*tabRowList.model.count // don't destroy the delegates

        snapMode: ListView.SnapOneItem

        preferredHighlightBegin: 0
        preferredHighlightEnd: width
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 300
        onCurrentIndexChanged: tabRowList.currentIndex = currentIndex

        model: tabRowList.model

        delegate: Item {
            id: tabContentItem
            width: ListView.view.width
            height: ListView.view.height

            property string tabId: model.text

            GridView {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: Math.floor(fullLauncher.width / fullLauncher.cellWidth) * fullLauncher.cellWidth
                height: parent.height

                model: DraggableAppIconDelegateModel {
                        // list of icons, filtered on that tab
                        model: LunaSysAPI.ApplicationModel {
                            filter: { "launcherTab": tabContentItem.tabId }
                            includeAppsWithMissingProperty: tabContentItem.tabId === "Apps" // apps without any tab indication go to the Apps tab
                        }

                        dragParent: fullLauncher
                        dragAxis: Drag.XAndYAxis
                        iconWidth: fullLauncher.appIconWidth
                        iconSize: fullLauncher.iconSize

                        onStartLaunchApplication: fullLauncher.startLaunchApplication(appId, appParams);
                }


                cellWidth: fullLauncher.cellWidth
                cellHeight: fullLauncher.cellHeight

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x, y"; duration: 200 }
                }
            }
        }
    }
}
