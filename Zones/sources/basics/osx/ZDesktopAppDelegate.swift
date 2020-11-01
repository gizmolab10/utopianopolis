//
//  ZDesktopAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Cocoa
import CloudKit


var gDesktopAppDelegate: ZDesktopAppDelegate?


@NSApplicationMain

class ZDesktopAppDelegate: ZAppDelegate, NSMenuDelegate {

    var needsSetup = true

    // MARK:- delegation
    // MARK:-

    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup          = false
            gDesktopAppDelegate = self

            UserDefaults.standard.set(false, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
            gApplication.registerForRemoteNotifications(matching: .badge)
            gStartup.startupCloudAndUI()
            gEvents.setup()
        }
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        if  let note = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification {
            gRemoteStorage.receiveFromCloud(note)
        }
    }

	
    func application(_ application: NSApplication, openFiles: [String]) {
        var insertInto = gSelecting.currentMoveable
        
        if  insertInto.databaseID != .mineID {
            if  let mineRoot = gMineCloud?.rootZone {
                insertInto   = mineRoot
            } else {
                return
            }
        }
        
        for file in openFiles {
            insertInto.importFile(from: file) { gRedrawMaps() }
        }
    }
	

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        printDebug(.dError, "hah!")
    }


    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // printDebug(.dError, deviceToken)
    }


    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        printDebug(.dError, "\(error)")
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
		gFiles.writeAll()

        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }


	var workingEditor: ZBaseEditor? {
		switch gWorkMode {
			case .editIdeaMode,
				 .mapMode: return gMapEditor
//			case .noteMode:  return gEssayEditor
			default: 	     return nil
		}
	}

    open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
        return workingEditor?.isValid(menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask) ?? true
    }
    
    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		if  let item = iItem,
			let e = workingEditor,
			validateMenuItem(item) {
			e.handleMenuItem(item)
		}
    }

}
