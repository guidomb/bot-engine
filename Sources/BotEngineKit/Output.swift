//
//  OutputRenderer.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation

public protocol BehaviorOutputRenderer {
    
    func render(output: BehaviorOutput, forChannel channel: ChannelId)
    
}

public enum BehaviorOutput {
    
    case textMessage(String)
    case confirmationQuestion(message: String, question: String)
    
}

public struct ResponseTransform {
    
    static func messageTransform(expected: String, transformed: String, channel: ChannelId, sender: BotEngine.UserId) -> ResponseTransform {
        return .init(
            expectedResponse: .message(
                message: BehaviorMessage(channel: channel, senderId: sender, text: expected),
                context: .anyContext),
            transformedResponse: .message(
                message: BehaviorMessage(channel: channel, senderId: sender, text: transformed),
                context: .init()
            )
        )
    }
    
    public let expectedResponse: BotEngine.Input
    public let transformedResponse: BotEngine.Input
    
    public init(expectedResponse: BotEngine.Input, transformedResponse: BotEngine.Input) {
        self.expectedResponse = expectedResponse
        self.transformedResponse = transformedResponse
    }
    
}

public struct ChanneledBehaviorOutput  {
        
    let output: BehaviorOutput
    let channel: ChannelId
    let transforms: [ResponseTransform]
    
    init(output: BehaviorOutput, channel: ChannelId, transforms: [ResponseTransform] = []) {
        self.output = output
        self.channel = channel
        self.transforms = transforms
    }
    
    init(output: BehaviorOutput, channel: ChannelId, transform: ResponseTransform) {
        self.init(output: output, channel: channel, transforms: [transform])
    }
    
}

extension ChannelId {
    
    static let anyChannel = ""
    
}

extension BehaviorMessage.Context {
    
    static let anyContext = BehaviorMessage.Context()
    
}
