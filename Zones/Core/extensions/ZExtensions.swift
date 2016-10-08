//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


extension String {
    func heightForFont(_ font: ZFont) -> CGFloat {
        let boundingBox = self.size(withAttributes: [NSFontAttributeName: font])

        return boundingBox.height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        let boundingBox = self.size(withAttributes: [NSFontAttributeName: font])

        return boundingBox.width
    }
}


//extension NSAttributedString {
//    func heightWithConstrainedWidth(width: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
//        let boundingBox = self.boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.height
//    }
//
//    func widthWithConstrainedHeight(height: CGFloat) -> CGFloat {
//        let constraint = CGSize(width: .greatestFiniteMagnitude, height: height)
//        let boundingBox = self.boundingRect(with: constraint, options: .usesLineFragmentOrigin, context: nil)
//
//        return boundingBox.width
//    }
//}
