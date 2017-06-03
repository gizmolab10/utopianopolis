//
//  ZLockManager.swift
//  Zones
//
//  Created by Jonathan Sand on 6/1/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation


enum ZOwner: Int {
    case storage
    case user
}


class ZLockManager: NSObject {


    var owner: ZOwner? = nil
    let semaphore      = DispatchSemaphore(value: 0)


    func borrowLock(for iOwner: ZOwner, block: Closure) {
        lock(for: iOwner)
        block()
        unlock(for: iOwner)
    }


    @discardableResult func lock(for iOwner: ZOwner) -> Bool {
        let previous = owner

        if  iOwner  != owner {
            if owner != nil {
                semaphore.wait()
            }

            owner = iOwner

            if previous != nil {
                report("\(previous!) =======> \(iOwner)")
            }
        }

        return previous != nil
    }


    func unlock(for iOwner: ZOwner) {
        if  owner == iOwner {
            let result = semaphore.signal()

            if result < 0 {
                report("unlock failed: \(result)")
            }

            owner = nil
        }
    }
}
