request =     require 'request'
querystring = require 'querystring'
util =        require 'util'

# This class helps to create PayPal recurring subscriptions through the
# PayPal API.
#
# To learn how to integrate it with your application, have a look at unit
# tests in the test folder and the provided example using express.js
#
# Note that you need to pass a valid set of PayPal API username, password & signature
# to the class constructor for the class to work.
#
# If you don't already have those at hands, visit https://developer.paypal.com
#
# For general documentation, visit;
# * https://www.x.com/developers/paypal/documentation-tools/express-checkout/integration-guide/ECRecurringPayments
# * https://www.x.com/developers/paypal/documentation-tools/api
#
class Paypal
  
  constructor: (credentials, env) ->
    throw new Error "Missing username"  unless credentials.username
    throw new Error "Missing password"  unless credentials.password
    throw new Error "Missing signature" unless credentials.signature

    @credentials = credentials

    @apiVersion = 94

    if env is "production"
      @endpointUrl = "https://api-3t.paypal.com/nvp"
      @checkoutUrl = "https://www.paypal.com/cgi?bin/webscr?cmd=_express-checkout&token="
    else
      @endpointUrl = "https://api-3t.sandbox.paypal.com/nvp"
      @checkoutUrl = "https://www.sandbox.paypal.com/webscr?cmd=_express-checkout&token="

  # Returns an object with the basic requirements to complete an
  # API request to PayPal.
  #
  # By passing an object as an argument, you can overwrite any default
  # request option.
  #
  # Note: SetExpressCheckout is the default API method and need to be
  #       changed for other types of API requests.
  #
  getParams: (opts) ->
    @_merge({
      USER:      @credentials.username
      PWD:       @credentials.password
      SIGNATURE: @credentials.signature
      VERSION:   @apiVersion
      METHOD:    "SetExpressCheckout"
    }, opts ? {})

  # Authenticates your user by letting him/her either login or create
  # a new PayPal account to accept your recurring payment.
  #
  # Upon success, the callback is invoked and passed two arguments:
  #  (1): error  False when no error present or containing error information
  #  (2): token  The paypal token
  #  (2): data   Containing the result of the API request with the Express checkout
  #              token that we need to take the checkout to the next step.
  #
  # Related API documentation:
  # https://www.x.com/developers/paypal/documentation-tools/api/setexpresscheckout-api-operation-nvp
  #
  authenticate: (opts, callback) ->

    self = @

    # Check for required params and throw error(s) if they aren't available
    reqs = [
      "RETURNURL",
      "CANCELURL",
      "PAYMENTREQUEST_0_AMT",
      "L_BILLINGAGREEMENTDESCRIPTION0"
    ]
    
    for i in reqs
      throw new Error "Missing param " + i if !opts[i]

    # Merge given params with default params for this type of API request.
    opts = @_merge({
      ADDROVERRIDE:          0
      ALLOWNOTE:             0
      BUYEREMAILOPTINENABLE: 1
      L_BILLINGTYPE0:        "RecurringPayments"
      NOSHIPPING:            1
      SURVEYENABLE:          0
    }, opts)

    @makeAPIrequest @getParams(opts), (err, response) ->
      return callback err, null, null if err

      return callback "Missing token", null, null unless response["TOKEN"]

      callback null, response, self.checkoutUrl + response["TOKEN"]

  # Creates a recurring payment profile for your customer by invoking the
  # "CreateRecurringPaymentsProfile" method in the PayPal API.
  #
  # To do this, you need to pass the function the unique token that you
  # recieve as a querystring appended to your RETURNURL sent to PayPal
  # using the above authenticate() method.
  #
  # This method takes below arguments:
  #  token (string)      The token as described above
  #  payerid (string)    The PayPal ID of the owner of the to-become subscriber
  #  opts  (object)      The object containing the options you want to send to PayPal
  #  callback (function) The Callback function that is invoked on API return
  #
  # Note that if you do not pass a PROFILESTARTDATE in the ops object, a PROFILESTARTDATE
  # with current time will be used to start the recurring payment immediately.
  #
  # Related API documentation:
  # https://www.x.com/developers/paypal/documentation-tools/api/createrecurringpaymentsprofile-api-operation-nvp
  #
  createSubscription: (token, payerid, opts, callback) ->
    
    self = @

    # Check for required arguments and params and throw error(s) if they aren't available
    throw new Error "Missing required token" unless token
    throw new Error "Missing payerid"        unless payerid

    reqs = [
      "DESC",
      "BILLINGPERIOD",
      "BILLINGFREQUENCY",
      "AMT"
    ]

    for i in reqs
      throw new Error "Missing param " + i if !opts[i]

    # Merge given params with default params for this type of API request.
    opts = @_merge({
      METHOD:           "CreateRecurringPaymentsProfile"
      TOKEN:            token
      PAYERID:          payerid
      INITAMT:          0
      PROFILESTARTDATE: new Date()
    }, opts)

    # Format the date
    opts["PROFILESTARTDATE"] = @_formatDate(opts["PROFILESTARTDATE"])
    
    @makeAPIrequest @getParams(opts), (err, response) ->
      
      return callback err, null if err

      return callback err ? true, null if response["ACK"] isnt "Success"

      callback err, response

  # Returns subscription information for an already created subscription by
  # invoking the "GetRecurringPaymentsProfileDetails" method in the PayPal API.
  #
  # The API response contains Profile status (whether or not your customer is paying),
  # how many failed billings to this date, next billing date and more. See PayPal's
  # own API documentation for full info. (Link below)
  #
  # This method takes below arguments:
  #  id (string)         The profile id of the subscription you want to return info on.
  #  callback (function) The Callback function that is invoked on API return
  #
  # Related API documentation:
  # https://www.x.com/developers/paypal/documentation-tools/api/getrecurringpaymentsprofiledetails-api-operation-nvp
  #
  getSubscription: (id, callback) ->
    
    # Ensure that we have a profile ID
    throw new Error "Missing profile id" unless id

    params = @getParams(
      METHOD:    "GetRecurringPaymentsProfileDetails"
      PROFILEID: id
    )

    @makeAPIrequest params, (err, response) ->
      
      return callback err, null if err

      return callback err ? true, null if response["ACK"] isnt "Success"

      callback err, response

  # Modifies the state of an existing subscription by invoking the
  # ManageRecurringPaymentsProfileStatus on the PayPal API.
  #
  # Note that the API action defaults to "cancel" when no action is given.
  #
  # This method takes below arguments:
  #  id (string)         The profile id of the subscription you want to return info on.
  #  action (string)     The action to be performed. May be "Cancel", "Suspend" or "Reactivate"
  #  callback (function) The Callback function that is invoked on API return
  #
  # Related API documentation:
  # https://www.x.com/developers/paypal/documentation-tools/api/managerecurringpaymentsprofilestatus-api-operation-nvp
  #
  modifySubscription: (id, action, note, callback) ->
    
    # Ensure that we have a profile ID
    throw new Error "Missing profile id" unless id
    
    args =     Array::slice.call(arguments)
    callback = args[args.length-1]

    # Default action to "Cancel" and uppercase first char
    action =   "Cancel" if typeof action is "function"
    action = action.charAt(0).toUpperCase() + action.slice(1)

    params = @getParams(
      METHOD:    "ManageRecurringPaymentsProfileStatus"
      PROFILEID: id
      ACTION:    action
    )

    params["NOTE"] = note if typeof note is "string"

    @makeAPIrequest params, (err, response) ->
      
      return callback err, null if err

      return callback err ? true, null if response["ACK"] isnt "Success"

      callback err, response

  # Performs the actual API request to the PayPal API endpoint.
  #
  # Mock this function to test this class when integrating with your
  # own code
  #
  makeAPIrequest: (params, callback) ->

    request.post @endpointUrl, {form: params}, (err, response, body) ->

      # We got an error. Network error maybe. Interwebs broken and such.
      if err
        return callback err, null

      # Non HTTP-200 response from API
      if response.statusCode isnt 200
        return callback querystring.parse(body) ? response.statusCode, null

      # Sailing smoothly. Parse query-string formatted body and return.
      callback null, querystring.parse(body)

  # Merges two objects passed as arguments.
  # Note that any property in the object passed as second argument will
  # overwrite any property in the object passed as first argument
  #
  _merge: (a, b) ->
    # Clone the first object
    # We don't want to overwrite things in our referenced objects
    # passed as arguments, so create a fresh copy of (a)
    c = {}
    c[i] = a[i] for i of a

    # Merge!
    c[i] = b[i] for i of b
    c

  # Converts a given date into UTC and then into the ISO format which PayPal
  # requires to set dates for billing, for example.
  #
  # The method takes a date object and returns the object as string.
  #
  _formatDate: (d) ->

    throw new Error "Date isn't a valid date object" unless util.isDate(d)

    date_utc = new Date(
      d.getUTCFullYear(),
      d.getUTCMonth(),
      d.getUTCDate(),
      d.getUTCHours(),
      d.getUTCMinutes(),
      d.getUTCSeconds()
    )

    date_utc.toISOString()

module.exports = Paypal