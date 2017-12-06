//
//  ZMobileAppDelegate.swift
//  iFocus
//
//  Created by Jonathan Sand on 7/7/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import UIKit
import CloudKit
import HockeySDK
import UserNotifications


@UIApplicationMain


class ZMobileAppDelegate: UIResponder, ZApplicationDelegate {


    var window: UIWindow?


    // MARK:- delegation
    // MARK:-

    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        application.applicationSupportsShakeToEdit = true
        BITHockeyManager.shared().configure(withIdentifier: "0d601d64398142a5a39ba45512035130")
        // Do some additional configuration if needed here
        BITHockeyManager.shared().start()
        BITHockeyManager.shared().authenticator.authenticateInstallation()

     // application.registerUserNotificationSettings(.badgeSetting)
        application.registerForRemoteNotifications()
        gControllersManager.startupCloudAndUI()

        return true
    }


    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! ZStorageDict)

        if note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            gRemoteStoresManager.receivedUpdateFor(queryNote.recordID!)
        }
    }


    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    @nonobjc public func application(_ application: UIApplication, didRegister notificationSettings: UNNotificationSettings) {
        // print(notificationSettings)
    }


    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        performance("cloud registration error: \(error)")
    }
}

