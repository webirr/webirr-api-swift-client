public struct Payment: Codable, Equatable {
    // 0 = not paid, 1 = payment in progress, 2 = paid.
    public var status: Int
    public var data: PaymentDetail?

    public init(status: Int = 0, data: PaymentDetail? = nil) {
        self.status = status
        self.data = data
    }

    // true if the bill is paid (payment process completed)
    public var isPaid: Bool {
        status == 2
    }
}

public struct PaymentDetail: Codable, Equatable {
    public var id: Int
    public var status: Int
    public var paymentReference: String
    public var confirmed: Bool
    public var confirmedTime: String
    public var bankID: String
    public var paymentDate: String
    public var amount: String
    public var wbcCode: String
    public var updateTimeStamp: String

    public init(
        id: Int = 0,
        status: Int = 0,
        paymentReference: String = "",
        confirmed: Bool = false,
        confirmedTime: String = "",
        bankID: String = "",
        paymentDate: String = "",
        amount: String = "",
        wbcCode: String = "",
        updateTimeStamp: String = ""
    ) {
        self.id = id
        self.status = status
        self.paymentReference = paymentReference
        self.confirmed = confirmed
        self.confirmedTime = confirmedTime
        self.bankID = bankID
        self.paymentDate = paymentDate
        self.amount = amount
        self.wbcCode = wbcCode
        self.updateTimeStamp = updateTimeStamp
    }

    /// Deprecated compatibility alias. Prefer paymentDate.
    public var time: String {
        get { paymentDate }
        set { paymentDate = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case paymentReference
        case confirmed
        case confirmedTime
        case bankID
        case paymentDate
        case amount
        case wbcCode
        case updateTimeStamp
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case time
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = Self.decodeInt(container, .id)
        status = Self.decodeInt(container, .status)
        paymentReference = Self.decodeString(container, .paymentReference)
        confirmed = Self.decodeBool(container, .confirmed)
        confirmedTime = Self.decodeString(container, .confirmedTime)
        bankID = Self.decodeString(container, .bankID)
        paymentDate = Self.decodeString(container, .paymentDate)
        if paymentDate.isEmpty {
            paymentDate = Self.decodeString(legacyContainer, .time)
        }
        amount = Self.decodeString(container, .amount)
        wbcCode = Self.decodeString(container, .wbcCode)
        updateTimeStamp = Self.decodeString(container, .updateTimeStamp)
    }
}

public struct PaymentResponse: Codable, Equatable {
    public var status: Int
    public var id: Int
    public var bankID: String
    public var paymentReference: String
    public var paymentDate: String
    public var confirmed: Bool
    public var confirmedTime: String
    public var canceled: Bool
    public var canceledTime: String
    public var amount: String
    public var wbcCode: String
    public var updateTimeStamp: String

    public init(
        status: Int = 0,
        id: Int = 0,
        bankID: String = "",
        paymentReference: String = "",
        paymentDate: String = "",
        confirmed: Bool = false,
        confirmedTime: String = "",
        canceled: Bool = false,
        canceledTime: String = "",
        amount: String = "",
        wbcCode: String = "",
        updateTimeStamp: String = ""
    ) {
        self.status = status
        self.id = id
        self.bankID = bankID
        self.paymentReference = paymentReference
        self.paymentDate = paymentDate
        self.confirmed = confirmed
        self.confirmedTime = confirmedTime
        self.canceled = canceled
        self.canceledTime = canceledTime
        self.amount = amount
        self.wbcCode = wbcCode
        self.updateTimeStamp = updateTimeStamp
    }

    /// Deprecated compatibility alias. Prefer paymentDate.
    public var time: String {
        get { paymentDate }
        set { paymentDate = newValue }
    }

    public var isPaid: Bool {
        status == 2
    }

    public var isReversed: Bool {
        status == 3
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case id
        case bankID
        case paymentReference
        case paymentDate
        case confirmed
        case confirmedTime
        case canceled
        case canceledTime
        case amount
        case wbcCode
        case updateTimeStamp
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case time
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        status = PaymentDetail.decodeInt(container, .status)
        id = PaymentDetail.decodeInt(container, .id)
        bankID = PaymentDetail.decodeString(container, .bankID)
        paymentReference = PaymentDetail.decodeString(container, .paymentReference)
        paymentDate = PaymentDetail.decodeString(container, .paymentDate)
        if paymentDate.isEmpty {
            paymentDate = PaymentDetail.decodeString(legacyContainer, .time)
        }
        confirmed = PaymentDetail.decodeBool(container, .confirmed)
        confirmedTime = PaymentDetail.decodeString(container, .confirmedTime)
        canceled = PaymentDetail.decodeBool(container, .canceled)
        canceledTime = PaymentDetail.decodeString(container, .canceledTime)
        amount = PaymentDetail.decodeString(container, .amount)
        wbcCode = PaymentDetail.decodeString(container, .wbcCode)
        updateTimeStamp = PaymentDetail.decodeString(container, .updateTimeStamp)
    }
}

extension PaymentDetail {
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

    fileprivate static func decodeBool<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        _ key: K
    ) -> Bool {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            let text = value.lowercased()
            return text == "true" || text == "1"
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return value == 1
        }
        return false
    }
}
