Official Swift/iOS Client Library for WeBirr Payment Gateway APIs

This Client Library provides convenient access to WeBirr Payment Gateway APIs from Swift/iOS Apps.

## Install

Add WeBirr as Package Dependency

>To add a package dependency to your Xcode project, select
File > Swift Packages > Add Package Dependency & enter the repository URL
https://github.com/webirr/webirr-api-swift-client     |    [read more](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app)

## Usage

The library needs to be configured with a *merchant Id* & *API key*. You can get it by contacting [webirr.com](https://webirr.com)

> You can use this library for production or test environments. you will need to set isTestEnv=true for test, and false for production apps when creating objects of class WeBirrClient

For TestEnv examples and smoke tests, set these environment variables:

```bash
export WEBIRR_TEST_ENV_MERCHANT_ID="YOUR_MERCHANT_ID"
export WEBIRR_TEST_ENV_API_KEY="YOUR_API_KEY"
```

Create the client with merchant ID, API key, and environment. The client sets `Bill.merchantID` automatically before create/update calls, so examples should not set bill merchant ID manually.

```swift
let api = WeBirr.WeBirrClient(
    merchantId: merchantId,
    apiKey: apiKey,
    isTestEnv: true)
```

For batch or mass bill workloads, you can pass a caller-owned `URLSession` so your app controls connection reuse and transport policy.

```swift
let session = URLSession(configuration: .default)
let api = WeBirr.WeBirrClient(
    merchantId: merchantId,
    apiKey: apiKey,
    isTestEnv: true,
    urlSession: session)
```

## Example

### Creating a new Bill / Updating an existing Bill on WeBirr Servers

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func createAndUpdateBillAsync() {

    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

    var bill = Bill(
        customerCode: "cc01", // it can be email address or phone number if you dont have customer code
        customerName: "Elias Haileselassie",
        billReference: "swift/2021/143", // your unique reference number
        time: "2021-07-22 22:14", // your bill time, always in this format
        description: "hotel booking",
        amount: "270.90",
        customerPhone: "0911000000",
        extras: [:])

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
    bill.amount = "278.00"
    bill.customerName = "Elias swift"
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
```

### Getting a Bill and Listing Bills

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func getBillAndListBillsAsync() {

    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

    let billReference = "BILL_REFERENCE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"
    let paymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL"

    print("Getting Bill By Reference...")

    api.getBillByReferenceAsync(billReference: billReference) { resp in

        if resp.error == nil {
            // success
            print("Payment Code = \(resp.res?.wbcCode ?? "")")
            print("Payment Status = \(resp.res?.paymentStatus ?? 0)")
            print("Last Timestamp = \(resp.res?.updateTimeStamp ?? "")")
        } else {
            // fail
            print("error: \(resp.error!)")
            print("errorCode: \(resp.errorCode ?? "")")
        }
    }

    Thread.sleep(forTimeInterval: 2)

    print("Getting Bill By Payment Code...")

    api.getBillByPaymentCodeAsync(paymentCode: paymentCode) { resp in

        if resp.error == nil {
            // success
            print("Bill Reference = \(resp.res?.billReference ?? "")")
            print("Payment Status = \(resp.res?.paymentStatus ?? 0)")
            print("Last Timestamp = \(resp.res?.updateTimeStamp ?? "")")
        } else {
            // fail
            print("error: \(resp.error!)")
            print("errorCode: \(resp.errorCode ?? "")")
        }
    }

    Thread.sleep(forTimeInterval: 2)

    print("Listing Bills...")
    let paymentStatus = -1 // -1 all, 0 pending, 1 unconfirmed payment, 2 paid.
    let lastTimeStamp = "20251231" // Date-only cursor; use "20251231235959" when you need time precision.
    let limit = 10

    api.getBillsAsync(paymentStatus: paymentStatus, lastTimeStamp: lastTimeStamp, limit: limit) { resp in

        if resp.error == nil {
            // success
            print("Bills returned: \(resp.res?.count ?? 0)")
            for bill in resp.res ?? [] {
                print("Bill Reference = \(bill.billReference)")
                print("Payment Code = \(bill.wbcCode)")
                print("Payment Status = \(bill.paymentStatus)")
                print("Last Timestamp = \(bill.updateTimeStamp)")
            }
        } else {
            // fail
            print("error: \(resp.error!)")
            print("errorCode: \(resp.errorCode ?? "")")
        }
    }
}
```

### Getting Supported Banks for Checkout

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func getSupportedBanksAsync() {
    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

    print("Getting Supported Banks...")

    api.getSupportedBanksAsync { resp in
        if resp.error == nil {
            for bank in resp.res ?? [] {
                print("\(bank.bankID) - \(bank.name)")
            }
            print("Use only these merchant-specific banks when showing checkout payment instructions.")
        } else {
            print("error: \(resp.error!)")
            print("errorCode: \(resp.errorCode ?? "")")
        }
    }
}
```

Checkout pages should render bank-specific instructions only from `getSupportedBanksAsync`. Do not show a broad static bank list unless those banks are returned for the configured merchant.

### Getting Payment status of an existing Bill from WeBirr Servers

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func getPaymentStatusAsync() {

    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

    let paymentCode = "PAYMENT_CODE_YOU_SAVED_AFTER_CREATING_A_NEW_BILL" // such as '141 263 782';

    print("Getting Payment Status...")

    api.getPaymentStatusAsync(paymentCode: paymentCode) { resp in

        if resp.error == nil {
            // success
            if resp.res?.isPaid ?? false {
                print("bill is paid");
                print("bill payment detail")
                print("Bank: \(resp.res?.data?.bankID  ?? "")")
                print("Bank Reference Number: \(resp.res?.data?.paymentReference  ?? "")")
                print("Amount Paid: \(resp.res?.data?.amount  ?? "")")
                print("Payment Date: \(resp.res?.data?.paymentDate  ?? "")")
            } else {
                print("bill is pending payment")
            }

        } else {
            // fail
            print("error: \(resp.error!)");
            print("errorCode: \(resp.errorCode ?? "")"); // can be used to handle specific busines error such as ERROR_INVLAID_INPUT
        }
    }
}
```

*Sample object returned from getPaymentStatus()*

```json
{
  "status": 2,
  "data": {
    "id": 1,
    "status": 2,
    "bankID": "cbe_birr",
    "paymentReference": "BANK-REF-1",
    "paymentDate": "2025-01-01 10:00:00",
    "confirmed": true,
    "confirmedTime": "2025-01-01 10:00:01",
    "amount": "270.90",
    "wbcCode": "429 723 975",
    "updateTimeStamp": "20250101100001000001"
  }
}
```

### Deleting an existing Bill from WeBirr Servers (if it is not paid)

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func deleteBillAsync() {

    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

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

### Getting list of Payments and process them with Bulk Polling Consumer

```swift
import Foundation
import WeBirr

class BulkPaymentPollingConsumer {
    private let api: WeBirrClient
    private var lastTimeStamp = "20251231" // use a saved cursor; time precision can be like "20251231235959"

    init() {
        let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
        let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"
        api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)
    }

    func fetchAndProcessPayments() {
        let limit = 100

        print("Getting Payments...")

        api.getPaymentsAsync(lastTimeStamp: lastTimeStamp, limit: limit) { resp in

            if resp.error == nil {
                // success
                for payment in resp.res ?? [] {
                    self.processPayment(payment)
                    if !payment.updateTimeStamp.isEmpty {
                        self.lastTimeStamp = payment.updateTimeStamp
                        print("Last Timestamp: \(self.lastTimeStamp)") // save updateTimeStamp to your database for the next getPaymentsAsync() call
                    }
                }
            } else {
                // fail
                print("error: \(resp.error!)")
                print("errorCode: \(resp.errorCode ?? "")")
            }
        }
    }

    private func processPayment(_ payment: PaymentResponse) {
        if payment.isPaid {
            print("bill is paid")
        } else if payment.isReversed {
            print("bill payment is reversed")
        }

        print("Bank: \(payment.bankID)")
        print("Bank Reference Number: \(payment.paymentReference)")
        print("Amount Paid: \(payment.amount)")
        print("Payment Date: \(payment.paymentDate)")
        print("Canceled Time: \(payment.canceledTime)")
        print("Update Timestamp: \(payment.updateTimeStamp)")
    }
}
```

### Webhooks - Payment processing using Webhook Callbacks

```swift
import Foundation
import WeBirr

func processWebhookPayment(rawBody: Data, authKey: String?) -> (statusCode: Int, body: String) {
    let expectedAuthKey = ProcessInfo.processInfo.environment["WEBIRR_WEBHOOK_AUTH_KEY"] ?? "YOUR_WEBHOOK_AUTH_KEY"

    guard authKey == expectedAuthKey else {
        return (401, "{\"error\":\"unauthorized\"}")
    }

    guard !rawBody.isEmpty else {
        return (400, "{\"error\":\"empty request body\"}")
    }

    do {
        let payment = try JSONDecoder().decode(PaymentResponse.self, from: rawBody)
        processPayment(payment)
        return (200, "{\"error\":null}")
    } catch {
        return (400, "{\"error\":\"invalid json\"}")
    }
}

func processPayment(_ payment: PaymentResponse) {
    if payment.isPaid {
        print("bill is paid")
    } else if payment.isReversed {
        print("bill payment is reversed")
    }

    print("Bank: \(payment.bankID)")
    print("Bank Reference Number: \(payment.paymentReference)")
    print("Amount Paid: \(payment.amount)")
    print("Payment Date: \(payment.paymentDate)")
    print("Canceled Time: \(payment.canceledTime)")
    print("Update Timestamp: \(payment.updateTimeStamp)")
}
```

Host webhook handlers on HTTPS, validate the HTTP method is POST before calling the processing code, validate the `authKey`, make payment processing idempotent, and enqueue longer work to a background process.

### Gettting basic Statistics about bills created and payments received for a date range

```swift
import Foundation
import WeBirr

let apiKey = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_API_KEY"] ?? "YOUR_API_KEY"
let merchantId = ProcessInfo.processInfo.environment["WEBIRR_TEST_ENV_MERCHANT_ID"] ?? "YOUR_MERCHANT_ID"

func getStatAsync() {

    let api = WeBirr.WeBirrClient(merchantId: merchantId, apiKey: apiKey, isTestEnv: true)

    let dateFrom = "2025-01-01"
    let dateTo = "2030-01-31"

    print("Getting Stat...")

    api.getStatAsync(dateFrom: dateFrom, dateTo: dateTo) { resp in

        if resp.error == nil {
            // success
            print("Bills Created: \(resp.res?.nBills ?? 0)")
            print("Bills Paid: \(resp.res?.nBillsPaid ?? 0)")
            print("Bills Unpaid: \(resp.res?.nBillsUnpaid ?? 0)")
            print("Amount Bills: \(resp.res?.amountBills ?? 0)")
            print("Amount Paid: \(resp.res?.amountPaid ?? 0)")
            print("Amount Unpaid: \(resp.res?.amountUnpaid ?? 0)")
        } else {
            // fail
            print("error: \(resp.error!)")
            print("errorCode: \(resp.errorCode ?? "")")
        }
    }
}
```

## Standalone Example

The `Examples/Example/main.swift` file includes workflows equivalent to the README sections:

| Workflow | Coverage |
| --- | --- |
| `createAndUpdateBillAsync` | Create bill, save payment code, update same bill. |
| `getPaymentStatusAsync` | Single payment status by saved payment code. |
| `deleteBillAsync` | Delete unpaid bill by payment code. |
| `fetchAndProcessPayments` | Poll payments with `lastTimeStamp`, process each payment, save `updateTimeStamp`. |
| `getStatAsync` | Merchant stats by date range. |
| `processWebhookPayment` | Webhook callback processing helper. |
| `getBillAndListBillsAsync` | Get bill by reference, get bill by payment code, list bills. |
| `getSupportedBanksAsync` | Get banks enabled for the configured merchant checkout. |

## Tests

Fast tests use a mock URL session:

```bash
swift test
```

Live TestEnv smoke tests call the running gateway when TestEnv credentials are available:

```bash
export WEBIRR_TEST_ENV_MERCHANT_ID="YOUR_MERCHANT_ID"
export WEBIRR_TEST_ENV_API_KEY="YOUR_API_KEY"
swift test
```

## Backward Compatibility

In 2.x, the client constructor requires the merchant ID argument. When merchant ID is explicitly empty, the client does not send an empty `merchant_id` query parameter and does not overwrite `Bill.merchantID`.
