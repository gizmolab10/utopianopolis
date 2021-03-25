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

enum ZTimerID : Int {
	case tTextEditorHandlesArrows
	case tNeedCloudDriveEnabled
	case tCoreDataAvailable
	case tRecordsEveryone
	case tNeedUserAccess
	case tCloudAvailable
	case tMouseLocation
	case tWriteEveryone
	case tRecordsMine
	case tWriteMine
	case tMouseZone
	case tOperation
	case tRecount
	case tStartup
	case tSync
	case tKey

	static func recordsTimerID(for databaseID: ZDatabaseID?) -> ZTimerID? {
		if  let    index = databaseID?.databaseIndex {
			switch index {
				case .mineIndex:     return .tRecordsMine
				case .everyoneIndex: return .tRecordsEveryone
				default:             break
			}
		}

		return nil
	}

	static func convert(from databaseID: ZDatabaseID?) -> ZTimerID? {
		if  let id = databaseID {
			switch id {
				case .everyoneID: return .tWriteEveryone
				case .mineID:     return .tWriteMine
				default:          return nil
			}
		}

		return nil
	}

	var string: String { return "\(self)" }

	var description: String {
		switch self {
			case .tSync:            return "saving data"
			case .tWriteEveryone:   return "writing public local data"
			case .tWriteMine:       return "writing private local data"
			case .tRecordsEveryone: return "acquiring public cloud data"
			case .tRecordsMine:     return "acquiring private cloud data"
			default:                return ""
		}
	}

}

func gStartTimers(for timers: [ZTimerID]) {
	for timer in timers {
		gStartTimer(for: timer)
	}
}

func gStartTimer(for timerID: ZTimerID?) {
	if  let       tid = timerID {
		var     block : TimerClosure?
		let repeaters : [ZTimerID] = [.tCoreDataAvailable, .tCloudAvailable, .tRecount, .tSync]
		let   repeats = repeaters.contains(tid)
		var  interval = 1.0

		switch tid {
			case .tSync:              interval = 15.0
			case .tRecount:           interval = 60.0
			case .tMouseZone:         interval =  0.5
			case .tCloudAvailable:    interval =  0.2
			default:                  break
		}

		switch tid {
			case .tKey:                     block = { iTimer in gCurrentKeyPressed        = nil }
			case .tMouseZone:               block = { iTimer in gCurrentMouseDownZone     = nil }
			case .tMouseLocation:           block = { iTimer in gCurrentMouseDownLocation = nil }
			case .tTextEditorHandlesArrows: block = { iTimer in gTextEditorHandlesArrows  = false }
			case .tStartup:                 block = { iTimer in gIncrementStartupProgress() }
			case .tSync:                    block = { iTimer in if gIsReadyToShowUI { gSaveContext(); gBatches.save { iSame in } } }
			case .tRecount:                 block = { iTimer in if gNeedsRecount    { gNeedsRecount = false; gRemoteStorage.recount() } }
			case .tCloudAvailable:          block = { iTimer in FOREGROUND(canBeDirect: true) { gBatches.cloudFire() } }
			case .tCoreDataAvailable:       block = { iTimer in gCoreDataStack.availabilityFire(iTimer) }
			default:                        break
		}

		gTimers.resetTimer(for: timerID, withTimeInterval: interval, repeats: repeats, block: block ?? { iTimer in })
	}
}

func gStopTimer(for timerID: ZTimerID?) {
	if  let id = timerID {
		FOREGROUND {
			gTimers.timers[id]?.invalidate()
			gTimers.timers[id] = nil
		}
	}
}

func gTemporarilySetKey(_ key: String) {
	gCurrentKeyPressed = key

	gStartTimer(for: .tKey)
}

func gTemporarilySetMouseZone(_ zone: Zone?) {
	gCurrentMouseDownZone = zone

	gStartTimer(for: .tMouseZone)
}

func gTemporarilySetMouseDownLocation(_ location: CGFloat?, for seconds: Double = 1.0) {
	gCurrentMouseDownLocation = location

	gStartTimer(for: .tMouseLocation)
}

func gTemporarilySetTextEditorHandlesArrows(for seconds: Double = 1.0) {
	gTextEditorHandlesArrows = true

	gStartTimer(for: .tTextEditorHandlesArrows)

}

class ZTimers: NSObject {

	var timers = [ZTimerID : Timer]()

	var statusText: String {
		let statusIDs: [ZTimerID] = [.tRecordsEveryone, .tRecordsMine, .tWriteEveryone, .tWriteMine]

		for id in timers.keys {
			if  statusIDs.contains(id) {
				return id.description
			}
		}

		return ""
	}

	func resetTimer(for timerID: ZTimerID?, withTimeInterval interval: TimeInterval, repeats: Bool = false, block: @escaping TimerClosure) {
		if  let id = timerID {
			FOREGROUND { // timers must have a runloop
				self.timers[id]?.invalidate()
				self.timers[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
				self.timers[id]?.fire()
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
							gSignal([.sStatus]) // show change in timer status
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
