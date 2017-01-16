//
//  ZAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


@NSApplicationMain


class ZAppDelegate: NSResponder, ZApplicationDelegate, NSMenuDelegate {


    var settingsController: ZSettingsViewController? { get { return controllersManager.controllerForID(.settings) as? ZSettingsViewController }     }
    var needsSetup = true


    // MARK:- delegation
    // MARK:-


    func applicationDidBecomeActive(_ notification: Notification) {
        if needsSetup {
            zapplication.registerForRemoteNotifications(matching: .badge)
            operationsManager.startup {
                self.signalFor(nil, regarding: .redraw)
            }

            needsSetup = false
        }
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! ZStorageDict)

        if note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            cloudManager.receivedUpdateFor(queryNote.recordID!)
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
        zfileManager.save()
        
        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        return .terminateNow
    }


    // MARK:- menu delegation
    // MARK:-
    

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return !editingManager.isEditing
    }
    

    // MARK:- actions
    // MARK:-


    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        var flags = (iItem?.keyEquivalentModifierMask)!
        let   key = (iItem?.keyEquivalent)!

        if key != key.lowercased() {
            flags.insert(.shift)    // add isShift to flags
        }

        editingManager.handleKey(key.lowercased(), flags: flags, isWindow: true)
    }


    @IBAction func toggleSearch(_ iItem: NSMenuItem?) {
        if gStorageMode != .favorites {
            gShowsSearching = !gShowsSearching

            signalFor(nil, regarding: .search)
        }
    }


    @IBAction func displayPreferences(_ sender: Any?) {
        settingsController?.displayViewFor(id: .Preferences)
    }


    @IBAction func displayHelp(_ sender: Any?) {
        settingsController?.displayViewFor(id: .Help)
    }


    @IBAction func printHere(_ sender: Any?) {
        editingManager.printHere()
    }
}

