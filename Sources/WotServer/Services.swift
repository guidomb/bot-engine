//
//  Services.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/16/18.
//

import Foundation
import BotEngineKit
import WoloxKit

extension BotEngine.Services {
    
    var mailGroup: MailGroupService {
        return .init(executor: self.googleAPIResourceExecutor)
    }
    
}
