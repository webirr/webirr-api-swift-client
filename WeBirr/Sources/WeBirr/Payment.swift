public struct Payment : Codable {

    // 0 = not paid, 1 = payment in progress,  2. paid !
    public var status : Int = 0
    public var data : PaymentDetail? = nil

    // true if the bill is paid (payment process completed)
    public var isPaid : Bool {
        get {
            status == 2
        }
    }
}

public struct PaymentDetail : Codable {
    public var id : Int = 0;
    public var paymentReference : String = ""
    public var confirmed : Bool = false
    public var confirmedTime : String = ""
    public var bankID : String = ""
    public var time : String = ""
    public var amount : String = ""
    public var wbcCode : String = ""
}
