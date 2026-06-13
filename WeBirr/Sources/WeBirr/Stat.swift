public struct Stat: Codable, Equatable {
    public var nBills: Double
    public var nBillsPaid: Double
    public var nBillsUnpaid: Double
    public var amountBills: Double
    public var amountPaid: Double
    public var amountUnpaid: Double

    public init(
        nBills: Double = 0,
        nBillsPaid: Double = 0,
        nBillsUnpaid: Double = 0,
        amountBills: Double = 0,
        amountPaid: Double = 0,
        amountUnpaid: Double = 0
    ) {
        self.nBills = nBills
        self.nBillsPaid = nBillsPaid
        self.nBillsUnpaid = nBillsUnpaid
        self.amountBills = amountBills
        self.amountPaid = amountPaid
        self.amountUnpaid = amountUnpaid
    }

    private enum CodingKeys: String, CodingKey {
        case nBills
        case nBillsPaid
        case nBillsUnpaid
        case amountBills
        case amountPaid
        case amountUnpaid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nBills = Self.decodeDouble(container, .nBills)
        nBillsPaid = Self.decodeDouble(container, .nBillsPaid)
        nBillsUnpaid = Self.decodeDouble(container, .nBillsUnpaid)
        amountBills = Self.decodeDouble(container, .amountBills)
        amountPaid = Self.decodeDouble(container, .amountPaid)
        amountUnpaid = Self.decodeDouble(container, .amountUnpaid)
    }

    private static func decodeDouble<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        _ key: K
    ) -> Double {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value) ?? 0
        }
        return 0
    }
}
