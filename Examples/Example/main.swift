//
//  main.swift
//  Example
//
//  Created by Elias on 8/17/21.
//

import Foundation
import WeBirr

let apiKey = "YOUR_API_KEY"
let merchantId = "YOUR_MERCHANT_ID"


createAndUpdateBillAsync()

func createAndUpdateBillAsync() {
    
let api = WeBirr.WeBirrClient(apiKey: apiKey, isTestEnv: true)

var bill = Bill(
    customerCode: "cc01",
    customerName: "Elias Haileselassie",
    billReference: "swift/2021/141",
    time: "2021-07-22 22:14",
    description: "hotel booking",
    amount: "270.90",
    merchantID: merchantId
)

print("Creating Bill...")

api.createBillAsync(bill: bill) { resp in
    
    if  resp.error == nil {
            // success
            let paymentCode = resp.res ?? "" // returns paymentcode such as 429 723 975
            print("Payment Code = \(paymentCode)") // we may want to save payment code in local db.

           } else {
               // fail
               print("error: \(resp.error!)")
               print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT_DUP_REF
           }
    
    //DispatchQueue.main.async {
    //       updateUIShouldBeHere()!
    //}
}

    // the above method call is async!
Thread.sleep(forTimeInterval: 2)
    
    print("Updating Bill...")
    
    api.updateBillAsync(bill: bill) { resp in

            if resp.error == nil {
                // success
                print("bill is updated successfully")  //it.res will be 'OK'  no need to check here!

            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
            }
        }
    
    // the above method call is async!
Thread.sleep(forTimeInterval: 2)
    
}

