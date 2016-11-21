//
//  XBGCD.m
//  XIMBLE
//
//  Created by Jonathan Sand on 3/30/16.
//  Copyright © 2016 Xicato. All rights reserved.
//


import Foundation


extension NSObject {


    func dispatchAsyncInForeground(_ closure: @escaping Closure) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async { closure() }
        }
    }


    func dispatchAsyncInForegroundAfter(_ seconds: Double, closure: @escaping Closure) {
        let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

        DispatchQueue.main.asyncAfter(deadline: when) { closure() }
    }
}
