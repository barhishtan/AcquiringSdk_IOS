//
//  BuyProductsViewController.swift
//  ASDKSample
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

import PassKit
import TinkoffASDKCore
import TinkoffASDKUI
import UIKit

// swiftlint:disable file_length
class BuyProductsViewController: UIViewController {

    enum TableViewCellType {
        case products
        /// открыть экран оплаты и перейти к оплате
        case pay
        /// оплатить с карты - выбрать карту из списка и сделать этот платеж родительским
        case payAndSaveAsParent
        /// оплатить
        case payRequrent
        /// оплатить с помощью `ApplePay`
        case payApplePay
        /// оплатить с помощью `Системы Быстрых Платежей`
        /// сгенерировать QR-код для оплаты
        case paySbpQrCode
        /// оплатить с помощью `Системы Быстрых Платежей`
        /// сгенерировать url для оплаты
        case paySbpUrl
    }

    private var tableViewCells: [TableViewCellType] = []

    var products: [Product] = []
    var sdk: AcquiringUISDK!
    var customerKey: String!
    var customerEmail: String?
    weak var scaner: AcquiringScanerProtocol?

    lazy var paymentApplePayConfiguration = AcquiringUISDK.ApplePayConfiguration()
    var paymentCardId: PaymentCard?
    var paymentCardParentPaymentId: PaymentCard?

    private var rebuidIdCards: [PaymentCard]?

    @IBOutlet var tableView: UITableView!
    @IBOutlet var buttonAddToCart: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = Loc.Title.paymentSource

        tableView.registerCells(types: [ButtonTableViewCell.self])
        tableView.delegate = self
        tableView.dataSource = self

        sdk.setupCardListDataProvider(for: customerKey, statusListener: self)
        try? sdk.cardListReloadData()
        sdk.addCardNeedSetCheckTypeHandler = {
            AppSetting.shared.addCardChekType
        }

        if products.count > 1 {
            buttonAddToCart.isEnabled = false
            buttonAddToCart.title = nil
        }

