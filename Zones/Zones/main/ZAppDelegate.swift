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


    var needsSetup = true


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


    // MARK:- actions
    // MARK:-


    var settingsController: ZSettingsViewController? { get { return controllersManager.controllerForID(.settings) as? ZSettingsViewController } }


    @IBAction func displayPreferences(_ sender: Any?) {
        settingsController?.displayViewFor(id: .Preferences)
    }


    @IBAction func toggleSearch(_ sender: Any?) {
        gShowsSearching = !gShowsSearching

        signalFor(nil, regarding: .search)
    }


    @IBAction func displayHelp(_ sender: Any?) {
        settingsController?.displayViewFor(id: .Help)
    }


    @IBAction func printHere(_ sender: Any?) {
        editingManager.printHere()
    }
}

