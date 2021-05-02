//
//  ZDesktopAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Cocoa
import CloudKit

var gAppDelegate: ZDesktopAppDelegate?

@NSApplicationMain

class ZDesktopAppDelegate: NSResponder, ZApplicationDelegate, ZMenuDelegate {

    var needsSetup = true

    // MARK:- delegation
    // MARK:-

    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup   = false
			gAppDelegate = self

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
        var parent = gSelecting.currentMoveable
        
        if !parent.userCanWrite {
			if  let candidate = gMineCloud?.hereZoneMaybe ?? gMineCloud?.rootZone {
				parent        = candidate
            } else {
                return
            }
        }

		if  parent.databaseID != gDatabaseID {
			gToggleDatabaseID()
		}

        for file in openFiles {
			parent.importFile(from: file) {
				gRedrawMaps()
			}
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
		if  gIsHelpFrontmost {
			return gHelpEditor
		}

		switch gWorkMode {
			case .wEditIdeaMode,
				 .wMapMode:    return gMapEditor
//			case .wEssayMode:  return gEssayEditor
			default: 	       return nil
		}
	}
    
    @IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem,
			let    e = workingEditor,
			e.validateMenuItem(item) {
			e  .handleMenuItem(item)
		}
    }

}
