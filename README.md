paypal-recurring
============
This package makes integration of PayPal's recurring payments easier in your next project using `node.js`.  
This package will be featured in my upcoming book about building your next SaaS. More information to follow.


Installation
============
  
    npm install paypal-recurring


Introduction
============
Integrating PayPal's recurring payments into your application to get paid can be confusing, but it only takes two steps to convert a user into a paying recurring
customer of yours.

Enter your own API credentials [(obtained here)](https://developer.paypal.com)
in the demo application (`./examples/express`) and run it by entering this
in your terminal:
  
    make demo

If you want to read up on PayPal's API documentation for recurring billing, visit [this page](https://www.x.com/developers/paypal/documentation-tools/express-checkout/integration-guide/ECRecurringPayments).


###Introduction & converting users into customers
Your user visits your node.js-driven website where you already have setup your environment by installing this package and passed your API credentials to the constructor of the class.

By calling the `authenticate()` method, you'll get an unique URL from PayPal that you redirect your user to.
Now at PayPal's website, your user either logs in to an existing account or creates a new one and then gets to accept your recurring payment agreement.

PayPal then sends the user back to your website along with a unique token + customer id appended to the url as query strings. With this token and the payerid, you run the `createSubscription`-method and your user is now turned into a paying subscriber of yours.

You can then use the `PROFILEID` that `createSubscription` returns on success
to either fetch subscription information and remotely pause/cancel subscriptions from within your app in the future by using the `.getSubscription()` & `.modifySubscription()` -methods.


Documentation
============

## Constructor

The constructor takes four arguments: `username`, `password`, `signature` & `enviroment`.  
Username, password and signature are all your [PayPal API credentials](https://developer.paypal.com)

The default environment uses the PayPal Sandbox API to allow testing. When going live, pass `environment: "production"` to the constructor. This will create real subscriptions, so use with care.


```js
// Require the module and setup our instance of the class
var Paypal = require('paypal-recurring'),
    paypal = new Paypal({
      username:  "info@example.com",
      password:  "****",
      signature: "****",
      // environment: "production" // USE WITH CARE!
    });
```

## .authenticate(options, callback)
*(first step in the payment flow)*

This method generates a unique url to authenticate the user through PayPal by calling the `SetExpressCheckout` action in the PayPal API.  
You should redirect your user to the url that this method returns to allow the user to either login to an existing account or create a new one with PayPal.

This method takes two arguments - `options` (object) and `callback` (fn).

The options object must contain at least `RETURNURL`, `CANCELURL`, `PAYMENTREQUEST_0_AMT` & `L_BILLINGAGREEMENTDESCRIPTION0` for this API operation to be valid.

Your callback will be passed three arguments upon API response; `error`, `data`
& `url`.

**Example usage of `.authenticate()`:**

```js
// Authenticate a future subscription of ~10 USD
paypal.authenticate({
  RETURNURL:                      "https://localhost/purchase/success",
  CANCELURL:                      "https://localhost/purchase/fail",
  PAYMENTREQUEST_0_AMT:           10,
  L_BILLINGAGREEMENTDESCRIPTION0: "A description of this subscription"
}, function(err, data, url) {
  // Redirect the user if everything went well with
  // a HTTP 302 according to PayPal's guidelines
  if (!err) { res.redirect(302, url); }
});
```

**This is what the actual API request will look like when calling `authenticate` as above:**

```
USER:                           "***",
PWD:                            "***",
SIGNATURE:                      "***",
VERSION:                        94,
METHOD:                         "SetExpressCheckout",
ADDROVERRIDE:                   0,
ALLOWNOTE:                      0,
BUYEREMAILOPTINENABLE:          1,
NOSHIPPING:                     1,
SURVEYENABLE:                   0,
RETURNURL:                      "https://localhost/purchase/success",
CANCELURL:                      "https://localhost/purchase/fail",
PAYMENTREQUEST_0_AMT:           10,
L_BILLINGAGREEMENTDESCRIPTION0: "A description of this subscription",
L_BILLINGTYPE0:                 "RecurringPayments"
```

**Note:** *Some of the parameters above are not explicitly specified in the
arguments and are set as default inside the `SetExpressCheckout` method to suit
most online subscription businesses. Override any of the defaults by including
that key/value in the `options` hash.*

Please visit [this page](https://www.x.com/developers/paypal/documentation-tools/api/setexpresscheckout-api-operation-nvp) for official PayPal API
documentation of the `SetExpressCheckout` action to learn how you can customize the API call to suit your business.


## .createSubscription(token, payerid, options, callback)
*(final step in the payment flow)*

After calling `.authenticate()` the user is now back on your server at the `RETURNURL` you specified with both `token` and `payerid` appended to the URL as querystrings.

You now call the `.createSubscription()`-method, passing both the `token` and the `payerid` to setup the actual recurring billing profile between you and the customer, which runs the `CreateRecurringPaymentsProfile` on the PayPal API.

This method takes four arguments: `token` (string), `payerid` (string), `options` (object) & `callback` (fn)

The options object must contain at least `AMT`, `DESC`, `BILLINGPERIOD` & `BILLINGFREQUENCY` for this API operation to be valid.

The start date of the payment profile is automatically set and converted into ISO/UTC format & timezone before being sent to the PayPal API. If you like to change the first billing date of your customer, just pass along a date object in the `options` object like `PROFILESTARTDATE: new Date()` and you should be fine.

Your callback function will be passed two arguments upon API response; `error` & `data`.

**Example usage of `.createSubscription()`:**


```js
// Create a subscription of 10 USD every month
paypal.createSubscription('token','payerid',{
  AMT:              10
  DESC:             "A description of this subscription"
  BILLINGPERIOD:    "Month",
  BILLINGFREQUENCY: 1,
}, function(err, data) {
  if (!err) {
    res.send("You are now one of our customers!");
    console.log("New customer with PROFILEID: " + data.PROFILEID)
  }
});
```

**This is what the actual API request will look when calling `.createSubscription()` as above: **

```
USER:             "***",
PWD:              "***",
SIGNATURE:        "***",
VERSION:          94,
METHOD:           "CreateRecurringPaymentsProfile",
TOKEN:            "***",
PAYERID:          "***",
INITAMT:          0,
PROFILESTARTDATE: "2013-02-11T18:25:25.000Z",
AMT:              10,
DESC:             "A description of this purchase",
BILLINGPERIOD:    "Month",
BILLINGFREQUENCY: 1
```

Please visit [this page](https://www.x.com/developers/paypal/documentation-tools/api/createrecurringpaymentsprofile-api-operation-nvp)
for official PayPal API documentation of the `CreateRecurringPaymentsProfile` action to learn how you can customize the API call to suit your business.


## .getSubscription(profileid, callback)

To fetch information about a payment profile of one of your customers, call the `.getSubscription` method with the `PROFILEID` that was returned when you invoked `.createSubscription`.

This method takes two arguments: `profileid` (string) & `callback` (fn).

Your callback function will be passed two arguments upon API response; `error` & `data`.

```js
paypal.getSubscription('subscriptionid', function(err, data) {
  if (!err) { console.log(data)}
});
```
Please visit [this page](https://www.x.com/developers/paypal/documentation-tools/api/getrecurringpaymentsprofiledetails-api-operation-nvp)
for official PayPal API documentation of the `GetRecurringPaymentsProfileDetails` action.


## .modifySubscription(profileid, action, callback)

To remotely modify subscriptions - cancel, suspend and reactivate subscriptions you can use the `.modifySubscription`-method.

It takes four arguments: `profileid` (string), `action` (string), `note` (string) & `callback` (fn). 

Action may be either `cancel`, `suspend` or `reactivate`.  
The note argument is optional and can be left out if you doesn't need to send an note along with the payment profile status change to your customer.

Your callback function will be passed two arguments upon API response; `error` & `data`.

```js
paypal.modifySubscription('subscriptionid', 'Cancel' , function(err, data) {
  if (!err) { res.send "Your subscription was cancelled" }
});
```
Please visit [this page](https://www.x.com/developers/paypal/documentation-tools/api/managerecurringpaymentsprofilestatus-api-operation-nvp)
for official PayPal API documentation of the `ManageRecurringPaymentsProfileStatus` action.

Pitfalls
============

###Different subtotals/descriptions

If your description and/or subtotal differs between what you enter when calling `authenticate` & `createSubscription`, PayPal may deny your API call.

###Trial periods

If you want to provide a proper free trial period *before* any billing is done, avoid using any of the billing fields (`TRIALBILLINGPERIOD` etc) when calling the `createSubscription` method.

Instead, make sure to set the `PROFILESTARTDATE` ahead in time according to when you want the *first* billing to occur:

    var d = new Date()
    d.setMonth(d.getMonth()+1)


Development
============

Feel free to go wild if you are missing any features in this package. Just make sure to write proper tests and that they pass:
  
    make test


Changelog
============

**v1.1.0:**

* The class does now validates API results to keep you from writing `if (response["ACK"] === "Success")` to manually validate every API action.

* Every API action is now tunneled through the `makeAPIrequest()`-method to make it easy to debug/unit test the class when integrating with your own code.


License
============

MIT license. See the `LICENSE` file for details.  
Copyright (c) 2013 Jay Bryant. All rights reserved.