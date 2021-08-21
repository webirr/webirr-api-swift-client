Official Swift/iOS Client Library for WeBirr Payment Gateway APIs

This Client Library provides convenient access to WeBirr Payment Gateway APIs from Swift/iOS Apps.

## Install

Add WeBirr as Package Dependency

>To add a package dependency to your Xcode project, select 
File > Swift Packages > Add Package Dependency & enter the repository URL
https://github.com/webirr/webirr-api-swift-client

>[read more](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app)

## Usage

The library needs to be configured with a *merchant Id* & *API key*. You can get it by contacting [webirr.com](https://webirr.com)

> You can use this library for production or test environments. you will need to set isTestEnv=true for test, and false for production apps when creating objects of class WeBirrClient

## Example

```swift

import Foundation
import WeBirr

let apiKey = "YOUR_API_KEY"
let merchantId = "YOUR_MERCHANT_ID"

//let apiKey  = ProcessInfo.processInfo.environment["wb_api_key"] ?? ""
//let merchantId  = ProcessInfo.processInfo.environment["wb_merchant_id"] ?? ""

createAndUpdateBillAsync(); Thread.sleep(forTimeInterval: 2);
getPaymentStatusAsync(); Thread.sleep(forTimeInterval: 2);
deleteBillAsync(); Thread.sleep(forTimeInterval: 2);

/**
 * Creating a new Bill / Updating an existing Bill on WeBirr Servers
 */
func createAndUpdateBillAsync() {
    
    let api = WeBirr.WeBirrClient(apiKey: apiKey, isTestEnv: true)

    var bill = Bill(
        customerCode: "cc01",
        customerName: "Elias Haileselassie",
        billReference: "swift/2021/143",
        time: "2021-07-22 22:14",
        description: "hotel booking",
        amount: "270.90",
        merchantID: merchantId)

    print("Creating Bill...")

    api.createBillAsync(bill: bill) { resp in
    
        if resp.error == nil {
             // success
            let paymentCode = resp.res ?? "" // returns paymentcode such as 429 723 975
            print("Payment Code = \(paymentCode)") // we may want to save payment code in local db.
            
            //DispatchQueue.main.async {  updateUIShouldBeHere()! }
            
           } else {
               // fail
               print("error: \(resp.error!)")
               print("errorCode: \(resp.errorCode ?? "")") // can be used to handle specific busines error such as ERROR_INVLAID_INPUT_DUP_REF
           }
    }

    // the above method call is async! will be ok in ios or anything that has ui runloop!
    Thread.sleep(forTimeInterval: 2)
    
    // update existing bill if it is not paid
    bill.amount = "278.50"
    bill.customerName = "Elias kotlin"
    //bill.billReference = "WE SHOULD NOT CHANGE THIS";
    
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
    
}

/**
 * Getting Payment status of an existing Bill from WeBirr Servers
 */
func getPaymentStatusAsync(){

    let api = WeBirr.WeBirrClient(apiKey: apiKey, isTestEnv: true)

    let paymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL" // such as '141 263 782';

    print("Getting Payment Status...")

    api.getPaymentStatusAsync(paymentCode: paymentCode) { resp in

        if resp.error == nil {
            // success
            if resp.res?.isPaid ?? false
            {
                print("bill is paid");
                print("bill payment detail")
                print("Bank: \(resp.res?.data?.bankID  ?? "")")
                print("Bank Reference Number: \(resp.res?.data?.paymentReference  ?? "")")
                print("Amount Paid: \(resp.res?.data?.amount  ?? "")")
            }
            else {
                print("bill is pending payment")
            }

        } else {
            // fail
            print("error: \(resp.error!)");
            print("errorCode: \(resp.errorCode ?? "")"); // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }
    }

}

/**
 * Deleting a Bill from WeBirr Servers if it is not paid yet
 */
func deleteBillAsync(){

    let api = WeBirr.WeBirrClient(apiKey: apiKey, isTestEnv: true)

    let paymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL" // suchas as '141 263 782';

    print("Deleting Bill...")

    api.deleteBillAsync(paymentCode: paymentCode) { resp in

        if resp.error == nil {
            // success
            print("bill is deleted successfully"); //res.res will be 'OK'  no need to check here!
        } else {
            // fail
            print("error: \(resp.error!)");
            print("errorCode: \(resp.errorCode ?? "")"); // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }

    }
}

```
