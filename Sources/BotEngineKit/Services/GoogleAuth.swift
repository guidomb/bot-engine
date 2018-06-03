//
//  Google.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/4/18.
//

import Foundation
import OAuth2
import GoogleAPI

public struct GoogleAuth {
    
    let credentialsFilename = "feebi.json"
    let scopes = [
        "https://www.googleapis.com/auth/spreadsheets.readonly",
        "https://www.googleapis.com/auth/forms",
        "https://www.googleapis.com/auth/drive.metadata.readonly",
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/admin.directory.group",
        "https://www.googleapis.com/auth/admin.directory.user.readonly"
    ]

    private let tokenFilename = ".feebi-token"
    
    public init() {
        
    }
    
    public func login() throws -> GoogleAPI.Token {
        guard let tokenProvider = BrowserTokenProvider(credentials: credentialsFilename, token: tokenFilename) else {
            fatalError("Unable to create token provider")
        }

        if tokenProvider.token == nil {
            try tokenProvider.signIn(scopes: scopes)
            try tokenProvider.saveToken(tokenFilename)
        }

        return tokenProvider.token!.asGoogleToken!
    }
    
}

fileprivate extension Token {

    var asGoogleToken: GoogleAPI.Token? {
        guard let tokenType = self.TokenType, let tokenValue = self.AccessToken else {
            return nil
        }
        return GoogleAPI.Token(type: tokenType, value: tokenValue)
    }

}
