import Foundation
import XCTest
@testable import WeBirr

#if os(Linux)
import Glibc
#else
import Darwin
#endif

final class WeBirrTests: XCTestCase {
    private let exampleCursor = "20251231"

    func testPreferredConstructorSetsBillMerchantIdBeforeSending() {
        let session = MockURLSession()
        let api = testClient(session: session)
        var bill = sampleBill()
        bill.merchantID = "merchant-on-bill"

        let _: ApiResponse<String> = waitForResponse { done in
            api.createBillAsync(bill: bill, callBack: done)
        }

        let body = decodeBody(session.requests[0])
        XCTAssertEqual(body["merchantID"] as? String, "merchant-from-client")
    }

    func testEmptyMerchantIdOverwritesExistingBillMerchantId() {
        let session = MockURLSession()
        let api = emptyMerchantTestClient(session: session)
        var bill = sampleBill()
        bill.merchantID = "merchant-on-bill"

        let _: ApiResponse<String> = waitForResponse { done in
            api.createBillAsync(bill: bill, callBack: done)
        }

        let body = decodeBody(session.requests[0])
        XCTAssertEqual(body["merchantID"] as? String, "")
    }

    func testInjectedURLSessionIsUsedForRequests() {
        let session = MockURLSession()
        let api = testClient(session: session)

        let response: ApiResponse<String> = waitForResponse { done in
            api.deleteBillAsync(paymentCode: "123 456 789", callBack: done)
        }

        XCTAssertEqual(response.res, "OK")
        XCTAssertEqual(session.requests.count, 1)
        XCTAssertEqual(query(session.requests[0])["merchant_id"], "merchant-from-client")
    }

    func testTestEnvDefaultsToApiWebirrDev() {
        unsetenv("GATEWAY_URL")
        let session = MockURLSession()
        let api = testClient(session: session)

        let _: ApiResponse<String> = waitForResponse { done in
            api.deleteBillAsync(paymentCode: "123 456 789", callBack: done)
        }

        XCTAssertEqual(session.requests[0].url?.scheme, "https")
        XCTAssertEqual(session.requests[0].url?.host, "api.webirr.dev")
        XCTAssertNil(session.requests[0].url?.port)
    }

    func testGatewayUrlOverridesTestEnvOnly() {
        setenv("GATEWAY_URL", "http://127.0.0.1:9999/", 1)
        defer { unsetenv("GATEWAY_URL") }

        let testSession = MockURLSession()
        let testApi = testClient(session: testSession)
        let _: ApiResponse<String> = waitForResponse { done in
            testApi.deleteBillAsync(paymentCode: "123 456 789", callBack: done)
        }

        XCTAssertEqual(testSession.requests[0].url?.scheme, "http")
        XCTAssertEqual(testSession.requests[0].url?.host, "127.0.0.1")
        XCTAssertEqual(testSession.requests[0].url?.port, 9999)

        let prodSession = MockURLSession()
        let prodApi = WeBirrClient(
            merchantId: "merchant-from-client",
            apiKey: "api-key",
            isTestEnv: false,
            urlSession: prodSession
        )
        let _: ApiResponse<String> = waitForResponse { done in
            prodApi.deleteBillAsync(paymentCode: "123 456 789", callBack: done)
        }

        XCTAssertEqual(prodSession.requests[0].url?.scheme, "https")
        XCTAssertEqual(prodSession.requests[0].url?.host, "api.webirr.net")
        XCTAssertEqual(prodSession.requests[0].url?.port, 8080)
    }

    func testEndpointRequestsIncludeMerchantIdWhenConfigured() {
        for endpoint in endpointCalls() {
            let session = MockURLSession()
            let api = testClient(session: session)

            waitForEndpoint(endpoint, api: api)

            let request = session.requests[0]
            let requestQuery = query(request)
            XCTAssertEqual(request.httpMethod, endpoint.method, endpoint.name)
            XCTAssertEqual(request.url?.path, endpoint.path, endpoint.name)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json", endpoint.name)
            XCTAssertEqual(requestQuery["api_key"], "api-key", endpoint.name)
            XCTAssertEqual(requestQuery["merchant_id"], "merchant-from-client", endpoint.name)
            for (key, value) in endpoint.expectedQuery {
                XCTAssertEqual(requestQuery[key], value, endpoint.name)
            }
        }
    }

