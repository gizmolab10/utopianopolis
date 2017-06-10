//
//  ZExtensions.swift
//  Zones
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


typealias ZStorageDict = [String : NSObject]


extension NSObject {
    var settingsController: ZSettingsController? { return gControllersManager.controllerForID(.settings) as? ZSettingsController }
    var  gEditorController:   ZEditorController? { return gControllersManager.controllerForID(.editor)   as? ZEditorController }
    var        gEditorView:       ZDragDrawView? { return gEditorController?.view                                  as? ZDragDrawView }


    func        note(_ iMessage: Any?)                            { } // report(iMessage) }
    func performance(_ iMessage: Any?)                            { report(iMessage) }
    func   signalFor(_ object: NSObject?, regarding: ZSignalKind) { gControllersManager.signalFor(object, regarding: regarding, onCompletion: nil) }
    func  debugCheck()                                            { gTravelManager.debugCheck() }


    func columnarReport(_ iFirst: Any?, _ iSecond: Any?) {
        if  var prefix = iFirst as? String {
            prefix.appendSpacesToLength(gLogTabStop - 1)
            report("\(prefix) \(iSecond ?? "")")
        }
    }


    func report(_ iMessage: Any?) {
        if iMessage != nil {
            print(iMessage!)
        }
    }


    func reportError(_ iError: Any? = nil, _ message: String? = nil) {
        let text = message ?? ""

        if let error: NSError = iError as? NSError {
            let waitForIt = (error.userInfo[CKErrorRetryAfterKey] as? String) ?? ""

            print(waitForIt + text)
        } else if let error: CKError = iError as? CKError {
            print(error.localizedDescription + text)
        } else {
            let error = iError as? String ?? ""

            print(error + text)
        }
    }


    func redrawAndSync(_ iZone: Zone? = nil, _ onCompletion: Closure? = nil) {
        gControllersManager.syncToCloudAndSignalFor(iZone, regarding: .redraw, onCompletion: onCompletion)
    }


    func redrawAndSyncAndRedraw(_ iZone: Zone? = nil) {
        redrawAndSync(iZone) {
            self.signalFor(iZone, regarding: .redraw)
        }
    }


    @discardableResult func detectWithMode(_ mode: ZStorageMode, block: ToBooleanClosure) -> Bool {
        gRemoteStoresManager.pushMode(mode)

        let result = block()

        gRemoteStoresManager.popMode()
        
        return result
    }


    func invokeWithMode(_ mode: ZStorageMode?, block: Closure) {
        if  mode != nil && mode != gStorageMode {
            detectWithMode(mode!) { block(); return false }
        } else {
            block()
        }
    }


    func manifestNameForMode(_ mode: ZStorageMode) -> String {
        return "\(manifestNameKey).\(mode.rawValue)"
    }


    func UNDO<TargetType : AnyObject>(_ target: TargetType, handler: @escaping (TargetType) -> Swift.Void) {
        gUndoManager.registerUndo(withTarget:target, handler: { iTarget in
            // gUndoManager.beginUndoGrouping()
            handler(iTarget)
            // gUndoManager.endUndoGrouping()
        })
    }


    func applyTo(_ array: [NSObject]?, closure: ObjectToStringClosure) -> String {
        var separator = ""
        var    string = ""

        if array != nil {
            for object in array! {
                let message = closure(object)
                string.append("\(separator) \(message)")

                if  separator.length == 0 {
                    separator.appendSpacesToLength(gLogTabStop - 1)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }


    func stringForZones(_ zones: [Zone]?) -> String {
        return applyTo(zones)  { object -> (String) in
            if let zone = object as? Zone, let name = zone.zoneName {
                return name
            }

            return "---"
        }
    }


    func stringForRecords(_ records: [CKRecord]?) -> String {
        return applyTo(records)  { object -> (String) in
            if let record = object as? CKRecord {
                return record[zoneNameKey] as? String ?? record.recordID.recordName
            }
            
            return "---"
        }
    }


    func stringForReferences(_ references: [CKReference]?, in storageMode: ZStorageMode) -> String {
        return applyTo(references)  { object -> (String) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(storageMode).zoneForReference(reference), let name = zone.zoneName {
                return name
            }

            return "---"
        }
    }


    func stringForRecordIDs(_ recordIDs: [CKRecordID]?, in storageMode: ZStorageMode) -> String {
        return applyTo(recordIDs)  { object -> (String) in
            if let recordID = object as? CKRecordID, let record = gRemoteStoresManager.recordsManagerFor(storageMode).recordForRecordID(recordID), let name = record.record.object(forKey: zoneNameKey) as? String {
                return name
            }

            return "---"
        }
    }
}


extension CGPoint {
    static func - ( left: CGPoint, right: CGPoint) -> CGSize {
        return CGSize(width: left.x - right.x, height: left.y - right.y)
    }
}


extension CGRect {

    var center : CGPoint { return CGPoint(x: midX, y: midY) }
    var extent : CGPoint { return CGPoint(x: maxX, y: maxY) }

    public init(start: CGPoint, end: CGPoint) {
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
}


extension String {
    var   asciiArray: [UInt32] { return unicodeScalars.filter{$0.isASCII}.map{$0.value} }
    var          isDigit: Bool { return "0123456789.+-=*/".characters.contains(self[startIndex]) }
    var          isAscii: Bool { return unicodeScalars.filter{ $0.isASCII}.count > 0 }
    var containsNonAscii: Bool { return unicodeScalars.filter{!$0.isASCII}.count > 0 }
    var           length: Int  { return unicodeScalars.count }

    func substring(from:         Int) -> String   { return substring(from: index(at: from)) }
    func substring(to:           Int) -> String  { return substring(to: index(at: to)) }
    func heightForFont(_ font: ZFont) -> CGFloat { return sizeWithFont(font).height }
    func widthForFont(_  font: ZFont) -> CGFloat { return sizeWithFont(font).width + 4.0 }


    func sizeWithFont(_ font: ZFont) -> CGSize {
        let   rect = CGSize(width: 1000000, height: 1000000)
        let bounds = self.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [kCTFontAttributeName as String : font], context: nil)

        return bounds.size
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


    func substring(with r: Range<Int>) -> String {
        let startIndex = index(at: r.lowerBound)
        let   endIndex = index(at: r.upperBound)

        return substring(with: startIndex..<endIndex)
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
}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
    }
}


extension ZGestureRecognizer {
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


    func addBorder(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        zlayer.cornerRadius = radius
        zlayer.borderWidth  = thickness
        zlayer.borderColor  = color
    }


    func addBorderRelative(thickness: CGFloat, radius: CGFloat, color: CGColor) {
        let            size = self.bounds.size
        let radius: CGFloat = min(size.height, size.width) * radius

        self.addBorder(thickness: thickness, radius: radius, color: color)
    }


    func applyToAllSubviews(_ closure: ViewClosure) {
        closure(self)

        for view in subviews {
            view.applyToAllSubviews(closure)
        }
    }


    func thinStroke(_ path: ZBezierPath?) {
        if  path != nil {
            path!.lineWidth = CGFloat(gLineThickness)

            path!.stroke()
        }
    }
}
