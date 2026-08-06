/*
 * SPDX-FileCopyrightText: 2026 Krita contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef KIS_IOS_LIFECYCLE_HANDLER_H
#define KIS_IOS_LIFECYCLE_HANDLER_H

enum class KisIOSLifecycleEvent {
    WillResignActive,
    DidEnterBackground,
    WillEnterForeground,
    DidBecomeActive,
    BackgroundTaskExpired,
};

using KisIOSLifecycleHandler = void (*)(KisIOSLifecycleEvent event);

void installKisIOSLifecycleHandler(KisIOSLifecycleHandler lifecycleHandler);
void finishKisIOSBackgroundTask();

#endif
