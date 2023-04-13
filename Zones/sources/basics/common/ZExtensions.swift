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

typealias                CKRecordID = CKRecord.ID
typealias               CKReference = CKRecord.Reference
typealias          ZStoryboardSegue = NSStoryboardSegue

typealias                 ZoneArray = [Zone]
typealias               ZOpIDsArray = [ZOperationID]
typealias               ZFilesArray = [ZFile]
typealias               ZTraitArray = [ZTrait]
typealias              StringsArray = [String]
typealias             CKAssetsArray = [CKAsset]
typealias             ZRecordsArray = [ZRecord]
typealias             ZObjectsArray = [NSObject]
typealias           ZoneWidgetArray = [ZoneWidget]
typealias           ZObjectIDsArray = [NSManagedObjectID]
typealias          CKRecordIDsArray = [CKRecordID]
typealias          ZSignalKindArray = [ZSignalKind]
typealias          ZDatabaseIDArray = [ZDatabaseID]
typealias         CKReferencesArray = [CKReference]
typealias         ZTinyDotTypeArray = [[ZTinyDotType]]
typealias        ZRelationshipArray = [ZRelationship]
typealias      ZManagedObjectsArray = [NSManagedObject]

typealias          ZTraitDictionary = [ZTraitType   : ZTrait]
typealias         ZAssetsDictionary = [UUID         : CKAsset]
typealias        ZStorageDictionary = [ZStorageType : NSObject]
typealias      WidgetHashDictionary = [Int          : ZoneWidget]
typealias  ZRelationshipsDictionary = [Int          : ZRelationshipArray]
typealias      ZStringAnyDictionary = [String       : Any]
typealias   StringZRecordDictionary = [String       : ZRecord]
typealias   ZStringObjectDictionary = [String       : NSObject]
typealias ZManagedObjectsDictionary = [String       : ZManagedObject]
typealias  StringZRecordsDictionary = [String       : ZRecordsArray]
typealias    ZDBIDRecordsDictionary = [ZDatabaseID  : ZRecordsArray]
typealias     ZAttributesDictionary = [NSAttributedString.Key : Any]
protocol ZGeneric {
	func controllerSetup(with mapView: ZMapView?)
}

func gSeparatorAt(level: Int) -> String { return " ( \(level) ) " }

func gSignal(_ multiple: ZSignalKindArray, _ onCompletion: Closure? = nil) {
	gControllers.signalFor(multiple: multiple, onCompletion: onCompletion)
}

private var canUpdate = true

func gRelayoutMaps(_ onCompletion: Closure? = nil) {
	gSignal([.spRelayout], onCompletion)
}

func gDeferRedraw(_ closure: Closure) {
	let         save = gDeferringRedraw
	gDeferringRedraw = true

	closure()

	gDeferringRedraw = save   // in case closure doesn't reset it
}

func gDisablePush(_ closure: Closure) {
	gPushIsDisabled = true

	closure()

	gPushIsDisabled = false
}

func gCompareZones(_ a: AnyObject, _ b: AnyObject) -> Bool {
	if  let alpha = (a as? Zone)?.recordName,
		let  beta = (b as? Zone)?.recordName {
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

func noop() {}

extension NSObject {

    func       performance(_ iMessage: Any?) { log(iMessage) }
	func               bam(_ iMessage: Any?) { log("\(kHyphen.repeatedFor(80)) " + (iMessage as? String ?? kEmpty)) }
	func printSelf()                         { print(self) }
	func printCurrentFocus()                 { gMapController?.hereWidget?.printWidget()}
	func printCurrentEssay()                 { gEssayView?.printView() }
	@objc func copyWithZone(_ with: NSZone) -> NSObject { return self }
	func columnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(mode: mode, iFirst, iSecond) }

	var        selfInQuotes : String { return "\"\(self)\"" }
	var          debugTitle : String { return zClassInitial + kSpace + debugName }
	@objc var     debugName : String { return description }
	@objc var zClassInitial : String { return zClassName[0] }

	@objc var zClassName: String {
		let parts = className.components(separatedBy: kDotSeparator)
		let index = parts.count == 1 ? 0 : 1
		let  name = parts[index].unCamelcased.uppercased()
		let names = name.components(separatedBy: kSpace).dropFirst()

		return names.joined(separator: kSpace)
	}

	func rawColumnarReport(mode: ZPrintMode = .dLog, _ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            printDebug(mode, "\(prefix)\(iSecond ?? kEmpty)")
        }
    }

    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != kEmpty {
            printDebug(.dLog, message)
        }
    }

	func debugTime(message: String, _ closure: Closure) {
		let start = Date()

		closure()

		let duration = Date().timeIntervalSince(start)

		printDebug(.dTime, duration.stringTo(precision: 2) + kSpace + message)
	}

    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }

    func blankScreenDebug() {
        if  let w = gMapController?.hereWidget?.bounds.size.width, w < 1.0 {
            bam("blank map !!!!!!")
        }
    }

	func temporarilyApplyThenDelay(for interval: Double, _ closure: BoolClosure?) {
		closure?(true)

		let _ = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { iTimer in
			closure?(false)
			iTimer.invalidate()
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

    func UNDO<TargetType : AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        gUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }

	func showThesaurus(for iString: String? = kEmpty) {
		if  let string = iString {
			let    url = URL(string: "https://www.thesaurus.com/browse/\(string)")
			url?.open()
		}
	}

    func openBrowserForSeriouslyWebsite() {
		"introduction+b+what-you-get-d565b064be7b".asHelpURL?.openAsURL()
    }

    func sendEmailBugReport() {
        let url = kMailTo + "sand@gizmolab.com?subject=Regarding Seriously"

		url.openAsURL()
	}

    // MARK: - JSON
    // MARK: -

    func dictFromJSON(_ dict: ZStringObjectDictionary) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + kColonSeparator)
                    if  parts.count > 1,
                        parts[0]    == kEmpty,
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

	var mainDictionary : ZStorageDictionary? {
		for (key, value) in self {
			switch key {
				case .graph: return value as? ZStorageDictionary
				default:     break
			}
		}

		return self
	}

	var recordName : String? {
		for (key, value) in self {
			switch key {
				case .graph:      return (value as? ZStorageDictionary)?.recordName
				case .recordName: return  value as? String
				default:          break
			}
		}

		return nil
	}

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
		} catch {
			printDebug(.dError, "\(error)")
		}

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

	var originalImageName : String? { return CGImageSource.readFrom(self)?.originalImageName }
	var walURL            :    URL? { return URL(string: path + "-wal") }
	var fileExists        :    Bool { return gFileManager.fileExists(atPath: path) }
	var containsData      :    Bool { return fileExists && dataRepresentation.count > 0 }
	var walContainsData   :    Bool { return walURL?.containsData ?? false }
	func remove()            throws { try gFileManager.removeItem(at: self) }

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

	func writeData(_ data: Data?) -> Bool {
		var success = false

		if  let d = data {
			do {
				try d.write(to: self, options: Data.WritingOptions.atomic)

				success = true
			} catch {
				printDebug(.dError, "\(error)")
			}
		}

		return success
	}

	func replacingPathComponent(_ first: String, with second: String) -> URL {
		var components = pathComponents

		for (index, component) in components.enumerated() {
			if  component == first {
				components[index] = second
			}
		}

		return URL(fileURLWithPath: components.joined(separator: kSlash))
	}

}

extension CGImageSource {

	class func readFrom(_ url: URL) -> CGImageSource? { return CGImageSourceCreateWithURL(url as CFURL, nil) }
	var metadata: ZStringAnyDictionary? { return CGImageSourceCopyPropertiesAtIndex(self, 0, nil) as? ZStringAnyDictionary }
	var originalImageName: String? { return metadata?[kOrignalImageName] as? String }

}

extension ZSignalKindArray {

	var debugDescription: String {
		get {
			var result = kEmpty
			forEach { kind in
				result.append("\(kind), ")

				if  kind == .spRelayout {
					noop()
				}
			}
			return result
		}
	}
}

extension CKAsset {

	var data       :   Data? { return gFileManager.contents(atPath: fileURL!.path) }
	var imageSize  : CGSize? { return fileURL!.imageSize }
	var uuidString : String? { return value(forKeyPath: "_UUID") as? String }
	var length     :    Int? { return value(forKeyPath: "_size") as? Int }

}

extension CKRecord {

    var reference: CKReference { return CKReference(recordID: recordID, action: .none) }
	var entityName: String {
		switch recordType {
			case kUserRecordType: return kUserEntityName
			default:              return recordType
		}
	}

