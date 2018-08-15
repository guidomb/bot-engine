//
//  impersonateUser.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/4/18.
//

import Foundation
import ReactiveSwift
import Result

struct ImpersonateUser: BotEngineCommand {
 
    let commandUsage = "impersonate USER_NAME"
    
    let permission: BotEngine.ExecutionPermission
    
    private let inputRegex = try! NSRegularExpression(
        pattern: "^impersonate\\s+<@(.+)>$",
        options: .caseInsensitive
    )
    private let impersonate: (BotEngine.UserId, BotEngine.ImpersonatorId) -> Void
    
    init(admin: BotEngine.UserId, impersonate: @escaping (BotEngine.UserId, BotEngine.ImpersonatorId) -> Void) {
        self.init(admins: [admin], impersonate: impersonate)
    }
    
    init(admins: [BotEngine.UserId], impersonate: @escaping (BotEngine.UserId, BotEngine.ImpersonatorId) -> Void) {
        self.permission = .only(admins)
        self.impersonate = impersonate
    }
    
    func parseInput(_ input: String) -> BotEngine.UserId? {
        return input.firstMatch(regex: inputRegex)
            .flatMap { $0.substring(from: input, at: 1) }
            .map(BotEngine.UserId.init(value:))
    }
    
    func execute(using services: BotEngine.Services, parameters: BotEngine.UserId, senderId: BotEngine.UserId)
        -> BotEngine.Producer<BotEngine.CommandOutput> {
        let impersonatee = parameters
        impersonate(impersonatee, senderId.asImpersonator)
            return .init(value: .init(message: "You are now impersonating \(impersonatee.value)"))
    }
    
}
