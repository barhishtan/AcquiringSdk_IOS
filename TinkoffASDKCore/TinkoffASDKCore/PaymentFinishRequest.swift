//
//  PaymentFinishRequest.swift
//  TinkoffASDKCore
//
//  Copyright (c) 2020 Tinkoff Bank
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

/// Источинк оплаты
public enum PaymentSourceData: Codable {
    /// при оплате по реквизитам  карты
    ///
    /// - Parameters:
    ///   - number: номер карты в виде строки
    ///   - expDate: expiration date в виде строки `MMYY`
    ///   - cvv: код `CVV` в виде строки.
    case cardNumber(number: String, expDate: String, cvv: String)

    /// при оплате с ранее сохраненной карты
    ///
    /// - Parameters:
    ///   - cardId: идентификатор сохраненной карты
    ///   - cvv: код `CVV` в виде строки.
    case savedCard(cardId: String, cvv: String?)

    /// при оплате на основе родительского платежа
    ///
    /// - Parameters:
    ///   - rebuidId: идентификатор родительского платежа
    case parentPayment(rebuidId: String)

    /// при оплате с помощью **ApplePay**
    ///
    /// - Parameters:
    ///   - string: UTF-8 encoded JSON dictionary of encrypted payment data from `PKPaymentToken.paymentData`
    case paymentData(String)

    case unknown

    enum CodingKeys: String, CodingKey {
        case cardNumber = "PAN"
        case cardExpDate = "ExpDate"
        case cardCVV = "CVV"
        case savedCardId = "CardId"
        case paymentData = "PaymentData"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .unknown

        if let number = try? container.decode(String.self, forKey: .cardNumber),
           let expDate = try? container.decode(String.self, forKey: .cardExpDate),
           let cvv = try? container.decode(String.self, forKey: .cardCVV) {
            self = .cardNumber(number: number, expDate: expDate, cvv: cvv)
        } else if let cardId = try? container.decode(String.self, forKey: .savedCardId) {
            let cvv = try? container.decode(String.self, forKey: .cardCVV)
            self = .savedCard(cardId: cardId, cvv: cvv)
        } else if let paymentDataString = try? container.decode(String.self, forKey: .paymentData) {
            self = .paymentData(paymentDataString)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .cardNumber(number, expData, cvv):
            try container.encode(number, forKey: .cardNumber)
            try container.encode(expData, forKey: .cardExpDate)
            try container.encode(cvv, forKey: .cardCVV)

        case let .savedCard(cardId, cvv):
            try container.encode(cardId, forKey: .savedCardId)
            try container.encode(cvv, forKey: .cardCVV)

        case let .paymentData(data):
            try container.encode(data, forKey: .paymentData)

        default:
            break
        }
    }

    // MARK: - Public

    public func getCardAndRebillId() -> (cardId: String?, rebillId: String?) {
        switch self {
        case let .parentPayment(rebillId):
            return (nil, rebillId)
        case let .savedCard(cardId, _):
            return (cardId, nil)
        default:
            return (nil, nil)
        }
    }
}

public class PaymentFinishRequest: RequestOperation, AcquiringRequestTokenParams {
    // MARK: RequestOperation

    public var name: String {
        return "FinishAuthorize"
    }

    public var parameters: JSONObject?

    // MARK: AcquiringRequestTokenParams

    ///
    /// отмечаем параметры которые участвуют в вычислении `token`
    public var tokenParamsKey: Set<String> = [
        PaymentFinishRequestData.CodingKeys.paymentId.rawValue,
        PaymentFinishRequestData.CodingKeys.cardData.rawValue,
        PaymentFinishRequestData.CodingKeys.encryptedPaymentData.rawValue,
        PaymentFinishRequestData.CodingKeys.sendEmail.rawValue,
        PaymentFinishRequestData.CodingKeys.infoEmail.rawValue,
        PaymentFinishRequestData.CodingKeys.ipAddress.rawValue,
        PaymentFinishRequestData.CodingKeys.source.rawValue,
        PaymentFinishRequestData.CodingKeys.route.rawValue,
    ]

    ///
    /// - Parameter data: `PaymentFinishRequestData`
    public init(data: PaymentFinishRequestData) {
        parameters = [:]
        parameters?.updateValue(data.paymentId, forKey: PaymentFinishRequestData.CodingKeys.paymentId.rawValue)

        if let value = data.sendEmail {
            parameters?.updateValue(value, forKey: PaymentFinishRequestData.CodingKeys.sendEmail.rawValue)
        }

        if let value = data.infoEmail {
            parameters?.updateValue(value, forKey: PaymentFinishRequestData.CodingKeys.infoEmail.rawValue)
        }

        if let ip = data.ipAddress {
            parameters?.updateValue(ip, forKey: PaymentFinishRequestData.CodingKeys.ipAddress.rawValue)
        }

        if let deviceInfo = data.deviceInfo, let value = try? deviceInfo.encode2JSONObject() {
            parameters?.updateValue(value, forKey: PaymentFinishRequestData.CodingKeys.deviceInfo.rawValue)
        }

        if let source = data.source {
            parameters?.updateValue(source, forKey: PaymentFinishRequestData.CodingKeys.source.rawValue)
        }

        if let route = data.route {
            parameters?.updateValue(route, forKey: PaymentFinishRequestData.CodingKeys.route.rawValue)
        }

        switch data.paymentSource {
        case let .cardNumber(number, expDate, cvv):
            let value = "\(PaymentSourceData.CodingKeys.cardNumber.rawValue)=\(number);\(PaymentSourceData.CodingKeys.cardExpDate.rawValue)=\(expDate);\(PaymentSourceData.CodingKeys.cardCVV.rawValue)=\(cvv)"
            parameters?.updateValue(value, forKey: PaymentFinishRequestData.CodingKeys.cardData.rawValue)

        case let .savedCard(cardId, cvv):
            var value = ""
            if let cardCVV = cvv { value.append("\(PaymentSourceData.CodingKeys.cardCVV.rawValue)=\(cardCVV);") }
            value.append("\(PaymentSourceData.CodingKeys.savedCardId.rawValue)=\(cardId)")
            parameters?.updateValue(value, forKey: PaymentFinishRequestData.CodingKeys.cardData.rawValue)

        case let .paymentData(token):
            parameters?.updateValue(token, forKey: PaymentFinishRequestData.CodingKeys.encryptedPaymentData.rawValue)

        default:
            break
        }
    }
} // PaymentFinishRequest

public struct Confirmation3DS2AppBasedData: Codable {
    public let acsSignedContent: String
    public let acsTransId: String
    public let tdsServerTransId: String
    public let acsRefNumber: String

    enum CodingKeys: String, CodingKey {
        case acsSignedContent = "AcsSignedContent"
        case acsTransId = "AcsTransId"
        case tdsServerTransId = "TdsServerTransId"
        case acsRefNumber = "AcsReferenceNumber"
    }
}