	var isOrphaned: Bool {
		var parentRecordName : String?
		var parentReference  = self[kpParent] as? CKReference

		if  parentReference == nil {
			if  let     link = self[kpZoneParentLink] as? String {
				parentRecordName = link.maybeRecordName // parent is in other db
			} else {
				parentReference  = self[kpOwner] as? CKReference
			}
		}

		if  let ref = parentReference {
			parentRecordName = ref.recordID.recordName
		}

		if  parentRecordName != nil {
			return gMaybeZoneForRecordName(parentRecordName) == nil
		}

		return true
	}

	var storable: String {
		get {
			var pairs = StringsArray()
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

    var isBookmark: Bool {
        if  let    link = self[kpZoneLink] as? String {
            return link.contains(kColonSeparator)
        }

        return false
    }

	var traitType: String {
		var string = kEmpty

		if  let        type = self["type"] as? String,
			let       trait = ZTraitType(rawValue: type),
			let description = trait.description {
			string          = description + kUncommonSeparator
		}

		return string
	}

    convenience init(for name: String) {
        self.init(recordType: kZoneType, recordID: CKRecordID(recordName: name))
    }

    func isDeleted(databaseID: ZDatabaseID) -> Bool {
        return gRemoteStorage.zRecords(for: databaseID)?.manifest?.deletedRecordNames?.contains(recordID.recordName) ?? false
    }

    @discardableResult func copy(to iCopy: CKRecord?, properties: StringsArray) -> Bool {
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

	static func ** (base: Double, power: Double) -> Double  { return pow(base, power) }
	func   confine(within: Double)               -> Double  { return Double(float.confine(within: CGFloat(within))) }
	func   stringTo(precision: Int)              -> String  { return        float.stringTo(precision: precision) }
	var    roundedToNearestInt                    : Int     { return        float.roundedToNearestInt }
	var    upward                                 : Bool    { return self < kPI }
	var    squared                                : Double  { return self * self }
	var    float                                  : CGFloat { return CGFloat(self) }

}

extension CGFloat {

	var  roundedToNearestInt                     : Int     { return Int(self + 0.5) }
	var  upward                                  : Bool    { return     self < kPI.float }
	var  squared                                 : CGFloat { return     self * self }
	var  invertedSquared                         : CGFloat { return 1.0 / squared }
	var  oneDigitString                          : String  { return stringTo(precision: 1) }
	var  twoDigitString                          : String  { return stringTo(precision: 2) }
	func stringTo(precision: Int)               -> String  { return String(format: "%.0\(precision)f", self) }
	func isBetween(low: CGFloat, high: CGFloat) -> Bool    { return low < high && low < self && self < high }

	func confineBetween(low: CGFloat, high: CGFloat) -> CGFloat {
		return fmax(fmin(self, high), low)
	}

	func confine(within: CGFloat) -> CGFloat {
		var       i  = self
		if   within != .zero {
			while i  < .zero {
				i   += within
			}

			while i >= within {
				i   -= within
			}
		}

		return i
	}

}

extension Int {

	var ordinal: String {
		switch self {
			case 1:  return "first"
			case 2:  return "second"
			case 3:  return "third"
			default: return kEmpty
		}
	}

	func isWithin(_ range: ClosedRange<Int>) -> Bool    { return range.contains(self) }
	func confine(within: Int)                -> Int     { return Int(float.confine(within: CGFloat(within))) }
	var  stringInThousands                    : String  { return "\(((float * 2.0 / 1000.0).rounded(.toNearestOrAwayFromZero) / 2.0).stringTo(precision: 1))" }
	var  stringInHundreds                     : String  { return "\((float / 100.0).rounded(.toNearestOrAwayFromZero).stringTo(precision: 0))" }
	var  float                                : CGFloat { return CGFloat(self) }

	func anglesArray(startAngle: Double, spreadAngle: Double = k2PI, offset: Double? = nil, oneSet: Bool = true, isFat: Bool = false, clockwise: Bool = false) -> [Double] {
		var angles             = [Double]()
		if  self              > 0 {
			let         isEven = self % 2 == 0
			let          extra = offset ?? ((clockwise || (isEven && oneSet)) ? .zero : 0.5)
			let incrementAngle = spreadAngle / (oneSet ? 1.0 : 2.0) / Double(-self) // negative means clockwise in osx (counterclockwise in ios)

			for index in 0 ... self - 1 {
				let increments = Double(index) + extra
				let      angle = startAngle + incrementAngle * increments

				angles.append(angle.confine(within: k2PI))
			}
		}

		return angles
	}

}

infix operator -- : AdditionPrecedence

extension CGPoint {

	var containsNAN     : Bool    { return x.isNaN || y.isNaN }
	var twoDigitsString : String  { return "(\(x.stringTo(precision: 2)), \(y.stringTo(precision: 2)))"}
	var oneDigitString  : String  { return "(\(x.stringTo(precision: 1)), \(y.stringTo(precision: 1)))"}
	var integerString   : String  { return "(\(Int(x)), \(Int(y)))" }
	var dividedInHalf   : CGPoint { return multiplyBy(0.5) }
	var inverted        : CGPoint { return CGPoint(x: -x, y: -y) }
	var length          : CGFloat { return sqrt(x * x + y * y) }
	var angle           : CGFloat { return atan2(y, x) }

	public static func squared(_ length: CGFloat) -> CGPoint { return CGPoint(x: length, y: length) }

    public init(_ size: CGSize) {
        self.init()

        x = size.width
        y = size.height
    }

	static func + (left: CGPoint, right: CGPoint) -> CGPoint {
		return CGPoint(x: left.x + right.x, y: left.y + right.y)
	}

    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
		return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }

	static func + (left: CGPoint, right: CGSize) -> CGPoint {
		return CGPoint(x: left.x + right.width, y: left.y + right.height)
	}

	static func - (left: CGPoint, right: CGSize) -> CGPoint {
		return CGPoint(x: left.x - right.width, y: left.y - right.height)
	}

    static func -- (left: CGPoint, right: CGPoint) -> CGFloat {
        let  width = Double(left.x - right.x)
        let height = Double(left.y - right.y)

        return CGFloat(sqrt(width * width + height * height))
    }

	static func * (left: CGPoint, multiplier: CGFloat) -> CGPoint {
		return CGPoint(x: left.x * multiplier, y: left.y * multiplier)
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

	func retreatBy(_ delta: CGSize) -> CGPoint { // reverse regress backslide goback
		return CGPoint(x: x - delta.width, y: y - delta.height)
	}

	func multiplyBy(_ fraction: CGFloat) -> CGPoint {
		return CGPoint(x: x * fraction, y: y * fraction)
	}

	func intersectsTriangle(pointingDown: Bool, in iRect: CGRect) -> Bool {
		return ZBezierPath.trianglePath(pointingDown: pointingDown, in: iRect).contains(self)
	}

	func intersectsCircle(in iRect: CGRect) -> Bool {
		return ZBezierPath.circlePath(in: iRect).contains(self)
	}

	func intersectsCircle(orientedUp: Bool, in iRect: CGRect) -> Bool {
		let (path, _) = ZBezierPath.circlesPath(orientedUp: orientedUp, in: iRect)

		return path.contains(self)
	}

	func rotate(by angle: Double, around center: CGPoint = .zero) -> CGPoint {
		let     r = length
		let delta = CGPoint(x: r * CGFloat(cos(angle)), y: r * CGFloat(sin(angle)))

		return center + delta
	}

	func drawColoredLine(_ color: ZColor, to endPoint: CGPoint, thickness: CGFloat = 0.5) {
		ZBezierPath.defaultLineWidth = thickness

		color.setStroke()
		ZBezierPath.strokeLine(from: self, to: endPoint)
	}

	func printPoint(_ message: String = kEmpty) {
		print(message + " x: " + x.stringTo(precision: 1) + " y: " + y.stringTo(precision: 1))
	}

}

extension CGSize {

	static var big     : CGSize  { return CGSize.squared(1000000.0) }
	var swapped        : CGSize  { return CGSize(width: height, height: width) }
	var absSize        : CGSize  { return CGSize(width: abs(width), height: abs(height)) }
	var dividedInHalf  : CGSize  { return multiplyBy(0.5) }
	var hypotenuse     : CGFloat { return sqrt(width * width + height * height) }
	var containsNAN    : Bool    { return width.isNaN || height.isNaN }
	var smallDimension : CGFloat { return min(abs(height), abs(width)) }
	func isLargerThan(_ other: CGSize)               -> Bool    { return hypotenuse > other.hypotenuse }
	public static func squared(_ length: CGFloat)    -> CGSize  { return CGSize(width: length, height: length) }
	public static func - (lhs: CGSize, rhs: CGPoint) -> CGPoint { return CGPoint(lhs) - rhs }
	func hypotenuse(relativeTo other: CGSize)        -> CGFloat { return abs(hypotenuse - other.hypotenuse) }
	func add(width: CGFloat, height: CGFloat)        -> CGSize  { return self + CGSize(width: width, height: height) }
	func multiplyBy(_ fraction: CGFloat)             -> CGSize  { return CGSize(width: width * fraction, height: height * fraction) }
	func multiplyBy(_ fraction: CGSize)              -> CGSize  { return CGSize(width: width * fraction.width, height: height * fraction.height).absSize }
	func fraction(_ delta: CGSize)                   -> CGSize  { CGSize(width: (width - delta.width) / width, height: (height - delta.height) / height).absSize }
	func expandedEquallyBy(_ expansion: CGFloat)     -> CGSize  { return insetEquallyBy(-expansion) }
	func    insetEquallyBy(_     inset: CGFloat)     -> CGSize  { return insetBy(inset, inset) }
	func expandedBy(_ x: CGFloat, _ y: CGFloat)      -> CGSize  { return insetBy(-x, -y) }
	func insetBy(_ x: CGFloat, _ y: CGFloat)         -> CGSize  { return CGSize(width: width - (x * 2.0), height: height - (y * 2.0)).absSize }
	func offsetBy(_ x: CGFloat, _ y: CGFloat)        -> CGSize  { return CGSize(width: width + x, height: height + y).absSize }
	func offsetBy(_ delta: CGSize)                   -> CGSize  { return CGSize(width: width + delta.width, height: height + delta.height).absSize }

	func scaleToFit(_ other: CGSize) -> CGFloat {
		let horizontal = other.width / width
		let   vertical = other.height / height

		return horizontal < vertical ? horizontal : vertical
	}

	public init(_ point: CGPoint) {
		self.init()

		width  = point.x
		height = point.y
	}

	public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
		var    size  = lhs
		size.height += rhs.height
		size.width  += rhs.width

		return size.absSize
	}

	public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
		var    size  = lhs
		size.height -= rhs.height
		size.width  -= rhs.width

		return size.absSize
	}

	func fractionalScaleToFit(size: CGSize) -> CGFloat {
		var fraction = CGFloat(1)

		if  width < size.width {
			fraction = width / size.width
		}

		if  height < size.height {
			fraction = height * fraction / size.height
		}

		return fraction
	}

	func scaleToFit(size: CGSize) -> CGSize {
		let fraction = fractionalScaleToFit(size: size)

		return CGSize(width: width * fraction, height: height * fraction)
	}

	func fractionPreservingRatio(_ delta: CGSize) -> CGSize {
		let ratio = (width - delta.width) / width

		return CGSize.squared(ratio).absSize
	}

	func rotate(by angle: Double) -> CGSize {
		let r = hypotenuse

		return CGSize(width: r * CGFloat(cos(angle)), height: r * CGFloat(sin(angle)))
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

	func ellipticalLengthAt(_ angle: Double) -> Double {
		let a = Double(width)  / 2.0
		let b = Double(height) / 2.0
		let c = sqrt((b * b * cos(angle) * cos(angle)) + (a * a * sin(angle) * sin(angle)))
		let l = a * b / c // (𝑏*cos(𝜃))2+(𝑎*sin(𝜃))2

		return l
	}

	func lengthAt(_ angle: CGFloat) -> CGFloat {
		let a = Double(angle)
		let x = width / CGFloat(abs(cos(a)))

		if  x < hypotenuse {
			return x / 2.0
		}

		return height / CGFloat(abs(sin(a))) / 2.0
	}

}

enum ZDirection : Int {

	case top
	case left
	case right
	case bottom
	case topLeft
	case topRight
	case bottomLeft
	case bottomRight

	var isFullResizeCorner : Bool    { return self == .topLeft || self == .bottomRight }

	var cursor: NSCursor {
		switch self {
			case .top, .bottom: return .resizeUpDown
			case .left, .right: return .resizeLeftRight
			default:            return  kFourArrowsCursor ?? .crosshair
		}
	}

}

extension CGRect {

	var minimumDimension: CGFloat { return min(size.height, size.width) }
	var containsNAN:         Bool { return origin.containsNAN || size.containsNAN }
	var hasZeroSize:         Bool { return size == .zero }
	var hasSize:             Bool { return size != .zero }

	var cornerPoints: [ZDirection : CGPoint] {
		var           result = [ZDirection : CGPoint]()
		result[.topLeft]     = topLeft
		result[.topRight]    = topRight
		result[.bottomLeft]  = bottomLeft
		result[.bottomRight] = bottomRight

		return result
	}

	var selectionPoints: [ZDirection : CGPoint] {
		var           result = cornerPoints
		result[.top]         = centerTop
		result[.left]        = centerLeft
		result[.right]       = centerRight
		result[.bottom]      = centerBottom

		return result
	}

	var normalized: CGRect {
		var r = CGRect(origin: origin, size: size)
		let h = size.height
		let w = size.width
		if  h < .zero {
			r.size.height = -h
			r.origin.y   +=  h
		}

		if  w < .zero {
			r.size.width  = -w
			r.origin.x   +=  w
		}

		return r
	}

	public init(center: CGPoint, size: CGSize) {
		self.init()

		origin    = center - size.dividedInHalf
		self.size = size
	}

	func printRect(_ message: String = kEmpty) {
		print(message + " x: " + minX.stringTo(precision: 1) + " X: " + maxX.stringTo(precision: 1))
	}

    public init(start: CGPoint, extent: CGPoint) {
        self.init()

		origin = start
        size   = CGSize(extent - origin)

        if  size .width < 0 {
            size .width = -size.width
            origin   .x = extent.x
        }

        if  size.height < 0 {
            size.height = -size.height
            origin   .y = extent.y
        }
    }

    func indices(within iBounds: CGRect, radix: Int) -> IndexSet {
        let c = center
        var set = IndexSet()

        set.insert(Int(c.x))

        return set
    }

	func offsetBy(_ offset: CGPoint) -> CGRect {
		return offsetBy(dx: offset.x, dy: offset.y)
	}

	func offsetBy(_ size: CGSize) -> CGRect {
		return offsetBy(dx: size.width, dy: size.height)
	}

    func offsetBy(fractionX: CGFloat = .zero, fractionY: CGFloat = .zero) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY
        
        return offsetBy(dx:dX, dy:dY)
    }

	func expandedBy(_ expansionSize: CGSize) -> CGRect {
		let dX = -expansionSize.width
		let dY = -expansionSize.height

		return insetBy(dx: dX, dy: dY)
	}

	func        expandedBy(dx: CGFloat, dy: CGFloat) -> CGRect { return insetBy(dx: -dx, dy: -dy) }
	func expandedEquallyBy(_     expansion: CGFloat) -> CGRect { return insetEquallyBy(-expansion) }
	func expandedEquallyBy(       fraction: CGFloat) -> CGRect { return insetEquallyBy(fraction: -fraction) }
	func    insetEquallyBy(       fraction: CGFloat) -> CGRect { return insetBy(fractionX: fraction, fractionY: fraction) }
	func    insetEquallyBy(_         inset: CGFloat) -> CGRect { return insetBy(dx: inset, dy: inset) }
	func   offsetEquallyBy(_        offset: CGFloat) -> CGRect { return offsetBy(dx: offset, dy: offset) }
	func      centeredRect(       diameter: CGFloat) -> CGRect { return centeredEquallyAround(center, diameter: diameter) }

	func insetBy(fractionX: CGFloat = .zero, fractionY: CGFloat = .zero) -> CGRect {
        let dX = size.width  * fractionX
        let dY = size.height * fractionY

        return insetBy(dx: dX, dy: dY)
    }

	func centeredEquallyAround(_ center: CGPoint, diameter: CGFloat) -> CGRect {
		return CGRect(origin: center, size: CGSize.zero).expandedEquallyBy(diameter / 2.0)
	}

	func twoDotsVertically(fractionalDiameter: CGFloat) -> (CGRect, CGRect) {
		let a = CGRect(origin: centerBottom, size: .zero)
		let b = CGRect(origin: centerTop,    size: .zero)
		let d = height * fractionalDiameter

		return (a.centeredRect(diameter: d), b.centeredRect(diameter: d))
	}

	func twoDotsHorizontally(fractionalDiameter: CGFloat) -> (CGRect, CGRect) {
		let a = CGRect(origin: centerLeft,  size: .zero)
		let b = CGRect(origin: centerRight, size: .zero)
		let d = width * fractionalDiameter

		return (a.centeredRect(diameter: d), b.centeredRect(diameter: d))
	}

	func centeredHorizontalLine(thick: CGFloat) -> CGRect {
		let y = center.y - (thick / 2.0)

		return CGRect(origin: CGPoint(x: minX, y: y), size: CGSize(width: maxX - minX, height: thick))
	}

	func centeredVerticalLine(thick: CGFloat) -> CGRect {
		let x = center.x - (thick / 2.0)

		return CGRect(origin: CGPoint(x: x, y: minY), size: CGSize(width: thick, height: maxY - minY))
	}

	var squareCentered: CGRect {
		let length = size.smallDimension
		let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

		return CGRect(origin: origin, size: CGSize.squared(length))
	}

	func intersectsOval(within other: CGRect) -> Bool {
		let center =  other.center
		let radius = (other.height + other.width) / 4.0
		let deltaX = center.x - max(minX, min(center.x, maxX))
		let deltaY = center.y - max(minY, min(center.y, maxY))
		let  delta = radius - sqrt(deltaX * deltaX + deltaY * deltaY)

		return delta > 0
	}

	func hitTestForResizeDot(in testRect: CGRect) -> ZDirection? {
		let   points = selectionPoints
		let        s = size.dividedInHalf      .insetEquallyBy(kEssayImageDotRadius)

		for (direction, point) in points {
			var rect = CGRect(origin: point, size: .zero).expandedEquallyBy(kEssayImageDotRadius)

			switch direction {
				case .bottom, .top: rect = rect.expandedBy(dx: s.width, dy:    .zero)   // extend width
				case .right, .left: rect = rect.expandedBy(dx:   .zero, dy: s.height)   //    "   height
				default:            break
			}

			if  testRect.intersects(rect) {
				return direction
			}
		}

		return nil
	}

	func drawCenteredVerticalLine(thickness: CGFloat = 0.5) {
		let rect = centeredVerticalLine(thick: thickness)
		let path = ZBezierPath(rect: rect)

		path.setClip()
		kGrayColor.setFill()
		path.fill()

	}

	func drawColoredRect(_ color: ZColor, radius: CGFloat = .zero, thickness: CGFloat = 0.5) {
		let       path = ZBezierPath(roundedRect: self, xRadius: radius, yRadius: radius)
		path.lineWidth = thickness

		color.setStroke()
		path.stroke()
	}

	func drawColoredOval(_ color: ZColor, thickness: CGFloat = 0.5, filled: Bool = false, dashes: Bool = false) {
		let       oval = ZBezierPath(ovalIn: self)
		oval.lineWidth = thickness

		if  dashes {
			oval.addDashes()
		}

		color.setStroke()
		oval.stroke()

		if  filled {
			color.setFill()
			oval.fill()
		}
	}

	func drawColoredCircle(_ color: ZColor, thickness: CGFloat = 0.5, filled: Bool = false, dashes: Bool = false) {
		squareCentered.drawColoredOval(color, thickness: thickness, filled: filled, dashes: dashes)
	}

	func drawImageResizeDotsAndRubberband() {
		for point in selectionPoints.values {
			let   dotRect = CGRect(origin: point, size: .zero).expandedEquallyBy(kEssayImageDotRadius)
			let      path = ZBezierPath(ovalIn: dotRect)
			path.flatness = kDefaultFlatness

			path.stroke()
		}

		drawRubberband()
	}

	func drawRubberband() {
		let       path = ZBezierPath(rect: self)
		path.lineWidth = CGFloat(gLineThickness * (gIsDark ? 3.0 : 2.0))
		path.flatness  = kDefaultFlatness

		path.addDashes()
		path.stroke()
	}

}

extension ZBezierPath {

