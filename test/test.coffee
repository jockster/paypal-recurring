assert = require("chai").assert
sinon =  require "sinon"
util =   require "util"

describe "constructor", ->

  describe "Throws errors when required params are missing", ->

    beforeEach ->
      @paypal = require "../"

    it "Throws error when username is missing", ->
      self = @
      assert.throws (-> new self.paypal ), /username/

    it "Throws error when password is missing", ->
      self = @
      assert.throws (-> new self.paypal(username: 1) ), /password/

    it "Throws error when signature is missing", ->
      self = @
      assert.throws (-> new self.paypal(username: 1, password: 1) ), /signature/

    it "Throws no error when all required params are given", ->
      self = @
      assert.doesNotThrow ->
        new self.paypal username: 1, password: 1, signature: 1

  describe "Stores data internally as intended", ->

    before ->
      paypal = require "../"
      @p = new paypal username: "u", password: "p", signature: "s"

    it "Password/username/signature is correct", ->
      assert.equal Object.keys(@p.credentials).length, 3
      assert.equal @p.credentials.password,  "p"
      assert.equal @p.credentials.username,  "u"
      assert.equal @p.credentials.signature, "s"

    it "apiVersion is at least 94", ->
      assert.operator @p.apiVersion, ">=", 94

  describe "URL's changes accordingly with environment", ->

    beforeEach ->
      @paypal = require "../"

    it "Sandbox is used as default", ->
      p = new @paypal username: "u", password: "p", signature: "s"
      assert.match p.endpointUrl, /sandbox.paypal.com/
      assert.match p.checkoutUrl, /sandbox.paypal.com/

    it "Default API_URL is used in production", ->
      p = new @paypal {username: "u", password: "p", signature: "s"}, "production"
      assert.notMatch p.endpointUrl, /sandbox/
      assert.notMatch p.checkoutUrl, /sandbox/

describe "_merge()", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"

  it "Merges two objects properly", ->

    a = one: 1, two: 2, three: 3
    b = four: 4
    c = @p._merge a, b

    assert.equal Object.keys(a).length, 3
    assert.equal Object.keys(b).length, 1
    assert.equal Object.keys(c).length, 4

  it "Overwrites props in the first object with props from the second", ->
    a = user: "John Doe"
    b = user: "Jane Doe"
    c = @p._merge a, b

    assert.equal c.user, "Jane Doe"

describe "_formatDate()", ->
  
  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"

  it "Passing a non-date argument results in error", ->
    self = @
    assert.throws (-> self.p._formatDate("HELLO!") ), /Date/

  it "Passing a date argument causes no error", ->
    self = @
    assert.doesNotThrow (-> self.p._formatDate(new Date()) )

  it "Returns a string", ->
    assert.typeOf @p._formatDate(new Date()), "string"

  it "Returns a valid date", ->
    d = @p._formatDate(new Date())
    assert.ok util.isDate(new Date(d))  

describe "getParams", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"

  it "Returns the basic fields and uses SetExpressCheckout as default", ->
    req = @p.getParams()
    assert.equal req.PWD,        "p"
    assert.equal req.USER,       "u"
    assert.equal req.SIGNATURE,  "s"
    assert.equal req.METHOD,     "SetExpressCheckout"
    assert.operator req.VERSION, ">=", 94

  it "Allows overriding default properties and custom args", ->
    req = @p.getParams METHOD: "CustomMethod", ANOTHERARG: "Hi!"

    assert.equal req.METHOD, "CustomMethod"
    assert.equal req.ANOTHERARG, "Hi!"

