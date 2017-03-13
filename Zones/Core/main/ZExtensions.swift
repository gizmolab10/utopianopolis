//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
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
    var settingsController: ZSettingsViewController? { return gControllersManager.controllerForID(.settings) as? ZSettingsViewController }
    var   editorController:   ZEditorViewController? { return gControllersManager.controllerForID(.editor)   as? ZEditorViewController }
    var        gEditorView:           ZonesDrawView? { return editorController?.view                         as? ZonesDrawView }


    func toConsole(_ iMessage: Any?) {
//        print(iMessage)
    }


    func debugCheck() {
        gTravelManager.debugCheck()
    }


    func report(_ iMessage: Any?) {
        if iMessage != nil {
            print(iMessage!)
        }
    }


    func reportError(_ iError: Any?) {
        if let error: NSError = iError as? NSError, let waitForIt = error.userInfo[CKErrorRetryAfterKey] {
            print(waitForIt)
        } else if let error: CKError = iError as? CKError {
            print(error.localizedDescription)
        } else if iError != nil {
            print(iError!)
        }
    }


    func signalFor(_ object: NSObject?, regarding: ZSignalKind) {
        gControllersManager.signalFor(object, regarding: regarding, onCompletion: nil)
    }


    func detectWithMode(_ mode: ZStorageMode, block: ToBooleanClosure) -> Bool {
        let savedMode = gStorageMode
        gStorageMode  = mode
        let    result = block()
        gStorageMode  = savedMode

        return result
    }


    func invokeWithMode(_ mode: ZStorageMode?, block: Closure) {
        if  mode == nil || mode == gStorageMode {
            block()
        } else {
            let savedMode = gStorageMode
            gStorageMode  = mode!

            block()

            gStorageMode  = savedMode
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
}


extension CGRect {
    var center : CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}


extension String {
    var asciiArray: [UInt32] {
        return unicodeScalars.filter{$0.isASCII}.map{$0.value}
    }


    var isDigit: Bool {
        return "0123456789.+-=*/".characters.contains(self[startIndex])
    }


    var isAscii: Bool {
        return unicodeScalars.filter{$0.isASCII}.count > 0
    }


    var containsNonAscii: Bool {
        return unicodeScalars.filter{!$0.isASCII}.count > 0
    }


    var arrow: ZArrowKey? {
        if containsNonAscii {
            let character = utf8CString[2]

            for arrowKey in ZArrowKey.up.rawValue...ZArrowKey.right.rawValue {
                if arrowKey == character {
                    return ZArrowKey(rawValue: character)
                }
            }
        }

        return nil
    }


    func heightForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).width + 4.0
    }


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


    func substring(from: Int) -> String {
        return substring(from: index(at: from))
    }


    func substring(to: Int) -> String {
        return substring(to: index(at: to))
    }


    func substring(with r: Range<Int>) -> String {
        let startIndex = index(at: r.lowerBound)
        let   endIndex = index(at: r.upperBound)

        return substring(with: startIndex..<endIndex)
    }
}


extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.first?.value
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
        let radius: CGFloat = min(size.width, size.height) * radius

        self.addBorder(thickness: thickness, radius: radius, color: color)
    }


    func applyToAllSubviews(_ closure: ViewClosure) {
        for view in subviews {
            closure(view)

            view.applyToAllSubviews(closure)
        }
    }


    func thinStroke(_ path: ZBezierPath?) {
        if  path != nil {
            path!.lineWidth = CGFloat(gLineThickness) / lineThicknessDivisor

            path!.stroke()
        }
    }
}