	static func setClip(to rect: CGRect) { ZBezierPath(rect: rect).setClip() }

	static func fillWithColor(_ color: ZColor, in rect: CGRect) {
		color.setFill()
		ZBezierPath(rect: rect).fill()
	}

	static func drawTriangle(pointingDown: Bool, in iRect: CGRect, thickness: CGFloat) {
		let path = trianglePath(pointingDown: pointingDown, in: iRect)

		path.draw(thickness: thickness)
	}

	static func trianglePath(pointingDown: Bool, in iRect: CGRect) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendTriangle(pointingDown: pointingDown, in: iRect)

		return path
	}

	static func drawCircle(in iRect: CGRect, thickness: CGFloat) {
		let path = circlePath(in: iRect)

		path.draw(thickness: thickness)
	}

	static func circlePath(origin: CGPoint, radius: CGFloat) -> ZBezierPath {
		let rect = CGRect.zero.offsetBy(origin).expandedEquallyBy(radius)

		return circlePath(in: rect)
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

	static func bloatedTrianglePath(in iRect: CGRect, aimedRight: Bool) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendBloatedTriangle(in: iRect, aimedRight: aimedRight)

		return path
	}

	static func bloatedTrianglePath(in iRect: CGRect, at angle: CGFloat) -> ZBezierPath {
		let path = ZBezierPath()

		path.appendBloatedTriangle(in: iRect, startAngle: Double(angle))

		return path
	}

