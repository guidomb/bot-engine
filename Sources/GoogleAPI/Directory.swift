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
        
        public struct Users {
            
            private let basePath: String
            
            fileprivate init(basePath: String) {
                self.basePath = "\(basePath)/users"
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/users/get
            public func get(userKey: String) -> Resource<DirectoryUser> {
                return Resource(
                    path: "\(basePath)/get",
                    queryParameters: "userKey=\(userKey)",
                    method: .get
                )
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/users/list
            public func list(options: ListUsersOptions = .init()) -> Resource<UserList> {
                return Resource(
                    path: basePath,
                    queryParameters: options,
                    method: .get
                )
            }
            
        }
        
        public struct Groups {
            
            private let basePath: String
            
            fileprivate init(basePath: String) {
                self.basePath = "\(basePath)/groups"
            }
            
            // https://developers.google.com/admin-sdk/directory/v1/reference/groups/list
            public func list(options: ListGroupsOptions = .init()) -> Resource<GroupList> {
                return Resource(
                    path: basePath,
                    queryParameters: options,
                    method: .get
                )
            }
            
            public func list(for member: Member) -> Resource<GroupList> {
                var options = ListGroupsOptions()
                options.customer = member.email
                return list(options: options)
            }
            
        }
        
        fileprivate init() {}

        public var users: Users { return Users(basePath: basePath) }
        public var groups: Groups { return Groups(basePath: basePath) }
        
        public func members(for groupKey: String) -> Members { return Members(basePath: basePath, groupKey: groupKey) }
        
    }
    
    public static let directory = Directory()
    
}

// MARK :- Data models

public struct ListMembersOptions: PaginableFetcherOptions, QueryStringConvertible {
    
    public var includeDerivedMembership: Bool?
    public var maxResults: Int?
    public var pageToken: String?
    public var roles: Member.Role?
    
    public var asQueryString: String {
        return toQueryString(object: self) ?? ""
    }
    
    public init() { }
    
}

public struct ListGroupsOptions: PaginableFetcherOptions, QueryStringConvertible {
    
    public var customer: String?
    public var domain: String?
    public var maxResults: Int?
    public var pageToken: String?
    public var roles: Member.Role?
    public var userKey: String?
    
    public var asQueryString: String {
        return toQueryString(object: self) ?? ""
    }
    
    public init() { }
    
}

public struct GroupList: Paginable, Decodable {
    
    public let groups: [Group]?
    public let nextPageToken: String?
    
}

public struct Group: Codable {
    
    public let id: String
    public let email: String
    public let name: String
    public let directMembersCount: String
    public let description: String
    public let adminCreated: Bool
    public let aliases: [String]?
    public let nonEditableAliases: [String]?

    
}

public struct UserList: Paginable, Decodable {
    
    public let users: [DirectoryUser]?
    public let nextPageToken: String?
    
}

public struct ListUsersOptions: PaginableFetcherOptions, QueryStringConvertible {
    
    public enum SortOder: String {
        
        case ascending  = "ASCENDING"
        case descending = "DESCENDING"
        
    }
    
    public enum ViewType: String {
        
        case AdminView      = "admin_view"
        case DomainPublic   = "domain_public"
    }
    
    public enum Projection: String {
        
        case basic  = "basic"
        case custom = "custom"
        case full   = "full"
        
    }
    
    public var maxResults: Int?
    public var orderBy: String?
    public var pageToken: String?
    public var sortOrder: SortOder?
    public var viewType: String?
    public var showDeleted: Bool?
    public var domain: String?
    public var customer: String?
    public var customFieldMask: String?
    public var projection: Projection?
    
    public var asQueryString: String {
        return toQueryString(object: self) ?? ""
    }
    
    public init() { }
    
}

public struct MemberList: Paginable, Decodable {
    
    public let members: [Member]?
    public let nextPageToken: String?

}

public struct Member: Codable, Equatable, Hashable {
    
    public static func ==(lhs: Member, rhs: Member) -> Bool {
        return lhs.email == rhs.email
    }
    
    public var hashValue: Int {
        return email.hashValue
    }
    
    public enum Role: String, Codable, Hashable, CustomStringConvertible {
        
        case owner   = "OWNER"
        case manager = "MANAGER"
        case member  = "MEMBER"
        
        public var description: String {
            return rawValue
        }
        
    }
    
    public enum Status: String, Codable, Hashable, CustomStringConvertible {
        
        case active     = "ACTIVE"
        case suspended  = "SUSPENDED"
        case unknown    = "UNKNOWN"
        
        public var description: String {
            return rawValue
        }
        
    }
    
    public enum MemberType: String, Codable, Hashable, CustomStringConvertible {
        
        case customer   = "CUSTOMER"
        case external   = "EXTERNAL"
        case group      = "GROUP"
        case user       = "USER"
        
        public var description: String {
            return rawValue
        }
        
    }
    
    public let id: String?
    public let email: String
    public let role: Role
    public let type: MemberType?
    public let status: Status?
    
    public init(email: String, role: Role) {
        self.email = email
        self.role = role
        self.id = .none
        self.type = .none
        self.status = .none
    }
    
}

public struct DirectoryUser: Decodable {
    
    public struct Name: Decodable {
        
        public let givenName: String
        public let familyName: String
        public let fullName: String
        
    }
    
    public let id: String
    public let primaryEmail: String
    public let name: Name
    public let isAdmin: Bool
    public let isDelegatedAdmin: Bool
    public let customerId: String
    
}
