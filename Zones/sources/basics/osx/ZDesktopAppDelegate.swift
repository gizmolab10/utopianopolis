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

//			UserDefaults.standard.set(false, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
//			UserDefaults.standard.synchronize()
			gApplication?.registerUserInterfaceItemSearchHandler(gHelpSearchDelegate) // so help search box functions as expected
			gMainWindow?.acceptsMouseMovedEvents = true                               // so hover detection functions as expected
            gStartup.grandStartup()
        }
    }

	func applicationDidResignActive(_ notification: Notification) {
		gStartup.captureElapsedTime()
	}

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
		print("remote note")
	}
	
    func application(_ application: NSApplication, openFiles: StringsArray) {
        var zone = gSelecting.currentMoveable
        
        if !zone.userCanWrite {
			if  let candidate = gMineCloud?.hereZoneMaybe ?? gMineCloud?.rootZone {
				zone          = candidate
            } else {
                return
            }
        }

		if  zone.databaseID != gDatabaseID {
			gToggleDatabaseID()
		}

        for file in openFiles {
			zone.importFile(from: file) {
				gRelayoutMaps()
			}
        }
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        printDebug(.dError, "hah!")
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		printDebug(.dRemote, deviceToken.base64EncodedString())
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        printDebug(.dError, "\(error)")
    }

    func applicationWillTerminate(aNotification: NSNotification) {}

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		gSaveContext()
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

}

