//
//  ZDesktopAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif


var gAppDelegate: ZDesktopAppDelegate?

@NSApplicationMain

class ZDesktopAppDelegate: NSResponder, ZApplicationDelegate, ZMenuDelegate {

    var needsSetup = true

    // MARK: - delegation
    // MARK: -

    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup   = false
			gAppDelegate = self

            UserDefaults.standard.set(false, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
			gApplication?.registerForRemoteNotifications(matching: .badge)
            gStartup.startupCloudAndUI()
			gNotificationCenter.addObserver(forName: .NSUbiquityIdentityDidChange, object: nil, queue: nil) { note in
				print("remove local data and fetch user data")
			}
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {}
	
    func application(_ application: NSApplication, openFiles: StringsArray) {
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
				gRelayoutMaps()
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
			case .wEssayMode:  return gEssayEditor
			default: 	       return nil
		}
	}
    
	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let   item = iItem,
			let editor = workingEditor {
			if  editor.validateMenuItem(item) {
				editor.handleMenuItem(item)
			} else if gCDMigrationState != .normal,
					  let alert = editor.invalidMenuItemAlert(item) {
				alert.runModal()
			}
		}
	}

}

