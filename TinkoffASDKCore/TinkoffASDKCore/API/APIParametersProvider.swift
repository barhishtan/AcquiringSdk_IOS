//
//
//  APIParametersProvider.swift
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

final class APIParametersProvider: NetworkRequestAdapter {

    private let terminalKey: String

    init(terminalKey: String) {
        self.terminalKey = terminalKey
    }

    func additionalParameters(for request: NetworkRequest) -> HTTPParameters {
        guard request.httpMethod != .get else {
            return [:]
        }

        let commonParameters: HTTPParameters = [APIConstants.Keys.terminalKey: terminalKey]
        return commonParameters
    }
}
