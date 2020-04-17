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


class ZDesktopAppDelegate: NSResponder, NSMenuDelegate, ZApplicationDelegate {


    var needsSetup = true


    // MARK:- delegation
    // MARK:-


    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup          = false
            gDesktopAppDelegate = self

            UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraint‌​s")
            gApplication.registerForRemoteNotifications(matching: .badge)
            gControllers.startupCloudAndUI()
            gEvents.setup()
        }
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        let note = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if  note.notificationType == .query,
            let queryNote = note as? CKQueryNotification {
			
            gRemoteStorage.receiveFromCloud(queryNote)
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
            gFiles.importFile(from: file, insertInto: insertInto) { self.redrawAndSync() }
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
				 .graphMode: return gGraphEditor
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
