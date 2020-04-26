//
//  ZTimers.swift
//  Zones
//
//  Created by Jonathan Sand on 3/21/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gTimers = ZTimers()

enum ZTimerID : Int {
	case tArrowsDoNotBrowse
	case tRecordsEveryone
	case tCloudAvailable
	case tMouseLocation
	case tWriteEveryone
	case tRecordsMine
	case tWriteMine
	case tMouseZone
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

	var timers = [Int: Timer]()

	var statusText: String {
		let hasStatus: [ZTimerID] = [.tRecordsEveryone, .tRecordsMine, .tWriteEveryone, .tWriteMine]

		for key in timers.keys {
			if  let id = ZTimerID(rawValue: key),
				hasStatus.contains(id) {
				return id.description
			}
		}

		return ""
	}

	func resetTimer(for timerID: ZTimerID?, withTimeInterval interval: TimeInterval, repeats: Bool = false, block: @escaping (Timer) -> Void) {
		guard let index = timerID?.rawValue else { return }

		timers[index]?.invalidate()

		timers[index]   = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
	}

	func isInvalidTimer(for timerID: ZTimerID) -> Bool {
		var   invalid = true
		let     index = timerID.rawValue
		if  let timer = timers[index] {
			invalid   = !timer.isValid
		}

		return invalid
	}

	func assureCompletion(for timerID: ZTimerID, now: Bool = false, withTimeInterval interval: TimeInterval, restartTimer: Bool = false, block: @escaping ThrowsClosure) {
		FOREGROUND { // timers must have a runloop
			if  restartTimer || self.isInvalidTimer(for: timerID) {
				let    index = timerID.rawValue
				var tryCatch : Closure = {}
				let    start = Date()

				let clearTimer: Closure = { [weak self] in
					self?.timers[index]?.invalidate()
					self?.timers[index]         = nil
				}

				let startTimer:  Closure = { [weak self] in
					clearTimer()

					self?.timers[index] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { iTimer in
						clearTimer()
						tryCatch()
					}
				}

				let debug: StringClosure = { [weak self] prefix in
					let interval = Date().timeIntervalSince(start)
					let duration = Float(Int(interval) * 10) / 10.0 // round to nearest tenth of second

					self?.columnarReport(mode: .dTimers, "\(prefix) \(timerID)", "\(duration)")
				}

				tryCatch = { [weak self] in
					do {
						try block()
						debug("•")
						self?.signal([.sStatus]) // show change in timer status
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
