
public struct Bill : Codable {
    
        public var customerCode : String = ""
        public var customerName : String = ""
        public var billReference : String = ""
        public var time : String = ""
        public var description : String = ""
        public var amount : String = ""
        public var merchantID : String = ""
    
    public init(customerCode : String,customerName : String,billReference : String,
                time : String, description : String, amount : String, merchantID : String ) {
        
        self.customerCode = customerCode
        self.customerName = customerName
        self.billReference = billReference
        self.time = time
        self.description = description
        self.amount = amount
        self.merchantID = merchantID
        
        
    }
    
}