        updateTableViewCells()
    }

    @IBAction func addToCart(_ sender: Any) {
        if let product = products.first {
            CartDataProvider.shared.addProduct(product)
        }
    }

    func updateTableViewCells() {
        tableViewCells = [
            .products,
            .pay,
            .payAndSaveAsParent,
            .payRequrent,
        ]

        tableViewCells.append(.payApplePay)
        tableViewCells.append(.paySbpQrCode)
        tableViewCells.append(.paySbpUrl)
    }

    private func selectRebuildCard() {
        guard let viewController = UIStoryboard(name: "Main", bundle: Bundle.main)
            .instantiateViewController(withIdentifier: "SelectRebuildCardViewController") as? SelectRebuildCardViewController,
            let cards: [PaymentCard] = rebuidIdCards,
            !cards.isEmpty else {
            return
        }

        viewController.cards = cards
        viewController.onSelectCard = { card in
            self.paymentCardParentPaymentId = card
            if let index = self.tableViewCells.firstIndex(of: .payRequrent) {
                self.tableView.beginUpdates()
                self.tableView.reloadSections(IndexSet(integer: index), with: .fade)
                self.tableView.endUpdates()
            }
        }

        present(UINavigationController(rootViewController: viewController), animated: true, completion: nil)
    }

    private func productsAmount() -> Double {
        var amount: Double = 0

        products.forEach { product in
            amount += product.price.doubleValue
        }

        return amount
    }

    private func createPaymentData() -> PaymentInitData {
        let amount = productsAmount()
        let randomOrderId = String(Int64.random(in: 1000 ... 10000))
        var paymentData = PaymentInitData(amount: NSDecimalNumber(value: amount), orderId: randomOrderId, customerKey: customerKey)
        paymentData.description = "Краткое описние товара"

        var receiptItems: [Item] = []
        products.forEach { product in
            let item = Item(
                amount: product.price.int64Value * 100,
                price: product.price.int64Value * 100,
                name: product.name,
                tax: .vat10
            )
            receiptItems.append(item)
        }

        paymentData.receipt = Receipt(
            shopCode: nil,
            email: customerEmail,
            taxation: .osn,
            phone: "+79876543210",
            items: receiptItems,
            agentData: nil,
            supplierInfo: nil,
            customer: nil,
            customerInn: nil
        )

        return paymentData
    }

    private func acquiringViewConfiguration() -> AcquiringViewConfiguration {
        let viewConfigration = AcquiringViewConfiguration()
        viewConfigration.scaner = scaner
        viewConfigration.tinkoffPayButtonStyle = TinkoffPayButton.DynamicStyle(lightStyle: .whiteBordered, darkStyle: .blackBordered)

        viewConfigration.fields = []
        // InfoFields.amount
        let title = NSAttributedString(
            string: Loc.Title.paymeny,

            attributes: [.font: UIFont.boldSystemFont(ofSize: 22)]
        )
        // swiftlint:disable:next compiler_protocol_init
        let amountString = Utils.formatAmount(NSDecimalNumber(floatLiteral: productsAmount()))

        let amountTitle = NSAttributedString(
            string: "\(Loc.Text.totalAmount) \(amountString)",

            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        // fields.append
        viewConfigration.fields.append(AcquiringViewConfiguration.InfoFields.amount(title: title, amount: amountTitle))

        // InfoFields.detail
        let productsDetatils = NSMutableAttributedString()
        productsDetatils.append(NSAttributedString(string: "Книги\n", attributes: [.font: UIFont.systemFont(ofSize: 17)]))

        let productsDetails = products.map { $0.name }.joined(separator: ", ")
        let detailsFieldTitle = NSAttributedString(
            string: productsDetails,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor(red: 0.573, green: 0.6, blue: 0.635, alpha: 1),
            ]
        )
        viewConfigration.fields.append(AcquiringViewConfiguration.InfoFields.detail(title: detailsFieldTitle))

        if AppSetting.shared.showEmailField {
            let emailField = AcquiringViewConfiguration.InfoFields.email(
                value: nil,
                placeholder: Loc.Plaseholder.email
            )
            viewConfigration.fields.append(emailField)
        }

        viewConfigration.featuresOptions.fpsEnabled = AppSetting.shared.paySBP
        viewConfigration.featuresOptions.tinkoffPayEnabled = AppSetting.shared.tinkoffPay

        viewConfigration.viewTitle = Loc.Title.pay
        viewConfigration.localizableInfo = AcquiringViewConfiguration.LocalizableInfo(lang: AppSetting.shared.languageId)

        return viewConfigration
    }

    private func responseReviewing(_ response: Result<PaymentStatusResponse, Error>) {
        switch response {
        case let .success(result):
            var message = Loc.Text.paymentStatusAmount
            message.append(" \(Utils.formatAmount(result.amount)) ")

            if result.status == .cancelled {
                message.append(Loc.Text.paymentStatusCancel)
            } else {
                message.append(" ")
                message.append(Loc.Text.paymentStatusSuccess)
                message.append("\npaymentId = \(result.paymentId)")
            }

            if AppSetting.shared.acquiring {
                sdk.presentAlertView(on: self, title: message, icon: result.status == .cancelled ? .error : .success)
            } else {
                let alertView = UIAlertController(title: "Tinkoff Acquaring", message: message, preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: Loc.Button.ok, style: .default, handler: nil))
                present(alertView, animated: true, completion: nil)
            }

        case let .failure(error):
            if AppSetting.shared.acquiring {
                sdk.presentAlertView(on: self, title: error.localizedDescription, icon: .error)
            } else {
                let alertView = UIAlertController(title: "Tinkoff Acquaring", message: error.localizedDescription, preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: Loc.Button.ok, style: .default, handler: nil))
                present(alertView, animated: true, completion: nil)
            }
        }
    }

    private func presentPaymentView(paymentData: PaymentInitData, viewConfigration: AcquiringViewConfiguration) {
        sdk.presentPaymentView(
            on: self,
            acquiringPaymentStageConfiguration: AcquiringPaymentStageConfiguration(
                paymentStage: .`init`(paymentData: paymentData)
            ),
            configuration: viewConfigration,
            tinkoffPayDelegate: nil
        ) { [weak self] response in
            self?.responseReviewing(response)
        }
    }

    func pay() {
        presentPaymentView(paymentData: createPaymentData(), viewConfigration: acquiringViewConfiguration())
    }

    func pay(_ complete: @escaping (() -> Void)) {
        sdk.pay(
            on: self,
            initPaymentData: createPaymentData(),
            cardRequisites: PaymentSourceData.cardNumber(number: "!!!номер карты!!!", expDate: "1120", cvv: "111"),
            infoEmail: nil,
            configuration: acquiringViewConfiguration()
        ) { [weak self] response in
            complete()
            self?.responseReviewing(response)
        }
    }

    func payByApplePay() {

        let paymentData = createPaymentData()

        let request = PKPaymentRequest()
        request.merchantIdentifier = paymentApplePayConfiguration.merchantIdentifier
        request.supportedNetworks = paymentApplePayConfiguration.supportedNetworks
        request.merchantCapabilities = paymentApplePayConfiguration.capabilties
        request.countryCode = paymentApplePayConfiguration.countryCode
        request.currencyCode = paymentApplePayConfiguration.currencyCode
        request.shippingContact = paymentApplePayConfiguration.shippingContact
        request.billingContact = paymentApplePayConfiguration.billingContact

        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: paymentData.description ?? "",
                amount: NSDecimalNumber(value: Double(paymentData.amount) / Double(100.0))
            ),
        ]

        guard let viewController = PKPaymentAuthorizationViewController(paymentRequest: request) else {
            return
        }

        viewController.delegate = self

        present(viewController, animated: true, completion: nil)
    }

    func payAndSaveAsParent() {
        var paymentData = createPaymentData()
        paymentData.savingAsParentPayment = true

        presentPaymentView(paymentData: paymentData, viewConfigration: acquiringViewConfiguration())
    }

    func charge(_ complete: @escaping (() -> Void)) {
        if let parentPaymentId = paymentCardParentPaymentId?.parentPaymentId {
            sdk.presentPaymentView(
                on: self,
                paymentData: createPaymentData(),
                parentPatmentId: parentPaymentId,
                configuration: acquiringViewConfiguration()
            ) { [weak self] response in
                complete()
                self?.responseReviewing(response)
            }
        }
    }

    func generateSbpQrImage() {
        sdk.presentPaymentSbpQrImage(
            on: self,
            paymentData: createPaymentData(),
            configuration: acquiringViewConfiguration()
        ) { [weak self] response in
            self?.responseReviewing(response)
        }
    }

    func generateSbpUrl() {
        let acquiringPaymentStageConfiguration = AcquiringPaymentStageConfiguration(
            paymentStage: .`init`(paymentData: createPaymentData())
        )
        let viewController = sdk.urlSBPPaymentViewController(
            acquiringPaymentStageConfiguration: acquiringPaymentStageConfiguration,
            configuration: acquiringViewConfiguration()
        )
        present(viewController, animated: true, completion: nil)
    }
}

