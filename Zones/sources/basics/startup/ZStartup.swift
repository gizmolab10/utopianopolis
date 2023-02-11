//
//  ZStartup.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gStartup = ZStartup()

class ZStartup: NSObject {

	func startupCloudAndUI() {

		gPrintModes                          = []
		gDebugModes                          = []
		gCoreDataMode                        = []
//		gPrintModes  .insert(.dTime)
		gCoreDataMode.insert(.dNoCloudKit)
		gDebugModes  .insert(.dNoSubscriptions)
		gDebugModes  .insert(.dHideNoteVisibility)

		gRefusesFirstResponder               = true			// WORKAROUND new feature of mac os x, prevents crash by ignoring user input
		gHelpWindowController                = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController
		gCDMigrationState                    = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .migrateFileData : .firstTime
		gWorkMode                            = .wStartupMode

		if  gCDMigrationState != .normal {
			gHereRecordNames = kDefaultRecordNames
		}

		gNotificationCenter.addObserver(forName: .NSUbiquityIdentityDidChange, object: nil, queue: nil) { note in
			print("remove local data and fetch user data")
		}

		gApplication?.registerForRemoteNotifications(matching: .badge)
		setStartupTime()
		gRemoteStorage.clear()
		gMainWindow?.revealEssayEditorInspectorBar(false)
		gSearching.setSearchStateTo(.sNot)
		gSignal([.spMain, .spStartupStatus])
		gTimers.startTimer(for: .tStartup)
		gEvents.controllerSetup(with: nil)

		gBatches.startUp { iSame in
			FOREGROUND { [self] in
				gRefusesFirstResponder = false
				gHasFinishedStartup    = true
				gCurrentHelpMode       = .proMode // so prepare strings will work correctly for all help modes

				if  gIsStartupMode {
					gSetMapWorkMode()
				}

				if  gNoSubscriptions {
					gDetailsController?.removeViewFromStack(for: .vSubscribe)
				} else {
					gProducts.fetchProductData()
				}

				gRefreshPersistentWorkMode()
				gRemoteStorage.setup()
				gRefreshCurrentEssay()
				gHereMaybe?.grab()

				FOREGROUND(after: 0.1) { [self] in
					if  gCDMigrationState != .normal {
						gSaveContext()
					}

					gIsReadyToShowUI = true

					gSignal([.sLaunchDone])

					requestFeedback() {
						gTimers.startTimers(for: [.tCloudAvailable, .tRecount, .tPersist, .tHover]) // .tLicense
						gSignal([.sSwap, .spMain, .spCrumbs, .spRelayout, .spDataDetails, .spPreferences])

						gMainController?.helpButton?.isHidden = false
					}
				}
			}
		}
	}

	var launchedEnoughTimes: Bool {
		gStartupCount = gStartupCount + 1

		return gStartupCount > 10
	}

	func requestFeedback(_ onCompletion: @escaping Closure) {
		if       !emailSent(for: .eBetaTesting), launchedEnoughTimes {
			recordEmailSent(for: .eBetaTesting)

			let image = kHelpMenuImage

			gAlerts.showAlert(
				"Please forgive my interruption", [
				"Thank you for downloading Seriously. Might you be interested in helping me beta test it, giving me feedback about it (good and bad)?",
				"You can let me know at any time, by selecting Report an Issue under the Help menu (red arrow in image), or now, by clicking the Reply button below."].joined(separator: kDoubleNewLine),
				"Reply in an email",
				"Dismiss",
				image) { [self] status in

				if  status != .sNo {
					sendEmailBugReport()
				}

				onCompletion()
			}
		} else {
			onCompletion()
		}
	}

	// MARK: - startup progress
	// MARK: -

	var    startupClockTime = Double.zero
	var        savedElapsed = Double.zero
	var               prior = Double.zero
	var    elapsedClockTime : Double { return CACurrentMediaTime() - startupClockTime }
	func captureElapsedTime()        { savedElapsed     = elapsedClockTime }
	func     setStartupTime()        { startupClockTime = CACurrentMediaTime() - savedElapsed } // mach_absolute_time()

	var oneTimerIntervalHasElapsed : Bool {
		let current = elapsedClockTime
		let enough  = (current - prior) > kOneStartupInterval
		if  enough  {
			prior   = current
		}

		return enough
	}

}