    func testEndpointRequestsIncludeEmptyMerchantIdWhenClientMerchantIdIsEmpty() {
        for endpoint in endpointCalls() {
            let session = MockURLSession()
            let api = emptyMerchantTestClient(session: session)

            waitForEndpoint(endpoint, api: api)

            XCTAssertEqual(query(session.requests[0])["merchant_id"], "", endpoint.name)
        }
    }

    func testBillDefaultsCustomerPhoneAndExtrasBeforeSending() throws {
        let bill = Bill(
            customerCode: "cc01",
            customerName: "Elias Haileselassie",
            billReference: "swift/2021/125",
            time: "2021-07-22 22:14",
            description: "hotel booking",
            amount: "270.90"
        )

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(bill)) as? [String: Any]
        XCTAssertEqual(json?["customerPhone"] as? String, "")
        XCTAssertEqual(json?["extras"] as? [String: String], [:])
    }

    func testBillKeepsPopulatedExtrasAsAnObject() throws {
        let bill = Bill(
            customerCode: "cc01",
            customerName: "Elias Haileselassie",
            billReference: "swift/2021/125",
            time: "2021-07-22 22:14",
            description: "hotel booking",
            amount: "270.90",
            extras: ["invoiceNo": "INV-001", "branch": "main"]
        )

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(bill)) as? [String: Any]
        XCTAssertEqual(json?["extras"] as? [String: String], ["invoiceNo": "INV-001", "branch": "main"])
    }

    func testPaymentDateIsPreferredWhileLegacyTimeAliasRemainsAvailable() throws {
        let data = jsonData([
            "paymentDate": "2025-01-01 10:00:00",
            "time": "2025-01-01 10:00:00"
        ])

        var detail = try JSONDecoder().decode(PaymentDetail.self, from: data)

        XCTAssertEqual(detail.paymentDate, "2025-01-01 10:00:00")
        XCTAssertEqual(detail.time, detail.paymentDate)
        detail.time = "2025-01-01 11:00:00"
        XCTAssertEqual(detail.paymentDate, "2025-01-01 11:00:00")
    }

    func testResponseDTOsDeserializeBillPaymentBulkPaymentAndStats() throws {
        let bill = try JSONDecoder().decode(BillResponse.self, from: jsonData(billResponseJson()))
        XCTAssertEqual(bill.wbcCode, "123 456 789")
        XCTAssertEqual(bill.paymentStatus, 0)
        XCTAssertEqual(bill.customerPhone, "0911000000")

        let payment = try JSONDecoder().decode(Payment.self, from: jsonData(paymentStatusJson()))
        XCTAssertTrue(payment.isPaid)
        XCTAssertEqual(payment.data?.paymentDate, "2025-01-01 10:00:00")

        let bulkPayment = try JSONDecoder().decode(PaymentResponse.self, from: jsonData(paymentResponseJson()))
        XCTAssertTrue(bulkPayment.isReversed)
        XCTAssertEqual(bulkPayment.updateTimeStamp, "20250101100100000001")

        let stat = try JSONDecoder().decode(Stat.self, from: jsonData([
            "nBills": 2,
            "nBillsPaid": 1,
            "nBillsUnpaid": 1,
            "amountBills": "548.00",
            "amountPaid": "270.00",
            "amountUnpaid": "278.00"
        ]))
        XCTAssertEqual(stat.nBills, 2)
        XCTAssertEqual(stat.amountBills, 548)

        let bank = try JSONDecoder().decode(SupportedBank.self, from: jsonData([
            "bankID": "cbe_mobile",
            "name": "CBE Mobile Banking"
        ]))
        XCTAssertEqual(bank.bankID, "cbe_mobile")
        XCTAssertEqual(bank.name, "CBE Mobile Banking")
    }

    func testAllEndpointsReturnAPIErrorPayload() {
        for endpoint in endpointCalls() {
            let session = MockURLSession(response: apiErrorData())
            let api = testClient(session: session)

            let response = waitForEndpoint(endpoint, api: api)

            XCTAssertEqual(response.error, "invalid api key", endpoint.name)
            XCTAssertEqual(response.errorCode, "ERROR_INVALID_API_KEY", endpoint.name)
        }
    }

    func testLiveTestEnvSmokeAllEndpoints() throws {
        let env = ProcessInfo.processInfo.environment
        let merchantId = env["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? ""
        let apiKey = env["WEBIRR_TEST_ENV_API_KEY"] ?? ""
        try XCTSkipIf(
            merchantId.isEmpty || apiKey.isEmpty,
            "WEBIRR_TEST_ENV_MERCHANT_ID and WEBIRR_TEST_ENV_API_KEY are required"
        )

        let api = WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)
        let billReference = "swift/test/\(UUID().uuidString)"
        var paymentCode = ""
        var billDeleted = false

        defer {
            if !paymentCode.isEmpty && !billDeleted {
                let _: ApiResponse<String> = waitForResponse { done in
                    api.deleteBillAsync(paymentCode: paymentCode, callBack: done)
                }
            }
        }

        let createResponse: ApiResponse<String> = waitForResponse { done in
            api.createBillAsync(bill: liveSampleBill(billReference), callBack: done)
        }
        assertNoApiError(createResponse, "createBill")
        paymentCode = createResponse.res ?? ""
        XCTAssertFalse(paymentCode.isEmpty)
        XCTAssertTrue(paymentCode.replacingOccurrences(of: " ", with: "").allSatisfy(\.isNumber))

        var updatedBill = liveSampleBill(billReference)
        updatedBill.amount = "278.00"
        let updateResponse: ApiResponse<String> = waitForResponse { done in
            api.updateBillAsync(bill: updatedBill, callBack: done)
        }
        assertNoApiError(updateResponse, "updateBill")
        XCTAssertEqual(updateResponse.res?.lowercased(), "ok")

        let statusResponse: ApiResponse<Payment> = waitForResponse { done in
            api.getPaymentStatusAsync(paymentCode: paymentCode, callBack: done)
        }
        assertNoApiError(statusResponse, "getPaymentStatus")
        XCTAssertEqual(statusResponse.res?.status, 0)
        XCTAssertNil(statusResponse.res?.data)

        let byReference: ApiResponse<BillResponse> = waitForResponse { done in
            api.getBillByReferenceAsync(billReference: billReference, callBack: done)
        }
        assertNoApiError(byReference, "getBillByReference")
        assertCreatedBill(byReference.res, billReference, merchantId, paymentCode)
        XCTAssertEqual(Double(byReference.res?.amount ?? "") ?? 0, 278, accuracy: 0.01)
        let listCursor = cursorBefore(byReference.res?.updateTimeStamp ?? "", fallback: exampleCursor)

        let byPaymentCode: ApiResponse<BillResponse> = waitForResponse { done in
            api.getBillByPaymentCodeAsync(paymentCode: paymentCode, callBack: done)
        }
        assertNoApiError(byPaymentCode, "getBillByPaymentCode")
        assertCreatedBill(byPaymentCode.res, billReference, merchantId, paymentCode)

        let bills: ApiResponse<[BillResponse]> = waitForResponse { done in
            api.getBillsAsync(paymentStatus: 0, lastTimeStamp: listCursor, limit: 100, callBack: done)
        }
        assertNoApiError(bills, "getBills")
        let foundBill = bills.res?.first {
            $0.billReference.lowercased() == billReference.lowercased()
        }
        assertCreatedBill(foundBill, billReference, merchantId, paymentCode)

        let payments: ApiResponse<[PaymentResponse]> = waitForResponse { done in
            api.getPaymentsAsync(lastTimeStamp: exampleCursor, limit: 10, callBack: done)
        }
        assertNoApiError(payments, "getPayments")
        XCTAssertNotNil(payments.res)

        let stat: ApiResponse<Stat> = waitForResponse { done in
            api.getStatAsync(dateFrom: "2025-01-01", dateTo: "2030-01-31", callBack: done)
        }
        assertNoApiError(stat, "getStat")
        XCTAssertNotNil(stat.res)

        let supportedBanks: ApiResponse<[SupportedBank]> = waitForResponse { done in
            api.getSupportedBanksAsync(callBack: done)
        }
        assertNoApiError(supportedBanks, "getSupportedBanks")
        XCTAssertFalse(supportedBanks.res?.isEmpty ?? true)
        for bank in supportedBanks.res ?? [] {
            XCTAssertFalse(bank.bankID.isEmpty)
            XCTAssertFalse(bank.name.isEmpty)
        }

        let deleteResponse: ApiResponse<String> = waitForResponse { done in
            api.deleteBillAsync(paymentCode: paymentCode, callBack: done)
        }
        assertNoApiError(deleteResponse, "deleteBill")
        XCTAssertEqual(deleteResponse.res?.lowercased(), "ok")
        billDeleted = true

        let deletedLookup: ApiResponse<BillResponse> = waitForResponse { done in
            api.getBillByReferenceAsync(billReference: billReference, callBack: done)
        }
        XCTAssertNotNil(deletedLookup.error)
    }

    private func testClient(session: MockURLSession) -> WeBirrClient {
        WeBirrClient(
            merchantId: "merchant-from-client",
            apiKey: "api-key",
            isTestEnv: true,
            urlSession: session
        )
    }

    private func emptyMerchantTestClient(session: MockURLSession) -> WeBirrClient {
        WeBirrClient(merchantId: "", apiKey: "api-key", isTestEnv: true, urlSession: session)
    }

    private func sampleBill() -> Bill {
        Bill(
            customerCode: "cc01",
            customerName: "Elias Haileselassie",
            billReference: "swift/2021/125",
            time: "2021-07-22 22:14",
            description: "hotel booking",
            amount: "270.90",
            merchantID: "x",
            customerPhone: "0911000000",
            extras: [:]
        )
    }

    private func liveSampleBill(_ billReference: String) -> Bill {
        Bill(
            customerCode: "cc01",
            customerName: "Elias Haileselassie",
            billReference: billReference,
            time: "2021-07-22 22:14",
            description: "hotel booking",
            amount: "270.90",
            customerPhone: "0911000000",
            extras: [:]
        )
    }

    private func waitForResponse<T: Codable>(
        _ operation: (@escaping (ApiResponse<T>) -> Void) -> Void
    ) -> ApiResponse<T> {
        let expectation = expectation(description: "response")
        var result: ApiResponse<T>?

        operation { response in
            result = response
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
        return result ?? ApiResponse(error: "test timeout")
    }

    @discardableResult
    private func waitForEndpoint(_ endpoint: EndpointCall, api: WeBirrClient) -> ApiResponse<String> {
        let expectation = expectation(description: endpoint.name)
        var response = ApiResponse<String>()

        endpoint.invoke(api) { endpointResponse in
            response = endpointResponse
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
        return response
    }

    private func endpointCalls() -> [EndpointCall] {
        [
            EndpointCall(
                name: "createBill",
                method: "POST",
                path: "/einvoice/api/bill",
                expectedQuery: [:],
                invoke: { api, done in
                    api.createBillAsync(bill: self.sampleBill()) { response in done(response.asStringResponse()) }
                }
            ),
            EndpointCall(
                name: "updateBill",
                method: "PUT",
                path: "/einvoice/api/bill",
                expectedQuery: [:],
                invoke: { api, done in
                    api.updateBillAsync(bill: self.sampleBill()) { response in done(response.asStringResponse()) }
                }
            ),
            EndpointCall(
                name: "deleteBill",
                method: "DELETE",
                path: "/einvoice/api/bill",
                expectedQuery: ["wbc_code": "123 456 789"],
                invoke: { api, done in
                    api.deleteBillAsync(paymentCode: "123 456 789", callBack: done)
                }
            ),
            EndpointCall(
                name: "getPaymentStatus",
                method: "GET",
                path: "/einvoice/api/paymentStatus",
                expectedQuery: ["wbc_code": "123 456 789"],
                invoke: { api, done in
                    api.getPaymentStatusAsync(paymentCode: "123 456 789") { response in done(response.asStringResponse()) }
                }
            ),
            EndpointCall(
                name: "getBillByReference",
                method: "GET",
                path: "/einvoice/api/bill",
                expectedQuery: ["bill_reference": "swift/unit/1"],
                invoke: { api, done in
                    api.getBillByReferenceAsync(billReference: "swift/unit/1") { response in done(response.asStringResponse()) }
                }
            ),
            EndpointCall(
                name: "getBillByPaymentCode",
                method: "GET",
                path: "/einvoice/api/bill",
                expectedQuery: ["wbc_code": "123 456 789"],
                invoke: { api, done in
                    api.getBillByPaymentCodeAsync(paymentCode: "123 456 789") { response in done(response.asStringResponse()) }
                }
            ),
            EndpointCall(
                name: "getBills",
                method: "GET",
                path: "/einvoice/api/bills",
                expectedQuery: [
                    "payment_status": "-1",
                    "last_timestamp": exampleCursor,
                    "limit": "10"
                ],
                invoke: { api, done in
                    api.getBillsAsync(paymentStatus: -1, lastTimeStamp: self.exampleCursor, limit: 10) { response in
                        done(response.asStringResponse())
                    }
                }
            ),
            EndpointCall(
                name: "getPayments",
                method: "GET",
                path: "/einvoice/api/payments",
                expectedQuery: [
                    "last_timestamp": exampleCursor,
                    "limit": "10"
                ],
                invoke: { api, done in
                    api.getPaymentsAsync(lastTimeStamp: self.exampleCursor, limit: 10) { response in
                        done(response.asStringResponse())
                    }
                }
            ),
            EndpointCall(
                name: "getStat",
                method: "GET",
                path: "/merchant/stat",
                expectedQuery: [
                    "date_from": "2025-01-01",
                    "date_to": "2030-01-31"
                ],
                invoke: { api, done in
                    api.getStatAsync(dateFrom: "2025-01-01", dateTo: "2030-01-31") { response in
                        done(response.asStringResponse())
                    }
                }
            ),
            EndpointCall(
                name: "getSupportedBanks",
                method: "GET",
                path: "/einvoice/api/banks",
                expectedQuery: [:],
                invoke: { api, done in
                    api.getSupportedBanksAsync { response in done(response.asStringResponse()) }
                }
            )
        ]
    }

    private func decodeBody(_ request: URLRequest) -> [String: Any] {
        guard let body = request.httpBody else {
            return [:]
        }
        return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    private func query(_ request: URLRequest) -> [String: String] {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
    }

    private func assertNoApiError<T>(_ response: ApiResponse<T>, _ operation: String) {
        if response.error != nil {
            XCTFail("\(operation) failed: \(response.error ?? "") \(response.errorCode ?? "")")
        }
    }

    private func assertCreatedBill(
        _ bill: BillResponse?,
        _ billReference: String,
        _ merchantId: String,
        _ paymentCode: String
    ) {
        XCTAssertEqual(bill?.billReference.lowercased(), billReference.lowercased())
        XCTAssertEqual(bill?.customerCode.lowercased(), "cc01")
        XCTAssertEqual(bill?.customerName, "Elias Haileselassie")
        XCTAssertEqual(bill?.customerPhone, "0911000000")
        XCTAssertEqual(bill?.description, "hotel booking")
        XCTAssertEqual(bill?.merchantID, merchantId)
        XCTAssertEqual(normalizePaymentCode(bill?.wbcCode ?? ""), normalizePaymentCode(paymentCode))
        XCTAssertFalse(bill?.updateTimeStamp.isEmpty ?? true)
    }

    private func normalizePaymentCode(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "")
    }

    private func cursorBefore(_ updateTimeStamp: String, fallback: String) -> String {
        guard !updateTimeStamp.isEmpty,
              updateTimeStamp.allSatisfy(\.isNumber) else {
            return fallback
        }

        var digits = Array(updateTimeStamp)
        for index in stride(from: digits.count - 1, through: 0, by: -1) {
            if let value = digits[index].wholeNumberValue, value > 0 {
                digits[index] = Character(String(value - 1))
                return String(digits)
            }
            digits[index] = "9"
        }

        return fallback
    }

    private func billResponseJson() -> [String: Any] {
        [
            "customerCode": "cc01",
            "customerName": "Elias Haileselassie",
            "customerPhone": "0911000000",
            "time": "2021-07-22 22:14",
            "description": "hotel booking",
            "amount": "270.90",
            "billReference": "swift/2021/125",
            "merchantID": "merchant-from-client",
            "extras": [:],
            "wbcCode": "123 456 789",
            "paymentStatus": 0,
            "updateTimeStamp": "20250101100000000001"
        ]
    }

    private func paymentStatusJson() -> [String: Any] {
        [
            "status": 2,
            "data": [
                "id": 1,
                "status": 2,
                "bankID": "cbe_birr",
                "paymentReference": "BANK-REF-1",
                "paymentDate": "2025-01-01 10:00:00",
                "confirmed": true,
                "confirmedTime": "2025-01-01 10:00:01",
                "amount": "270.90",
                "wbcCode": "123 456 789",
                "updateTimeStamp": "20250101100001000001"
            ]
        ]
    }

    private func paymentResponseJson() -> [String: Any] {
        [
            "status": 3,
            "id": 2,
            "bankID": "cbe_birr",
            "paymentReference": "BANK-REF-2",
            "paymentDate": "2025-01-01 10:01:00",
            "confirmed": true,
            "confirmedTime": "2025-01-01 10:01:01",
            "canceled": true,
            "canceledTime": "2025-01-01 10:02:00",
            "amount": "270.90",
            "wbcCode": "123 456 789",
            "updateTimeStamp": "20250101100100000001"
        ]
    }

    private func jsonData(_ value: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: value)
    }

    private func successData() -> Data {
        jsonData([
            "error": NSNull(),
            "errorCode": NSNull(),
            "res": "OK"
        ])
    }

    private func apiErrorData() -> Data {
        jsonData([
            "error": "invalid api key",
            "errorCode": "ERROR_INVALID_API_KEY",
            "res": NSNull()
        ])
    }
}

private struct EndpointCall {
    let name: String
    let method: String
    let path: String
    let expectedQuery: [String: String]
    let invoke: (WeBirrClient, @escaping (ApiResponse<String>) -> Void) -> Void
}

private final class MockURLSession: WeBirrURLSession {
    var requests: [URLRequest] = []
    private let response: Data

    init(response: Data? = nil) {
        if let response = response {
            self.response = response
        } else {
            self.response = try! JSONSerialization.data(withJSONObject: [
                "error": NSNull(),
                "errorCode": NSNull(),
                "res": "OK"
            ])
        }
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> WeBirrURLSessionDataTask {
        requests.append(request)
        return MockDataTask {
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            completionHandler(self.response, httpResponse, nil)
        }
    }
}

private final class MockDataTask: WeBirrURLSessionDataTask {
    private let onResume: () -> Void

    init(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    func resume() {
        onResume()
    }
}

private extension ApiResponse {
    func asStringResponse() -> ApiResponse<String> {
        ApiResponse<String>(error: error, errorCode: errorCode, res: nil)
    }
}
