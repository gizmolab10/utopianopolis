//
//  ZExtensions.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

typealias               ZoneArray = [Zone]
typealias              CKRecordID = CKRecord.ID
typealias             ZTraitArray = [ZTrait]
typealias             CKReference = CKRecord.Reference
typealias           ZRecordsArray = [ZRecord]
typealias           ZObjectsArray = [NSObject]
typealias          CKRecordsArray = [CKRecord]
typealias        CKRecordIDsArray = [CKRecordID]
typealias        ZTraitDictionary = [ZTraitType : ZTrait]
typealias       CKReferencesArray = [CKReference]
typealias       ZAssetsDictionary = [UUID : CKAsset]
typealias       ZTinyDotTypeArray = [[ZTinyDotType]]
typealias      ZOperationIDsArray = [ZOperationID]
typealias      ZStorageDictionary = [ZStorageType : NSObject]
typealias   ZAttributesDictionary = [NSAttributedString.Key : Any]
typealias ZStringObjectDictionary = [String : NSObject]
let                  gApplication = ZApplication.shared

protocol ZGeneric {
	func setup()
}

func printFancy(_ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  let t = test, !t() { return }
	let fancy = (surround == nil) ? message : message.surround(with: surround!)
	FOREGROUND {
		print(fancy)
	}
}

func printDebug(_ mode: ZPrintMode, prefix: String = "  ", _ message: String, surround: String? = nil, _ test: ToBooleanClosure? = nil) {
	if  gPrintModes.contains(mode) {
		printFancy("\(mode): " + prefix + message, surround: surround, test)
	}
}

func gSeparatorAt(level: Int) -> String { return " ( \(level) ) " }

func gSignal(for object: Any? = nil, _ multiple: [ZSignalKind], _ onCompletion: Closure? = nil) {
	gControllers.signalFor(object, multiple: multiple, onCompletion: onCompletion)
}

func gUpdateStartupProgress() {
	if !gHasFinishedStartup {
		FOREGROUND {
			gSignal([.sStartupProgress])
		}
	}
}

func gRedrawMaps(for object: Any? = nil, _ onCompletion: Closure? = nil) {
	gSignal(for: object, [.sRelayout], onCompletion)
}

func gDeferRedraw(_ closure: Closure) {
	gDeferringRedraw = true

	closure()

	FOREGROUND(after: 0.4) {
		gDeferringRedraw = false   // in case closure doesn't set it
	}
}

func gCompareZones(_ a: AnyObject, _ b: AnyObject) -> Bool {
	if  let alpha = (a as? Zone)?.ckRecordName,
		let  beta = (b as? Zone)?.ckRecordName {
		return alpha == beta
	}

	return false
}

precedencegroup BooleanPrecedence { associativity: left }
infix operator ^^ : BooleanPrecedence
/**
Swift Logical XOR operator
```
true  ^^ true   // false
true  ^^ false  // true
false ^^ true   // true
false ^^ false  // false
```
- parameter lhs: First value.
- parameter rhs: Second value.
*/

func ^^(lhs: Bool, rhs: Bool) -> Bool {
	return lhs != rhs
}

extension NSObject {

    func           performance(_ iMessage: Any?)                { log(iMessage) }
    func                   bam(_ iMessage: Any?)                { log("-------------------------------------------------------------------- " + (iMessage as? String ?? "")) }
	func     printCurrentFocus()                                { gHere.widget?.printView() }
	func     printCurrentEssay()                                { gEssayView?.printView() }

	func columnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(mode: mode, iFirst, iSecond) }

	func rawColumnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            printDebug(mode, "\(prefix)\(iSecond ?? "")")
        }
    }

    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != "" {
            printDebug(.dLog, message)
        }
    }

	func debugTime(message: String, _ closure: Closure) {
		let start = Date()

		closure()

		let duration = Date().timeIntervalSince(start)

		printDebug(.dTime, duration.stringToTwoDecimals + " " + message)
	}

    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }

    func blankScreenDebug() {
        if  let w = gMapController?.rootWidget.bounds.size.width, w < 1.0 {
            bam("blank map !!!!!!")
        }
    }

    func repeatUntil(_ isDone: @escaping ToBooleanClosure, then: @escaping Closure) {
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { iTimer in
            if  isDone() {
                iTimer.invalidate()
                then()
            }
        }
    }

    @discardableResult func detectWithMode(_ dbID: ZDatabaseID, block: ToBooleanClosure) -> Bool {
        gRemoteStorage.pushDatabaseID(dbID)

        let result = block()

        gRemoteStorage.popDatabaseID()
        
        return result
    }

    func invokeUsingDatabaseID(_ dbID: ZDatabaseID?, block: Closure) {
        if  dbID != nil && dbID != gDatabaseID {
            detectWithMode(dbID!) { block(); return false }
        } else {
            block()
        }
    }

    func UNDO<TargetType : AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        gUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }

    func openBrowserForFocusWebsite() {
        "https://medium.com/@sand_74696/what-you-get-d565b064be7b".openAsURL()
    }

    func sendEmailBugReport() {
        "mailto:sand@gizmolab.com?subject=Regarding Seriously".openAsURL()

//		let service = NSSharingService(named: NSSharingService.Name.composeEmail)
//		service?.recipients = ["sand@gizmolab.com"]
//		service?.subject = "Reporting an error"
//		service?.perform(withItems: ["Something happened"])
	}

    // MARK:- bookmarks
    // MARK:-

    func isValid(_ iLink: String?) -> Bool {
        return components(of: iLink) != nil
    }

    func components(of iLink: String?) -> [String]? {
        if  let       link = iLink {
            let components =  link.components(separatedBy: kColonSeparator)
            if  components.count > 2 {
                return components
            }
        }

        return nil
    }

    func recordName(from iLink: String?) -> String? {
        if  let components = components(of: iLink) {
            let      name  = components[2]
            return   name != "" ? name : kRootName // by design: empty component means root
        }

        return nil
    }

    func databaseID(from iLink: String?) -> ZDatabaseID? {
        if  let components = components(of: iLink) {
            let      dbID  = components[0]
            return   dbID == "" ? nil : ZDatabaseID(rawValue: dbID)
        }

        return nil
    }

    func zoneFrom(_ iLink: String?) -> Zone? {
        if  iLink                   != nil,
            iLink                   != "",
            let                 name = recordName(from: iLink) {
            let components: [String] = iLink!.components(separatedBy: kColonSeparator)
            let        rawIdentifier = components[0]
            let   dbID: ZDatabaseID? = rawIdentifier == "" ? gDatabaseID : ZDatabaseID(rawValue: rawIdentifier)
            let             zRecords = gRemoteStorage.zRecords(for: dbID)
            let                 zone = zRecords?.maybeZoneForRecordName(name)

            return zone
        }

        return nil
    }

    // MARK:- JSON
    // MARK:-

    func dictFromJSON(_ dict: ZStringObjectDictionary) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + kColonSeparator)
                    if  parts.count > 1,
                        parts[0]    == "",
                        let interval = TimeInterval(parts[1]) {
                        goodValue    = Date(timeIntervalSinceReferenceDate: interval) as NSObject
                        translated   = true
                    }
                }

                if !translated {
                    if  let     subDict = value as? ZStringObjectDictionary {
                        goodValue       = dictFromJSON(subDict) as NSObject
                    } else if let array = value as? [ZStringObjectDictionary] {
                        var   goodArray = [ZStorageDictionary] ()

                        for subDict in array {
                            goodArray.append(dictFromJSON(subDict))
                        }

                        goodValue       = goodArray as NSObject
                    }
                }

                result[storageKey]      = goodValue
            }
        }

        return result
    }
}

extension ZStorageDictionary {