extension BuyProductsViewController: CardListDataSourceStatusListener {

    // MARK: CardListDataSourceStatusListener

    func cardsListUpdated(_ status: FetchStatus<[PaymentCard]>) {
        switch status {
        case let .object(cards):
            if paymentCardId == nil {
                paymentCardId = cards.first
            }

            rebuidIdCards = cards.filter { card -> Bool in
                card.parentPaymentId != nil
            }

            if paymentCardParentPaymentId == nil {
                paymentCardParentPaymentId = cards.last(where: { card -> Bool in
                    card.parentPaymentId != nil
                })
            }

        default:
            break
        }

        updateTableViewCells()
        tableView.reloadData()
    }
}

extension BuyProductsViewController: UITableViewDataSource {

    // MARK: UITableViewDataSource

    private func yellowButtonColor() -> UIColor {
        return UIColor(red: 1, green: 0.867, blue: 0.176, alpha: 1)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewCells.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var result = 1

        switch tableViewCells[section] {
        case .products:
            result = products.count

        case .payRequrent:
            if rebuidIdCards?.count ?? 0 > 0 {
                result = 2
            }

        default:
            result = 1
        }

        return result
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableViewCells[indexPath.section] {
        case .products:
            let cell = tableView.defaultCell()
            let product = products[indexPath.row]
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.text = product.name
            cell.detailTextLabel?.text = Utils.formatAmount(product.price)
            return cell

        case .pay:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                cell.button.setTitle(Loc.Button.pay, for: .normal)
                cell.button.isEnabled = true
                cell.button.backgroundColor = yellowButtonColor()
                cell.button.setImage(nil, for: .normal)
                // открыть экран оплаты и оплатить
                cell.onButtonTouch = { [weak self] in
                    self?.pay()
                }
                // оплатить в один клик, не показывая экран оплаты
                // cell.onButtonTouch = { [weak self, weak cell] in
                //	cell?.activityIndicator.startAnimating()
                //	cell?.button.isEnabled = false
                //	self?.pay {
                //		cell?.activityIndicator.stopAnimating()
                //		cell?.button.isEnabled = true
                //	}
                // }

                return cell
            }

        case .payAndSaveAsParent:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                cell.button.setTitle(Loc.Button.pay, for: .normal)
                cell.button.isEnabled = true
                cell.button.backgroundColor = yellowButtonColor()
                cell.button.setImage(nil, for: .normal)
                cell.onButtonTouch = { [weak self] in
                    self?.payAndSaveAsParent()
                }

                return cell
            }

