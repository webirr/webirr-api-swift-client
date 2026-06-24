import Foundation

public protocol WeBirrURLSessionDataTask {
    func resume()
}

extension URLSessionDataTask: WeBirrURLSessionDataTask {}

public protocol WeBirrURLSession {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> WeBirrURLSessionDataTask
}

extension URLSession: WeBirrURLSession {
    public func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> WeBirrURLSessionDataTask {
        dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask
    }
}

/**
 * A WeBirrClient instance object can be used to
 * Create, Update or Delete a Bill at WeBirr Servers and also to
 * Get bill/payment information.
 * It is a wrapper for the REST Web Service API.
 */
public final class WeBirrClient {
    private static let testBaseAddress = "https://api.webirr.dev"
    private static let prodBaseAddress = "https://api.webirr.net:8080"

    private let apiKey: String
    private let merchantId: String
    private let baseAddress: String
    private let urlSession: WeBirrURLSession

    public init(
        merchantId: String,
        apiKey: String,
        isTestEnv: Bool,
        urlSession: WeBirrURLSession = URLSession.shared
    ) {
        self.apiKey = apiKey
        self.merchantId = merchantId
        self.baseAddress = Self.resolveBaseAddress(isTestEnv: isTestEnv)
        self.urlSession = urlSession
    }

    private static func resolveBaseAddress(isTestEnv: Bool) -> String {
        guard isTestEnv else {
            return prodBaseAddress
        }

        guard let gatewayURL = ProcessInfo.processInfo.environment["GATEWAY_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !gatewayURL.isEmpty else {
            return testBaseAddress
        }

        let normalized = gatewayURL.trimmingTrailingSlashes()
        return normalized.isEmpty ? testBaseAddress : normalized
    }

    /**
     * Create a new bill at WeBirr Servers.
     * Check if(ApiResponse.error == nil) to see if there are errors.
     * ApiResponse.res will have the value of the returned PaymentCode on success.
     */
    public func createBillAsync(bill: Bill, callBack: @escaping (ApiResponse<String>) -> Void) {
        request(.POST, path: "/einvoice/api/bill", body: prepareBill(bill), callBack: callBack)
    }

    /**
     * Update an existing bill at WeBirr Servers, if the bill is not paid yet.
     * The billReference has to be the same as the original bill created.
     * Check if(ApiResponse.error == nil) to see if there are errors.
     * ApiResponse.res will have the value of "OK" on success.
     */
    public func updateBillAsync(bill: Bill, callBack: @escaping (ApiResponse<String>) -> Void) {
        request(.PUT, path: "/einvoice/api/bill", body: prepareBill(bill), callBack: callBack)
    }

    /**
     * Delete an existing bill at WeBirr Servers, if the bill is not paid yet.
     * paymentCode is the number that WeBirr Payment Gateway returns on createBillAsync.
     */
    public func deleteBillAsync(paymentCode: String, callBack: @escaping (ApiResponse<String>) -> Void) {
        request(
            .DELETE,
            path: "/einvoice/api/bill",
            query: ["wbc_code": paymentCode],
            callBack: callBack
        )
    }

    /**
     * Get Payment Status of a bill from WeBirr Servers.
     */
    public func getPaymentStatusAsync(paymentCode: String, callBack: @escaping (ApiResponse<Payment>) -> Void) {
        request(
            .GET,
            path: "/einvoice/api/paymentStatus",
            query: ["wbc_code": paymentCode],
            callBack: callBack
        )
    }

    public func getBillByReferenceAsync(
        billReference: String,
        callBack: @escaping (ApiResponse<BillResponse>) -> Void
    ) {
        request(
            .GET,
            path: "/einvoice/api/bill",
            query: ["bill_reference": billReference],
            callBack: callBack
        )
    }

    public func getBillByPaymentCodeAsync(
        paymentCode: String,
        callBack: @escaping (ApiResponse<BillResponse>) -> Void
    ) {
        request(
            .GET,
            path: "/einvoice/api/bill",
            query: ["wbc_code": paymentCode],
            callBack: callBack
        )
    }

    public func getBillsAsync(
        paymentStatus: Int = -1,
        lastTimeStamp: String = "",
        limit: Int = 100,
        callBack: @escaping (ApiResponse<[BillResponse]>) -> Void
    ) {
        request(
            .GET,
            path: "/einvoice/api/bills",
            query: [
                "payment_status": String(paymentStatus),
                "last_timestamp": lastTimeStamp,
                "limit": String(limit)
            ],
            callBack: callBack
        )
    }

    public func getPaymentsAsync(
        lastTimeStamp: String = "",
        limit: Int = 100,
        callBack: @escaping (ApiResponse<[PaymentResponse]>) -> Void
    ) {
        request(
            .GET,
            path: "/einvoice/api/payments",
            query: [
                "last_timestamp": lastTimeStamp,
                "limit": String(limit)
            ],
            callBack: callBack
        )
    }

    public func getStatAsync(
        dateFrom: String,
        dateTo: String,
        callBack: @escaping (ApiResponse<Stat>) -> Void
    ) {
        request(
            .GET,
            path: "/merchant/stat",
            query: [
                "date_from": dateFrom,
                "date_to": dateTo
            ],
            callBack: callBack
        )
    }

    public func getSupportedBanksAsync(
        callBack: @escaping (ApiResponse<[SupportedBank]>) -> Void
    ) {
        request(
            .GET,
            path: "/einvoice/api/banks",
            callBack: callBack
        )
    }

    private func prepareBill(_ bill: Bill) -> Bill {
        var prepared = bill
        if !merchantId.isEmpty {
            prepared.merchantID = merchantId
        }
        return prepared
    }

    private func request<T: Encodable, V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:],
        body: T,
        callBack: @escaping (ApiResponse<V>) -> Void
    ) {
        do {
            let bodyData = try JSONEncoder().encode(body)
            send(verb, path: path, query: query, bodyData: bodyData, callBack: callBack)
        } catch {
            callBack(ApiResponse(error: "local error \(error)"))
        }
    }

    private func request<V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:],
        callBack: @escaping (ApiResponse<V>) -> Void
    ) {
        send(verb, path: path, query: query, bodyData: nil, callBack: callBack)
    }

    private func send<V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String],
        bodyData: Data?,
        callBack: @escaping (ApiResponse<V>) -> Void
    ) {
        guard let url = buildURL(path: path, query: query) else {
            callBack(ApiResponse(error: "local error invalid url"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = verb.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bodyData = bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        urlSession.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                callBack(ApiResponse(error: error?.localizedDescription))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                callBack(ApiResponse(error: "unknown error"))
                return
            }

            if response.statusCode < 200 || response.statusCode > 299 {
                callBack(
                    ApiResponse(
                        error: "http error \(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))"
                    )
                )
                return
            }

            do {
                let resp = try JSONDecoder().decode(ApiResponse<V>.self, from: data)
                callBack(resp)
            } catch {
                callBack(ApiResponse(error: "local error \(error)"))
            }
        }.resume()
    }

    private func buildURL(path: String, query: [String: String]) -> URL? {
        var components = URLComponents(string: "\(baseAddress)\(path)")
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        if !merchantId.isEmpty {
            queryItems.append(URLQueryItem(name: "merchant_id", value: merchantId))
        }

        for key in query.keys.sorted() {
            queryItems.append(URLQueryItem(name: key, value: query[key]))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}

private enum Verb: String {
    case GET
    case POST
    case PUT
    case DELETE
}

private extension String {
    func trimmingTrailingSlashes() -> String {
        var value = self
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