	static func ovalPath(in iRect: CGRect, at angle: CGFloat) -> ZBezierPath {
		let   size = iRect.size
		let center = CGPoint(size).multiplyBy(-0.5)
		let origin = iRect.origin - center
		let   rect = CGRect(origin: center, size: size)
		let   path = ZBezierPath(ovalIn: rect)

		path.transform(using: AffineTransform(rotationByRadians: angle))
		path.transform(using: AffineTransform(translationByX: origin.x, byY: origin.y))

		return path
	}

	static func linePath(start: CGPoint, length: CGFloat, angle: CGFloat) -> ZBezierPath {
		let path = ZBezierPath()
		let  end = CGPoint(x: .zero, y: length).rotate(by: Double(angle)).offsetBy(start)

		path.move(to: start)
		path.line(to: end)

		return path
	}

	func addDashes() {
		let pattern: [CGFloat] = [3.0, 3.0]

		setLineDash(pattern, count: 2, phase: 3.0)
	}

	func appendTriangle(pointingDown: Bool, in iRect: CGRect, full: Bool = true) {
		let yStart = pointingDown ? iRect.minY : iRect.maxY
		let   yEnd = pointingDown ? iRect.maxY : iRect.minY
		let    tip = CGPoint(x: iRect.midX, y: yStart)
		let   left = CGPoint(x: iRect.minX, y: yEnd)
		let  right = CGPoint(x: iRect.maxX, y: yEnd)

		move(to: left)
		line(to: tip)
		line(to: right)

		if  full {
			line(to: left)
		}
	}

	func appendCircles(orientedUp: Bool, in iRect: CGRect) -> CGRect {
		let   rect = iRect.offsetBy(fractionX: .zero, fractionY: orientedUp ? 0.1 : -0.1)
		var    top = rect.insetBy(fractionX: .zero, fractionY: 0.375)  // shrink to one-fifth size
		let middle = top.offsetBy(dx: .zero, dy: top.midY - rect.midY)
		let bottom = top.offsetBy(dx: .zero, dy: top.maxY - rect.maxY) // move to bottom
		top        = top.offsetBy(dx: .zero, dy: top.minY - rect.minY) // move to top

		appendOval(in: top)
		appendOval(in: middle)
		appendOval(in: bottom)

		return orientedUp ? top : bottom
	}

	func draw(thickness: CGFloat) {
		lineWidth = thickness

		stroke()
	}

	func appendBloatedTriangle(in iRect: CGRect, aimedRight: Bool) {
		appendBloatedTriangle(in: iRect, startAngle: aimedRight ? .zero : kPI)
	}

