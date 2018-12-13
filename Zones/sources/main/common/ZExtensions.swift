//
//  ZExtensions.swift
//  Thoughtful
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


typealias ZStorageDictionary = [ZStorageType : NSObject]


extension NSObject {


    func                  note(_ iMessage: Any?)                { } // logk(iMessage) }
    func           performance(_ iMessage: Any?)                { log(iMessage) }
    func                   bam(_ iMessage: Any?)                { log("-------------------------------------------------------------------- " + (iMessage as? String ?? "")) }
    func        columnarReport(_ iFirst: Any?, _ iSecond: Any?) { rawColumnarReport(iFirst, iSecond) }


    func rawColumnarReport(_ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(kLogTabStop)
            log("\(prefix)\(iSecond ?? "")")
        }
    }


    func log(_ iMessage: Any?) {
        if  let   message = iMessage as? String, message != "" {
            print(message)
        }
    }


    func time(of title: String, _ closure: Closure) {
        let start = Date()

        closure()

        let duration = Date().timeIntervalSince(start)

        columnarReport(title, duration)
    }


    func blankScreenDebug() {
        if  let w = gEditorController?.editorRootWidget.bounds.size.width, w < 1.0 {
            bam("blank graph !!!!!!")
        }
    }


    func syncAndRedraw(_ zone: Zone? = nil) {
        gControllers.sync(zone) {
            gControllers.signalFor(zone, regarding: .eRelayout, onCompletion: nil)
        }
    }
    

    func redrawAndSync(_ zone: Zone? = nil, _ onCompletion: Closure? = nil) {
        gControllers.syncToCloudAfterSignalFor(zone, regarding: .eRelayout, onCompletion: onCompletion)
    }
    

    func redrawSyncRedraw(_ zone: Zone? = nil) {
        redrawAndSync(zone) {
            gControllers.signalFor(zone, regarding: .eRelayout)
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
        kUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            handler(iTarget)
        })
    }


    func openBrowserForFocusWebsite() {
        "https://medium.com/@sand_74696/what-you-get-d565b064be7b".openAsURL()
    }

    
    func sendEmailBugReport() {
        "mailto:sand@gizmolab.com".openAsURL()
    }
    

    // MARK:- bookmarks
    // MARK:-


    func isValid(_ iLink: String?) -> Bool {
        return components(of: iLink) != nil
    }


    func components(of iLink: String?) -> [String]? {
        if  let       link = iLink {
            let components =  link.components(separatedBy: kSeparator)
            if  components.count > 2 {
                return components
            }
        }

        return nil
    }


    func name(from iLink: String?) -> String? {
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
            let                 name = name(from: iLink) {
            var components: [String] = iLink!.components(separatedBy: kSeparator)
            let recordID: CKRecord.ID = CKRecord.ID(recordName: name)
            let ckRecord: CKRecord   = CKRecord(recordType: kZoneType, recordID: recordID)
            let        rawIdentifier = components[0]
            let   dbID: ZDatabaseID? = rawIdentifier == "" ? gDatabaseID : ZDatabaseID(rawValue: rawIdentifier)
            let              manager = gRemoteStorage.recordsFor(dbID)
            let                 zone = manager?.zoneForCKRecord(ckRecord) ?? Zone(record: ckRecord, databaseID: dbID) // BAD DUMMY ?

            return zone
        }

        return nil
    }


    // MARK:- JSON
    // MARK:-


    func dictFromJSON(_ dict: [String : NSObject]) -> ZStorageDictionary {
        var                   result = ZStorageDictionary ()

        for (key, value) in dict {
            if  let       storageKey = ZStorageType(rawValue: key) {
                var        goodValue = value
                var       translated = false

                if  let string       = value as? String {
                    let parts        = string.components(separatedBy: kTimeInterval + ":")
                    if  parts.count > 1,
                        parts[0]    == "",
                        let interval = TimeInterval(parts[1]) {
                        goodValue    = Date(timeIntervalSinceReferenceDate: interval) as NSObject
                        translated   = true
                    }
                }

                if !translated {
                    if  let     subDict = value as? [String : NSObject] {
                        goodValue       = dictFromJSON(subDict) as NSObject
                    } else if let array = value as? [[String : NSObject]] {
                        var   goodArray = [ZStorageDictionary] ()

                        for subDict in array {
                            goodArray.append(dictFromJSON(subDict))
                        }

                        goodValue       = goodArray as NSObject
                    }
                }

                result[storageKey]  = goodValue
            }
        }

        return result
    }


    func jsonDictFrom(_ dict: ZStorageDictionary) -> [String : NSObject] {
        var deferals = ZStorageDictionary ()
        var   result = [String : NSObject] ()

        let closure = { (key: ZStorageType, value: Any) in
            var goodValue       = value
            if  let     subDict = value as? ZStorageDictionary {
                goodValue       = self.jsonDictFrom(subDict)
            } else if let  date = value as? Date {
                goodValue       = kTimeInterval + ":\(date.timeIntervalSinceReferenceDate)"
            } else if let array = value as? [ZStorageDictionary] {
                var jsonArray   = [[String : NSObject]] ()

                for subDict in array {
                    jsonArray.append(self.jsonDictFrom(subDict))
                }

                goodValue       = jsonArray
            }

            result[key.rawValue]   = (goodValue as! NSObject)
        }

        for (key, value) in dict {
            if [.children, .traits].contains(key) {
                deferals[key] = value
            } else {
                closure(key, value)
            }
        }

        for (key, value) in deferals {
            closure(key, value)
        }

        return result
    }

}


