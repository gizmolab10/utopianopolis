//
//  ZRing.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

let gEssayRing = ZRing()

class ZRing: NSObject {

    var             ring = [AnyObject] ()
    var     currentIndex = -1
    var       priorIndex = -1
	var        ringPrime : AnyObject?        { return ring[currentIndex] }
	var    possiblePrime : AnyObject?        { return gCurrentEssay }
    var         topIndex : Int               { return ring.count - 1 }
    var          atPrime : Bool              { return currentIndex >= 0 && currentIndex <= topIndex && isPrime }
	var          isEssay : Bool              { return true }
	var visibleRingTypes : ZTinyDotTypeArray { return ZTinyDotTypeArray() }

	var isPrime : Bool {
		guard let essay = ringPrime as? ZParagraph else { return false }

		return gCurrentEssay == essay
	}

	// MARK:- ring
    // MARK:-

    var primeIndex : Int? {
		if  let p = possiblePrime {
			for (index, item) in ring.enumerated() {
				if  p === item {
					return index
				}
			}
		}

        return nil
    }

    func dump() {
        if  gDebugMode.contains(.focus) {
//            for (index, item) in ring.enumerated() {
//                let isCurrentIndex = index == currentIndex
//                let prefix = isCurrentIndex ? "                   •" : ""
//                columnarReport(prefix, item.unwrappedName)
//            }
        }
    }

	func isInRing(_ item: AnyObject) -> Bool {
		if  let o = item as? ZParagraph {
			for ringItem in ring {
				if  let r = ringItem as? ZParagraph,
					o.zone == r.zone {
					return true
				}
			}
		}

		return false
	}

	func insertIfUnique(_ newIndex: Int? = nil) {
		if  let     item = possiblePrime, !isInRing(item) {
			if let index = newIndex {
				ring.insert(item, at: index)
			} else {
				ring.append(item)
			}
		}
	}

	func push() {
        var newIndex  = currentIndex + 1

        if  topIndex < 0 || !atPrime {
            if  let index = primeIndex {
                newIndex  = index   // prevent duplicates in stack
            } else if topIndex <= currentIndex {
				insertIfUnique()
            } else {
                if  currentIndex < 0 {
                    currentIndex = 0
                    newIndex  = currentIndex + 1
                }

				insertIfUnique(newIndex)
			}

            currentIndex = newIndex
        }
    }

    func goBack(extreme: Bool = false) {
        if  let    index = primeIndex {
            currentIndex = index
        } else if !atPrime {
            push()
        }

        if  currentIndex <= 0 || currentIndex > topIndex {
            currentIndex = topIndex
        } else if extreme {
            currentIndex = 0
        } else if currentIndex == topIndex || atPrime {
            currentIndex -= 1
        }

        go()
    }

    func goForward(extreme: Bool = false) {
        if  let    index = primeIndex {
            currentIndex = index
        } else if !atPrime {
            push()
        }

        if  currentIndex == topIndex {
            currentIndex  = 0
        } else if  extreme {
            currentIndex = topIndex
        } else if  currentIndex < topIndex {
            currentIndex += 1
        }

        go()
    }

    func go() {
        if  0          <= currentIndex,
            ring.count  > currentIndex, (!atPrime ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex

			update(ring[currentIndex])
			dump()
        }
    }

	func update(_ item: AnyObject?) {
		if  let     essay = item as? ZParagraph {
			gCurrentEssay = essay

			drawEssay()
		}
	}

    func pop() {
        if  let i = primeIndex {
            goBack()
            ring.remove(at: i)
        } else {
            go()
        }
    }

	func removeFromStack(_ iItem: AnyObject) {
		for (index, item) in ring.enumerated() {
			if  item === iItem {
				ring.remove(at: index)

				return
			}
		}
	}

}
