# Demo application of the paypal-recurring package.
#
# If coffeescript confuses you, go wild with http://js2coffee.org/
#
# Do only use this for personal testing and make sure to
# use HTTPS on your own server when using the package in production.
#
# Enter your own credentials below, or you won't be able
# to run this demo.
#
# Obtain your very own API credentials at: https://developer.paypal.com
#
express =     require 'express'
app =         express()
Paypal =      require '../'

#####
# ENTER YOUR CREDENTIALS HERE
#####
paypal = new Paypal
  username:  ""
  password:  ""
  signature: ""

#####
# No need to edit anything below. The demo should run itself.
#####
app.get "/", (req, res) ->
  res.send '<a href="/purchase/buy">Click here to do a demo subscription</a> <br/><br/>
  Make sure to have your test account credentials at hands - click 
  <a href="https://developer.paypal.com/">here</a> to obtain such
  if you haven\'t already done so.'  

app.get "/purchase/buy", (req, res) ->

  # We want to create a demo subscription to learn how this
  # works, so as we run this script at port 3000 on localhost,
  # we can pass below URL's as RETURNURL and CANCELURL to PayPal accordingly.
  #
  # L_BILLINGAGREEMENTDESCRIPTION0 could be just anything but must stay the same
  # in both calls of authenticate() and createSubscription()
  #
  # PAYMENTREQUEST_0_AMT sets the cost of the subscription to 10 USD, which
  # is the default PayPal currency.
  # 
  # See all params that you can use on following website:
  # https://www.x.com/developers/paypal/documentation-tools/api/setexpresscheckout-api-operation-nvp
  #
  params = 
    "RETURNURL":                      "http://localhost:3000/purchase/success"
    "CANCELURL":                      "http://localhost:3000/purchase/fail"
    "L_BILLINGAGREEMENTDESCRIPTION0": "Demo subscription"
    "PAYMENTREQUEST_0_AMT":           10

  # Do the authenticate() call (SetExpressCheckout on the PayPal API)
  paypal.authenticate params, (error, data, url) ->
    
    # Show a friendly error message to the user if PayPal's API isn't available
    return res.send "Temporary error, please come back later", 500 if error or !url

    # Make a HTTP 302 redirect of our user to PayPal.
    res.redirect 302, url

app.get "/purchase/success", (req, res) ->

  # Extract the Token and PayerID which PayPal has appended to the URL as
  # query strings:
  token =   req.query.token      ? false
  payerid = req.query['PayerID'] ? false

  # Show an error if we don't have both token & payerid
  return res.send "Invalid request.", 500 if !token or !payerid

  # We want to create a demo subscription with one month of free trial period
  # with no initial charging of the user.

  # Therefore we set the PROFILESTARTDATE to one month ahead from now
  startdate = new Date()
  startdate.setMonth(startdate.getMonth()+1)

  params = 
    AMT:              10
    DESC:             "Demo subscription"
    BILLINGPERIOD:    "Month"
    BILLINGFREQUENCY: 1
    PROFILESTARTDATE: startdate

  paypal.createSubscription token, payerid, params, (error, data) ->

    if !error
      # We've just turned our user into a subscribing customer. Chapeau!
      # Show some links so that we can fetch some data about the subscription
      # or to cancel the subscription.
      res.send '<strong>Thanks for subscribing to our service!</strong><br/><br/>
      Click <a href="/subscription/'+data["PROFILEID"]+'/info" target="_blank">here</a>
      to fetch details about your subscription or 
      <a href="/subscription/'+data["PROFILEID"]+'/cancel" target="_blank">here</a> if
      you want to cancel your subscription.'

    else
      # PayPal's API can be down or more probably, you provided an invalid token. 
      return res.send "Temporary error or invalid token, please come back later"


app.get "/purchase/fail", (req,res) ->

  # The user gets returned here when he/she didn't go through with the PayPal
  # login/account creation. 
  res.send "Aww. We're so sorry that you didn't go through with our subscription. Next time maybe?"

app.get "/subscription/:pid/info", (req, res) ->

  # Show an error if we didn't get a PROFILEID
  pid = req.params.pid ? false
  return res.send "Invalid request.", 500 if !pid

  # Fetch subscription data based upon given PROFILEID
  paypal.getSubscription pid, (error, data) ->

    return res.json data if !error

    res.send "Your subscription doesn't exist or we couldn't reach PayPal's API right now"


app.get "/subscription/:pid/cancel", (req, res) ->

  # Show an error if we didn't get a PROFILEID
  pid = req.params.pid ? false
  return res.send "Invalid request.", 500 if !pid

  paypal.modifySubscription pid, "Cancel", (error, data) ->

    if !error and data["ACK"] isnt "Failure"
      res.send "<pre>" + JSON.stringify(data, null, 4) + "</pre>
      <br/><br/>
      <a href=\"/subscription/"+pid+"/info\">
      Check status now for the subscription and it should have changed to \"Cancelled\"</a>"

    else
      # PayPal's API can be down or more probably, you provided an invalid PROFILEID. 
      res.send "Your subscription either doesn't exist, is already cancelled or
      something just went plain wrong..."

app.listen(3000)

console.log "Open http://localhost:3000 in your browser to launch the demo"