//
//  Ability.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

public struct Ability: Equatable, Codable {
    
    public struct Attribute: Equatable, Codable {
        
        public enum Frequency: String, Codable {
            
            case sometimes = "algunas veces"
            case regularly = "habitualmente"
            case inMostCases = "en la mayoría de los casos"
            case almostAlways = "casi siempre"
            
        }
        
        public enum Level: UInt, Codable {
            
            case first
            case second
            case third
            case fourth
            
        }
        
        public let name: String
        public let level: Level?
        public let levelDescriptions: [String]
        public let frequency: Frequency?
        public let comment: String?
        
        public func description(for level: Level) -> String {
            return levelDescriptions[Int(level.rawValue)]
        }
        
    }
    
    public let name: String
    public let identifier: String
    public let description: String
    public let attributes: [Attribute]
    
}
