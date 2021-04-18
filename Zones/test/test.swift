//
//  test.swift
//  test
//
//  Created by Jonathan Sand on 4/18/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import XCTest

class test: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

	func testRange1() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 2, length: 1)
		let c = a.intersection(b)
		XCTAssert(c == b)
	}

	func testRange2() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 2, length: 0)
		let c = a.intersection(b)
		XCTAssert(c == b)
	}

	func testRange3() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 3, length: 1)
		let c = a.intersection(b)
		XCTAssert(c == nil)
	}

	func testRange4() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 3, length: 0)
		let c = a.intersection(b)
		XCTAssert(c == nil)
	}

	func testRange5() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 3, length: 1)
		let c = NSRange(location: 3, length: 0)
		let d = a.inclusiveIntersection(b)
		XCTAssert(c == d)
	}

	func testRange6() throws {
		let a = NSRange(location: 1, length: 2)
		let b = NSRange(location: 3, length: 3)
		let c = NSRange(location: 3, length: 0)
		let d = a.inclusiveIntersection(b)
		XCTAssert(c == d)
	}

	func testRange7() throws {
		let a = NSRange(location: 1, length: 3)
		let b = NSRange(location: 3, length: 3)
		let c = NSRange(location: 3, length: 1)
		let d = a.inclusiveIntersection(b)
		XCTAssert(c == d)
	}

	func testRange8() throws {
		let a = NSRange(location: 3, length: 3)
		let b = NSRange(location: 1, length: 2)
		let c = NSRange(location: 3, length: 0)
		let d = a.inclusiveIntersection(b)
		XCTAssert(c == d)
	}

}

extension NSRange {

	func inclusiveIntersection(_ other: NSRange) -> NSRange? {
		if  let    i = intersection(other) {
			return i
		}

		if  upperBound == other.location {
			return NSRange(location: other.location, length: 0)
		}

		if  other.upperBound == location {
			return NSRange(location: location, length: 0)
		}

		return nil
	}

}
