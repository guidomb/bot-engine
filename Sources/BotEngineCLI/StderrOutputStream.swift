//
//  StderrOutputStream.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/11/18.
//

import Foundation

struct StderrOutputStream: TextOutputStream {
    
    mutating func write(_ string: String) {
        fputs(string, stderr)
    }
    
}
