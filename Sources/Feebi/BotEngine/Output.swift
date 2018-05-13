//
//  OutputRenderer.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation

protocol BehaviorOutputRenderer {
    
    func render(output: BehaviorOutput, forChannel channel: ChannelId)
    
}

enum BehaviorOutput {
    
    case textMessage(String)
    case confirmationQuestion(yesMessage: String, noMessage: String)
    
}
