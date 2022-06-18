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

import QtQuick 2.5
//For future migration
import Qt5Compat.GraphicalEffects
//Should be replaced with https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html#centerRadius-prop
//import QtQuick.Shapes 1.3
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

    //FIXME migrate to: https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html#centerRadius-prop
	RadialGradient {
        horizontalRadius: Math.min(Settings.displayWidth, Settings.displayHeight) / 3
        verticalRadius: Math.min(Settings.displayWidth, Settings.displayHeight) / 3
        anchors.fill: parent
        GradientStop {
            position: 0.0
            color: "#FFFFFFFF"
        }
        GradientStop {
            position: 0.15
            color: "#FFFFD0C0"
        }
        GradientStop {
            position: 0.5
            color: "#FFFFD0F0"
        }
        GradientStop {
            position: 0.75
            color: "#FFFFD00F"
        }
        GradientStop {
            position: 1.0
            color: "#FFFFD000"
        }
    }
}
