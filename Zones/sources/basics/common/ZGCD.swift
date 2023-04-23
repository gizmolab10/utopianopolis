//
//  ZGCD.m
//  Seriously
//
//  Created by Jonathan Sand on 3/30/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

let gFOREGROUND = DispatchQueue.main
let gBACKGROUND = DispatchQueue.global(qos: .background)

func FOREGROUND(forced: Bool = false, after seconds: Double? = nil, _ closure: @escaping Closure) {
	if  let after = seconds, after != .zero {
		let  when = DispatchWallTime.now() + Double(Int64(after * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

		gFOREGROUND.asyncAfter(wallDeadline: when) { closure() }
	} else if Thread.isMainThread {
		closure()
	} else if forced {
		gFOREGROUND .sync { closure() }
    } else {
        gFOREGROUND.async { closure() }
    }
}

func BACKGROUND(_ closure: @escaping Closure) {
	if !Thread.isMainThread {
		closure()
	} else {
		gBACKGROUND.async { closure() }
	}
}

func gSynchronized<T>(lock: AnyObject, _ body: () throws -> T) rethrows -> T {
	objc_sync_enter(lock)
	defer { objc_sync_exit(lock) }
	return try body()
}
