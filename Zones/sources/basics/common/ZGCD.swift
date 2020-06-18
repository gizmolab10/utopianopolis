//
//  ZGCD.m
//  Seriously
//
//  Created by Jonathan Sand on 3/30/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

var gFOREGROUND = DispatchQueue.main
var gBACKGROUND = DispatchQueue.global(qos: .background)

func FOREGROUND(canBeDirect: Bool = false, _ closure: @escaping Closure) {
    if  canBeDirect && Thread.isMainThread {
        closure()
    } else {
        gFOREGROUND.async { closure() }
    }
}

func BACKGROUND(_ closure: @escaping Closure) {
    gBACKGROUND.async { closure() }
}

func FOREGROUND(after seconds: Double, closure: @escaping Closure) {
    let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

    gFOREGROUND.asyncAfter(deadline: when) { closure() }
}

func BACKGROUND(after seconds: Double, closure: @escaping Closure) {
    let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

    gBACKGROUND.asyncAfter(deadline: when) { closure() }
}

