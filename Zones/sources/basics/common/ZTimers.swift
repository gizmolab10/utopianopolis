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
	case tCoreDataDeferral         // repeat forever
	case tNeedUserAccess
	case tCloudAvailable           // repeat forever
	case tMouseLocation
	case tMouseZone
	case tOperation
	case tLicense
	case tStartup
	case tRecount                  // repeat forever
	case tPersist                  // "
	case tHover                    // "
	case tKey

	var string: String { return "\(self)" }

	var description: String? {
		switch self {
			case .tPersist: return "saving data"
			default:        return nil
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

	var statusText: String? { return gCurrentTimerID?.description ?? kEmpty }

	func stopTimer(for timerID: ZTimerID?) {
		if  let id = timerID {
			FOREGROUND { [self] in
				timers[id]?.invalidate()
				timers[id] = nil

				if  gCurrentTimerID == id {
					gCurrentTimerID  = nil
				}
			}
		}
	}

	func startTimer(for timerID: ZTimerID?) {
		if  let     tid = timerID {

			// //
			// interval of time before firing, also between repeats
			// //

			var waitFor = 1.0                   // one second

			switch tid {
				case .tKey,     .tPersist:   waitFor =  5.0              // five seconds
				case .tLicense, .tRecount:   waitFor = 60.0              // one minute
				case .tHover,   .tMouseZone: waitFor = kOneHoverInterval // one fifth second
				default:                     break
			}

			// //
			// associate closure with timer id
			// //

			var block : Closure = {}          // do nothing by default

			switch tid {
				case .tKey:                     block = { gCurrentKeyPressed        = nil }
				case .tMouseZone:               block = { gCurrentMouseDownZone     = nil }
				case .tMouseLocation:           block = { gCurrentMouseDownLocation = nil }
				case .tTextEditorHandlesArrows: block = { gTextEditorHandlesArrows  = false }
				case .tCoreDataDeferral:        block = { gCoreDataStack.invokeDeferralMaybe(tid) }
				case .tLicense:                 block = { gProducts.updateForSubscriptionChange() }
				case .tStartup:                 block = { gStartupController?.startupUpdate() }
				case .tCloudAvailable:          block = { gBatches.cloudFire() }
				case .tRecount:                 block = { gRecountMaybe() }
				case .tHover:                   block = { gUpdateHover() }
				case .tPersist:                 block = { gSaveContext() }
				default:                        break
			}

			// //
			// create the timer. while it fires, set the current timer id
			// //

			let repeaters: [ZTimerID] = [.tCoreDataDeferral, .tCloudAvailable, .tRecount, .tHover, .tPersist]  // only these tasks repeat (forever)
			let repeats = repeaters.contains(tid)

			resetTimer(for: timerID, withTimeInterval: waitFor, repeats: repeats) {
				gCurrentTimerID     = timerID      // this is for cloudStatusLabel, in data details

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
			FOREGROUND(forced: true) { [self] in // timers require a runloop
				timers[id]?.invalidate() // do not leave the old one "floating around and uncontrollable"
				timers[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: { iTimer in
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
		FOREGROUND { [self] in // timers must have a runloop
			if  restartTimer || isInvalidTimer(for: timerID) {
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
							debug(kHyphen)
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
