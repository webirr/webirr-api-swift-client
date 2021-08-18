
public struct Bill : Codable {
    
        var customerCode : String = ""
        var customerName : String = ""
        var billReference : String = ""
        var time : String = ""
        var description : String = ""
        var amount : String = ""
        var merchantID : String = ""
    
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