describe "authenticate()", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"
    global.request = require "request"

    @requiredParams = 
      "RETURNURL":            "http://localhost/success",
      "CANCELURL":            "http://localhost/fail"
      "PAYMENTREQUEST_0_AMT": 10
      "L_BILLINGAGREEMENTDESCRIPTION0": "Test"

  afterEach ->
    if request.post
      request.post.restore() if request.post.restore

  it "Throws errors when required params aren't given", ->

    self = @

    assert.throws (->
      self.p.authenticate {}, ->
    ), /RETURNURL/

    assert.throws (->
      self.p.authenticate RETURNURL: 1, ->
    ), /CANCELURL/
    
    assert.throws (->
      self.p.authenticate RETURNURL: 1, CANCELURL: 1, ->
    ), /PAYMENTREQUEST_0_AMT/

    assert.throws (->
      self.p.authenticate RETURNURL: 1, CANCELURL: 1, PAYMENTREQUEST_0_AMT: 1, ->
    ), /L_BILLINGAGREEMENTDESCRIPTION0/
    
    assert.doesNotThrow (->
      self.p.authenticate {
        RETURNURL: 1
        CANCELURL: 1
        PAYMENTREQUEST_0_AMT: 1
        L_BILLINGAGREEMENTDESCRIPTION0: 1
      }, ->
    )

  it "Uses the correct PayPal API method", (done) ->
    sinon.stub request, "post", -> arguments[2](null, {statusCode: 200}, null)

    @p.authenticate @requiredParams, ->
      assert.equal request.post.args[0][1]["form"]["METHOD"], "SetExpressCheckout"
      done()

  it "Handles an erroneous request properly", (done) ->

    sinon.stub request, "post", -> arguments[2]("ERROR!", null, null)

    @p.authenticate @requiredParams, (error, data, url) ->
      assert.equal  error, "ERROR!"
      assert.isNull data
      assert.isNull url
      done()

  it "Handles an non-HTTP-200 response properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 500}, "ERROR=Darth%20vader%20is%20angry")

    @p.authenticate @requiredParams, (error, data, url) ->
      assert.deepEqual error, {ERROR: "Darth vader is angry"}
      #assert.equal  error, 500
      assert.isNull data
      assert.isNull url
      done()    

  it "Handles a correct/successful request properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 200}, "TOKEN=1")

    checkoutUrl = @p.checkoutUrl

    @p.authenticate @requiredParams, (error, data, url) ->

      assert.isNull    error
      assert.ok        data
      assert.deepEqual data, TOKEN: "1"
      assert.equal     url, checkoutUrl + "1"
      done()

describe "createSubscription()", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"
    global.request = require "request"

    @requiredParams = 
      AMT:              1
      DESC:             "Description"
      BILLINGPERIOD:    "Month"
      BILLINGFREQUENCY: 1

  afterEach ->
    request.post.restore() if request.post.restore

  it "Throws errors when required params aren't given", ->

    self = @

    # Test for missing token
    assert.throws (->
      self.p.createSubscription "", {}, ->
    ), /token/

    # Test for missing params
    assert.throws (->
      self.p.createSubscription "token", "payerid", ->
    ), /DESC/
    
    assert.throws (->
      self.p.createSubscription "token", "payerid", DESC: 1, ->
    ), /BILLINGPERIOD/

    assert.throws (->
      self.p.createSubscription "token", "payerid", {
        DESC:             1
        BILLINGPERIOD:    1
      }, ->
    ), /BILLINGFREQUENCY/

    assert.throws (->
      self.p.createSubscription "token", "payerid", {
        DESC:             1
        BILLINGPERIOD:    1
        BILLINGFREQUENCY: 1
      }, ->
    ), /AMT/

    assert.doesNotThrow (->
      self.p.createSubscription "token", "payerid", {
        DESC:             1
        BILLINGPERIOD:    1
        BILLINGFREQUENCY: 1
        AMT:              1
        PROFILESTARTDATE: new Date()
      }, ->
    )

  it "Uses the correct PayPal API method", (done) ->
    sinon.stub request, "post", -> arguments[2](null, {statusCode: 200}, null)

    @p.createSubscription "token", "payerid", @requiredParams, ->
      assert.equal request.post.args[0][1]["form"]["METHOD"], "CreateRecurringPaymentsProfile"
      done()

  it "Handles an erroneous request properly", (done) ->

    sinon.stub request, "post", -> arguments[2]("ERROR!", null, null)

    checkoutUrl = @p.checkoutUrl

    @p.createSubscription "token", "payerid", @requiredParams, (error, data) ->
      assert.equal error, "ERROR!"#    error
      assert.isNull data
      done()

  it "Handles a non HTTP 200 response properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 500}, "QUERY=STRING")

    checkoutUrl = @p.checkoutUrl

    @p.createSubscription "token", "payerid", @requiredParams, (error, data) ->
      #assert.deepEqu
      assert.deepEqual error, QUERY: "STRING"
      assert.isNull    data
      done()      
    
  it "Handles a correct/successful request properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 200}, "ACK=Success")

    checkoutUrl = @p.checkoutUrl

    @p.createSubscription "token", "payerid", @requiredParams, (error, data) ->
      assert.isNull    error
      assert.ok        data
      assert.deepEqual data, ACK: "Success"
      done()