	var jsonDict : ZStringObjectDictionary {
        var    last = ZStorageDictionary ()
        var  result = ZStringObjectDictionary ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue        = value
            if  let      subDict = value as? ZStorageDictionary {
				goodValue        = subDict.jsonDict
            } else if let   date = value as? Date {
                goodValue        = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let  array = value as? [ZStorageDictionary] {
                var jsonArray    = [ZStringObjectDictionary] ()

                for subDict in array {
                    jsonArray.append(subDict.jsonDict)
                }

                goodValue        = jsonArray
            }

            result[key.rawValue] = (goodValue as! NSObject)
        }

        for (iKey, value) in self {
			let key = (iKey != .essay) ? iKey : .note

            if [.children, .traits].contains(key) {
                last[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in last {
            closure(key, value)
        }

        return result
    }

}

extension Dictionary {

	var byteCount: Int { return data?.count ?? 0 }
	var string: String? { return data?.string }

	var data: Data? {
		do {
			let data = try JSONSerialization.data(withJSONObject:self, options: [])

			return data
		} catch {}

		return nil
	}

	subscript (i: Int) -> Any? {
		if  i < count {
			let k = Array(keys)

			return self[k[i]]
		}

		return nil
	}

}

extension URL {

	var originalImageName: String? { return CGImageSource.readFrom(self)?.originalImageName }

	func destination(imageType: CFString = kUTTypeImage) -> CGImageDestination? {
		return CGImageDestinationCreateWithURL(self as CFURL, imageType, 1, nil)
	}

	var imageProperties: [NSObject : AnyObject]? {
		if  let          source = CGImageSource.readFrom(self),
			let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as [NSObject : AnyObject]? {
			return imageProperties
		}

		return nil
	}

	var imageSize: CGSize? {
		if  let properties  = imageProperties {
			let pixelHeight = properties[kCGImagePropertyPixelHeight] as! Int
			let pixelWidth  = properties[kCGImagePropertyPixelWidth]  as! Int

			return CGSize(width: pixelWidth, height: pixelHeight)

		}

		return nil
	}

	func readImage() -> ZImage? {
		return nil
	}

	func writeImage(_ image: ZImage) -> Bool {
		var  success = false

		if  let data = image.jpeg {
			do {
				try data.write(to: self, options: Data.WritingOptions.atomic)

				success = true
			} catch {
			}
		}

		return success
	}

	func testWriteImage(_ image: ZImage, addOriginalImageName: String? = nil) -> Bool {
		if  let d = destination() {
			let cgImage = image as! CGImage
			var metadata = [String : Any]()

			if  let name = addOriginalImageName {
				metadata[kOrignalImageName] = name
			}

			CGImageDestinationAddImage(d, cgImage, metadata as CFDictionary)
			CGImageDestinationFinalize(d)

			return true
		}

		return false
	}

}

extension CGImageSource {

	class func readFrom(_ url: URL) -> CGImageSource? { return CGImageSourceCreateWithURL(url as CFURL, nil) }
	var metadata: [String : Any]? { return CGImageSourceCopyPropertiesAtIndex(self, 0, nil) as? [String : Any] }
	var originalImageName: String? { return metadata?[kOrignalImageName] as? String }

}

extension CKAsset {

	var data       :   Data? { return FileManager.default.contents(atPath: fileURL.path) }
	var imageSize  : CGSize? { return fileURL.imageSize }
	var uuidString : String? { return value(forKeyPath: "_UUID") as? String }
	var length     :    Int? { return value(forKeyPath: "_size") as? Int }

}

extension CKRecord {

    var reference: CKReference { return CKReference(recordID: recordID, action: .none) }
	var entityName: String {
		switch recordType {
			case "Users": return "ZUser"
			default:      return recordType
		}
	}

	var isOrphaned: Bool {
		var parentRecordName : String?
		var parentReference  = self[kpParent] as? CKReference

		if  parentReference == nil {
			if  let     link = self[kpZoneParentLink] as? String {
				parentRecordName = recordName(from: link) // parent is in other db
			} else {
				parentReference  = self[kpOwner] as? CKReference
			}
		}

		if  let ref = parentReference {
			parentRecordName = ref.recordID.recordName
		}

		if  parentRecordName != nil {
			return gRemoteStorage.maybeZoneForRecordName(parentRecordName) == nil
		}

		return true
	}

	var storable: String {
		get {
			var pairs = [String]()
			let  keys = allKeys()

			for key in keys {
				if  let value = self[key] {
					let pair = "\(key)\(gSeparatorAt(level: 2))\(value)"

					pairs.append(pair)
				}
			}

			return pairs.joined(separator: gSeparatorAt(level: 1))
		}

		set {
			let pairs = newValue.componentsSeparatedAt(level: 1)

			for pair in pairs {
				let parts = pair.componentsSeparatedAt(level: 2)

				if  parts.count > 1 {
					let   key = parts[0]
					let value = parts[1]
					self[key] = value
				}
			}
		}
	}

    var isEmpty: Bool {
        for key in [kpZoneName, kpParent, kpZoneParentLink] {
            if  self[key] != nil {
                return false
            }
        }

        return true
    }

	var matchesFilterOptions: Bool {
		switch recordType {
			case kZoneType:
				let    isBookmark = self[kpZoneLink] != nil

				return isBookmark && gFilterOption.contains(.fBookmarks) || !isBookmark && gFilterOption.contains(.fIdeas)
			case kTraitType:
				return gFilterOption.contains(.fNotes)
			default: break
		}

		return true
	}

    var isBookmark: Bool {
        if  let    link = self[kpZoneLink] as? String {
            return link.contains(kColonSeparator)
        }

        return false
    }

	var traitType: String {
		var string = ""

		if  let        type = self["type"] as? String,
			let       trait = ZTraitType(rawValue: type),
			let description = trait.description {
			string          = description + kSearchSeparator
		}

		return string
	}

    var decoratedName: String {
		switch recordType {
			case kTraitType:
				let text = self["text"] as? String ?? kNoValue

				return "\(traitType) \(text)"
			case kZoneType:
				if  let      name = self[kpZoneName] as? String {
					let separator = kSpace
					var    prefix = ""
					
					if  isBookmark {
						prefix.append("L")
					}
					
					if  let fetchable = self[kpZoneCount] as? Int, fetchable > 1 {
						if  prefix != "" {
							prefix.append(separator)
						}
						
						prefix.append("\(fetchable)")
					}
					
					if  prefix != "" {
						prefix  = "(" + prefix + ")  "
					}
					
					return prefix.appending(name)
				}
			default:
				return recordID.recordName
		}

        return kNoValue
    }

    convenience init(for name: String) {
        self.init(recordType: kZoneType, recordID: CKRecordID(recordName: name))
    }

    func isDeleted(dbID: ZDatabaseID) -> Bool {
        return gRemoteStorage.cloud(for: dbID)?.manifest?.deletedRecordNames?.contains(recordID.recordName) ?? false
    }

    @discardableResult func copy(to iCopy: CKRecord?, properties: [String]) -> Bool {
        var  altered = false
        if  let copy = iCopy {
            for keyPath in properties {
                let        leftSide = copy[keyPath]
                let       rightSide = self[keyPath]
                if  leftSide?.hash != rightSide?.hash {
                    copy[keyPath]   = rightSide
                    altered         = true
                }
            }
        }

        return altered
    }

    func hasKey(_ key: String) -> Bool {
        return allKeys().contains(key)
    }

    func index(within iReferences: CKRecordIDsArray) -> Int? {
        for (index, identifier) in iReferences.enumerated() {
            if  identifier == recordID {
                return index
            }
        }

        return nil
    }

    func maybeMarkAsFetched(_ databaseID: ZDatabaseID?) {
        let states        = [ZRecordState.notFetched, ZRecordState.needsFetch]
        if  creationDate != nil,
            let dbID      = databaseID,
            let manager   = gRemoteStorage.cloud(for: dbID),
            manager.hasCKRecord(self, forAnyOf: states) {
            manager.clearCKRecords([self], for: states)
        }
    }

}

extension ZTinyDotTypeArray {

	static func ideaTypes(_ count: Int) -> ZTinyDotTypeArray {
		var  types = ZTinyDotTypeArray()
		var  added = count

		while added > 0 {
			added  -= 1
			types.append([.eIdea])
		}

		return types
	}

}

extension BlockOperation {
    
    func invokeCompletions() {
        if  let block = completionBlock {
            block()
        }
        
//        if  let recordBlock = perRecordCompletionBlock {
//            recordBlock()
//        }
    }
    
}

infix operator ** : MultiplicationPrecedence

extension Double {

	static func ** (base: Double, power: Double) -> Double { return pow(base, power) }
	var    stringToTwoDecimals                    : String { return String(format: "%.02f", self) }
}

extension CGFloat {
	var    stringToTwoDecimals                    : String { return String(format: "%.02f", self) }
}

infix operator -- : AdditionPrecedence

extension CGPoint {

	var descriptionToTwoDecimals: String { return "(\(x.stringToTwoDecimals), \(y.stringToTwoDecimals))"}

    public init(_ size: CGSize) {
        self.init()

        x = size.width
        y = size.height
    }

    static func - ( left: CGPoint, right: CGPoint) -> CGSize {
        return CGSize(width: left.x - right.x, height: left.y - right.y)
    }

    static func -- ( left: CGPoint, right: CGPoint) -> CGFloat {
        let  width = Double(left.x - right.x)
        let height = Double(left.y - right.y)

        return CGFloat(sqrt(width * width + height * height))
    }

	func offsetBy(_ delta: CGPoint) -> CGPoint {
		return CGPoint(x: x + delta.x, y: y + delta.y)
	}

	func offsetBy(_ delta: CGSize) -> CGPoint {
		return CGPoint(x: x + delta.width, y: y + delta.height)
	}

	func offsetBy(_ xOffset: CGFloat, _ yOffset: CGFloat) -> CGPoint {
		return CGPoint(x: x + xOffset, y: y + yOffset)
	}

	func intersectsTriangle(orientedUp: Bool, in iRect: CGRect) -> Bool {
		return ZBezierPath.trianglePath(orientedUp: orientedUp, in: iRect).contains(self)
	}

	func intersectsCircle(in iRect: CGRect) -> Bool {
		return ZBezierPath.circlePath(in: iRect).contains(self)
	}

	func intersectsCircle(orientedUp: Bool, in iRect: CGRect) -> Bool {
		let (path, _) = ZBezierPath.circlesPath(orientedUp: orientedUp, in: iRect)

		return path.contains(self)
	}

	var hypontenuse: CGFloat {
		return sqrt(x * x + y * y)
	}

	func rotate(by angle: Double) -> CGPoint {
		let r = hypontenuse

		return CGPoint(x: r * CGFloat(cos(angle)), y: r * CGFloat(sin(angle)))
	}

}

extension CGSize {

	static var big: CGSize {
		return CGSize(width: 1000000, height: 1000000)
	}

	var smallDimension: CGFloat {
		return min(abs(height), abs(width))
	}

    var hypontenuse: CGFloat {
        return sqrt(width * width + height * height)
    }

	func isLargerThan(_ other: CGSize) -> Bool {
		return hypontenuse > other.hypontenuse
	}

	func multiplyBy(_ fraction: CGFloat) -> CGSize {
		return CGSize(width: width * fraction, height: height * fraction)
	}

	func multiplyBy(_ fraction: CGSize) -> CGSize {
		return CGSize(width: width * fraction.width, height: height * fraction.height)
	}

	func fraction(_ delta: CGSize) -> CGSize {
		CGSize(width: (width - delta.width) / width, height: (height - delta.height) / height)
	}

	func offsetBy(_ x: CGFloat, _ y: CGFloat) -> CGSize {
		return CGSize(width: width + x, height: height + y)
	}

	func offsetBy(_ delta: CGSize) -> CGSize {
		return CGSize(width: width + delta.width, height: height + delta.height)
	}

	func force(horizotal: Bool, into range: NSRange) -> CGSize {
		if  horizotal {
			let value = max(min(width,  CGFloat(range.upperBound)), CGFloat(range.lowerBound))
			return CGSize(width: value, height: height)
		} else {
			let value = max(min(height, CGFloat(range.upperBound)), CGFloat(range.lowerBound))
			return CGSize(width: width, height: value)
		}
	}

}

extension CGRect {

	var       extent: CGPoint { return CGPoint(x: maxX, y: maxY) }
	var     topRight: CGPoint { return CGPoint(x: maxX, y: minY) }
	var    topCenter: CGPoint { return CGPoint(x: midX, y: minY) }
	var   bottomLeft: CGPoint { return CGPoint(x: minX, y: maxY) }
	var  rightCenter: CGPoint { return CGPoint(x: maxX, y: midY) }
	var bottomCenter: CGPoint { return CGPoint(x: midX, y: maxY) }

	var leftCenter: CGPoint {
		get { return CGPoint(x: minX, y: midY) }
		set {
			origin.x = newValue.x
			origin.y = newValue.y - (height / 2.0)
		}
	}

	var center: CGPoint {
		get { return CGPoint(x: midX, y: midY) }
		set {
			origin.x = newValue.x - (width  / 2.0)
			origin.y = newValue.y - (height / 2.0)
		}
	}

	var cornerPoints: [ZDirection : CGPoint] {
		var           result = [ZDirection : CGPoint]()
		result[.topLeft]     = origin
		result[.topRight]    = topRight
		result[.bottomLeft]  = bottomLeft
		result[.bottomRight] = extent

		return result
	}

	var selectionPoints: [ZDirection : CGPoint] {
		var           result = cornerPoints
		result[.top]         = topCenter
		result[.left]        = leftCenter
		result[.right]       = rightCenter
		result[.bottom]      = bottomCenter

		return result
	}

    public init(start: CGPoint, end: CGPoint) {
        self.init()

        size   = end - start
        origin = start

        if  size .width < 0 {
            size .width = -size.width
            origin   .x = end.x
        }

        if  size.height < 0 {
            size.height = -size.height
            origin   .y = end.y
        }
    }

    func indices(within iBounds: CGRect, radix: Int) -> IndexSet {
        let c = center
        var set = IndexSet()

        set.insert(Int(c.x))

        return set
    }

    func offsetBy(fractionX: CGFloat = 0.0, fractionY: CGFloat = 0.0) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY
        
        return offsetBy(dx:dX, dy:dY)
    }

	func insetBy(fractionX: CGFloat = 0.0, fractionY: CGFloat = 0.0) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY

        return insetBy(dx: dX, dy: dY)
    }

	func insetEquallyBy(fraction: CGFloat) -> CGRect {
		return insetBy(fractionX: fraction, fractionY: fraction)
	}

	func insetEquallyBy(_ inset: CGFloat) -> CGRect {
		return insetBy(dx: inset, dy: inset)
	}

	func offsetEquallyBy(_ offset: CGFloat) -> CGRect {
		return offsetBy(dx: offset, dy: offset)
	}

	var squareCentered: CGRect {
		let length = size.smallDimension
		let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

		return CGRect(origin: origin, size: CGSize(width: length, height: length))
	}

	func intersectsOval(within other: CGRect) -> Bool {
		let center =  other.center
		let radius = (other.height + other.width) / 4.0
		let deltaX = center.x - max(minX, min(center.x, maxX))
		let deltaY = center.y - max(minY, min(center.y, maxY))
		let  delta = radius - sqrt(deltaX * deltaX + deltaY * deltaY)

		return delta > 0
	}

}

extension ZBezierPath {

