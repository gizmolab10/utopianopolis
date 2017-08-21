//
//  ZAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Cocoa
import CloudKit


@NSApplicationMain


class ZAppDelegate: NSResponder, ZApplicationDelegate, NSMenuDelegate {


    var needsSetup = true


    // MARK:- delegation
    // MARK:-


    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup = false

            UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraint‌​s")
            zapplication.registerForRemoteNotifications(matching: .badge)
            gControllersManager.startupDataAndUI()
        }
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! ZStorageDict)

        if note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            gRemoteStoresManager.receivedUpdateFor(queryNote.recordID!)
        }
    }


    func applicationDidFinishLaunching(aNotification: NSNotification) {
    }


    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
        gFileManager.save(to: gStorageMode)
        
        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        return .terminateNow
    }


    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        gEditingManager.handleMenuItem(iItem)
    }

}