describe "getSubscription()", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"
    global.request = require "request"

  afterEach ->
    request.post.restore() if request.post.restore

  it "Throws error when invoked without profile id", ->

    self = @

    assert.throws (->
      self.p.getSubscription "", ->
    ), /profile id/

  it "Uses the correct PayPal API method", (done) ->
    sinon.stub request, "post", -> arguments[2](null, {statusCode: 200}, null)

    @p.getSubscription "profileid", ->
      assert.equal request.post.args[0][1]["form"]["METHOD"], "GetRecurringPaymentsProfileDetails"
      done()

  it "Handles an erroneous request as intended", (done) ->

    sinon.stub request, "post", -> arguments[2]("ERROR!", null, null)

    checkoutUrl = @p.checkoutUrl

    @p.getSubscription "profileid", (error, data) ->
      assert.equal error, "ERROR!"#    error
      assert.isNull data
      done()

  it "Handles a non-HTTP 200 response properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 500}, "QUERY=STRING")

    checkoutUrl = @p.checkoutUrl

    @p.getSubscription "profileid", (error, data) ->
      assert.deepEqual error, QUERY: "STRING"
      assert.isNull    data
      done()      
    
  it "Handles a correct/successful request properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 200}, "ACK=Success")

    checkoutUrl = @p.checkoutUrl

    @p.getSubscription "profileid", (error, data) ->
      assert.isNull    error
      assert.ok        data
      assert.deepEqual data, ACK: "Success"
      done()

describe "modifySubscription()", ->

  before ->
    paypal = require "../"
    @p = new paypal username: "u", password: "p", signature: "s"
    global.request = require "request"

  afterEach ->
    request.post.restore() if request.post.restore

  it "Throws error when invoked without profile id", ->

    self = @

    assert.throws (->
      self.p.modifySubscription "", ->
    ), /profile id/

  it "Can be invoked without passing action & note arguments", ->

    self = @

    assert.doesNotThrow (->
      self.p.modifySubscription "profileid", ->
    )

  it "Handles an erroneous request as intended", (done) ->

    sinon.stub request, "post", -> arguments[2]("ERROR!", null, null)

    checkoutUrl = @p.checkoutUrl

    @p.modifySubscription "profileid", (error, data) ->
      assert.equal error, "ERROR!"#    error
      assert.isNull data
      done()

  it "Handles a non-HTTP 200 response properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 500}, "QUERY=STRING")

    checkoutUrl = @p.checkoutUrl

    @p.modifySubscription "profileid", (error, data) ->
      assert.deepEqual error, QUERY: "STRING"
      assert.isNull    data
      done()      
    
  it "Handles a correct/successful request properly", (done) ->

    sinon.stub request, "post", -> arguments[2](false, {statusCode: 200}, "ACK=Success")

    checkoutUrl = @p.checkoutUrl

    @p.modifySubscription "profileid", (error, data) ->
      assert.isNull    error
      assert.ok        data
      assert.deepEqual data, ACK: "Success"
      done()

  describe "Uses correct params", ->

      before (done)->
        self = @

        sinon.stub request, "post", -> arguments[2](null, {statusCode: 200}, null)
        
        @p.modifySubscription "profileid", ->
          self.args = request.post.args[0][1]
          request.post.restore()
          done()

      it "Uses the right API method", ->
        assert.equal @args["form"]["METHOD"], "ManageRecurringPaymentsProfileStatus"

      it "Uses \"Cancel\" as default action", ->
        assert.equal @args["form"]["ACTION"], "Cancel"      