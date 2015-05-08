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

.pragma library

var isTestEnvironment = true;

/* A500 alike
var displayWidth = 1024;
var displayHeight = 768;
var dpi = 148;
/**/
/*GNex alike
var displayWidth = 768;
var displayHeight = 1280;
var dpi = 311;
/**/
/* N7 alike
var displayWidth = 1280;
var displayHeight = 800;
var dpi = 216;
/**/
/* Tofe little laptop */
var displayWidth = 800;
var displayHeight = 600;
var dpi = 114;
/**/

var displayFps = true;
var fontStatusBar = "Prelude"
var showReticle = false;
var tabletUi = true;

// not used
var lunaSystemResourcesPath = "./resourcesPath";
var compatDpi = 114;
var splashIconSize = 64;
var gestureAreaHeight = 64;
var positiveSpaceTopPadding = 0;
var positiveSpaceBottomPadding = 0;

var layoutScale = dpi/132;
var gridUnit = 8;
