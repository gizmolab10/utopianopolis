//
//  ZExtensions.swift
//  Zones
//
//  Created by Jonathan Sand on 10/8/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(iOS)
    import UIKit
#elseif os(OSX)
    import Cocoa

    extension String {
        func size(attributes attrs: [String : Any]? = nil) -> NSSize {
            return size(withAttributes:attrs)
        }
    }
#endif


extension ZApplication {

    func clearBadge() {
        #if os(OSX)
            self.dockTile.badgeLabel = ""
        #else
            self.applicationIconBadgeNumber += 1
            self.applicationIconBadgeNumber  = 0

            self.cancelAllLocalNotifications()
        #endif
    }
}


extension String {

    func sizeWithFont(_ font: ZFont) -> CGSize {
        return self.size(attributes: [NSFontAttributeName: font])
    }


    func heightForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).height
    }


    func widthForFont(_ font: ZFont) -> CGFloat {
        return sizeWithFont(font).width
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