	func appendBloatedTriangle(in iRect: CGRect, startAngle: Double) {
		let      center = iRect.center
		let  insetRatio = 0.35
		let      radius = Double(iRect.width) * insetRatio
		let    bigAngle = k2PI /  6.0 // one sixth of a circle
		let  smallAngle = k2PI / 30.0 // one thirtieth of a circle
		let innerVector = CGPoint(x: radius,       y: .zero)
		let outerVector = CGPoint(x: radius * 1.5, y: .zero)
		var  controlOne = CGPoint.zero
		var  controlTwo = CGPoint.zero
		var       point = CGPoint.zero
		var       index = Double.zero

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

	func apply(closure: AnyObjectClosure) {
		for element in self {
			closure(element as AnyObject)
		}
	}

	func applyBoolean(closure: AnyObjectToBooleanClosure) -> Bool {
		var result = false
		for element in self {
			if  closure(element as AnyObject) {
				result = true
				break
			}
		}
		return result
	}

    func applyIntoString(closure: AnyToStringClosure) -> String {
        var separator = kEmpty
        var    string = kEmpty

        for object in self {
            if let message = closure(object) {
                string.append("\(separator)\(message)")

                if  separator.isEmpty {
                    separator.appendSpacesToLength(kLogTabStop)

                    separator = kNewLine + separator
                }
            }
        }

        return string
    }

	func intersects(_ other: Array) -> Bool {
		return intersection(other).count > 0
	}

	func intersection(_ other: Array) -> Array {
		var result = Array()

		apply { another in
			other.apply { yetAnother in
				if  yetAnother.isEqual(to: another) {
					result.append(another as! Element)
				}
			}
		}

		return result
	}

	func containsAnyOf(_ other: Any?) -> Bool {
		return (other == nil) ? false : containsCompare(with: other) { (item, another) in
			return item === another
		}
	}

    func containsCompare(with other: Any?, using: CompareClosure? = nil) -> Bool {

		// TODO: use a dictionary of record names : records

        if  let compare = using,
			let to = other as AnyObject? {
            for item in self {
                if  compare(item as AnyObject, to) {
                    return true     // true means has a match
                }
            }
        }
        
        return false    // false means has no match
    }

	mutating func insertUnique(item: Any?, at index: Int = 0, compare: CompareClosure? = nil) {
		if  let e = item as? Element,
			!containsCompare(with: item, using: compare) {
			insert(e, at: index)
		}
	}

	@discardableResult mutating func appendUnique(item: Any?, compare: CompareClosure? = nil) -> Bool {
		if  let e = item as? Element,
			(count == 0 || !containsCompare(with: item, using: compare)) {
			append(e)
			return true
		}
		return false
	}

	@discardableResult mutating func prependUnique(item: Any?, compare: CompareClosure? = nil) -> Bool {
		if  let e = item as? Element,
			!containsCompare(with: item, using: compare) {
			insert(e, at: 0)
			return true
		}
		return false
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

}

extension ZRecordsArray {

	static func createFromObjectIDs(_ ids: ZObjectIDsArray, in context: NSManagedObjectContext) -> ZRecordsArray {
		var zRecords = ZRecordsArray()

		for  id in ids {
			if  let zRecord = context.object(with: id) as? ZRecord {
				zRecords.append(zRecord)
			}
		}

		return zRecords
	}

	var recordNames: StringsArray {
		var  names = StringsArray()

		for zRecord in self {
			if  let name = zRecord.recordName {
				names.append(name)
			}
		}

		return names
	}

	func createStorageArray(from databaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false, allowEach: ZRecordToBooleanClosure? = nil) throws -> [ZStorageDictionary]? {
		if  count > 0 {
			var result = [ZStorageDictionary] ()

			for zRecord in self {
				if  zRecord.recordName == nil {
					printDebug(.dFile, "no record name: \(zRecord)")
				} else if (allowEach == nil || allowEach!(zRecord)),
						  let dict = try zRecord.createStorageDictionary(for: databaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {

					if  dict.count != 0 {
						result.append(dict)
					} else {
						printDebug(.dFile, "empty storage dictionary: \(zRecord)")

						if  let dict2 = try zRecord.createStorageDictionary(for: databaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
							print("gotcha \(dict2.count)")
						}
					}
				}
			}

			if  result.count > 0 {
				return result
			}
		}

		return nil
	}

	func appending(_ records: ZRecordsArray?) -> ZRecordsArray {
		if  let  more = records {
			var union = ZRecordsArray()
			union.append(contentsOf: self)
			union.append(contentsOf: more)

			return union
		}

		return self
	}

	@discardableResult mutating func appendUnique(item: ZRecord) -> Bool {
		return appendUnique(item: item) { (a, b) -> (Bool) in
			if  let    aName  = (a as? ZRecord)?.recordName,
				let    bName  = (b as? ZRecord)?.recordName {
				return aName ==  bName
			}

			return false
		}
	}

	func containsMatch(to other: AnyObject) -> Bool {
		return containsCompare(with: other) { (a, b) in
			if  let    aName  = (a as? ZRecord)?.recordName,
				let    bName  = (b as? ZRecord)?.recordName {
				return aName ==  bName
			}

			return false
		}
	}

}

extension NSRange {

	var center: Int { return (lowerBound + upperBound) / 2 }

	func insetBy   (_ inset:  Int)    -> NSRange { return NSRange(location:  inset + location, length: length - (inset * 2)) }
	func offsetBy  (_ offset: Int)    -> NSRange { return NSRange(location: offset + location, length: length) }
	func intersects(_ other: NSRange) ->    Bool { return intersection(other) != nil }

	func extendedBy(_ increment: Int) -> NSRange {
		if  increment > 0 {
			return NSRange(location: location, length: increment + length)
		} else {
			return NSRange(location: increment + location, length: length - increment)
		}
	}

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

extension NSCursor {

	class func fourArrows() -> NSCursor? {
		let     length = CGFloat(20)
		let halfLength = length / 2.0
		let       size = CGSize.squared(length)
		let    hotSpot = CGPoint(x: halfLength, y: halfLength)
		if  let  image = kFourArrowsImage {
			image.size = size

			return NSCursor(image: image, hotSpot: hotSpot)
		}

		return nil
	}

}

extension NSTextTab {

	var string: String {
		return kAlignment + gSeparatorAt(level: 6) + "\(alignment.rawValue)" + gSeparatorAt(level: 5) + kLocation + gSeparatorAt(level: 6) + "\(location)"
	}

	convenience init(string: String) {
		var location: CGFloat = .zero
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
		let indent = firstLineHeadIndent
		let  lists = textLists

		if  let stops = tabStops {
			result.append(gSeparatorAt(level: 2) + kStops)

			for stop in stops {
				result.append(gSeparatorAt(level: 3) + stop.string)
			}
		}

		if  indent > .zero {
			result.append(gSeparatorAt(level: 2) + kIndent)
			result.append(gSeparatorAt(level: 3) + "\(indent.roundedToNearestInt)")
		}

		result.append(gSeparatorAt(level: 2) + kLists)

		for list in lists {
			let  format = list.markerFormat.rawValue
			let options = "\(list.listOptions.rawValue)"

			result.append(gSeparatorAt(level: 3) + format)
			result.append(gSeparatorAt(level: 4) + options)
		}

		return result
	}

	convenience init(string: String) {
		self.init()

		let parts = string.componentsSeparatedAt(level: 2)

		for part in parts {
			let subparts = part.componentsSeparatedAt(level: 3)
			let    count = subparts.count
			var    index = 1

			if  count > 1 {
				switch subparts[0] {
					case kAlignment:
						if  let   raw = subparts[1].integerValue,
							let     a = NSTextAlignment(rawValue: raw) {
							alignment = a
						}
					case kIndent:
						if  let             raw = subparts[1].integerValue {
							let          indent = CGFloat(raw) + 6.0 // 8 pixel gap between dot and title
							firstLineHeadIndent = indent
						}
					case kLists:
						var       lists = [NSTextList]()
						while     index < count {
							let subpart = subparts[index]
							let subsubs = subpart.componentsSeparatedAt(level: 4)
							let  format = NSTextList.MarkerFormat(subsubs[0])
							let options = 0 // Int(subsubs[1]) ?? 0
							index      += 1

							lists.append(NSTextList(markerFormat: format, options: options))
						}

						textLists = lists
					case kStops:
						var       stops = [NSTextTab]()
						while     index < count {
							let subpart = subparts[index]
							index      += 1

							stops.append(NSTextTab(string: subpart))
						}

						tabStops       = stops
					default: break
				}
			}
		}
	}

}

extension ZFont {

	var string: String { return fontDescriptor.string }

	convenience init(string: String) {
		let descriptor = ZFontDescriptor(string: string)

		self.init(descriptor: descriptor, textTransform: nil)!
	}

	func withTraits(_ traits: ZFontDescriptor.SymbolicTraits...) -> ZFont {
		let descriptor = self.fontDescriptor.withSymbolicTraits(ZFontDescriptor.SymbolicTraits(traits))

		return ZFont(descriptor: descriptor, size: descriptor.pointSize) ?? self
	}
}

extension ZFontDescriptor {

	var string: String {
		var    result = kEmpty
		var separator = kEmpty

		for (name, attribute) in fontAttributes {
			result.append(separator + name.rawValue + gSeparatorAt(level: 3) + "\(attribute)")
			separator = gSeparatorAt(level: 2)
		}

		return result
	}

	convenience init(string: String) {
		let parts = string.modern.componentsSeparatedAt(level: 2)
		var dict  = [ZFontDescriptor.AttributeName : Any]()

		for part in parts {
			let subparts   = part.componentsSeparatedAt(level: 3)
			if  subparts.count > 1 {
				let    key = subparts[0]
				let  value = subparts[1]
				let   name = ZFontDescriptor.AttributeName(key)

				dict[name] = value
			}
		}

		self.init(fontAttributes: dict)
	}

}

extension NSMutableAttributedString {

	var allKeys: [NSAttributedString.Key] { return [.font, .link, .attachment, .paragraphStyle, .foregroundColor, .backgroundColor] }

	var linkRanges: [NSRange] {
		let range = NSRange(location: 0, length: length)
		var found = [NSRange]()

		enumerateAttribute(.link, in: range, options: []) { (_, inRange, _) in
			if  inRange.length < 100 {
				found.append(inRange)
			}
		}

		return found
	}

	var rangedAttachments: ZRangedAttachmentArray {
		let range = NSRange(location: 0, length: length)
		var found = ZRangedAttachmentArray()

		enumerateAttribute(.attachment, in: range, options: .reverse) { (item, inRange, _) in
			if  let attach = item as? NSTextAttachment {
				let append = ZRangedAttachment(glyphRange: inRange, attachment: attach)

				found.append(append)
			}
		}

		return found
	}

	var imageFileNames: StringsArray {
		var names = StringsArray()

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
		let array: [ZImage?] = attachmentCells.map { $0.image }
		var result           = [ZImage]()

		for item in array {
			if  let image    = item {
				result.append(image)
			}
		}

		return result
	}

	func rangedAttachment(in range: NSRange) -> ZRangedAttachment? {
		for attach in rangedAttachments {
			if  range.intersects(attach.glyphRange) {
				return attach
			}
		}

		return nil
	}

	var attributesAsString: String {
		get { return attributeStrings.joined(separator: gSeparatorAt(level: 1)) }
		set { attributeStrings = newValue.componentsSeparatedAt(level: 1) }
	}

	var attributeStrings: StringsArray {
		get {
			var result = StringsArray()
			let  range = NSRange(location: 0, length: length)

			for key in allKeys {
				enumerateAttribute(key, in: range, options: .reverse) { (item, inRange, _) in
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
			for item in newValue {
				let     parts = item.componentsSeparatedAt(level: 4)
				if      parts.count > 3,
					let start = parts[0].integerValue,
					let count = parts[1].integerValue {
					let   raw = parts[2]
					let value = parts[3]
					let   key = NSAttributedString.Key(rawValue: raw)
					let range = NSRange(location: start, length: count)
					var attribute: Any?

					switch key {
						case .link:            attribute =                                    value
						case .font:            attribute = ZFont 		   		     (string: value)
						case .attachment:      attribute = gCurrentTrait?.textAttachment(for: value)
						case .foregroundColor,
							 .backgroundColor: attribute = ZColor				     (string: value)
						case .paragraphStyle:  attribute = NSMutableParagraphStyle   (string: value)
						default:    		   break
					}

					if  let v = attribute {
						printDebug(.dNotes, "add attribute over \(range) for \(raw): \(v)")

						addAttribute(key, value: v, range: range)
					}
				}
			}
		}
	}

	// ONLY called during save note (in set note text)
	// side-effect for a freshly dropped image:
	// it creates and returns an additional asset

	func assets(for trait: ZTraitAssets) -> CKAssetsArray? {
		var array = CKAssetsArray()
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
		fixAttributes(in: NSRange(location: 0, length: length))
	}

}

extension NSDraggingInfo {

	var pasteboardArray : NSArray? {
		return draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray
	}

}

extension ZImage {

	var invertedImage: ZImage? {
		if  let          tiffData = tiffRepresentation,
			let            bitMap = NSBitmapImageRep(data: tiffData) {
			let        beginImage = CIImage(bitmapImageRep: bitMap)
			if  let        filter = CIFilter(name: "CIColorInvert") {
				filter.setValue(beginImage, forKey: kCIInputImageKey)

				if  let  filtered = filter.outputImage {
					let  imageRep = NSCIImageRep(ciImage: filtered)
					let  newImage = NSImage(size: imageRep.size)
					newImage.size = size

					newImage.addRepresentation(imageRep)

					return newImage
				}
			}
		}

		return nil
	}

}

extension NSTextAttachmentCell {

	var frame: CGRect {
		return CGRect(origin: attachment?.bounds.origin ?? CGPoint.zero, size: cellSize())
	}

}

extension NSTextAttachment {

	var cellImage: ZImage? {
		get {
			if  let             cell = attachmentCell as? ZImageAttachmentCell {
				return          cell.original?.image
			}

			return nil
		}

		set {
			if  let             cell = attachmentCell as? ZImageAttachmentCell {
				cell.original?.image = newValue
			}
		}
	}

}

extension String {
    var               length :              Int  { return unicodeScalars.count }
	var             isHyphen :             Bool  { return self == kHyphen }
    var              isDigit :             Bool  { return "0123456789.+-=*/".contains(self[startIndex]) }
    var       isAlphabetical :             Bool  { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var              isAscii :             Bool  { return unicodeScalars.filter{  $0.isASCII }.count > 0 }
	var      containsNoAscii :             Bool  { return unicodeScalars.filter{ !$0.isASCII }.count > 0 }
	var       containsNoTabs :             Bool  { return filter{ $0 != kTab.first}.count != 0 }
    var           isOpposite :             Bool  { return "]}>)".contains(self) }
	var         isDashedLine :             Bool  { return contains(kHalfLineOfDashes) }
	var          isValidLink :             Bool  { return components != nil }
	var containsLineEndOrTab :             Bool  { return hasMatchIn(kLineEndingsAndTabArray) }
	var        smartStripped :           String  { return substring(fromInclusive: 4).spacesStripped }
	var           asciiValue :           UInt32  { return asciiArray[0] }
	var           asciiArray :          [UInt32] { return unicodeScalars.filter { $0.isASCII }.map{ $0.value } }
	var           components :     StringsArray? { return components(separatedBy: kColonSeparator) }
	var            maybeZone :             Zone? { return maybeZRecord?.maybeZone }
	func maybeZone(in id: ZDatabaseID?) -> Zone? { return maybeZRecord(in: id)?.maybeZone }

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

	var removeProblemCharacters: String {
		var     result    = "\(self)"
		for character in "\\\n\r\t" {
			let separator = "\(character)"
			if  result.contains(separator) {
				result    = result.replacingOccurrences(of: separator, with: kEmpty)
			}
		}

		return result
	}

    var escaped: String {
        var     result    = "\(self)"
        for character in "\\\"\'`" {
            let separator = "\(character)"
			if  result.contains(separator) {
				result    = result.replacingOccurrences(of: separator, with: kBackSlash + separator)
			}
        }

        return result
    }

	var escapeCommasWithinQuotes: String {
		let parts = components(separatedBy: kDoubleQuote)

		if  parts.count > 2 {
			let  bad = parts[1]
			let good = bad.replacingOccurrences(of: kCommaSeparator, with: kUncommonSeparator)

			return parts[0] + good + parts[2]
		}

		return self
	}

    var spacesStripped: String {
        var before = self
        
        while before.starts(withAnyCharacterIn: kSpace) {
            before = before.substring(fromInclusive: 1) // strip extra space
        }
        
        while before.ends(withAnyCharacterIn: kSpace) {
            before = before.substring(toExclusive: before.length - 1) // strip trailing space
        }
        
        return before
    }

	var modern: String {
		return replacingOccurrences(of: kLevelOneSeparator,   with: gSeparatorAt(level: 1))
			.replacingOccurrences  (of: kLevelTwoSeparator,   with: gSeparatorAt(level: 2))
			.replacingOccurrences  (of: kLevelThreeSeparator, with: gSeparatorAt(level: 3))
			.replacingOccurrences  (of: kLevelFourSeparator,  with: gSeparatorAt(level: 4))
	}

	var searchable: String {
		return lowercased()
			.replacingEachCharacter(in: ",;@!(){}\\\"",              with: kEmpty)
			.replacingEachCharacter(in: ".:_-='?/\r\n",              with: kSpace)
			.replacingEachString   (in: ["%2f", "%3a", "   ", "  "], with: kSpace)
	}

	var unCamelcased: String {
		guard count > 0 else { return self }

		var newString = kEmpty
		let uppercase = CharacterSet.uppercaseLetters
		let     first = unicodeScalars.first!

		newString.append(Character(first))

		for scalar in unicodeScalars.dropFirst() {
			if  uppercase.contains(scalar) {
				newString.append(kSpace)
			}

			newString.append(Character(scalar))
		}

		return newString.lowercased()
	}

	// MARK: - bookmarks
	// MARK: -

	var maybeRecordName: String? {
		if  let   parts  = components, parts.count > 1 {
			let    name  = parts[2]
			return name != kEmpty ? name : kRootName // by design: empty component means root
		}

		return nil
	}

	var maybeDatabaseID: ZDatabaseID? {
		if  let         parts  = components {
			let    databaseID  = parts[0]
			return databaseID == kEmpty ? gDatabaseID : ZDatabaseID(rawValue: databaseID)
		}

		return nil
	}

	func maybeZRecord(in databaseID: ZDatabaseID?) -> ZRecord? {
		let zRecords = gRemoteStorage.zRecords(for: databaseID)
		let  zRecord = zRecords?.maybeZoneForRecordName(self)

		return zRecord
	}

	var maybeZRecord: ZRecord? {
		if  self          != kEmpty,
			let       name = maybeRecordName,
			let      parts = components, parts.count > 0 {
			let    rawDBID = parts[0]
			let databaseID = rawDBID == kEmpty ? gDatabaseID : ZDatabaseID(rawValue: rawDBID)

			return name.maybeZRecord(in: databaseID)
		}

		return nil
	}

	var rootID: ZRootID? {
		switch self {
			case          kRootName: return .rootID
			case         kTrashName: return .trashID
			case       kDestroyName: return .destroyID
			case  kLostAndFoundName: return .lostID
			case kFavoritesRootName: return .favoritesID
			default:                 return nil
		}
	}

	func hasMatchIn(_ array: StringsArray) -> Bool {
		var index = array.count - 1

		while index >= 0 {
			if  contains(array[index]) {
				return true
			}

			index -= 1
		}

		return false
	}

	func componentsSeparatedAt(level: Int) -> StringsArray {
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

	func replacingEachString(in matchAgainst: StringsArray, with: String) -> String {
		var result = self
		for string in matchAgainst {
			result = result.replacingOccurrences(of: string, with: with)
		}

		return result
	}

	var asBundleResource: String? {
		var    parts = components(separatedBy: kDotSeparator)
		let     last = parts.removeLast()
		let resource = parts.joined(separator: kDotSeparator)

		return Bundle.main.path(forResource: resource, ofType: last)
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

	static func pluralized(_ iValue: Int, unit: String = kEmpty, plural: String = "s", followedBy: String = kEmpty) -> String { return iValue <= 0 ? kEmpty : "\(iValue) \(unit)\(iValue == 1 ? kEmpty : "\(plural)")\(followedBy)" }
    static func from(_ ascii:  UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(fromInclusive: Int) -> String  { return String(self[index(at: fromInclusive)...]) }
    func substring(toExclusive:   Int) -> String  { return String(self[..<index(at: toExclusive)]) }

    func rect(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGRect {
		let within = substring(with: iRange)
		let bounds = within.rectWithFont(font)
		let xDelta = offset(using: font, for: iRange, atStart: atStart)
        
        return bounds.offsetBy(dx: xDelta, dy: .zero)
    }

    func offset(using font: ZFont, for iRange: NSRange, atStart: Bool) -> CGFloat {
        let            end = iRange.lowerBound
        let     startRange = NSMakeRange(0, end)
        let      selection = substring(with: iRange)
        let startSelection = substring(with: startRange)
        let          width = selection     .sizeWithFont(font).width
        let     startWidth = startSelection.sizeWithFont(font).width
        
        return startWidth + (atStart ? .zero : width)    // move down, use right side of selection
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
		if  self == kEmpty {        // special case
			return nil
		} else {
            let pairs = components(separatedBy: kCommaSeparator)
			var green = Double.zero
			var  blue = Double.zero
			var   red = Double.zero

			if  pairs.count > 2 {
				for pair in pairs {
					let values = pair.components(separatedBy: kColonSeparator)
					let  value = Double(values[1])!
					let    key = values[0]

					switch key {
						case "green": green = value
						case  "blue":  blue = value
						case   "red":   red = value
						default:              break
					}
				}
			}

            return ZColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
        }
    }

	var darkAdaptedTitle: NSAttributedString {
		let color = gIsDark ? kDarkestGrayColor : kBlackColor
		let title = NSMutableAttributedString(string: self)
		let range = NSRange(location: 0, length: length)

		title.addAttribute(.foregroundColor, value: color, range: range)

		return title
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

        while before.ends(withAnyCharacterIn: kSpace) && after == kEmpty {
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
        var    total = CGFloat(0)
        
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
        let i = index(startIndex, offsetBy: iOffset)

        return self[i].description
    }

	mutating func appendSpacesToLength(_ iLength: Int) {
		if 0 < iLength {
			while length < iLength {
				append(kSpace)
			}
		}
	}

    func appendingSpacesToLength(_ iLength: Int) -> String {
		var appending = self

		appending.appendSpacesToLength(iLength)

		return appending
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
		return zones?.applyIntoString()  { object -> (String?) in
			if  let zone  = object as? Zone {
				let name  = zone.decoratedName
				if  name != kEmpty {
					return name
				}
			}

			return nil
		} ?? kEmpty
	}

    static func forOperationIDs (_ iIDs: ZOpIDsArray?) -> String {
        return iIDs?.applyIntoString()  { object -> (String?) in
            if  let operation  = object as? ZOperationID {
                let name  = "\(operation)"
                if  name != kEmpty {
                    return name
                }
            }

            return nil
            } ?? kEmpty
    }

    static func *(_ input: String, _ multiplier: Int) -> String {
        var  count = multiplier
        var output = kEmpty

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
        let   romanValues = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        let  arabicValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        var startingValue = number
        var    romanValue = kEmpty

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

	func repeatedFor(_ length: Int) -> String {
		var  count = length
		var result = kEmpty

		while count > 0 {
			count -= 1

			result.append(self)
		}

		return result
	}

	func surround(with repeater: String) -> String {
		let inner = smallSurround(with: kSpace).smallSurround(with: repeater)
		let outer = repeater.repeatedFor(count + 8)

		if  repeater == kEmpty {
			return kNewLine + inner + kNewLine
		} else {
			return kNewLine + outer + kNewLine + inner + kNewLine + outer + kNewLine
		}
	}

	func smallSurround(with repeater: String, repeating: Int = 2) -> String {
		let small = repeater.repeatedFor(repeating)

		return "\(small)\(self)\(small)"
	}

	func draw(at point: CGPoint, angle: CGFloat, andAttributes attributes: [NSAttributedString.Key : Any]) {
		let transform = NSAffineTransform()
		let    offset = CGPoint((self as NSString).size(withAttributes: attributes).dividedInHalf)

		transform.translateX(by: point.x, yBy: point.y)
		transform.rotate(byRadians: angle)
		draw(at: .zero - offset, withAttributes: attributes)
	}

	func rangeOfParagraph(for range: NSRange) -> NSRange {
		var   result = range
		while result.location > 0,
			  substring(with: result)[0] != kReturn {
			result = result.extendedBy(-1)
		}

		return result
	}

}

extension NSPredicate {

	func and(_ predicate: NSPredicate) -> NSPredicate {
		return NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self])
	}

	func or(_ predicate: NSPredicate) -> NSPredicate {
		return NSCompoundPredicate(orPredicateWithSubpredicates: [predicate, self])
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
		} catch {
			printDebug(.dError, "\(error)")
		}

		return nil
	}

	func storeFor(_ key: String) {
		let query = [
			kSecValueData   as String : self,
			kSecAttrAccount as String : key,
			kSecClass       as String : kSecClassGenericPassword as String
		] as CFDictionary

		SecItemDelete(query)
		SecItemAdd   (query, nil)
	}

	static func loadFor(_ key: String) -> Data? {
		let query = [
			kSecClass       as String : kSecClassGenericPassword as String,
			kSecAttrAccount as String : key,
			kSecReturnData  as String : kCFBooleanTrue!,
			kSecMatchLimit  as String : kSecMatchLimitOne
		] as CFDictionary

		var dataTypeRef : AnyObject? = nil

		if  SecItemCopyMatching(query as CFDictionary, &dataTypeRef) == noErr {
			return dataTypeRef as! Data?
		}

		return nil
	}

	func extractJSONDict() -> ZStringObjectDictionary? {
		do {
			if  let    json = try JSONSerialization.jsonObject(with: self) as? ZStringObjectDictionary {
				return json
			}
		} catch {
			printDebug(.dError, "\(error)")    // de-serialization
		}
		return nil
	}

	func extractCSV() -> [StringsArray] {
		var           rows  = [StringsArray]()
		if  let     string  = String(data: self, encoding: .ascii)?.substring(fromInclusive: 3) {
			let      items  = string.components(separatedBy: kNewLine)
			for item in items {
				let fields  = item.escapeCommasWithinQuotes.components(separatedBy: kCommaSeparator)
				rows.append(fields)
			}
		}

		return rows
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

	func withAlpha(_ alpha: CGFloat) -> ZColor { return ZColor(calibratedRed: redComponent, green: greenComponent, blue: blueComponent, alpha: alpha) }

}

extension Date {

	func easyToReadDateFrom(_ format: String) -> String {
		let f = DateFormatter()
		f.dateFormat = format

		return f.string(from: self)
	}

	var easyToReadDateTime: String { return easyToReadDateFrom("h:mm a MMM d, YYYY") }
	var easyToReadDate:     String { return easyToReadDateFrom("MMM d, YYYY") }
	var easyToReadTime:     String { return easyToReadDateFrom("h:mm a") }

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
	@objc var isControlDown: Bool { return false }
	var       isDone:        Bool { return [.ended, .cancelled, .failed, .possible].contains(state) }

    func cancel() {
        isEnabled = false // Apple says "when changed to NO the gesture recognizer will be cancelled [and] will not receive events"
        isEnabled = true
    }

}

extension ZView {

	@objc var size: CGSize { return bounds.size }

	var currentMouseLocationInWindow: CGPoint? {
		return window?.convertPoint(fromScreen: ZEvent.mouseLocation)
	}

	var maxX: CGFloat {
		var x = CGFloat.zero

		for subview in subviews {
			let subX = subview.frame.maxX

			if  x < subX {
				x = subX
			}
		}

		return x
	}

	var currentMouseLocation: CGPoint? {
		if  let w = currentMouseLocationInWindow {
			return convert(w, from: nil)
		}

		return nil
	}

	var rootSuperview : ZView {
		var root    = self
		while let s = root.superview {
			root    = s
		}

		return root
	}

	var kickoffToolID : ZKickoffToolID? {
		let           item = self as NSUserInterfaceItemIdentification
		if  let identifier = gConvertFromOptionalUserInterfaceItemIdentifier(item.identifier),
			let     itemID = ZKickoffToolID(rawValue: identifier) {
			return  itemID
		}

		return nil
	}

	var linkButtonType : ZLinkButtonType? {
		let        item = self as NSUserInterfaceItemIdentification
		if  let  itemID = gConvertFromOptionalUserInterfaceItemIdentifier(item.identifier),
			let    type = ZLinkButtonType(rawValue: itemID) {
			return type
		}

		return nil
	}

	var modeButtonType : ZModeButtonType? {
		get {
			let        item = self as NSUserInterfaceItemIdentification
			if  let  itemID = gConvertFromOptionalUserInterfaceItemIdentifier(item.identifier),
				let    type = ZModeButtonType(rawValue: itemID) {
				return type
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = gConvertToUserInterfaceItemIdentifier(value)
			}
		}
	}

	var viewIdentifierString: String? {
		if  let id = viewIdentifier {
			return gConvertFromOptionalUserInterfaceItemIdentifier(id)
		}

		return nil
	}

	var viewIdentifier: NSUserInterfaceItemIdentifier? {
		let    item = self as NSUserInterfaceItemIdentification

		return item.identifier
	}

	var helpMode : ZHelpMode? {
		get {
			if  let  itemID = viewIdentifierString,
				let    mode = ZHelpMode(rawValue: itemID) {
				return mode
			}

			return nil
		}

		set {
			if  let  value = newValue?.rawValue {
				identifier = gConvertToUserInterfaceItemIdentifier(value)
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
		var result = StringsArray()

		result.append("\(identifier?.rawValue ?? "dunno") ")

		for constraint in constraints {
			result.append("\(constraint)")
		}

		print(result.joined(separator: kReturn))
	}

	func drawColoredRect(_ rect: CGRect, _ color: ZColor, thickness: CGFloat = 0.5) {
		let     radius = CGFloat(8.0)
		let       path = ZBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
		path.lineWidth = thickness

		color.setStroke()
		path.stroke()
	}

	func drawColoredOval(_ rect: CGRect, _ color: ZColor, filled: Bool = false) {
		let oval = ZBezierPath(ovalIn: rect)

		color.setStroke()
		oval.stroke()

		if  filled {
			color.setFill()
			oval.fill()
		}
	}

    func drawBorder(thickness: CGFloat, inset: CGFloat = .zero, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }

	func displayAllSubviews() {
		if !gDeferringRedraw {
			applyToAllSubviews { view in
				view.display()
			}
		}
	}

    func setAllSubviewsNeedDisplay() {
        if !gDeferringRedraw {
            applyToAllSubviews { view in
                view.setNeedsDisplay()
            }
        }
    }

	func layoutAllSubviews() {
		if !gDeferringRedraw {
			applyToAllSubviews { view in
				view.layout()
			}
		}
	}

	func setAllSubviewsNeedLayout() {
		if !gDeferringRedraw {
			applyToAllSubviews { view in
				view.setNeedsLayout()
			}
		}
	}

    func applyToAllSubviews(_ closure: ViewClosure) {
		closure(self)

        for view in subviews {
            view.applyToAllSubviews(closure)
        }
    }

	func applyToAllVisibleSubviews(_ closure: ViewClosure) {
		closure(self)

		for view in subviews {
			if !view.isHidden {
				view.applyToAllSubviews(closure)
			}
		}
	}

    func applyToAllSuperviews(_ closure: ViewClosure) {
        closure(self)

        superview?.applyToAllSuperviews(closure)
	}

	func locationFromEvent(_ event: ZEvent) -> CGPoint {
		return convert(event.locationInWindow, from: nil)
	}

	func analyze(_ object: AnyObject?) -> (Bool, Bool, Bool, Bool, Bool) {
		return (false, true, false, false, false)
	}

}

extension ZPseudoView {

	func drawTinyDots(surrounding rect: CGRect, count: Int?, radius: Double, color: ZColor?, countMax: Int = 10, clockwise: Bool = false, onEach: IntRectClosure? = nil) {
		if  let              c = controller ?? gHelpController, // for help dots, widget and controller are nil; so use help controller
			var       dotCount = count {
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

				let drawDots: IntBooleanClosure = { (iCount, isFat) in
					let     oneSet = (isFat ? tinyCount : fatCount) == 0
					let   isHollow = (isFat && fatHollow) || (!isFat && tinyHollow)

					if  iCount     > 0 {
						let isEven = iCount % 2 == 0
						let fullCircle = k2PI
						let startAngle = fullCircle / 4.0 * ((clockwise ? .zero : 1.0) * (oneSet ? (isEven ? .zero : 2.0) : isFat ? 1.0 : 3.0)) + (oneSet ? .zero : kPI)
						let angles = iCount.anglesArray(startAngle: startAngle, oneSet: oneSet, isFat: isFat, clockwise: clockwise)

						for (index, angle) in angles.enumerated() {
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
								path    .lineWidth = CGFloat(c.coreThickness * (asEssay ? 7.0 : 3.0))
								path     .flatness = kDefaultFlatness

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

extension NSSegmentedControl {

	var seletedSegments: IndexSet {
		var set = IndexSet()

		for segment in 0..<segmentCount {
			if  isSelected(forSegment: segment) {
				set.insert(segment)
			}
		}

		return set
	}

	func selectSegments(from set: IndexSet) {
		for segment in 0..<segmentCount {
			setSelected(set.contains(segment), forSegment: segment)
		}
	}

}
