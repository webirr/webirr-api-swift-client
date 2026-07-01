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

public enum WeBirrPlatformError: Error, Equatable {
    case invalidURL
    case invalidHTTPResponse
    case emptyResponse(statusCode: Int)
    case httpStatus(statusCode: Int, status: String)
}

public enum WeBirrErrors {
    public static func isTransient(_ error: Error) -> Bool {
        if let platformError = error as? WeBirrPlatformError {
            switch platformError {
            case let .httpStatus(statusCode, _):
                return statusCode >= 500 || statusCode == 429 || statusCode == 408
            case .invalidURL, .invalidHTTPResponse, .emptyResponse:
                return false
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .networkConnectionLost, .notConnectedToInternet, .secureConnectionFailed:
                return true
            default:
                return false
            }
        }

        return false
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
    public func createBill(bill: Bill) async throws -> ApiResponse<String> {
        try await request(.POST, path: "/einvoice/api/bill", body: prepareBill(bill))
    }

    /**
     * Update an existing bill at WeBirr Servers, if the bill is not paid yet.
     * The billReference has to be the same as the original bill created.
     * Check if(ApiResponse.error == nil) to see if there are errors.
     * ApiResponse.res will have the value of "OK" on success.
     */
    public func updateBill(bill: Bill) async throws -> ApiResponse<String> {
        try await request(.PUT, path: "/einvoice/api/bill", body: prepareBill(bill))
    }

    /**
     * Delete an existing bill at WeBirr Servers, if the bill is not paid yet.
     * paymentCode is the number that WeBirr Payment Gateway returns on createBill.
     */
    public func deleteBill(paymentCode: String) async throws -> ApiResponse<String> {
        try await request(
            .DELETE,
            path: "/einvoice/api/bill",
            query: ["wbc_code": paymentCode]
        )
    }

    /**
     * Get Payment Status of a bill from WeBirr Servers.
     */
    public func getPaymentStatus(paymentCode: String) async throws -> ApiResponse<Payment> {
        try await request(
            .GET,
            path: "/einvoice/api/paymentStatus",
            query: ["wbc_code": paymentCode]
        )
    }

    public func getBillByReference(billReference: String) async throws -> ApiResponse<BillResponse> {
        try await request(
            .GET,
            path: "/einvoice/api/bill",
            query: ["bill_reference": billReference]
        )
    }

    public func getBillByPaymentCode(paymentCode: String) async throws -> ApiResponse<BillResponse> {
        try await request(
            .GET,
            path: "/einvoice/api/bill",
            query: ["wbc_code": paymentCode]
        )
    }

    public func getBills(
        paymentStatus: Int = -1,
        lastTimeStamp: String = "",
        limit: Int = 100
    ) async throws -> ApiResponse<[BillResponse]> {
        try await request(
            .GET,
            path: "/einvoice/api/bills",
            query: [
                "payment_status": String(paymentStatus),
                "last_timestamp": lastTimeStamp,
                "limit": String(limit)
            ]
        )
    }

    public func getPayments(
        lastTimeStamp: String = "",
        limit: Int = 100
    ) async throws -> ApiResponse<[PaymentResponse]> {
        try await request(
            .GET,
            path: "/einvoice/api/payments",
            query: [
                "last_timestamp": lastTimeStamp,
                "limit": String(limit)
            ]
        )
    }

    public func getStat(
        dateFrom: String,
        dateTo: String
    ) async throws -> ApiResponse<Stat> {
        try await request(
            .GET,
            path: "/merchant/stat",
            query: [
                "date_from": dateFrom,
                "date_to": dateTo
            ]
        )
    }

    public func getSupportedBanks() async throws -> ApiResponse<[SupportedBank]> {
        try await request(
            .GET,
            path: "/einvoice/api/banks"
        )
    }

    private func prepareBill(_ bill: Bill) -> Bill {
        var prepared = bill
        prepared.merchantID = merchantId
        return prepared
    }

    private func request<T: Encodable, V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:],
        body: T
    ) async throws -> ApiResponse<V> {
        try await withCheckedThrowingContinuation { continuation in
            request(verb, path: path, query: query, body: body) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func request<V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:]
    ) async throws -> ApiResponse<V> {
        try await withCheckedThrowingContinuation { continuation in
            request(verb, path: path, query: query) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func request<T: Encodable, V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:],
        body: T,
        callBack: @escaping (Result<ApiResponse<V>, Error>) -> Void
    ) {
        do {
            let bodyData = try JSONEncoder().encode(body)
            send(verb, path: path, query: query, bodyData: bodyData, callBack: callBack)
        } catch {
            callBack(.failure(error))
        }
    }

    private func request<V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String] = [:],
        callBack: @escaping (Result<ApiResponse<V>, Error>) -> Void
    ) {
        send(verb, path: path, query: query, bodyData: nil, callBack: callBack)
    }

    private func send<V: Decodable>(
        _ verb: Verb,
        path: String,
        query: [String: String],
        bodyData: Data?,
        callBack: @escaping (Result<ApiResponse<V>, Error>) -> Void
    ) {
        guard let url = buildURL(path: path, query: query) else {
            callBack(.failure(WeBirrPlatformError.invalidURL))
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
            if let error = error {
                callBack(.failure(error))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                callBack(.failure(WeBirrPlatformError.invalidHTTPResponse))
                return
            }

            if response.statusCode < 200 || response.statusCode > 299 {
                callBack(.failure(WeBirrPlatformError.httpStatus(
                    statusCode: response.statusCode,
                    status: HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
                )))
                return
            }

            guard let data = data, !data.isEmpty else {
                callBack(.failure(WeBirrPlatformError.emptyResponse(statusCode: response.statusCode)))
                return
            }

            do {
                let resp = try JSONDecoder().decode(ApiResponse<V>.self, from: data)
                callBack(.success(resp))
            } catch {
                callBack(.failure(error))
            }
        }.resume()
    }

    private func buildURL(path: String, query: [String: String]) -> URL? {
        var components = URLComponents(string: "\(baseAddress)\(path)")
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "merchant_id", value: merchantId)
        ]

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
