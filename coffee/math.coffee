###
Decimal adjustment of a number.

@param {String}  type  The type of adjustment.
@param {Number}  value The number.
@param {Integer} exp   The exponent (the 10 logarithm of the adjustment base).
@returns {Number} The adjusted value.
###
decimalAdjust = (type, value, exp) ->
	# If the exp is undefined or zero...
	if typeof exp is 'undefined' or +exp is 0
		return Math[type](value)
	value = +value
	exp = +exp
	# If the value is not a number or the exp is not an integer...
	if isNaN(value) or !(typeof exp is 'number' and exp % 1 is 0)
		return NaN
	# Shift
	value = value.toString().split('e')
	value = Math[type](+(value[0] + 'e' + (if value[1] then (+value[1] - exp) else -exp)))
	# Shift back
	value = value.toString().split('e')
	return +(value[0] + 'e' + (if value[1] then (+value[1] + exp) else exp))

# Decimal round
Math.round10 ?= (value, exp) ->
	return decimalAdjust 'round', value, exp

# Decimal floor
Math.floor10 ?= (value, exp) ->
	return decimalAdjust 'floor', value, exp

# Decimal ceil
Math.ceil10 ?= (value, exp) ->
	return decimalAdjust 'ceil', value, exp

Math.getRandom ?= (min, max) ->
	return Math.random() * (max - min) + min

Math.hypot ?= (args...) ->
	Math.sqrt args.reduce (previous, current) ->
			previous + current ** 2
		, 0