extension CKRecord {

    var isBookmark: Bool {
        if  let    link = self[kpZoneLink] as? String {
            return link.contains(kSeparator)
        }

        return false
    }


    var decoratedName: String {
        switch recordType {
        case kTraitType:
            let text = self["text"] as? String ?? kNoValue
            return    (self["type"] as? String ?? "") + " " + text
        case kZoneType:
            if  let      name = self[kpZoneName] as? String {
                let separator = " "
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
        self.init(recordType: kZoneType, recordID: CKRecord.ID(recordName: name))
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


    func index(within iReferences: [CKRecord.ID]) -> Int? {
        var index: Int?

        for (i, identifier) in iReferences.enumerated() {
            if  identifier == recordID {
                index = i

                break
            }
        }

        return index
    }


    func maybeMarkAsFetched(_ databaseID: ZDatabaseID?) {
        if  let dbID      = databaseID,
            creationDate != nil {
            let states    = [ZRecordState.notFetched]
            if  let manager   = gRemoteStorage.cloud(for: dbID),
                manager.hasCKRecord(self, forAnyOf: states) {
                manager.clearCKRecords([self], for: states)
            }
        }
    }

}


infix operator ** : MultiplicationPrecedence


extension Double {
    static func ** (base: Double, power: Double) -> Double{
        return pow(base, power)
    }
}


infix operator -- : AdditionPrecedence


extension CGPoint {

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

}


extension CGSize {

    var scalarDistance: CGFloat {
        return sqrt(width * width + height * height)
    }

    static var big: CGSize {
        return CGSize(width: 1000000, height: 1000000)
    }
}


extension CGRect {

    var center: CGPoint { return CGPoint(x: midX, y: midY) }
    var extent: CGPoint { return CGPoint(x: maxX, y: maxY) }


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

}


extension Array {


    func updateOrder() { updateOrdering(start: 0.0, end: 1.0) }


    func orderLimits() -> (start: Double, end: Double) {
        var start = 1.0
        var   end = 0.0

        for element in self {
            if  let   zone = element as? Zone {
                let  order = zone.order
                let  after = order > end
                let before = order < start

                if  before {
                    start  = order
                }

                if  after {
                    end    = order
                }
            }
        }

        return (start, end)
    }


    func sortedByReverseOrdering() -> Array {
        return sorted { (a, b) -> Bool in
            if  let zoneA = a as? Zone,
                let zoneB = b as? Zone {
                return zoneA.order > zoneB.order
            }

            return true
        }
    }


    func updateOrdering(start: Double, end: Double) {
        let increment = (end - start) / Double(self.count + 2)

        for (index, element) in self.enumerated() {
            if  let    child = element as? Zone {
                let newOrder = start + (increment * Double(index + 1))
                let    order = child.order

                if  order      != newOrder {
                    child.order = newOrder

                    child.maybeNeedSave()
                }
            }
        }
    }


    func apply(closure: AnyToStringClosure) -> String {
        var separator = ""
        var    string = ""

        for object in self {
            if let message = closure(object) {
                string.append("\(separator)\(message)")

                if  separator.length == 0 {
                    separator.appendSpacesToLength(kLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }

    
    func containsCompare(_ with: AnyObject, using: CompareClosure? = nil) -> Bool {
        if  let compare = using {
            for item in self {
                if  compare(item as AnyObject, with) {
                    return true     // true means match
                }
            }
        }
        
        return false    // false means unique
    }
    

    mutating func appendUnique(contentsOf items: Array, compare: CompareClosure? = nil) {
        let array = self as NSArray
        
        for item in items {
            if  !array.contains(item),
                !containsCompare(item as AnyObject, using: compare) {
                append(item)
            }
        }
    }

    
    func intersection<S>(_ other: Array<Array<Element>.Element>) -> S where Element: Hashable {
        return Array(Set(self).intersection(Set(other))) as! S
    }
    
}


extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var   asciiValue:  UInt32  { return asciiArray[0] }
    var          isDigit: Bool { return "0123456789.+-=*/".contains(self[startIndex]) }
    var   isAlphabetical: Bool { return "abcdefghijklmnopqrstuvwxyz".contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var           length: Int  { return unicodeScalars.count }
    

    var escaped: String {
        var result = "\(self)"
        for character in "\\\"\'`" {
            let separator = "\(character)"
            let components = result.components(separatedBy: separator)
            result = components.joined(separator: "\\" + separator)
        }

        return result
    }


    static func from(_ ascii: UInt32) -> String  { return String(UnicodeScalar(ascii)!) }
    func substring(from:         Int) -> String  { return String(self[index(at: from)...]) }
    func substring(to:           Int) -> String  { return String(self[..<index(at: to)]) }
    func widthForFont (_ font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }
    func heightForFont(_ font: ZFont, options: NSString.DrawingOptions = []) -> CGFloat { return sizeWithFont(font, options: options).height }
    func sizeWithFont (_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGSize { return rectWithFont(font, options: options).size }


    func rectWithFont(_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGRect {
        let attributes = convertToOptionalNSAttributedStringKeyDictionary([kCTFontAttributeName as String : font])

        return self.boundingRect(with: CGSize.big, options: options, attributes: attributes, context: nil)
    }
    
    
    func rect(using font: ZFont, for iRange: NSRange, movingUp: Bool) -> CGRect {
        let bounds = rectWithFont(font)
        let xDelta = offset(using: font, for: iRange, movingUp: movingUp)
        
        return bounds.offsetBy(dx: xDelta, dy: 0.0)
    }

    
    func offset(using font: ZFont, for iRange: NSRange, movingUp: Bool) -> CGFloat {
        let            end = iRange.lowerBound
        let     startRange = NSMakeRange(0, end)
        let      selection = substring(with: iRange)
        let startSelection = substring(with: startRange)
        let          width = selection     .sizeWithFont(font).width
        let     startWidth = startSelection.sizeWithFont(font).width
        
        return startWidth + (movingUp ? 0.0 : width)    // move down, use right side of selection
    }
    

    var color: ZColor? {
        if self != "" {
            let pairs = components(separatedBy: ",")
            var   red = 0.0
            var  blue = 0.0
            var green = 0.0

            for pair in pairs {
                let values = pair.components(separatedBy: kSeparator)
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


    func ends(with: String) -> Bool {
        let    end = substring(from: length - 1)

        return end == with
    }


    func stringBySmartly(appending: String) -> String {
        var before = self
        var  after = appending

        while (before.ends(with: kSpace) || before == "") && after.starts(with: kSpace) {
            after = after.substring(from: 1) // strip extra space
        }

        while before.ends(with: kSpace) && after == "" {
            before = before.substring(to: before.length - 1) // strip trailing space
        }

        if !before.ends(with: kSpace) && !after.starts(with: kSpace) {
            before = before + kSpace // add missing space
        }
        
        return before + after
    }


    func stringBySmartReplacing(_ range: NSRange, with replacement: String) -> String {
        let a = substring(to:   range.lowerBound)
        let b = replacement
        let c = substring(from: range.upperBound)

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

    
    var isLineTitle: Bool {
        let substrings = components(separatedBy: kHalfLineOfDashes)
        
        return substrings.count > 1 && substrings[1].count > 0
    }

    
    func isLineTitle(within range: NSRange) -> Bool {
        let a = substring(to: range.lowerBound - 1)
        let b = substring(from: range.upperBound + 1)

        return a == kHalfLineOfDashes && b == kHalfLineOfDashes
    }


    static func forZones(_ zones: [Zone]?) -> String {
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


    static func forCKRecords(_ records: [CKRecord]?) -> String {
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


    static func forReferences(_ references: [CKRecord.Reference]?, in databaseID: ZDatabaseID) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKRecord.Reference, let zone = gRemoteStorage.recordsFor(databaseID)?.maybeZoneForReference(reference) {
                let    name  = zone.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
            } ?? ""
    }


    static func forOperationIDs (_ iIDs: [ZOperationID]?) -> String {
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


    static func pluralized(_ iValue: Int, unit: String = "", plural: String = "s", followedBy: String = "") -> String {
        return iValue <= 0 ? "" : "\(iValue) \(unit)\(iValue == 1 ? "" : "\(plural)")\(followedBy)"
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



}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }
}


extension Date {

    func mid(to iEnd: Date?) -> Date {
        let      end = iEnd ?? Date()
        let duration = timeIntervalSince(end) / 2.0

        return addingTimeInterval(duration)
    }

}


extension ZColor {
    
    var inverted: ZColor {
        let b = max(0.0, min(1.0, 1.25 - brightnessComponent))
        let s = max(0.0, min(1.0, 1.45 - saturationComponent))

        return ZColor(calibratedHue: hueComponent, saturation: s, brightness: b, alpha: alphaComponent)
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


    func clearGestures() {
        if recognizers != nil {
            for recognizer in recognizers! {
                removeGestureRecognizer(recognizer)
            }
        }
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
        applyToAllSubviews { iView in
            iView.setNeedsDisplay()
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

}


extension ZTextField {

    var       isEditingText:  Bool { return false }
    @objc var preferredFont: ZFont { return gWidgetFont }

    @objc func selectCharacter(in range: NSRange) {}
    @objc func alterCase(up: Bool) {}
    @objc func setup() {}
}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
