//
//  ZLockManager.swift
//  Zones
//
//  Created by Jonathan Sand on 6/1/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation


enum ZOwner: Int {
    case cloud
    case user
}


class ZLockManager: NSObject {


    var owner: ZOwner? = nil
    let semaphore      = DispatchSemaphore(value: 0)
    let ownerLock      = NSLock()


    func borrowLock(for iOwner: ZOwner, block: Closure) {
        lock(for: iOwner)
        block()
        unlock(for: iOwner)
    }


    func lock(for iOwner: ZOwner) {
        if  iOwner  != owner {
            let previous = owner

            if owner != nil {
                semaphore.wait()
            }

            ownerLock.withCriticalScope {
                owner = iOwner

                if previous != nil {
                    report("\(previous!) =======> \(iOwner)")
                }
            }
        }
    }


    func unlock(for iOwner: ZOwner) {
        if  owner == iOwner {
            ownerLock.withCriticalScope {
                let result = semaphore.signal()

                if result < 0 {
                    report("unlock failed: \(result)")
                }

                owner = nil
            }
        }
    }
}
