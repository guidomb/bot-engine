//
//  AutoProtocols.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation

internal protocol AutoDecodable: Decodable {}
internal protocol AutoEncodable: Encodable {}
internal protocol AutoCodable: AutoDecodable, AutoEncodable {}
internal protocol AutoEquatable { }
internal protocol AutoSnakeCaseCodingKey { }
