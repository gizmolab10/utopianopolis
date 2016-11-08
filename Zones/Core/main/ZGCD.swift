//
//  XBGCD.m
//  XIMBLE
//
//  Created by Jonathan Sand on 3/30/16.
//  Copyright © 2016 Xicato. All rights reserved.
//


import Foundation


extension NSObject {


    func dispatchAsyncInForeground(_ closure: @escaping Closure) {
        DispatchQueue.main.async {
            closure();
        }
    }


}
