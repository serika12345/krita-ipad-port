/*
 * SPDX-FileCopyrightText: 2026 Krita contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#import <UIKit/UIKit.h>

#include <QDebug>

#include "KisIOSLifecycleHandler.h"

namespace
{
KisIOSBackgroundHandler s_backgroundHandler = nullptr;
id s_backgroundObserver = nil;
id s_foregroundObserver = nil;

void saveRecoveryStateBeforeBackgrounding()
{
    if (!s_backgroundHandler) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;
    UIBackgroundTaskIdentifier backgroundTask =
        [application beginBackgroundTaskWithName:@"Krita autosave recovery"
                               expirationHandler:^{
        qWarning() << "iPadOS background time expired while saving recovery data";
    }];

    s_backgroundHandler();

    if (backgroundTask != UIBackgroundTaskInvalid) {
        [application endBackgroundTask:backgroundTask];
    }
}
}

void installKisIOSLifecycleHandler(KisIOSBackgroundHandler backgroundHandler)
{
    if (s_backgroundObserver) {
        return;
    }

    s_backgroundHandler = backgroundHandler;
    NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;

    // Autosave while the process still has foreground execution time, then
    // keep the save alive briefly if iPadOS completes the transition first.
    s_backgroundObserver = [notificationCenter
        addObserverForName:UIApplicationWillResignActiveNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *) {
                    saveRecoveryStateBeforeBackgrounding();
                }];

    s_foregroundObserver = [notificationCenter
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *) {
                    // Qt restores the surface and event delivery for the
                    // existing window. Keeping this observer makes that
                    // lifecycle boundary explicit in the device log.
                    qInfo() << "iPadOS returned Krita to the foreground";
                }];
}
