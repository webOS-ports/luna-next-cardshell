/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2013 Simon Busch <morphis@gravedo.de>
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

ShaderEffect {
    // radius, goes from 0 to width/2
    property real radius
    property alias sourceItem: cornerShaderSource.sourceItem
    property variant source: ShaderEffectSource {
        id: cornerShaderSource
        anchors.fill: parent
        hideSource: true
    }

    property size center: Qt.size(0.5, 0.5)
    property size start: Qt.size(0.5 - radius/width, 0.5 - radius/height)
    property real delta: 0.05
    property real active: 1
    vertexShader: ":/corner_shader.vert.gsb"
    fragmentShader: ":/corner_shader.frag.gsb"
}
