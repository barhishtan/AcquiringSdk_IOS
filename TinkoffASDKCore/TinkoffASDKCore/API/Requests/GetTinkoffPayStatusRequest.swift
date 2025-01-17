//
//
//  GetTinkoffPayStatusRequest.swift
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

public struct GetTinkoffPayStatusRequest: APIRequest {
    typealias Payload = GetTinkoffPayStatusPayload

    var requestPath: [String] { [createRequestName()] }
    var httpMethod: HTTPMethod { .get }
    var baseURL: URL

    // MARK: - Parameters

    private let terminalKey: String

    // MARK: - Init

    init(terminalKey: String, baseURL: URL) {
        self.terminalKey = terminalKey
        self.baseURL = baseURL
    }
}

private extension GetTinkoffPayStatusRequest {
    func createRequestName() -> String {
        var endpointURL = URL(string: "TinkoffPay/terminals")!
        let postfixPart = "status"
        endpointURL.appendPathComponent(terminalKey)
        endpointURL.appendPathComponent(postfixPart)
        return endpointURL.absoluteString
    }
}