	func addDashes() {
		let pattern: [CGFloat] = [3.0, 3.0]

		setLineDash(pattern, count: 2, phase: 3.0)
	}

	static func drawTriangle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
		let path = trianglePath(orientedUp: orientedUp, in: iRect)

		path.draw(thickness: thickness)
	}

	static func trianglePath(orientedUp: Bool, in iRect: CGRect) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendTriangle(orientedUp: orientedUp, in: iRect)

		return path
	}

	func appendTriangle(orientedUp: Bool, in iRect: CGRect) {
		let yStart = orientedUp ? iRect.minY : iRect.maxY
		let   yEnd = orientedUp ? iRect.maxY : iRect.minY
		let    tip = CGPoint(x: iRect.midX, y: yStart)
		let   left = CGPoint(x: iRect.minX, y: yEnd)
		let  right = CGPoint(x: iRect.maxX, y: yEnd)

		move(to: tip)
		line(to: left)
		line(to: right)
		line(to: tip)
	}

	static func drawCircle(in iRect: CGRect, thickness: CGFloat) {
		let path = circlePath(in: iRect)

		path.draw(thickness: thickness)
	}

	static func circlePath(in iRect: CGRect) -> ZBezierPath {
		return ZBezierPath(ovalIn: iRect)
	}

	static func drawCircles(in iRect: CGRect, thickness: CGFloat, orientedUp: Bool) -> CGRect {
		let (path, rect) = circlesPath(orientedUp: orientedUp, in: iRect)

		path.draw(thickness: thickness)

		return rect
	}

	static func circlesPath(orientedUp: Bool, in iRect: CGRect) -> (ZBezierPath, CGRect) {
		let path = ZBezierPath()
		let rect = path.appendCircles(orientedUp: orientedUp, in: iRect)

		return (path, rect)
	}

	func appendCircles(orientedUp: Bool, in iRect: CGRect) -> CGRect {
		let   rect = iRect.offsetBy(fractionX: 0.0, fractionY: orientedUp ? 0.1 : -0.1)
		var    top = rect.insetBy(fractionX: 0.0, fractionY: 0.375)  // shrink to one-fifth size
		let middle = top.offsetBy(dx: 0.0, dy: top.midY - rect.midY)
		let bottom = top.offsetBy(dx: 0.0, dy: top.maxY - rect.maxY) // move to bottom
		top        = top.offsetBy(dx: 0.0, dy: top.minY - rect.minY) // move to top

		appendOval(in: top)
		appendOval(in: middle)
		appendOval(in: bottom)

		return orientedUp ? top : bottom
	}

	func draw(thickness: CGFloat) {
		lineWidth = thickness

		stroke()
	}

	static func drawBloatedTriangle(aimedRight: Bool, in iRect: CGRect, thickness: CGFloat) {
		let path = bloatedTrianglePath(aimedRight: aimedRight, in: iRect)

		path.draw(thickness: thickness)
	}

	static func bloatedTrianglePath(aimedRight: Bool, in iRect: CGRect) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendBloatedTriangle(aimedRight: aimedRight, in: iRect)

		return path
	}

	func appendBloatedTriangle(aimedRight: Bool, in iRect: CGRect) {
		let      center = iRect.center
		let  insetRatio = 0.35
		let      radius = Double(iRect.width) * insetRatio
		let  startAngle = aimedRight ? 0.0 : Double.pi
		let    bigAngle = Double.pi /  3.0 // one sixth of a circle
		let  smallAngle = Double.pi / 15.0 // one thirtieth
		let innerVector = CGPoint(x: radius,       y: 0.0)
		let outerVector = CGPoint(x: radius * 1.5, y: 0.0)
		var  controlOne = CGPoint.zero
		var  controlTwo = CGPoint.zero
		var       point = CGPoint.zero
		var       index = 0.0

		func rotatePoints() {
			let   angle = index * bigAngle + startAngle
			let   other = angle - bigAngle
			let     one = other - smallAngle
			let     two = other + smallAngle
			point       = innerVector.rotate(by: angle).offsetBy(center)
			controlOne  = outerVector.rotate(by:   one).offsetBy(center)
			controlTwo  = outerVector.rotate(by:   two).offsetBy(center)
			index      += 2.0
		}

		rotatePoints()
		move(to: point)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
		rotatePoints()
		curve(to: point, controlPoint1: controlOne, controlPoint2: controlTwo)
	}

	func appendCircle(at center: CGPoint, radius: CGFloat) {
		let rect = CGRect(origin: center, size: CGSize.zero).insetBy(dx: -radius, dy: -radius)

		appendOval(in: rect)
	}

}

