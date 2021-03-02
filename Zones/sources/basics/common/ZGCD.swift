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

func FOREGROUND(canBeDirect: Bool = false, forced: Bool = false, _ closure: @escaping Closure) {
    if  Thread.isMainThread && (canBeDirect || forced) {
        closure()
	} else if forced {
		gFOREGROUND .sync { closure() }
    } else {
        gFOREGROUND.async { closure() }
    }
}

func BACKGROUND(canBeDirect: Bool = false, _ closure: @escaping Closure) {
	if  canBeDirect && !Thread.isMainThread {
		closure()
	} else {
		gBACKGROUND.async { closure() }
	}
}

func FOREGROUND(after seconds: Double, closure: @escaping Closure) {
    let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

    gFOREGROUND.asyncAfter(deadline: when) { closure() }
}

func BACKGROUND(after seconds: Double, closure: @escaping Closure) {
    let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

    gBACKGROUND.asyncAfter(deadline: when) { closure() }
}

