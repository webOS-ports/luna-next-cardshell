/* @@@LICENSE
*
* Copyright (C) 2013-2026 Herman van Hazendonk <github.com@herrie.org>
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* LICENSE@@@ */

import QtQuick 2.0
import LunaNext.Common 0.1

/*
 * System menu drawer for the SIM slots.
 *
 * Lists every slot with its operator and signal, lets each slot's radio be
 * switched on and off individually, and lets the user pick which slot handles
 * calls, messages and packet data. The whole element hides itself on devices
 * with a single slot, where none of these choices exist.
 */
Drawer {
    id: simMenu

    property int ident:         0
    property int internalIdent: 0

    // the TelephonyService connector instance owning the SIM model
    property var telephonyService

    readonly property string _summary: {
        if (!telephonyService)
            return "";

        var voice = telephonyService.sims.defaultVoiceSim;
        var label = telephonyService.sims.labelForSim(voice);

        if (telephonyService.sims.multiSim)
            return label.length > 0 ? label : "DUAL SIM";

        return label;
    }

    signal menuCloseRequest(int delayMs)

    width: parent.width

    // nothing here is meaningful with a single slot
    visible: telephonyService && telephonyService.sims.multiSim

    function _roleLabel(role) {
        if (!telephonyService)
            return "";

        var simId = role === "voice" ? telephonyService.sims.defaultVoiceSim :
                    role === "sms"   ? telephonyService.sims.defaultSmsSim :
                                       telephonyService.sims.defaultDataSim;

        var label = telephonyService.sims.labelForSim(simId);

        return label.length > 0 ? label : "None";
    }

    /*
     * Move a role to the next slot that actually holds a SIM. Cycling on tap
     * keeps the whole choice on one row, which is all the system menu has
     * room for; the settings app is the place for anything richer.
     */
    function _cycleRole(role) {
        if (!telephonyService)
            return;

        var current = role === "voice" ? telephonyService.sims.defaultVoiceSim :
                      role === "sms"   ? telephonyService.sims.defaultSmsSim :
                                         telephonyService.sims.defaultDataSim;

        var next = telephonyService.sims.nextPresentSim(current);
        if (next >= 0)
            telephonyService.setDefaultSim(role, next);
    }

    drawerHeader:
    MenuListEntry {
        selectable: simMenu.active
        content: Item {
            width: parent.width

            Text {
                id: simTitle
                x: ident
                anchors.verticalCenter: parent.verticalCenter
                text: "SIM"
                color: simMenu.active ? "#FFF" : "#AAA"
                font.bold: false
                font.pixelSize: FontUtils.sizeToPixels("medium")
                font.family: "Prelude"
            }

            Text {
                id: simTitleState
                x: simMenu.width - width - Units.gu(1.4)
                anchors.verticalCenter: parent.verticalCenter
                text: _summary
                width: simMenu.width - simTitle.width - Units.gu(6.0)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                color: "#AAA"
                font.pixelSize: FontUtils.sizeToPixels("small")
                font.family: "Prelude"
                font.capitalization: Font.AllUppercase
            }
        }
    }

    drawerBody:
    Column {
        spacing: 0
        width: parent.width

        MenuDivider { id: separator }

        // ---- the slots themselves; tapping one toggles its radio ----
        Repeater {
            id: simListView
            width: parent.width
            model: simMenu.telephonyService ? simMenu.telephonyService.sims : null
            delegate: simListDelegate
        }

        // ---- which slot handles what ----
        MenuListEntry {
            selectable: true
            content: Item {
                width: parent.width

                Text {
                    id: voiceLabel
                    x: ident + internalIdent
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Calls"
                    color: "#FFF"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                    font.family: "Prelude"
                }

                Text {
                    x: simMenu.width - width - Units.gu(1.4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: _roleLabel("voice")
                    width: simMenu.width - voiceLabel.width - Units.gu(6.0)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    color: "#AAA"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    font.family: "Prelude"
                    font.capitalization: Font.AllUppercase
                }
            }
            onAction: _cycleRole("voice")
        }

        MenuDivider {}

        MenuListEntry {
            selectable: true
            content: Item {
                width: parent.width

                Text {
                    id: smsLabel
                    x: ident + internalIdent
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Messages"
                    color: "#FFF"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                    font.family: "Prelude"
                }

                Text {
                    x: simMenu.width - width - Units.gu(1.4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: _roleLabel("sms")
                    width: simMenu.width - smsLabel.width - Units.gu(6.0)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    color: "#AAA"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    font.family: "Prelude"
                    font.capitalization: Font.AllUppercase
                }
            }
            onAction: _cycleRole("sms")
        }

        MenuDivider {}

        MenuListEntry {
            selectable: true
            content: Item {
                width: parent.width

                Text {
                    id: dataLabel
                    x: ident + internalIdent
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Mobile data"
                    color: "#FFF"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                    font.family: "Prelude"
                }

                Text {
                    x: simMenu.width - width - Units.gu(1.4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: _roleLabel("data")
                    width: simMenu.width - dataLabel.width - Units.gu(6.0)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    color: "#AAA"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    font.family: "Prelude"
                    font.capitalization: Font.AllUppercase
                }
            }
            onAction: _cycleRole("data")
        }
    }

    Component {
        id: simListDelegate

        Column {
            spacing: 0
            width: parent.width

            MenuListEntry {
                selectable: true
                forceSelected: model.defaultForData

                content: SimEntry {
                    x: ident + internalIdent
                    width: simMenu.width - x

                    name:         model.name
                    operatorName: model.operatorName
                    simStatus:    model.simStatus
                    registration: model.registration
                    present:      model.present
                    powered:      model.powered
                    bars:         model.bars
                }

                onAction: {
                    if (simMenu.telephonyService)
                        simMenu.telephonyService.setSimPower(model.simId, !model.powered);
                }
            }

            MenuDivider {}
        }
    }
}
