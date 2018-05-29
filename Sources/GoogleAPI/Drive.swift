//
//  Drive.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation

public extension GoogleAPI {
    
    public struct Drive {
        
        public struct Files {
            
            private let basePath: String
            
            fileprivate init(basePath: String) {
                self.basePath = "\(basePath)/files"
            }
            
            // https://developers.google.com/drive/v3/reference/files/get
            public func get(
                byId fileId: String,
                acknowledgeAbuse: Bool = false,
                supportsTeamDrives: Bool = false) -> Resource<FileMetadata> {
                
                return Resource(
                    path: "\(basePath)/\(fileId)",
                    queryParameters: "acknowledgeAbuse=\(acknowledgeAbuse)&supportsTeamDrives=\(supportsTeamDrives)",
                    method: .get
                )
            }
            
        }
        
        public var files: Files { return Files(basePath: basePath) }
        
        private let baseURL = "https://www.googleapis.com/drive"
        private let version = "v3"
        
        private var basePath: String {
            return "\(baseURL)/\(version)"
        }
        
        fileprivate init() {}
        
    }
    
    public static var drive: Drive { return Drive() }
    
}

// MARK :- Data models

public struct FileMetadata: Decodable {
    
    public let id: String
    public let kind: String
    public let name: String
    public let mimeType: String
    
}
