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

Item {
    id: indicatorRoot

    property Image indicatorImage;
    property real originalWidth: indicatorImage.width

    width: indicatorImage.width

    clip: true

    Component.onCompleted: {
        indicatorImage.anchors.fill = undefined;
        indicatorImage.anchors.left = indicatorRoot.left;
        indicatorImage.anchors.top = indicatorRoot.top;
        indicatorImage.anchors.bottom = indicatorRoot.bottom;
        indicatorImage.sourceSize.height = Qt.binding(function() { return indicatorRoot.height*0.8 });
    }
}
