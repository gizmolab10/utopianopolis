//
//  ZAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


@NSApplicationMain


class ZAppDelegate: NSResponder, ZApplicationDelegate, NSMenuDelegate {


    var needsSetup = true


    // MARK:- delegation
    // MARK:-


    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup = false

            zapplication.registerForRemoteNotifications(matching: .badge)
            signalFor(nil, regarding: .startup)
            gControllersManager.displayActivity(true)
            gOperationsManager.startup {
                gHere.grab()

                gControllersManager.displayActivity(false)
                self.signalFor(nil, regarding: .redraw)

                gOperationsManager.finishUp {
                    self.signalFor(nil, regarding: .redraw)
                }

            }
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
