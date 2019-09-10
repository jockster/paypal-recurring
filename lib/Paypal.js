(function() {
  var Paypal, querystring, request, util;
  request = require('request');
  querystring = require('querystring');
  util = require('util');

  Paypal = (function() {
    function Paypal(credentials, env) {
      if (!credentials.username) {
        throw new Error("Missing username");
      }
      if (!credentials.password) {
        throw new Error("Missing password");
      }
      if (!credentials.signature) {
        throw new Error("Missing signature");
      }
      this.credentials = credentials;
      this.apiVersion = 94;
      if (env === "production") {
        this.endpointUrl = "https://api-3t.paypal.com/nvp";
        this.checkoutUrl = "https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=";
      } else {
        this.endpointUrl = "https://api-3t.sandbox.paypal.com/nvp";
        this.checkoutUrl = "https://www.sandbox.paypal.com/webscr?cmd=_express-checkout&token=";
      }
    }

    Paypal.prototype.getParams = function(opts) {
      return this._merge({
        USER: this.credentials.username,
        PWD: this.credentials.password,
        SIGNATURE: this.credentials.signature,
        VERSION: this.apiVersion,
        METHOD: "SetExpressCheckout"
      }, opts != null ? opts : {});
    };

    Paypal.prototype.authenticate = function(opts, callback) {
      var i, j, len, reqs, self;
      self = this;
      reqs = ["RETURNURL", "CANCELURL", "PAYMENTREQUEST_0_AMT", "L_BILLINGAGREEMENTDESCRIPTION0"];
      for (j = 0, len = reqs.length; j < len; j++) {
        i = reqs[j];
        if (!opts[i]) {
          throw new Error("Missing param " + i);
        }
      }
      opts = this._merge({
        ADDROVERRIDE: 0,
        ALLOWNOTE: 0,
        BUYEREMAILOPTINENABLE: 1,
        L_BILLINGTYPE0: "RecurringPayments",
        NOSHIPPING: 1,
        SURVEYENABLE: 0
      }, opts);
      return this.makeAPIrequest(this.getParams(opts), function(err, response) {
        if (err) {
          return callback(err, null, null);
        }
        if (!response["TOKEN"]) {
          return callback("Missing token", null, null);
        }
        return callback(null, response, self.checkoutUrl + response["TOKEN"]);
      });
    };

    Paypal.prototype.createSubscription = function(token, payerid, opts, callback) {
      var i, j, len, reqs, self;
      self = this;
      if (!token) {
        throw new Error("Missing required token");
      }
      if (!payerid) {
        throw new Error("Missing payerid");
      }
      reqs = ["DESC", "BILLINGPERIOD", "BILLINGFREQUENCY", "AMT"];
      for (j = 0, len = reqs.length; j < len; j++) {
        i = reqs[j];
        if (!opts[i]) {
          throw new Error("Missing param " + i);
        }
      }
      opts = this._merge({
        METHOD: "CreateRecurringPaymentsProfile",
        TOKEN: token,
        PAYERID: payerid,
        INITAMT: 0,
        PROFILESTARTDATE: new Date()
      }, opts);
      opts["PROFILESTARTDATE"] = this._formatDate(opts["PROFILESTARTDATE"]);
      return this.makeAPIrequest(this.getParams(opts), function(err, response) {
        console.log(err);
        console.log(response);
        if (err) {
          return callback(err, null);
        }
        if (response["ACK"] !== "Success") {
          return callback(new Error(self._getFailureInfo(response)), null);
        }
        return callback(err, response);
      });
    };

    Paypal.prototype.getSubscription = function(id, callback) {
      var params, self;
      if (!id) {
        throw new Error("Missing profile id");
      }
      self = this;
      params = this.getParams({
        METHOD: "GetRecurringPaymentsProfileDetails",
        PROFILEID: id
      });
      return this.makeAPIrequest(params, function(err, response) {
        if (err) {
          return callback(err, null);
        }
        if (response["ACK"] !== "Success") {
          return callback(new Error(self._getFailureInfo(response)), null);
        }
        return callback(err, response);
      });
    };

    Paypal.prototype.updateSubscription = function(id, opts, callback) {
      var params, opts, self;
      if (!id) {
        throw new Error("Missing profile id");
      }
      self = this;
      opts = this._merge({
        METHOD: "UpdateRecurringPaymentsProfile",
        PROFILEID: id
      }, opts);
      params = this.getParams(opts);
      return this.makeAPIrequest(params, function(err, response) {
        if (err) {
          return callback(err, null);
        }
        if (response["ACK"] !== "Success") {
          return callback(new Error(self._getFailureInfo(response)), null);
        }
        return callback(err, response);
      });
    };
   
    Paypal.prototype.modifySubscription = function(id, action, note, callback) {
      var args, params, self;
      if (!id) {
        throw new Error("Missing profile id");
      }
      self = this;
      args = Array.prototype.slice.call(arguments);
      callback = args[args.length - 1];
      if (typeof action === "function") {
        action = "Cancel";
      }
      action = action.charAt(0).toUpperCase() + action.slice(1);
      params = this.getParams({
        METHOD: "ManageRecurringPaymentsProfileStatus",
        PROFILEID: id,
        ACTION: action
      });
      if (typeof note === "string") {
        params["NOTE"] = note;
      }
      return this.makeAPIrequest(params, function(err, response) {
        if (err) {
          return callback(err, null);
        }
        if (response["ACK"] !== "Success") {
          return callback(new Error(self._getFailureInfo(response)), null);
        }
        return callback(err, response);
      });
    };

    Paypal.prototype.makeAPIrequest = function(params, callback) {
      return request.post(this.endpointUrl, {
        form: params
      }, function(err, response, body) {
        var ref;
        if (err) {
          return callback(err, null);
        }
        if (response.statusCode !== 200) {
          return callback((ref = querystring.parse(body)) != null ? ref : response.statusCode, null);
        }
        return callback(null, querystring.parse(body));
      });
    };

    Paypal.prototype._merge = function(a, b) {
      var c, i;
      c = {};
      for (i in a) {
        c[i] = a[i];
      }
      for (i in b) {
        c[i] = b[i];
      }
      return c;
    };

    Paypal.prototype._formatDate = function(d) {
      if (!util.isDate(d)) {
        throw new Error("Date isn't a valid date object");
      }
      return d.toISOString();
    };

    Paypal.prototype._getFailureInfo = function(response) {
      var result = "";
      var appended = false;
      if(response){
        if(response.L_ERRORCODE0){ result += response.L_ERRORCODE0; appended = true; }
        if(appended) { result += " - "; }
        if(response.L_SHORTMESSAGE0){ result += response.L_SHORTMESSAGE0; appended = true; }
        if(appended) { result += " - "; }
        if(response.L_LONGMESSAGE0){ result += response.L_LONGMESSAGE0; appended = true; }
      }
      if(!appended){
        result = "An error ocurred but no information was provided in the response.";
      }
      return(result);
    };

    return Paypal;

  })();

  module.exports = Paypal;

}).call(this);