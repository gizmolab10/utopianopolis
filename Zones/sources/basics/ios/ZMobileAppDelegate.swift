//
//  ZMobileAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/7/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import UIKit
import CloudKit
import UserNotifications

var gAppDelegate: ZMobileAppDelegate?

@UIApplicationMain

class ZMobileAppDelegate: UIResponder, ZApplicationDelegate {

	var needsSetup = true
    var window: UIWindow?


    // MARK: - delegation
    // MARK: -

    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		if  needsSetup {
			needsSetup                                 = false
			gAppDelegate                               = self
			application.applicationSupportsShakeToEdit = true

			gStartup.startupCloudAndUI()
		}

        return true
    }


    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {}


    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		printDebug(.dError, deviceToken.description)
    }


    @nonobjc public func application(_ application: UIApplication, didRegister notificationSettings: UNNotificationSettings) {
		printDebug(.dError, notificationSettings.description)
    }


    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        performance("cloud registration error: \(error)")
    }
}