        case .payRequrent:
            if indexPath.row == 0 {
                if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                    cell.button.setTitle(Loc.Button.paymentTryAgain, for: .normal)
                    cell.button.backgroundColor = yellowButtonColor()
                    cell.button.setImage(nil, for: .normal)
                    if let card = paymentCardParentPaymentId {
                        cell.button.isEnabled = (card.parentPaymentId != nil)
                    } else {
                        cell.button.isEnabled = false
                    }

                    cell.onButtonTouch = { [weak self, weak cell] in
                        cell?.activityIndicator.startAnimating()
                        cell?.button.isEnabled = false
                        self?.charge {
                            cell?.activityIndicator.stopAnimating()
                            cell?.button.isEnabled = true
                        }
                    }

                    return cell
                }
            } else {
                let cell = tableView.defaultCell()
                cell.accessoryType = .disclosureIndicator
                cell.textLabel?.text = Loc.Button.selectAnotherCard
                cell.detailTextLabel?.text = nil
                return cell
            }

        case .payApplePay:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                cell.button.setTitle(nil, for: .normal)
                cell.button.backgroundColor = .clear
                cell.button.setImage(Asset.buttonApplePay.image, for: .normal)
                cell.button.isEnabled = sdk.canMakePaymentsApplePay(with: paymentApplePayConfiguration)

                cell.onButtonTouch = { [weak self] in
                    self?.payByApplePay()
                }

                return cell
            }

        case .paySbpQrCode:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                cell.button.setTitle(nil, for: .normal)
                cell.button.backgroundColor = .clear
                cell.button.isEnabled = sdk.canMakePaymentsSBP()
                cell.button.setImage(Asset.logoSbp.image, for: .normal)
                cell.onButtonTouch = { [weak self] in
                    self?.generateSbpQrImage()
                }

                return cell
            }

        case .paySbpUrl:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.nibName) as? ButtonTableViewCell {
                cell.button.setTitle(nil, for: .normal)
                cell.button.backgroundColor = .clear
                cell.button.isEnabled = sdk.canMakePaymentsSBP()
                cell.button.setImage(Asset.logoSbp.image, for: .normal)
                cell.onButtonTouch = { [weak self] in
                    self?.generateSbpUrl()
                }

                return cell
            }
        }

        return tableView.defaultCell()
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch tableViewCells[section] {
        case .products:
            return Loc.Title.goods

        case .pay:
            return Loc.Title.paymeny

        case .payAndSaveAsParent:
            return Loc.Title.payAndSaveAsParent

        case .payRequrent:
            return Loc.Title.paymentTryAgain

        case .payApplePay:
            return Loc.Title.payByApplePay

        case .paySbpUrl, .paySbpQrCode:
            return Loc.Title.payBySBP
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch tableViewCells[section] {
        case .products:
            return "сумма: \(Utils.formatAmount(NSDecimalNumber(value: productsAmount())))"

        case .pay:
            let cardsCount = (try? sdk.cardListNumberOfCards()) ?? 0
            if cardsCount > 0 {
                return "открыть платежную форму и перейти к оплате товара, доступно \(cardsCount) сохраненных карт"
            }

            return "открыть платежную форму и перейти к оплате товара"
        case .payAndSaveAsParent:
            let cardsCount = (try? sdk.cardListNumberOfCards()) ?? 0
            if cardsCount > 0 {
                return "открыть платежную форму и перейти к оплате товара. При удачной оплате этот платеж сохраниться как родительский. Доступно \(cardsCount) сохраненных карт"
            }

            return "оплатить и сделать этот платеж родительским"
        case .payRequrent:
            if let card = paymentCardParentPaymentId, let parentPaymentId = card.parentPaymentId {
                return "оплатить с карты \(card.pan) \(card.expDateFormat() ?? ""), используя родительский платеж \(parentPaymentId)"
            }

            return "нет доступных родительских платежей"

        case .payApplePay:
            if sdk.canMakePaymentsApplePay(with: paymentApplePayConfiguration) {
                return "оплатить с помощью ApplePay"
            }

            return "оплата с помощью ApplePay недоступна"

        case .paySbpUrl:
            if sdk.canMakePaymentsSBP() {
                return "сгенерировать url и открыть диалог для выбора приложения для оплаты"
            }

            return "оплата недоступна"

        case .paySbpQrCode:
            if sdk.canMakePaymentsSBP() {
                return "сгенерировать QR-код для оплаты и показать его на экране, для сканирования и оплаты другим смартфоном"
            }

            return "оплата недоступна"
        }
    }
}

extension BuyProductsViewController: UITableViewDelegate {

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch tableViewCells[indexPath.section] {
        case .payRequrent:
            selectRebuildCard()

        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {}
}

extension BuyProductsViewController: PKPaymentAuthorizationViewControllerDelegate {

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        let initData = createPaymentData()
        sdk.performPaymentWithApplePay(
            paymentData: initData,
            paymentToken: payment.token,
            acquiringConfiguration: AcquiringConfiguration(paymentStage: .none)
        ) { result in
            switch result {
            case let .failure(error):
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
            case .success:
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            }
        }
    }
}
