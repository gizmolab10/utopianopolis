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

//		gPrintModes            = []
//		gPrintModes  .insert(.dTime)
//		gDebugModes  .insert(.dUseSubscriptions)
//		gCoreDataMode.remove(.dCloudKit)

		gRefusesFirstResponder = true			// WORKAROUND new feature of mac os x, prevents crash by ignoring user input
		gHelpWindowController  = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController
		gCDMigrationState      = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .migrateFileData : .firstTime
		gWorkMode              = .wStartupMode
		gMainWindow?.acceptsMouseMovedEvents = true // so hover detection works

		if  gCDMigrationState != .normal {
			gHereRecordNames = kDefaultRecordNames
		}

		gRemoteStorage.clear()
		gMainWindow?.revealEssayEditorInspectorBar(false)
		gSearching.setSearchStateTo(.sNot)
		gSignal([.spMain, .spStartupStatus])
		gTimers.startTimer(for: .tStartup)
		gEvents.controllerSetup(with: nil)

		gBatches.startUp { iSame in
			FOREGROUND { [self] in
				gMainController?.helpButton?.isHidden = false
				gRefusesFirstResponder                = false
				gHasFinishedStartup                   = true
				gCurrentHelpMode                      = .proMode // so prepare strings will work correctly for all help modes

				gDetailsController?.removeViewFromStack(for: .vSubscribe)
				gRefreshPersistentWorkMode()
				gRemoteStorage.setup()
				gRefreshCurrentEssay()
				gProducts.fetchProductData()
				gHereMaybe?.grab()

				if  gIsStartupMode {
					gSetMapWorkMode()
				}

				FOREGROUND(after: 0.1) { [self] in
					if  gCDMigrationState != .normal {
						gSaveContext()
					}

					gIsReadyToShowUI = true

					gSignal([.sLaunchDone])

					requestFeedback() {
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

	// MARK: - startup progress times
	// MARK: -

	var  progressTimesReady = false
	var    gotProgressTimes = false
	var       progressTimes = [ZOperationID : Double]()
	var    startupClockTime = Double.zero
	var        savedElapsed = Double.zero
	var               prior = Double.zero
	var    elapsedClockTime : Double { return CACurrentMediaTime() - startupClockTime }
	var fractionOfClockTime : Double { return elapsedClockTime / getAccumulatedProgressTime(untilExcluding: .oLoadingIdeas) }
	var        dataLoadTime : Int    { return gRemoteStorage.totalLoadableRecordsCount / timePerRecord }
	func captureElapsedTime()        { savedElapsed = elapsedClockTime }
	func     setStartupTime()        { startupClockTime = CACurrentMediaTime() - savedElapsed } // mach_absolute_time()

	var oneTimerIntervalHasElapsed : Bool {
		let current = elapsedClockTime
		let enough  = (current - prior) > kOneTimerInterval
		if  enough  {
			prior   = current
		}

		return enough
	}

	var totalProgressTime : Double {
		if  assureProgressTimesAreLoaded() {
			return progressTimes.values.reduce(0, +)
		}

		return Double(Int.max)
	}

	var timePerRecord : Int {
		switch gCDMigrationState {         // TODO: adjust for cpu speed
			case .normal: return 800
			default:      return 130
		}
	}

	func loadProgressTimes() {
		if  let string = getPreferenceString(for: kProgressTimes) {
			let  pairs = string.components(separatedBy: kCommaSeparator)

			for op in ZOperationID.oStartingUp.rawValue ... ZOperationID.oEnd.rawValue {
				setProgressTime(nil, for: op)
			}

			for pair in pairs {
				let       items = pair.components(separatedBy: kColonSeparator)
				if  items.count > 1,
					let      op = items[0].integerValue,
					let    time = items[1].doubleValue {

					setProgressTime(time, for: op)
				}
			}
		}
	}

	func storeProgressTimes() {
		var separator = kEmpty
		var  storable = kEmpty

		for (op, value) in progressTimes {
			if  value >= 1.5 {
				storable.append("\(separator)\(op)\(kColonSeparator)\(value)")

				separator = kCommaSeparator
			}
		}

		setPreferencesString(storable, for: kProgressTimes)
	}

	func setProgressTime(_  value: Double?, for opInt: Int) {
		if  let op = ZOperationID(rawValue: opInt) {
			let time = value ?? Double(op.defaultProgressTime) // when value is nil, insert default

			if  time > 1 {
				progressTimes[op] = time
			}
		}
	}

	func setProgressTime(for op: ZOperationID) {
		if  !gHasFinishedStartup, op != .oUserPermissions,
			assureProgressTimesAreLoaded() {

			let expected = getAccumulatedProgressTime(untilExcluding: op)
			let elapsed  = elapsedClockTime
			let delta    = expected - elapsed

			if  delta   >= 1.5 {
				progressTimes[op] = delta

				storeProgressTimes()
			}

			printDebug(.dTime, delta.stringTo(precision: 2) + "      \(gCurrentOp) \(elapsed.stringTo(precision: 2))")
		}
	}

	func assureProgressTimesAreLoaded() -> Bool {
		if  progressTimesReady, !gotProgressTimes {
			loadProgressTimes()

			gotProgressTimes = true
		}

		return gotProgressTimes
	}

	func getAccumulatedProgressTime(untilExcluding op: ZOperationID) -> Double {
		var sum = Double.zero

		if  assureProgressTimesAreLoaded() {
			let opValue = op.rawValue

			for opID in ZOperationID.allCases {
				if  opValue > opID.rawValue {          // all ops prior to op parameter
					sum += progressTimes[opID] ?? kDefaultProgressTime
				}
			}
		}

		return sum
	}

}

extension ZOperationID {

	var defaultProgressTime : Int {
		switch self {
			case .oLoadingIdeas:     return gStartup.dataLoadTime
			case .oMigrateFromCloud: return gNeedsMigrate ? 50 : 0
			case .oWrite:            return gWriteFiles   ? 40 : 0
			case .oResolve:          return  4
			case .oManifest:         return  3
			case .oAdopt:            return  2
			default:                 return  1
		}
	}

}
