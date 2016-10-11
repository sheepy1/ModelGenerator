//
//  NSNumberExtension.swift
//  ModelGenerator
//
//  Created by 杨洋 on 10/11/16.
//  Copyright © 2016 Sheepy. All rights reserved.
//

import Foundation

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

extension NSNumber {
    var isBool:Bool {
        get {
            let objCType = String(cString: self.objCType)
            if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType)
                || (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType) {
                return true
            } else {
                return false
            }
        }
    }
}
