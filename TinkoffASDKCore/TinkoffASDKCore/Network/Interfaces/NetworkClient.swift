//
//
//  NetworkClient.swift
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

protocol NetworkClient: AnyObject {

    @discardableResult
    func performRequest(_ request: NetworkRequest, completion: @escaping (NetworkResponse) -> Void) -> Cancellable

    @discardableResult
    @available(*, deprecated, message: "Use performRequest(_:completion:) instead")
    func performDeprecatedRequest<Response: ResponseOperation>(
        _ request: NetworkRequest,
        delegate: NetworkTransportResponseDelegate?,
        completion: @escaping (Result<Response, Error>) -> Void
    ) -> Cancellable

    @discardableResult
    @available(*, deprecated, message: "Use performRequest(_:completion:) instead")
    func sendCertsConfigRequest(
        _ request: NetworkRequest,
        completionHandler: @escaping (Result<GetCertsConfigResponse, Error>) -> Void
    ) -> Cancellable
}
