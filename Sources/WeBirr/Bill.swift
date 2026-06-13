public struct Bill: Codable, Equatable {
    public var customerCode: String
    public var customerName: String
    public var billReference: String
    public var time: String
    public var description: String
    public var amount: String
    public var merchantID: String
    public var customerPhone: String
    public var extras: [String: String]

    public init(
        customerCode: String,
        customerName: String,
        billReference: String,
        time: String,
        description: String,
        amount: String,
        merchantID: String = "",
        customerPhone: String = "",
        extras: [String: String] = [:]
    ) {
        self.customerCode = customerCode
        self.customerName = customerName
        self.billReference = billReference
        self.time = time
        self.description = description
        self.amount = amount
        self.merchantID = merchantID
        self.customerPhone = customerPhone
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey {
        case customerCode
        case customerName
        case billReference
        case time
        case description
        case amount
        case merchantID
        case customerPhone
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customerCode = Self.decodeString(container, .customerCode)
        customerName = Self.decodeString(container, .customerName)
        billReference = Self.decodeString(container, .billReference)
        time = Self.decodeString(container, .time)
        description = Self.decodeString(container, .description)
        amount = Self.decodeString(container, .amount)
        merchantID = Self.decodeString(container, .merchantID)
        customerPhone = Self.decodeString(container, .customerPhone)
        extras = (try? container.decodeIfPresent([String: String].self, forKey: .extras)) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(customerCode, forKey: .customerCode)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(billReference, forKey: .billReference)
        try container.encode(time, forKey: .time)
        try container.encode(description, forKey: .description)
        try container.encode(amount, forKey: .amount)
        try container.encode(merchantID, forKey: .merchantID)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encode(extras, forKey: .extras)
    }
}

public struct BillResponse: Codable, Equatable {
    public var customerCode: String
    public var customerName: String
    public var billReference: String
    public var time: String
    public var description: String
    public var amount: String
    public var merchantID: String
    public var customerPhone: String
    public var extras: [String: String]
    public var wbcCode: String
    public var paymentStatus: Int
    public var updateTimeStamp: String

    public init(
        customerCode: String = "",
        customerName: String = "",
        billReference: String = "",
        time: String = "",
        description: String = "",
        amount: String = "",
        merchantID: String = "",
        customerPhone: String = "",
        extras: [String: String] = [:],
        wbcCode: String = "",
        paymentStatus: Int = 0,
        updateTimeStamp: String = ""
    ) {
        self.customerCode = customerCode
        self.customerName = customerName
        self.billReference = billReference
        self.time = time
        self.description = description
        self.amount = amount
        self.merchantID = merchantID
        self.customerPhone = customerPhone
        self.extras = extras
        self.wbcCode = wbcCode
        self.paymentStatus = paymentStatus
        self.updateTimeStamp = updateTimeStamp
    }

    private enum CodingKeys: String, CodingKey {
        case customerCode
        case customerName
        case billReference
        case time
        case description
        case amount
        case merchantID
        case customerPhone
        case extras
        case wbcCode
        case paymentStatus
        case updateTimeStamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customerCode = Bill.decodeString(container, .customerCode)
        customerName = Bill.decodeString(container, .customerName)
        billReference = Bill.decodeString(container, .billReference)
        time = Bill.decodeString(container, .time)
        description = Bill.decodeString(container, .description)
        amount = Bill.decodeString(container, .amount)
        merchantID = Bill.decodeString(container, .merchantID)
        customerPhone = Bill.decodeString(container, .customerPhone)
        extras = (try? container.decodeIfPresent([String: String].self, forKey: .extras)) ?? [:]
        wbcCode = Bill.decodeString(container, .wbcCode)
        paymentStatus = Bill.decodeInt(container, .paymentStatus)
        updateTimeStamp = Bill.decodeString(container, .updateTimeStamp)
    }
}

extension Bill {
    fileprivate static func decodeString<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        _ key: K
    ) -> String {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return String(value)
        }
        return ""
    }

    fileprivate static func decodeInt<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        _ key: K
    ) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value) ?? 0
        }
        return 0
    }
}