extension Array {

    func apply(closure: AnyToStringClosure) -> String {
        var separator = ""
        var    string = ""

        for object in self {
            if let message = closure(object) {
                string.append("\(separator)\(message)")

                if  separator.isEmpty {
                    separator.appendSpacesToLength(kLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }

	func contains(_ other: AnyObject) -> Bool {
		return containsCompare(with: other) { (item, another) in
			return item === another
		}
	}

    func containsCompare(with other: AnyObject, using: CompareClosure? = nil) -> Bool {
        if  let compare = using {
            for item in self {
                if  compare(item as AnyObject, other) {
                    return true     // true means match
                }
            }
        }
        
        return false    // false means unique
    }

	mutating func appendUnique(contentsOf items: Array, compare: CompareClosure? = nil) {
		let existing = self as NSArray

		for item in items {
			if  !existing.contains(item),
				!containsCompare(with: item as AnyObject, using: compare) {
				append(item)
			}
		}
	}

	mutating func appendUniqueAndRemoveDuplicates(contentsOf items: Array, compare: CompareClosure? = nil) {
		let   existing = self as NSArray
		var duplicates = Array<Int>()

		for (index, item) in items.enumerated() {
			if  existing.contains(item) || containsCompare(with: item as AnyObject, using: compare) {
				duplicates.insert(index, at: 0)
			} else {
				append(item)
			}
		}

		for index in duplicates {
			if  count > index {
				remove(at: index)
			}
		}
	}

    func intersection<S>(_ other: Array<Array<Element>.Element>) -> S where Element: Hashable {
        return Array(Set(self).intersection(Set(other))) as! S
    }

}

extension ZRecordsArray {

	var recordNames: [String] {
		var  names = [String]()

		for zRecord in self {
			if  let name = zRecord.ckRecordName {
				names.append(name)
			}
		}

		return names
	}
}

extension CKReferencesArray {

	func containsReference(_ reference: CKReference) -> Bool {
		return containsCompare(with: reference) { (item, another) in
			return item.recordID.recordName == another.recordID.recordName
		}
	}

	func asZones(in dbID: ZDatabaseID) -> ZoneArray {
		return map { ckReference -> Zone in
			return gRemoteStorage.cloud(for: dbID)!.sureZoneForCKRecord(CKRecord(recordType: kZoneType, recordID: ckReference.recordID))
		}
	}

	var asRecordNames: [String] {
		return map { ckReference -> String in
			return ckReference.recordID.recordName
		}
	}

}

extension ZRecordsArray {

	func createStorageArray(from dbID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false, allowEach: ZRecordToBooleanClosure? = nil) throws -> [ZStorageDictionary]? {
		if  count > 0 {
			var result = [ZStorageDictionary] ()

			for zRecord in self {
//				if  let      zone  = zRecord as? Zone,
//					zone.zoneName == kLostAndFoundName,
//					zone.isInFavorites {
//					print("hah! found it")
//				}

				if  zRecord.ckRecord == nil {
					printDebug(.dFile, "no record: \(zRecord)")
				} else if (allowEach == nil || allowEach!(zRecord)),
						  let dict = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {

					if  dict.count != 0 {
						result.append(dict)
					} else {
						printDebug(.dFile, "empty storage dictionary: \(zRecord)")

						if  let dict2 = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
							print("gotcha \(dict2.count)")
						}
					}
				} else if !zRecord.isBookmark {
					printDebug(.dFile, "no storage dictionary: \(zRecord)")
				}
			}

			if  result.count > 0 {
				return result
			}
		}

		return nil
	}

	mutating func appendUnique(_ item: ZRecord) {
		appendUnique(contentsOf: [item]) { (a, b) -> (Bool) in
			if  let    aName  = (a as? ZRecord)?.ckRecordName,
				let    bName  = (b as? ZRecord)?.ckRecordName {
				return aName ==  bName
			}

			return false
		}
	}

	func containsMatch(to other: AnyObject) -> Bool {
		return containsCompare(with: other) { (a, b) in
			if  let    aName  = (a as? ZRecord)?.ckRecordName,
				let    bName  = (b as? ZRecord)?.ckRecordName {
				return aName ==  bName
			}

			return false
		}
	}

}

extension CKRecordsArray {

	mutating func appendUnique(_ item: CKRecord) {
		appendUnique(contentsOf: [item]) { (a, b) -> (Bool) in
			if  let aRecordName = (a as? CKRecord)?.recordID.recordName,
				let bRecordName = (b as? CKRecord)?.recordID.recordName {
				return aRecordName == bRecordName
			}

			return false
		}
	}

	func asZones(in dbID: ZDatabaseID) -> ZoneArray {
		return self.filter { ckRecord -> Bool in
			return ckRecord.recordType == kZoneType
		}.map { ckRecord -> Zone in
			return gRemoteStorage.cloud(for: dbID)!.sureZoneForCKRecord(ckRecord)
		}
	}

	var asRecordNames: [String] {
		return map { ckRecord -> String in
			return ckRecord.recordID.recordName
		}
	}

}

extension NSRange {

	var center: Int { return (lowerBound + upperBound) / 2 }

	func offsetBy(_ offset: Int) -> NSRange { return NSRange(location: offset + location, length: length) }

	func inclusiveIntersection(_ other: NSRange, includeUpper: Bool = true) -> NSRange? {
		if  let    i = intersection(other) {
			return i
		}

		if  location == other.location || (includeUpper && (other.upperBound == location || other.upperBound == upperBound)) {
			return NSRange(location: location, length: other.upperBound - location)
		}

		return nil
	}

}

extension NSTextTab {

	var string: String {
		return kAlignment + gSeparatorAt(level: 6) + "\(alignment.rawValue)" + gSeparatorAt(level: 5) + kLocation + gSeparatorAt(level: 6) + "\(location)"
	}

	convenience init(string: String) {
		var location: CGFloat = 0.0
		var alignment = NSTextAlignment.natural

		let parts = string.componentsSeparatedAt(level: 5)

		for part in parts {
			let subparts = part.componentsSeparatedAt(level: 6)
			let    value = subparts[1]
			switch subparts[0] {
				case kLocation:  if let v = value.floatValue                                         { location  = v }
				case kAlignment: if let v = value.integerValue, let a = NSTextAlignment(rawValue: v) { alignment = a }
				default: break
			}
		}

		self.init(textAlignment: alignment, location: location, options: [:])
	}
}

extension NSMutableParagraphStyle {

	var string: String {
		var result = kAlignment + gSeparatorAt(level: 3) + "\(alignment.rawValue)"

		if  let stops = tabStops {
			result.append(gSeparatorAt(level: 2) + kStops)

			for stop in stops {
				result.append(gSeparatorAt(level: 3) + stop.string)
			}
		}

		return result
	}

	convenience init(string: String) {
		self.init()

		let parts = string.componentsSeparatedAt(level: 2)

		for part in parts {
			let subparts = part.componentsSeparatedAt(level: 3)

			if  subparts.count > 1 {
				switch subparts[0] {
					case kAlignment:
						if  let   raw = subparts[1].integerValue,
							let     a = NSTextAlignment(rawValue: raw) {
							alignment = a
						}
					case kStops:  // TODO: can have more than one stop
						let string = subparts[1]
						let   stop = NSTextTab(string: string)
						tabStops   = [stop]
					default: break
				}
			}
		}
	}

}

extension ZFont {

	var string: String { return fontDescriptor.string }

	convenience init(string: String) {
		let descriptor = NSFontDescriptor(string: string)

		self.init(descriptor: descriptor, textTransform: nil)!
	}
}

extension NSFontDescriptor {

	var string: String {
		var result = ""
		var separator = ""

		for (name, attribute) in fontAttributes {
			result.append(separator + name.rawValue + gSeparatorAt(level: 3) + "\(attribute)")
			separator = gSeparatorAt(level: 2)
		}

		return result
	}

	convenience init(string: String) {
		let parts = string.modern.componentsSeparatedAt(level: 2)
		var dict  = [NSFontDescriptor.AttributeName : Any]()

		for part in parts {
			let subparts   = part.componentsSeparatedAt(level: 3)
			if  subparts.count > 1 {
				let    key = subparts[0]
				let  value = subparts[1]
				let   name = NSFontDescriptor.AttributeName(key)

				dict[name] = value
			}
		}

		self.init(fontAttributes: dict)
	}
}

struct ZRangedAttachment {
	let range: NSRange
	let attachment: NSTextAttachment
}

extension NSMutableAttributedString {

	var allKeys: [NSAttributedString.Key]     { return [.font, .link, .attachment, .paragraphStyle, .foregroundColor, .backgroundColor] }

	var linkRanges: [NSRange] {
		let range = NSRange(location: 0, length: length)
		var found = [NSRange]()

		enumerateAttribute(.link, in: range, options: []) { (item, inRange, flag) in
			if  inRange.length < 100 {
				found.append(inRange)
			}
		}

		return found
	}

	var rangedAttachments: [ZRangedAttachment] {
		let range = NSRange(location: 0, length: length)
		var found = [ZRangedAttachment]()

		enumerateAttribute(.attachment, in: range, options: .reverse) { (item, inRange, flag) in
			if  let attach = item as? NSTextAttachment {
				let append = ZRangedAttachment(range: inRange, attachment: attach)

				found.append(append)
			}
		}

		return found
	}

	var imageFileNames: [String] {
		var names = [String]()

		for rangedAttach in rangedAttachments {
			if  let name = rangedAttach.attachment.fileWrapper?.preferredFilename {
				names.append(name)
			}
		}

		return names
	}

	var attachmentCells: [NSTextAttachmentCell] {
		var array = [NSTextAttachmentCell] ()

		for rangedAttach in rangedAttachments {
			if  let  cell = rangedAttach.attachment.attachmentCell as? NSTextAttachmentCell {
				array.append(cell)
			}
		}

		return array
	}

	var attachedImages: [ZImage] {
		let array: [ZImage?] = attachmentCells.map { cell -> ZImage? in
			return cell.image
		}

		var result = [ZImage]()

		for item in array {
			if  let image = item {
				result.append(image)
			}
		}

		return result
	}

	var attributesAsString: String {
		get { return attributeStrings.joined(separator: gSeparatorAt(level: 1)) }
		set { attributeStrings = newValue.componentsSeparatedAt(level: 1) }
	}

	var attributeStrings: [String] {
		get {
			var result = [String]()
			let  range = NSRange(location: 0, length: length)

			for key in allKeys {
				enumerateAttribute(key, in: range, options: .reverse) { (item, inRange, flag) in
					var string: Any?

					if  let value      = item {
						if  let   font = value as? ZFont {
							string     = font.string
						}

						if  key       == .link {
							string     = "\(value)"
						}

						if  let  color = value as? NSColor {
							string     = color.string
						}

						if  let  style = value as? NSMutableParagraphStyle {
							string     = style.string
						}

						if  let attach = value as? NSTextAttachment,
							let   file = attach.fileWrapper { // check if file actually exists
							string     = file.preferredFilename
						}

						if  let append = string as? String {
							result.append("\(inRange.location)" + gSeparatorAt(level: 4) + "\(inRange.length)" + gSeparatorAt(level: 4) + key.rawValue + gSeparatorAt(level: 4) + append)
						}
					}
				}
			}

			return result
		}

		set {
			for string in newValue {
				let      parts = string.componentsSeparatedAt(level: 4)
				if       parts.count > 3,
					let  start = parts[0].integerValue,
					let  count = parts[1].integerValue {
					let    raw = parts[2]
					let string = parts[3]
					let    key = NSAttributedString.Key(rawValue: raw)
					let  range = NSRange(location: start, length: count)
					var attribute: Any?

					switch key {
						case .link:            attribute =                                    string
						case .font:            attribute = ZFont 		   		     (string: string)
						case .attachment:      attribute = gCurrentTrait?.textAttachment(for: string)
						case .foregroundColor,
							 .backgroundColor: attribute = ZColor				     (string: string)
						case .paragraphStyle:  attribute = NSMutableParagraphStyle   (string: string)
						default:    		   break
					}

					if  let value = attribute {
						printDebug(.dNotes, "add attribute over \(range) for \(raw): \(value)")

						addAttribute(key, value: value, range: range)
					}
				}
			}
		}
	}

	// ONLY called during save note (in set note text)
	// side-effect for a freshly dropped image:
	// it creates and returns an additional asset

	func assets(for trait: ZTrait) -> [CKAsset]? {
		var array = [CKAsset]()
		let     i = attachedImages // grab from text attachment cells

		for (index, name) in imageFileNames.enumerated() {
			if  index < i.count {
				let image = i[index]
				if  let a = trait.assetFromImage(image, for: name) {
					array.append(a)
				}
			}
		}

		return array.count == 0 ? nil : array
	}

	func removeAllAttributes() {
		let range = NSRange(location: 0, length: length)

		for key in allKeys {
			removeAttribute(key, range: range)
		}
	}

	func fixAllAttributes() {
		fixAttributes(in: NSRange(location: 0, length: self.length))
	}

}

extension NSTextAttachmentCell {

	var frame: CGRect {
		return CGRect(origin: attachment?.bounds.origin ?? CGPoint.zero, size: cellSize())
	}
}

extension NSTextAttachment {

	var image: ZImage? {
		get {
			if  let cell = attachmentCell as? NSTextAttachmentCell {
				return cell.image
			}

			return nil
		}

		set {
			if  let   cell = attachmentCell as? NSTextAttachmentCell {
				cell.image = newValue
			}
		}
	}

	func refreshImage() {
		// how?
	}

}

extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var   asciiValue:  UInt32  { return asciiArray[0] }
    var           length: Int  { return unicodeScalars.count }
	var         isHyphen: Bool { return self == "-" }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var   isAlphabetical: Bool { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var       isOpposite: Bool { return "]}>)".contains(self) }
	var     isDashedLine: Bool { return contains(kHalfLineOfDashes) }

    var opposite: String {
		switch self {
			case "[": return "]"
			case "]": return "["
			case "(": return ")"
			case ")": return "("
			case "{": return "}"
			case "}": return "{"
			case "<": return ">"
			case ">": return "<"
			default:  return self
		}
    }

    var escaped: String {
        var result = "\(self)"
        for character in "\\\"\'`" {
            let separator = "\(character)"
            let components = result.components(separatedBy: separator)
            result = components.joined(separator: kBackSlash + separator)
        }

        return result
    }

    var stripped: String {
        var before = self
        
        while before.starts(withAnyCharacterIn: kSpace) {
            before = before.substring(fromInclusive: 1) // strip extra space
        }
        
        while before.ends(withAnyCharacterIn: kSpace) {
            before = before.substring(toExclusive: before.length - 1) // strip trailing space
        }
        
        return before
    }

    /// remove underline from leading spaces

	var smartStripped: String {     //
        var altered = substring(fromInclusive: 4)
//        let lastIndex = altered.length - 1
//
//        if  altered[lastIndex] == "+" {
//            altered = altered.substring(toExclusive: lastIndex)
//        }

        altered = altered.stripped

        return altered
    }

	var modern: String {
		return replacingOccurrences(of: kLevelOneSeparator,   with: gSeparatorAt(level: 1))
			.replacingOccurrences  (of: kLevelTwoSeparator,   with: gSeparatorAt(level: 2))
			.replacingOccurrences  (of: kLevelThreeSeparator, with: gSeparatorAt(level: 3))
			.replacingOccurrences  (of: kLevelFourSeparator,  with: gSeparatorAt(level: 4))
	}

	var searchable: String {
		return lowercased()
			.replacingEachCharacter(in: ",;@!(){}\\\"",              with: "")
			.replacingEachCharacter(in: ".:_-='?/\r\n",              with: " ")
			.replacingEachString   (in: ["%2f", "%3a", "   ", "  "], with: " ")
	}

	var unCamelcased: String {
		guard self.count > 0 else { return self }

		var newString: String = ""
		let         uppercase = CharacterSet.uppercaseLetters
		let             first = unicodeScalars.first!

		newString.append(Character(first))

		for scalar in unicodeScalars.dropFirst() {
			if  uppercase.contains(scalar) {
				newString.append(" ")
			}
			let character = Character(scalar)
			newString.append(character)
		}

		return newString.lowercased()
	}

	func componentsSeparatedAt(level: Int) -> [String] {
		return components(separatedBy: gSeparatorAt(level: level))
	}

	func replacingEachCharacter(in matchAgainst: String, with: String) -> String {
		var        result = self
		for character in matchAgainst {
			let separator = String(character)
			result        = result.replacingOccurrences(of: separator, with: with)
		}

		return result
	}

	func replacingEachString(in matchAgainst: [String], with: String) -> String {
		var result = self
		for string in matchAgainst {
			result = result.replacingOccurrences(of: string, with: with)
		}

		return result
	}

	subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }

	subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

	static func pluralized(_ iValue: Int, unit: String = "", plural: String = "s", followedBy: String = "") -> String { return iValue <= 0 ? "" : "\(iValue) \(unit)\(iValue == 1 ? "" : "\(plural)")\(followedBy)" }
    static func from(_ ascii:  UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(fromInclusive: Int) -> String  { return String(self[index(at: fromInclusive)...]) }
    func substring(toExclusive:   Int) -> String  { return String(self[..<index(at: toExclusive)]) }
    func widthForFont  (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }

    func rect(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGRect {
		let within = substring(with: iRange)
		let bounds = within.rectWithFont(font)
		let xDelta = offset(using: font, for: iRange, atStart: atStart)
        
        return bounds.offsetBy(dx: xDelta, dy: 0.0)
    }

    func offset(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGFloat {
        let            end = iRange.lowerBound
        let     startRange = NSMakeRange(0, end)
        let      selection = substring(with: iRange)
        let startSelection = substring(with: startRange)
        let          width = selection     .sizeWithFont(font).width
        let     startWidth = startSelection.sizeWithFont(font).width
        
        return startWidth + (atStart ? 0.0 : width)    // move down, use right side of selection
    }

	var integerValue: Int? {
		if  let    value = Int(self) {
			return value
		}

		return nil
	}

	var doubleValue: Double? {
		return Double(self)
	}

    var floatValue: CGFloat? {
		if  let d = doubleValue {
			return CGFloat(d)
		}

		return nil
    }

    var color: ZColor? {
        if self != "" {
            let pairs = components(separatedBy: kCommaSeparator)
            var   red = 0.0
            var  blue = 0.0
            var green = 0.0

            for pair in pairs {
                let values = pair.components(separatedBy: kColonSeparator)
                let  value = Double(values[1])!
                let    key = values[0]

				switch key {
					case   "red":   red = value
					case  "blue":  blue = value
					case "green": green = value
					default:      break
				}
            }

            return ZColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
        }

        return nil
    }

    func index(at: Int) -> Index {
        var position = at

        repeat {
            if let index = index(startIndex, offsetBy: position, limitedBy: endIndex) {
                return index
            }

            position -= 1
        } while position > 0

        return startIndex
    }

	
	func starts(with: String) -> Bool {
		let start = substring(toExclusive: with.length)
		
		return with == start
	}
	

	func starts(withAnyCharacterIn: String) -> Bool {
		let start = substring(toExclusive: 1)
		
		return withAnyCharacterIn.contains(start)
	}

    func ends(withAnyCharacterIn: String) -> Bool {
        let end = substring(fromInclusive: length - 1)

        return withAnyCharacterIn.contains(end)
    }

    func stringBySmartly(appending: String) -> String {
        var before = self
        var  after = appending

        while after.starts(with: kSpace) {
            after = after.substring(fromInclusive: 1) // strip starting space
        }

        while before.ends(withAnyCharacterIn: kSpace) && after == "" {
            before = before.substring(toExclusive: before.length - 1) // strip trailing space
        }

        if !before.ends(withAnyCharacterIn: kSpace) && !after.starts(withAnyCharacterIn: kSpace) && !after.isEmpty {
            before = before + kSpace // add separator space when after is not empty
        }

        while before.starts(with: kSpace) {
            before = before.substring(fromInclusive: 1) // strip starting space
        }

        return before + after
    }

    func stringBySmartReplacing(_ range: NSRange, with replacement: String) -> String {
        let a = substring(toExclusive:   range.lowerBound)
        let b = replacement
        let c = substring(fromInclusive: range.upperBound)

        return a.stringBySmartly(appending: b.stringBySmartly(appending: c))
    }

    func substring(with range: NSRange) -> String {
        let iStart = index(at: range.lowerBound)
        let   iEnd = index(at: range.upperBound)

        return String(self[iStart ..< iEnd])
    }

    func location(of offset: CGFloat, using font: ZFont) -> Int {
        var location = 0
        var total = CGFloat(0.0)
        
        for (index, character) in enumerated() {
            let width = String(character).sizeWithFont(font).width
            let threshold = total + width / 2.0
            total += width

            if  threshold <= offset {
                location = index + 1
            }

            if  threshold >= offset {
                break
            }
        }

        return location
    }

    func character(at iOffset: Int) -> String {
        let index = self.index(startIndex, offsetBy: iOffset)

        return self[index].description
    }

    mutating func appendSpacesToLength(_ iLength: Int) {
        if 0 < iLength {
            while length < iLength {
                append(" ")
            }
        }
    }

    var isLineWithTitle: Bool {
        let substrings = components(separatedBy: kHalfLineOfDashes)
        
        if  substrings.count == 3 {
            return substrings[1].count > 0 || substrings[2].count > 0
        }
        
        return false
    }

    func isLineTitle(enclosing range: NSRange) -> Bool {
        let a = substring(  toExclusive: range.lowerBound - 1)
        let b = substring(fromInclusive: range.upperBound + 1)

        return a == kHalfLineOfDashes && b == kHalfLineOfDashes
    }

    static func forZones(_ zones: ZoneArray?) -> String {
        return zones?.apply()  { object -> (String?) in
            if  let zone  = object as? Zone {
                let name  = zone.decoratedName
                if  name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }

    static func forCKRecords(_ records: CKRecordsArray?) -> String {
        return records?.apply() { object -> (String?) in
            if  let  record  = object as? CKRecord {
                let    name  = record.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }

    static func forReferences(_ references: CKReferencesArray?, in databaseID: ZDatabaseID) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStorage.zRecords(for: databaseID)?.maybeZoneForReference(reference) {
                let    name  = zone.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }

    static func forOperationIDs (_ iIDs: ZOperationIDsArray?) -> String {
        return iIDs?.apply()  { object -> (String?) in
            if  let operation  = object as? ZOperationID {
                let name  = "\(operation)"
                if  name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }

    static func *(_ input: String, _ multiplier: Int) -> String {
        var  count = multiplier
        var output = ""

        while count > 0 {
            count  -= 1
            output += input
        }

        return output
    }

    static func character(at index: Int, for levelType: ZOutlineLevelType) -> String {
        if levelType == .roman {
            return toRoman(number: index + 1)
        } else if levelType == .number {
            return String(index + Int(levelType.level))
        } else {
            return String.from(levelType.asciiValue + UInt32(index))
        }
    }

    static func toRoman(number: Int) -> String {
        let romanValues = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        let arabicValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        var startingValue = number
        var romanValue = ""

        for (index, romanChar) in romanValues.enumerated() {
            let arabicValue = arabicValues[index]
            let ratio = startingValue / arabicValue

            if (ratio > 0) {
                for _ in 0 ..< ratio {
                    romanValue += romanChar
                }

                startingValue -= arabicValue * ratio
            }
        }

        return romanValue
    }
	
	
	func trimmed(by: Int = 1) -> String {
		let t = substring(toExclusive: self.length - by)
		return t.substring(fromInclusive: by)
	}

	func rangesMatching(_ iText: String?, ignoreRange: NSRange, seekForward: Bool = true, needSpaces: Bool = true) -> [NSRange]? {
		return rangesMatching(iText, needSpaces: needSpaces)
	}

	func rangesMatching(_ iText: String?, needSpaces: Bool = true) -> [NSRange]? {
		if  let     t = iText?.lowercased() {
			let parts = lowercased().components(separatedBy: t)
			let count = parts.count - 1
			let match = " -,:.;"

			if  count > 0 {
				var   ranges = [NSRange] ()
				var location = 0
				
				for index in 0 ..< count {
					let  this = parts[index]
					let range = NSRange(location: location + this.length, length: t.length)
					location  = range.upperBound
					
					if  needSpaces,
						index + 1 < count {
						let next = parts[index + 1]

						if  (this.length > 0 && !this  .ends(withAnyCharacterIn: match)) ||
							(next.length > 0 && !next.starts(withAnyCharacterIn: match)) {
							continue
						}
					}

					ranges.append(range)
					
					break
				}
				
				return ranges
			}
		}
		
		return nil
	}

	func repeatOf(_ length: Int) -> String {
		var  count = length
		var result = ""

		while count > 0 {
			count -= 1

			result.append(self)
		}

		return result
	}

	func surround(with repeater: String) -> String {
		let inner = smallSurround(with: " ").smallSurround(with: repeater)
		let outer = repeater.repeatOf(count + 8)

		if  repeater == "" {
			return "\n\(inner)\n"
		} else {
			return "\n\(outer)\n\(inner)\n\(outer)\n"
		}
	}

	func smallSurround(with repeater: String) -> String {
		let small = repeater.repeatOf(2)

		return "\(small)\(self)\(small)"
	}

}

extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }
}

extension Data {

	var checksum : Int {
		return map { Int($0) }.reduce(0, +)
	}

	var string: String? {
		do {
			if  let s = try JSONSerialization.jsonObject(with: self, options: .mutableLeaves) as? String {
				return s
			}
		} catch {}

		return nil
	}

}

extension ZColor {

	static func + (left: ZColor, right: ZColor?) -> ZColor {
		if right == nil { return left }

		var (rLeft,  gLeft,  bLeft,  aLeft)  = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
		var (rRight, gRight, bRight, aRight) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))

		left  .getRed(&rLeft,  green: &gLeft,  blue: &bLeft,  alpha: &aLeft)
		right!.getRed(&rRight, green: &gRight, blue: &bRight, alpha: &aRight)

		return ZColor(red: (rLeft + rRight) / 2, green: (gLeft + gRight) / 2, blue: (bLeft + bRight) / 2, alpha: (aLeft + aRight) / 2)
	}

}

extension Date {
	
	var easyToReadDate: String {
		let f = DateFormatter()
		f.dateFormat = "MMM d, YYYY"
		
		return f.string(from: self)
	}
	
	var easyToReadTime: String {
		let f = DateFormatter()
		f.dateFormat = "h:mm a"
		
		return f.string(from: self)
	}

    func mid(to iEnd: Date?) -> Date? {
        let      end = iEnd ?? Date()
        let duration = timeIntervalSince(end) / 2.0
		
		if  duration > -1.0 {
			return nil
		}

        return addingTimeInterval(duration)
    }

}

extension ZGestureRecognizer {

    @objc var isShiftDown:   Bool { return false }
    @objc var isOptionDown:  Bool { return false }
    @objc var isCommandDown: Bool { return false }

    func cancel() {
        isEnabled = false
        isEnabled = true
    }
}

extension ZView {

	var simpleToolID : ZSimpleToolID? {
		let           item = self as NSUserInterfaceItemIdentification
		if  let identifier = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
			let     itemID = ZSimpleToolID(rawValue: identifier) {
			return  itemID
		}

		return nil
	}

	var modeButtonType : ZModeButtonType? {
		get {
			let        item = self as NSUserInterfaceItemIdentification
			if  let  itemID = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
				let    type = ZModeButtonType(rawValue: itemID) {
				return type
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = convertToUserInterfaceItemIdentifier(value)
			}
		}
	}

	var helpMode : ZHelpMode? {
		get {
			let        item = self as NSUserInterfaceItemIdentification
			if  let  itemID = convertFromOptionalUserInterfaceItemIdentifier(item.identifier),
				let    mode = ZHelpMode(rawValue: itemID) {
				return mode
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = convertToUserInterfaceItemIdentifier(value)
			}
		}
	}

	func removeAllSubviews() {
		for view in subviews {
			view.removeFromSuperview()
		}
	}

    func clearGestures() {
        if  recognizers != nil {
            for recognizer in recognizers! {
                removeGestureRecognizer(recognizer)
            }
        }
    }

	func printConstraints() {
		var result = [String]()

		result.append("\(identifier?.rawValue ?? "dunno") ")

		for constraint in constraints {
			result.append("\(constraint)")
		}

		print(result.joined(separator: "\r"))
	}

	func drawColored(rect: CGRect, _ color: ZColor) {
		color.setStroke()
		ZBezierPath(rect: rect).stroke()
	}

    func addBorder(thickness: CGFloat, inset: CGFloat = 0.0, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }

    func addBorderRelative(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        let            size = self.bounds.size
        let radius: CGFloat = min(size.height, size.width) * radius

        self.addBorder(thickness: thickness, radius: radius, color: color)
    }

    func setAllSubviewsNeedDisplay() {
        if !gDeferringRedraw {
            applyToAllSubviews { iView in
                iView.setNeedsDisplay()
            }
        }
    }

    func applyToAllSubviews(_ closure: ViewClosure) {
        closure(self)

        for view in subviews {
            view.applyToAllSubviews(closure)
        }
    }

    func applyToAllSuperviews(_ closure: ViewClosure) {
        closure(self)

        superview?.applyToAllSuperviews(closure)
	}

	func locationFromEvent(_ event: ZEvent) -> CGPoint {
		return convert(event.locationInWindow, from: nil)
	}

	func rectFromEvent(_ event: ZEvent) -> CGRect {
		return convert(CGRect(origin: event.locationInWindow, size: CGSize.zero), from: nil)
	}

	func analyze(_ object: AnyObject?) -> (Bool, Bool, Bool, Bool, Bool) {
		return (false, true, false, false, false)
	}

	// this is abandoned
	// code for examining objects in the ring

	func xanalyze(_ object: AnyObject) -> (Bool, Bool, Bool, Bool, Bool) {
		var noteFocus = false
		var ideaFocus = false
		var   asEssay = false
		var    asNote = false
		var    asIdea = false

		if      let  idea = object as? Zone {
			if  let ident = idea.identifier() {
				asIdea    = true
				ideaFocus = ident == gHereMaybe?.identifier()
			}
		} else if let note = object as? ZNote {
			asNote    = true

			if  let current = gCurrentEssay,
				note == current {
				noteFocus = true
			}

			if  note.isKind(of: ZEssay.self) {
				asEssay = true
			}
		} else if let others = object as? ZObjectsArray {
			for other in others {
				let (newIdeaFocus, newIdea, newNoteFocus, newNote, newEssay) = analyze(other)
				noteFocus = noteFocus || newNoteFocus
				ideaFocus = ideaFocus || newIdeaFocus
				asEssay   = asEssay   || newEssay
				asNote    = asNote    || newNote
				asIdea    = asIdea    || newIdea
			}
		}

		return (ideaFocus, asIdea, noteFocus, asNote, asEssay)
	}

	func drawTinyDots(surrounding rect: CGRect, count: Int?, radius: Double, color: ZColor?, countMax: Int = 10, clockwise: Bool = false, onEach: IntRectClosure? = nil) {
		if  var       dotCount = count {
			var      fatHollow = false
			var     tinyHollow = false
			var      tinyIsFat = false
			var          scale = 1.0

			while     dotCount > (countMax *  countMax) {
				dotCount       = (dotCount + (countMax / 2)) / countMax    // round to closest
				scale          = 1.25

				if  fatHollow {
					tinyHollow = true
				} else {
					tinyIsFat  = true
					fatHollow  = true
				}
			}

			if  dotCount       > 0 {
				let  tinyCount = dotCount % countMax
				let   fatCount = dotCount / countMax
				let fullCircle = Double.pi * 2.0

				let drawDots: IntBooleanClosure = { (iCount, isFat) in
					let             oneSet = (isFat ? tinyCount : fatCount) == 0
					let           isHollow = (isFat && fatHollow) || (!isFat && tinyHollow)

					if  iCount             > 0 {
						let         isEven = iCount % 2 == 0
						let incrementAngle = fullCircle / (oneSet ? 1.0 : 2.0) / Double(-iCount)
						let     startAngle = fullCircle / 4.0 * ((clockwise ? 0.0 : 1.0) * (oneSet ? (isEven ? 0.0 : 2.0) : isFat ? 1.0 : 3.0)) + (oneSet ? 0.0 : Double.pi)

						for index in 0 ... iCount - 1 {
							let  increment = Double(index) + ((clockwise || (isEven && oneSet)) ? 0.0 : 0.5)
							let      angle = startAngle + incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
							let (ideaFocus, asIdea, asEssay) = (false, true, false)

							// notes are ALWAYS big (fat ones are bigger) and ALWAYS hollow (surround idea dots)
							// ideas are ALWAYS tiny and SOMETIMES fat (if over ten) and SOMETIMES hollow (if over hundered)
							//
							// so, three booleans: isFat, isHollow, forNote
							//
							// everything should always goes out more (regardless of no notes)

							func drawDot(isFocus: Bool) {
								let          asFat = isFat || tinyIsFat
								let    offsetRatio = asFat ? 2.1 : 1.28
								let       fatRatio = isFat ? 2.0 : 1.6
								let       dotRatio = asFat ? 4.0 : 2.5

								let   scaledRadius = radius * scale
								let  necklaceDelta = scaledRadius * 2.0 * 1.5
								let      dotRadius = scaledRadius * fatRatio
								let     rectRadius = Double(rect.size.height) / 2.0
								let necklaceRadius = CGFloat(rectRadius + necklaceDelta)
								let    dotDiameter = CGFloat(dotRadius  * dotRatio)
								let         offset = CGFloat(dotRadius  * offsetRatio)

								let     rectCenter = rect.center
								let         center = CGPoint(x: rectCenter.x - offset, y: rectCenter.y - offset)
								let              x = center.x + (necklaceRadius * CGFloat(cos(angle)))
								let              y = center.y + (necklaceRadius * CGFloat(sin(angle)))

								let       ovalRect = CGRect(x: x, y: y, width: dotDiameter, height: dotDiameter)
								let           path = ZBezierPath(ovalIn: ovalRect)
								path    .lineWidth = CGFloat(gLineThickness * (asEssay ? 7.0 : 3.0))
								path     .flatness = 0.0001

								if  isHollow {
									color?.setStroke()
									path.stroke()
								} else {
									color?.setFill()
									path.fill()
								}

								onEach?(index, ovalRect)
							}

							if  asIdea {
								drawDot(isFocus: ideaFocus)
							}
						}
					}
				}

				drawDots( fatCount, true)  // isFat = true
				drawDots(tinyCount, false)
			}
		}
	}

}

extension ZTextField {

    var       isEditingText:  Bool { return gIsEditIdeaMode }
    @objc var preferredFont: ZFont { return gWidgetFont }

    @objc func selectCharacter(in range: NSRange) {}
    @objc func alterCase(up: Bool) {}
}
