//
//  ZAppDelegate.swift
//  PadZones
//
//  Created by Jonathan Sand on 7/7/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import UIKit
import CloudKit


@UIApplicationMain


class ZAppDelegate: UIResponder, ZApplicationDelegate {


    var window: UIWindow?


    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let     type = UIUserNotificationType.badge
        let settings = UIUserNotificationSettings(types: type, categories: nil)

        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        modelManager.resetBadgeCounter()

        return true
    }


    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! ZStorageDict)

        if note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            modelManager.receivedUpdateFor(queryNote.recordID!)
        }
    }


    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    public func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        // print(notificationSettings)
    }


    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("notification registration error: \(error)")
    }
}

