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
    vertexShader: "
                    uniform highp mat4 qt_Matrix;
                    attribute highp vec4 qt_Vertex;
                    attribute highp vec2 qt_MultiTexCoord0;
                    varying highp vec2 textureCoords;
                    void main() {
                        textureCoords = qt_MultiTexCoord0;
                        gl_Position = qt_Matrix * qt_Vertex;
                    }"
    fragmentShader: "
                varying highp vec2 textureCoords;
                uniform sampler2D source;
                uniform lowp float qt_Opacity;
                uniform highp vec2 start;
                uniform highp vec2 center;
                uniform highp float delta;
                uniform highp float active;
                void main() {
                    highp vec2 Coord  = max((abs(textureCoords - center) - start) / (center - start), vec2(0.0));
                    lowp float Alpha = smoothstep(1.0, 1.0 - delta, length(Coord));
                    gl_FragColor = vec4(texture2D(source, textureCoords).rgb * Alpha * active, Alpha) * qt_Opacity;
                }"
}
