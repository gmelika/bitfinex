# https://bitfinex.com/pages/api

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

request = require 'request'
crypto = require 'crypto'
qs = require 'querystring'
_ = require 'lodash'

module.exports = class Bitfinex

	constructor: (key, secret, nonceGenerator) ->
    @url = "https://api.bitfinex.com"
    @key = key
    @secret = secret
    @nonce = nonceGenerator

  retry: (method,args) ->
    self = @

    # make sure the callback (and any other fn)
    # is bound to Bitfinex
    _.each args, (arg, i) ->
      if _.isFunction(arg)
        args[i] = _.bind(arg, self);

    # run the failed method again with the same
    # arguments after wait
    setTimeout(
      -> method.apply(self, args)
      100
    );

	make_request: (sub_path, params, cb, counter) ->
    if !@key or !@secret
      return cb(new Error("missing api key or secret"))

    self = @
    path = '/v1/' + sub_path
    url = @url + path
    if @nonce?
      nonce = @nonce()
    else
      nonce = Math.round((new Date()).getTime() / 1000)
      
    nonce = JSON.stringify(nonce)

    payload = 
      request: path
      nonce: nonce

    for key, value of params
      payload[key] = value

    payload = new Buffer(JSON.stringify(payload)).toString('base64')
    signature = crypto.createHmac("sha384", @secret).update(payload).digest('hex')

    headers = 
      'X-BFX-APIKEY': @key
      'X-BFX-PAYLOAD': payload
      'X-BFX-SIGNATURE': signature

    request { url: url, method: "POST", headers: headers, timeout: 15000 }, (err,response,body)->
      if err || (response.statusCode != 200 && response.statusCode != 400)
        return cb new Error(err ? response.statusCode)
          
      try
        result = JSON.parse(body)
      catch error
        return cb(null, { messsage : body.toString() } )
      
      if result.message?
        if counter != 3 && result.message.indexOf("Nonce") != -1
          return self.retry self.make_request, [sub_path, params, cb, (counter||0)+1]
        return cb new Error(result.message + " - nonce: " + nonce)

      cb null, result
      

	make_public_request: (path, cb) ->

		url = @url + '/v1/' + path	

		request { url: url, method: "GET", timeout: 15000}, (err,response,body)->
      if err || (response.statusCode != 200 && response.statusCode != 400)
        return cb new Error(err ? response.statusCode)
          
      try
        result = JSON.parse(body)
      catch error
        return cb(null, { messsage : body.toString() } )
      
      if result.message?
        return cb new Error(result.message)

      cb null, result

	#####################################
	########## PUBLIC REQUESTS ##########
	#####################################                            

	ticker: (symbol, cb) ->

		@make_public_request('ticker/' + symbol, cb)

	today: (symbol, cb) ->

		@make_public_request('today/' + symbol, cb)		

	candles: (symbol, cb) ->

		@make_public_request('candles/' + symbol, cb)	

	lendbook: (currency, cb) ->

		@make_public_request('lendbook/' + currency, cb)	

	orderbook: (symbol, cb) ->

		@make_public_request('book/' + symbol, cb)

	trades: (symbol, cb) ->

		@make_public_request('trades/' + symbol, cb)

	lends: (currency, cb) ->

		@make_public_request('lends/' + currency, cb)		

	get_symbols: (cb) ->

		@make_public_request('symbols', cb)

	# #####################################
	# ###### AUTHENTICATED REQUESTS #######
	# #####################################   

	new_order: (symbol, amount, price, exchange, side, type, cb) ->

		params = 
			symbol: symbol
			amount: amount
			price: price
			exchange: exchange
			side: side
			type: type
			# is_hidden: is_hidden 

		@make_request('order/new', params, cb)  

	multiple_new_orders: (symbol, amount, price, exchange, side, type, cb) ->

		params = 
			symbol: symbol
			amount: amount
			price: price
			exchange: exchange
			side: side
			type: type

		@make_request('order/new/multi', params, cb)  

	cancel_order: (order_id, cb) ->

		params = 
			order_id: order_id

		@make_request('order/cancel', params, cb)  

	cancel_multiple_orders: (order_ids, cb) ->

		params = 
			order_ids: order_ids

		@make_request('order/cancel/multi', params, cb)

	order_status: (order_id, cb) ->

		params = 
			order_id: order_id

		@make_request('order/status', params, cb)  

	active_orders: (cb) ->

		@make_request('orders', {}, cb)  

	active_positions: (cb) ->

		@make_request('positions/', {}, cb)  

	past_trades: (symbol, timestamp, until_time, limit_trades, reverse, cb) ->

		params = 
			symbol: symbol
			timestamp: timestamp
			limit_trades: limit_trades
      until: until_time
      reverse: reverse

		@make_request('mytrades', params, cb)  

	new_offer: (symbol, amount, rate, period, direction, insurance_option, cb) ->

		params = 
			currency: currency
			amount: amount
			rate: rate
			period: period
			direction: direction
			insurance_option: insurance_option

		@make_request('offer/new', params, cb)  

	cancel_offer: (offer_id, cb) ->

		params = 
			order_id: order_id

		@make_request('offer/cancel', params, cb) 

	offer_status: (order_id, cb) ->

		params = 
			order_id: order_id

		@make_request('offer/status', params, cb) 

	active_offers: (cb) ->

		@make_request('offers', {}, cb) 

	active_credits: (cb) ->

	 	@make_request('credits', {}, cb) 

	wallet_balances: (cb) ->

		@make_request('balances', {}, cb)


