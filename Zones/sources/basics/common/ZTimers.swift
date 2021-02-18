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
	case tNeedCloudDriveEnabled
	case tArrowsDoNotBrowse
	case tCoreDataAvailable
	case tRecordsEveryone
	case tNeedUserAccess
	case tCloudAvailable
	case tMouseLocation
	case tWriteEveryone
	case tLoadCoreData
	case tSaveCoreData
	case tRecordsMine
	case tWriteMine
	case tMouseZone
	case tOperation
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
			case .tWriteEveryone:   return "writing public local data"
			case .tWriteMine:       return "writing private local data"
			case .tRecordsEveryone: return "acquiring public cloud data"
			case .tRecordsMine:     return "acquiring private cloud data"
			default:                return ""
		}
	}

}

class ZTimers: NSObject {

	var timers = [ZTimerID : Timer]()

	var statusText: String {
		let allTimerIDs: [ZTimerID] = [.tRecordsEveryone, .tRecordsMine, .tWriteEveryone, .tWriteMine]

		for id in timers.keys {
			if  allTimerIDs.contains(id) {
				return id.description
			}
		}

		return ""
	}

	func stopTimer(for timerID: ZTimerID?) {
		if  let id = timerID {
			FOREGROUND {
				self.timers[id]?.invalidate()
			}
		}
	}

	func resetTimer(for timerID: ZTimerID?, withTimeInterval interval: TimeInterval, repeats: Bool = false, block: @escaping (Timer) -> Void) {
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
					do {
						try block()
						debug("•")
						FOREGROUND {
							gSignal([.sStatus]) // show change in timer status
						}
					} catch {
						startTimer()
						debug("-")
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
