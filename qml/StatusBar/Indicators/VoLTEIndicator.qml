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

import QtQuick 2.0
import LunaNext.Common 0.1

/*
 * "VoLTE" while the voice SIM is registered with IMS for voice: calls go
 * over LTE (or 5G, or Wi-Fi) instead of falling back to 2G/3G. telephonyd
 * reports it as networkStatusQuery's extended.volte, from oFono's
 * IpMultimediaSystem Registered and VoiceCapable.
 */
BaseIndicator {
    id: volteIndicator

    imageSource: "../../images/statusbar/network/network-volte.png"
}
