/*
 * Copyright (C) 2013 Christophe Chapuis <chris.chapuis@gmail.com>
 * Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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

.pragma library

Qt.include("UnitsStub.js")

function modularScale(size) {
    if (size == "xx-small" || size == "8pt") {
        return 0.5714;
    } else if (size == "x-small" || size == "10pt") {
        return 0.7143;
    } else if (size == "small" || size == "12pt") {
        return 0.8571;
    } else if (size == "13pt") {
        return 0.9286;
    } else if (size == "medium" || size == "14pt") {
        return 1.0;
    } else if (size == "15pt") {
        return 1.0714;
    } else if (size == "16pt") {
        return 1.1429;
    } else if (size == "17pt") {
        return 1.2143;
    } else if (size == "18pt") {
        return 1.2857;
    } else if (size == "large" || size == "20pt") {
        return 1.4286;
    } else if (size == "22pt") {
        return 1.5714;
    } else if (size == "24pt") {
        return 1.7143;
    } else if (size == "26pt") {
        return 1.8571;
    } else if (size == "28pt") {
        return 2.0;
    } else if (size == "30pt") {
        return 2.1429;
    } else if (size == "x-large" || size == "32pt") {
        return 2.2857;
    } else if (size == "36pt") {
        return 2.5714;
    } else if (size == "48pt") {
        return 3.4286;
    } else if (size == "72pt") {
        return 5.1429;
    }
    return 0.0;
}

function sizeToPixels(size) {
    return modularScale(size) * dp(14);
}
