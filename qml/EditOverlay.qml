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

import QtQuick 2.5
import LunaNext.Common 0.1

/*!
 * \brief The system-wide Select All / Cut / Copy / Paste overlay.
 *
 * Legacy had two of these and LuneOS inherited neither in a usable form: an
 * "Edit" section inside enyo.AppMenu, which only an Enyo application that asked
 * for it ever showed, and the floating selection pill, which in LuneOS exists
 * only inside Atlas. Anything else - Memos, a QML application, the browser's
 * own fields - had no way to cut, copy or paste but a keyboard shortcut, and
 * until recently not even that.
 *
 * This is the shell's own, so every application gets it. It performs the edits
 * by asking the compositor to type Ctrl+X/C/V/A at the focused surface, which
 * is why it needs nothing of the application: every toolkit already implements
 * those shortcuts, and after the input method's grab was taught to hand keys
 * back they reach the client whatever it is written in. No command channel per
 * client, and nothing new in the web runtime.
 *
 * Shown only while a text field holds the input method's focus, which is what
 * keyboardService.inputFocus reports - the same question legacy's EditMenu
 * asked to decide whether to grey its items out.
 *
 * The look is legacy's selection pill, as Atlas still draws it: a dark rounded
 * bar with a downward arrow, light text, a soft drop shadow and no inset one.
 */
Item {
    id: editOverlay

    property QtObject keyboardService: null
    property QtObject compositorInstance: null

    //! Where the pill points. Set before calling show().
    property real anchorX: width / 2
    property real anchorY: height / 2

    visible: false
    z: 1001

    //! Whether there is anything to edit. Nothing is shown without it.
    readonly property bool editable: keyboardService ? keyboardService.inputFocus : false

    function showAt(x, y) {
        if (!editOverlay.editable)
            return;

        editOverlay.anchorX = x;
        editOverlay.anchorY = y;
        editOverlay.visible = true;
    }

    function hide() {
        editOverlay.visible = false;
    }

    //! The field going away takes the overlay with it.
    onEditableChanged: if (!editOverlay.editable) editOverlay.hide()

    // A press anywhere else dismisses, the way the legacy pill did. Below the
    // pill in z order so its own buttons are hit first.
    MouseArea {
        anchors.fill: parent
        onPressed: editOverlay.hide()
    }

    Rectangle {
        id: pill

        color: "#39393b"
        radius: Units.gu(1.4)
        height: actions.height + Units.gu(1.2)
        width: actions.width + Units.gu(2)

        // Kept on screen whichever edge the anchor is near, and sitting above
        // the point rather than under the finger.
        x: Math.max(Units.gu(0.5),
                    Math.min(editOverlay.width - width - Units.gu(0.5),
                             editOverlay.anchorX - width / 2))
        y: Math.max(Units.gu(0.5), editOverlay.anchorY - height - Units.gu(1))

        Row {
            id: actions
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: [
                    { label: "Select All", command: "selectAll" },
                    { label: "Cut",        command: "cut" },
                    { label: "Copy",       command: "copy" },
                    { label: "Paste",      command: "paste" }
                ]

                delegate: Item {
                    height: label.height + Units.gu(1)
                    width: label.width + Units.gu(2)

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        color: "#f2f2f2"
                        font.family: Settings.fontStatusBar
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                        style: Text.Raised
                        styleColor: "#00000099"
                    }

                    // The separators legacy drew between the pill's buttons.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height * 0.6
                        color: "#00000066"
                        visible: index < 3
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#ffffff30"
                        visible: press.pressed
                    }

                    MouseArea {
                        id: press
                        anchors.fill: parent
                        onClicked: {
                            if (editOverlay.compositorInstance)
                                editOverlay.compositorInstance.sendEditCommand(modelData.command);

                            // Select All leaves the selection to act on, so the
                            // pill stays up for the Cut or Copy that follows.
                            if (modelData.command !== "selectAll")
                                editOverlay.hide();
                        }
                    }
                }
            }
        }
    }

    // The arrow under the pill, pointing at what the edit applies to.
    Canvas {
        width: Units.gu(1.6)
        height: Units.gu(0.9)
        x: Math.max(pill.x + Units.gu(0.5),
                    Math.min(pill.x + pill.width - width - Units.gu(0.5),
                             editOverlay.anchorX - width / 2))
        y: pill.y + pill.height - 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#39393b";
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fill();
        }
    }
}
