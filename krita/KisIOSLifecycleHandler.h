/*
 * SPDX-FileCopyrightText: 2026 Krita contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef KIS_IOS_LIFECYCLE_HANDLER_H
#define KIS_IOS_LIFECYCLE_HANDLER_H

using KisIOSBackgroundHandler = void (*)();

void installKisIOSLifecycleHandler(KisIOSBackgroundHandler backgroundHandler);

#endif
