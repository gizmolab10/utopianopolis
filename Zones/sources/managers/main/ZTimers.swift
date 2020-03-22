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
	case tEveryone
	case tMine
	case tMinimal
	case tCloudAvailable
	case tMouseZone
	case tMouseLocation
	case tEveryoneRecords
	case tMineRecords

	static func recordsID(for databaseID: ZDatabaseID?) -> ZTimerID? {
		if  let index = databaseID?.index {
			return ZTimerID(rawValue: index + ZTimerID.tEveryoneRecords.rawValue)
		}

		return nil
	}

}

class ZTimers: NSObject {

	var timers = [Int: Timer]()

	func setTimer(for timerID: ZTimerID?, withTimeInterval interval: TimeInterval, repeats: Bool = false, block: @escaping (Timer) -> Void) {
		guard let index = timerID?.rawValue else { return }

		timers[index]?.invalidate()

		timers[index]   = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
	}
	
	func isInvalidTimer(for timerID: ZTimerID) -> Bool {
		var   restart = true
		let     index = timerID.rawValue
		if  let timer = timers[index] {
			restart   = !timer.isValid
		}

		return restart
	}

	func assureCompletion(for timerID: ZTimerID, now: Bool = false, withTimeInterval interval: TimeInterval, restartTimer: Bool = false, block: @escaping ThrowsClosure) {
		FOREGROUND { // timers must have a runloop
			if  restartTimer || self.isInvalidTimer(for: timerID) {
				let   index = timerID.rawValue
				var  bBlock : Closure? = nil
				var isBegun = false
				var  isDone = false

				let clear: Closure = {
					self.timers[index]?.invalidate()

					self.timers[index] = nil
				}

				let tBlock: TimerClosure = { iTimer in
					bBlock?()
				}

				let sTimer: Closure = {
					clear()

					let          timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: tBlock)
					self.timers[index] = timer
				}

				bBlock = {
					clear()

					if !isDone {
						if !isBegun {
							isBegun = true

							do {
								try block()
							} catch {
								sTimer()
							}

							isDone  = true
						}
					}
				}

				if  now {
					bBlock?()
				} else {
					sTimer()
				}
			}
		}
	}

}
