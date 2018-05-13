//
//  Extensions.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation

extension String {
    
    func matches(regex: NSRegularExpression) -> [NSTextCheckingResult] {
        let inputRange = NSRange(location: 0, length: self.count)
        return regex.matches(in: self, options: [], range: inputRange)
    }
    
    func firstMatch(regex: NSRegularExpression) -> NSTextCheckingResult? {
        return self.matches(regex: regex).first
    }
    
}

extension NSTextCheckingResult {
    
    func substring(from string: String, at index: Int) -> String? {
        guard index < self.numberOfRanges else {
            return nil
        }
        guard let range = Range(self.range(at: index), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
}
