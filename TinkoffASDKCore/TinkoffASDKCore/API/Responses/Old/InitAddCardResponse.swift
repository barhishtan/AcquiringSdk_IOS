//
//
//  InitAddCardResponse.swift
//
//  Copyright (c) 2021 Tinkoff Bank
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

public struct InitAddCardResponse: ResponseOperation {
    public var success: Bool
    public var errorCode: Int
    public var errorMessage: String?
    public var errorDetails: String?
    public var terminalKey: String?
    //
    var requestKey: String

    private enum CodingKeys: CodingKey {
        case success
        case errorCode
        case errorMessage
        case errorDetails
        case terminalKey
        case requestKey

        var stringValue: String {
            switch self {
            case .success: return APIConstants.Keys.success
            case .errorCode: return APIConstants.Keys.errorCode
            case .errorMessage: return APIConstants.Keys.errorMessage
            case .errorDetails: return APIConstants.Keys.errorDetails
            case .terminalKey: return APIConstants.Keys.terminalKey
            case .requestKey: return APIConstants.Keys.requestKey
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        errorCode = try Int(container.decode(String.self, forKey: .errorCode))!
        errorMessage = try? container.decode(String.self, forKey: .errorMessage)
        errorDetails = try? container.decode(String.self, forKey: .errorDetails)
        terminalKey = try? container.decode(String.self, forKey: .terminalKey)
        requestKey = try container.decode(String.self, forKey: .requestKey)
    }
}
