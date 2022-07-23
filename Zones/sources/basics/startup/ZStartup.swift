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
	var       prior = 0.0
	let   startedAt = Date()
	var elapsedTime = 0.0
	
	var oneTimerIntervalHasElapsed : Bool {
		let lapse       = Date().timeIntervalSince(startedAt)
		let enough      = (lapse - prior) > kOneTimerInterval
		if  enough {
			prior       = lapse
			elapsedTime = lapse
		}

		return enough
	}

	func startupCloudAndUI() {
		gCoreDataMode.insert(.dCloudKit)
		gDebugModes.remove(.dWriteFiles)
		gRefusesFirstResponder = true			// WORKAROUND new feature of mac os x, prevents crash by ignoring user input
		gHelpWindowController  = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController
		gCDMigrationState      = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .migrateFileData : .firstTime
		gWorkMode              = .wStartupMode

		gRemoteStorage.clear()
		gMainWindow?.revealEssayEditorInspectorBar(false)
		gSearching.setSearchStateTo(.sNot)
		gSignal([.spMain, .spStartupStatus])
		gTimers.startTimer(for: .tStartup)

		gBatches.startUp { iSame in
			FOREGROUND { [self] in
				gIsReadyToShowUI = true

				gDetailsController?.removeViewFromStack(for: .vSubscribe)
				gRefreshPersistentWorkMode()
				gRemoteStorage.updateRootsOfAllProjeny()
				gRemoteStorage.updateAllManifestCounts()
				gRemoteStorage.recount()
				gRefreshCurrentEssay()
//				gProducts.fetchProductData()

				gRefusesFirstResponder                = false
				gMainController?.helpButton?.isHidden = false
				gHasFinishedStartup                   = true
				gCurrentHelpMode                      = .proMode // so prepare strings will work correctly for all help modes

				if  gIsStartupMode {
					gSetMapWorkMode()
				}

				gHereMaybe?.grab()
				gSignal([.sLaunchDone])

				FOREGROUND(after: 0.1) { [self] in
					if  gCDMigrationState != .normal {
						gSaveContext()
					}

					requestFeedback() {
						gTimers.stopTimer (for: .tStartup)
						gTimers.startTimers(for: [.tCloudAvailable, .tRecount, .tPersist, .tHover]) // .tLicense
						gSignal([.sSwap, .spMain, .spCrumbs, .spPreferences, .spRelayout, .spDataDetails])
					}
				}
			}
		}
	}

	func requestFeedback(_ onCompletion: @escaping Closure) {
		if       !emailSent(for: .eBetaTesting) {
			recordEmailSent(for: .eBetaTesting)

			let image = kHelpMenuImage

			gAlerts.showAlert(
				"Please forgive my interruption",
				"Thank you for downloading Seriously. Might you be interested in helping me beta test it, giving me feedback about it (good and bad)?\n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow in image), or now, by clicking the Reply button below.",
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

}
