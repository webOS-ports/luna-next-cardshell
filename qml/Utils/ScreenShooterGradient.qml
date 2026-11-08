/*
 * Copyright (C) 2016 Herman van Hazendonk <github.com@herrie.org> 
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

import QtQuick
import QtQuick.Shapes
import LunaNext.Common 0.1

Item {
    id: screenShooterGradient
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    visible: false
    opacity: 1

    function startShootEffect()
    {
        opacityAnimator.restart();
    }

    OpacityAnimator {
        id: opacityAnimator
        target: screenShooterGradient
        from: 1
        to: 0
        duration: 500
        onStarted: screenShooterGradient.visible = true;
        onStopped: screenShooterGradient.visible = false;
    }

    // A shape the size of the item, filled with a radial gradient: a camera
    // flash that washes the whole screen out, brightest at the centre and a
    // faint warm white towards the edges. The focal point has to be put on the
    // centre by hand, it defaults to the origin.
    Shape {
        id: flash
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: flash.width / 2
                centerY: flash.height / 2
                focalX: centerX
                focalY: centerY
                centerRadius: Math.min(Settings.displayWidth, Settings.displayHeight) / 3
                GradientStop {
                    position: 0.0
                    color: "#FFFFFFFF"
                }
                GradientStop {
                    position: 0.4
                    color: "#F2FFFFFF"
                }
                GradientStop {
                    position: 1.0
                    color: "#CCFFF4DC"
                }
            }
            PathRectangle {
                width: flash.width
                height: flash.height
            }
        }
    }
}
