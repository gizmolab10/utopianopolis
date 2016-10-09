//
//  ZAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Cocoa
import CloudKit


@NSApplicationMain


class ZAppDelegate: NSResponder, ZApplicationDelegate {


    func applicationDidFinishLaunching(aNotification: NSNotification) {
    }


    func applicationDidBecomeActive(_ notification: Notification) {
        zapplication.clearBadge()
        zapplication.registerForRemoteNotifications(matching: .badge)
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        application.clearBadge()
        
        let note: CKQueryNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject]) as! CKQueryNotification

        if note.notificationType == .query {
            modelManager.receivedUpdateFor(note.recordID!)
        }
    }


    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
        persistenceManager.save()
        
        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        return .terminateNow
    }
}

