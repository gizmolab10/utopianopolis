//
//  ZTimers.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/21/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gTimers = ZTimers()
var gCurrentTimerID: ZTimerID?

enum ZTimerID : Int {

	case tTextEditorHandlesArrows
	case tNeedCloudDriveEnabled
	case tCoreDataDeferral
	case tNeedUserAccess
	case tCloudAvailable
	case tMouseLocation
	case tMouseZone
	case tOperation
	case tLicense
	case tRecount
	case tStartup
	case tSync
	case tKey

	var string: String { return "\(self)" }

	var description: String? {
		switch self {
			case .tSync: return "saving data"
			default:     return nil
		}
	}

}

func gTemporarilySetKey(_ key: String) {
	gCurrentKeyPressed = key

	gTimers.startTimer(for: .tKey)
}

func gTemporarilySetMouseZone(_ zone: Zone?) {
	gCurrentMouseDownZone = zone

	gTimers.startTimer(for: .tMouseZone)
}

func gTemporarilySetMouseDownLocation(_ location: CGFloat?, for seconds: Double = 1.0) {
	gCurrentMouseDownLocation = location

	gTimers.startTimer(for: .tMouseLocation)
}

func gTemporarilySetTextEditorHandlesArrows(for seconds: Double = 1.0) {
	gTextEditorHandlesArrows = true

	gTimers.startTimer(for: .tTextEditorHandlesArrows)
}

class ZTimers: NSObject {

	var timers = [ZTimerID : Timer]()

	var statusText: String? { return gCurrentTimerID?.description }

	func stopTimer(for timerID: ZTimerID?) {
		if  let id = timerID {
			FOREGROUND {
				self.timers[id]?.invalidate()
				self.timers[id] = nil

				if  gCurrentTimerID == id {
					gCurrentTimerID  = nil
				}
			}
		}
	}

	func startTimer(for timerID: ZTimerID?) {
		if  let       tid = timerID {
			let repeaters : [ZTimerID] = [.tCoreDataDeferral, .tCloudAvailable, .tRecount, .tSync]
			var     block : Closure    = { }          // do nothing by default
			let   repeats = repeaters.contains(tid)
			var   waitFor = 1.0                                   // one second

			switch tid {
				case .tSync:                    waitFor = 15.0    // seconds
				case .tLicense:                 waitFor = 60.0
				case .tRecount:                 waitFor = 60.0    // one minute
				case .tStartup, .tMouseZone:    waitFor = kOneTimerInterval
				default:                        break
			}

			switch tid {
				case .tKey:                     block = { gCurrentKeyPressed        = nil }
				case .tMouseZone:               block = { gCurrentMouseDownZone     = nil }
				case .tMouseLocation:           block = { gCurrentMouseDownLocation = nil }
				case .tTextEditorHandlesArrows: block = { gTextEditorHandlesArrows  = false }
				case .tSync:                    block = { if gIsReadyToShowUI { gSaveContext() } }
				case .tRecount:                 block = { if gNeedsRecount    { gNeedsRecount = false; gRemoteStorage.recount(); gSignal([.spDataDetails]) } }
				case .tCloudAvailable:          block = { gBatches.cloudFire() }
				case .tCoreDataDeferral:        block = { gCoreDataStack.invokeDeferralMaybe(tid) }
				case .tStartup:                 block = { gStartupController?.startupUpdate() }
				case .tLicense:                 block = { gProducts.updateForSubscriptionChange() }
				default:                        break
			}

			resetTimer(for: timerID, withTimeInterval: waitFor, repeats: repeats) {
				gCurrentTimerID     = timerID

				block()

				if !repeats {
					gCurrentTimerID = nil
				}
			}
		}
	}

	func startTimers(for timers: [ZTimerID]) {
		for timer in timers {
			gTimers.startTimer(for: timer)
		}
	}

	func resetTimer(for timerID: ZTimerID?, withTimeInterval interval: TimeInterval, repeats: Bool = false, block: @escaping Closure) {
		if  let id = timerID {
			FOREGROUND { // timers require a runloop
				self.timers[id]?.invalidate() // do not leave the old one "floating around and uncontrollable"
				self.timers[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: { iTimer in
					block()
				})
			}
		}
	}

	func isInvalidTimer(for timerID: ZTimerID) -> Bool {
		var   isValid = false
		if  let timer = timers[timerID] {
			isValid   = timer.isValid
		}

		return !isValid
	}

	func assureCompletion(for timerID: ZTimerID, now: Bool = false, withTimeInterval interval: TimeInterval, restartTimer: Bool = false, block: @escaping ThrowsClosure) {
		FOREGROUND { // timers must have a runloop
			if  restartTimer || self.isInvalidTimer(for: timerID) {
				var tryCatch : Closure = {}
				let    start = Date()

				let clearTimer: Closure = { [weak self] in
					self?.timers[timerID]?.invalidate()
					self?.timers[timerID] = nil
				}

				let startTimer:  Closure = { [weak self] in
					clearTimer()

					self?.timers[timerID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { iTimer in
						clearTimer()
						tryCatch()
					}
				}

				let debug: StringClosure = { [weak self] prefix in
					let interval = Date().timeIntervalSince(start)
					let duration = Float(Int(interval) * 10) / 10.0 // round to nearest tenth of second

					self?.columnarReport(mode: .dTimers, "\(prefix) \(timerID)", "\(duration)")
				}

				tryCatch = {
					FOREGROUND {
						do {
							try block()
							debug("•")
							gSignal([.spDataDetails]) // show change in timer status
						} catch {
							startTimer()
							debug("-")
						}
					}
				}

				if  now {
					clearTimer() // in case timer was already set up
					tryCatch()
				} else {
					startTimer()
				}
			}
		}
	}

}
