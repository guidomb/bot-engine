//
//  Directory.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 5/23/18.
//

import Foundation

public extension GoogleAPI {
    
    public struct Directory {
        
        private let baseURL = "https://www.googleapis.com/admin"
        private let version = "v1"
        
        private var basePath: String {
            return "\(baseURL)/directory/\(version)"
        }
        
        public struct Members {
            
            private let basePath: String
            
            fileprivate init(basePath: String, groupKey: String) {
                self.basePath = "\(basePath)/groups/\(groupKey)/members"
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/members/list
            public func list(options: ListMembersOptions = .init()) -> Resource<MemberList> {
                return Resource(
                    path: basePath,
                    queryParameters: options,
                    method: .get
                )
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/members/insert
            public func insert(member : Member) -> Resource<Member> {
                return Resource(
                    path: basePath,
                    requestBody: member,
                    method: .post
                )
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/members/delete
            public func delete(member memberKey: String) -> Resource<Void> {
                return Resource(
                    path: "\(basePath)/\(memberKey)",
                    method: .delete
                )
            }
            
        }
        
        fileprivate init() {}

        public func members(for groupKey: String) -> Members { return Members(basePath: basePath, groupKey: groupKey) }
        
    }
    
    public static let directory = Directory()
    
}

// MARK :- Data models

public struct ListMembersOptions: QueryStringConvertible {
    
    public var includeDerivedMembership: Bool?
    public var maxResults: Int?
    public var pageToken: String?
    public var roles: Member.Role?
    
    public var asQueryString: String {
        return toQueryString(object: self) ?? ""
    }
    
    public init() { }
    
}

public struct MemberList: Decodable {
    
    public let members: [Member]
    public let nextPageToken: String?

}

public struct Member: Codable {
    
    public enum Role: String, Codable {
        
        case owner   = "OWNER"
        case manager = "MANAGER"
        case member  = "MEMBER"
        
    }
    
    public enum Status: String, Codable {
        
        case active     = "ACTIVE"
        case suspended  = "SUSPENDED"
        case unknown    = "UNKNOWN"
        
    }
    
    public enum MemberType: String, Codable {
        
        case customer   = "CUSTOMER"
        case external   = "EXTERNAL"
        case group      = "GROUP"
        case user       = "USER"
        
    }
    
    public let id: String?
    public let email: String
    public let role: Role
    public let type: MemberType?
    public let status: Status?
    
}
