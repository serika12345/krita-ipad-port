/*
 * SPDX-FileCopyrightText: 2026 Krita contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef KIS_IOS_PENCIL_INTERACTION_H
#define KIS_IOS_PENCIL_INTERACTION_H

enum class KisIOSPencilTapAction {
    SwitchEraser,
    SwitchPrevious
};

using KisIOSPencilTapHandler = void (*)(KisIOSPencilTapAction action);

void installKisIOSPencilInteraction(void *nativeView, KisIOSPencilTapHandler handler);

#endif
