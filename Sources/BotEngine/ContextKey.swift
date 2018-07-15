//
//  ContextKey.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/14/18.
//

import Foundation
import BotEngineKit
import GoogleAPI

enum ContextKey: String {
    
    case googleToken = "GoogleToken"
    
}

extension BotEngine.Services {
    
    var googleToken: GoogleAPI.Token? {
        return context[ContextKey.googleToken.rawValue] as? GoogleAPI.Token
    }
    
}
