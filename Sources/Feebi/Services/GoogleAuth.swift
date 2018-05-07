//
//  Google.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/4/18.
//

import Foundation
import OAuth2
import FeebiKit

fileprivate extension Token {
    
    var asGoogleToken: GoogleAPI.Token? {
        guard let tokenType = self.TokenType, let tokenValue = self.AccessToken else {
            return nil
        }
        return GoogleAPI.Token(type: tokenType, value: tokenValue)
    }
    
}

struct GoogleAuth {
    
    private let tokenFilename = ".feebi-token"
    let credentialsFilename = "feebi.json"
    let scopes = [
        "https://www.googleapis.com/auth/spreadsheets.readonly",
        "https://www.googleapis.com/auth/forms",
        "https://www.googleapis.com/auth/drive.metadata.readonly"
    ]
    
    func login() throws -> GoogleAPI.Token {
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

