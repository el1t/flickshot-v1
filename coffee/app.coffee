# Inclusive
getRandomInt = (min, max) ->
	Math.floor Math.random() * (max - min + 1) + min

class Game
	constructor: (@canvas, @ctx, @dimens) ->
		@delay = undefined
		Target.image = new Image()
		Target.image.onload = =>
			@startGame()
			requestAnimationFrame => @tick()
			return
		Target.image.src = 'target.svg'
		canvas.addEventListener 'mousedown', (e) =>
			@clickHandler e.pageX - e.target.offsetLeft, e.pageY - e.target.offsetTop
		# For ticking:
		@lastTime = @prevElapsed = @prevElapsed2 = 0

	clickHandler: (x, y) ->
		if @delay isnt undefined then return
		@clicks.push new Click x, y
		for target in @targets by -1
			if not target.destroyed and target.clickWithin x, y
				@score++
				@shrinkRadii() if @score <= 100 and @score % 10 is 0
				target.destroy() # Signal clicked
				@generateTarget()
				return
		# Didn't click a circle
		@gameOver()
		return

	startGame: ->
		scalar = Math.min @dimens.width, @dimens.height
		@MIN_RADIUS = 0.25 * scalar
		@MAX_RADIUS = 0.3 * scalar
		@delay = undefined
		@initialize()
		@generateTarget() for i in [1..3]
		@canvas.style.cursor = 'none'

	initialize: ->
		@score = 0
		@targets = []
		@clicks = []

	gameOver: ->
		console.log @score
		@canvas.style.cursor = 'auto'
		@delay =
			callback: @startGame
			time: 750
		@render undefined

	generateTarget: ->
		target = new Target getRandomInt(0, @dimens.width - 2 * @MAX_RADIUS),
			getRandomInt(0, @dimens.height - 2 * @MAX_RADIUS),
			getRandomInt(@MIN_RADIUS, @MAX_RADIUS),
			@MIN_RADIUS * 0.7
		@targets.push target

	shrinkRadii: ->
		@MIN_RADIUS *= .95
		@MAX_RADIUS *= .95

	render: ->
		# Clear screen
		@ctx.clearRect 0, 0, @canvas.width, @canvas.height
		for target in @targets
			target.render @ctx
		for click in @clicks
			click.render @ctx

	process: (delta) ->
		if @delay isnt undefined
			@delay.time -= delta
			if @delay.time <= 0
				@delay.callback.bind(this)()
				@delay = undefined
			return
		newTargets = []
		for target in @targets
			if target.tick delta
				newTargets.push target
		@targets = newTargets
		newClicks = []
		for click in @clicks
			if click.tick delta > 0
				newClicks.push click
		@clicks = newClicks
		@render delta
		@gameOver() if @targets.length is 0

	tick: ->
		requestAnimationFrame => @tick()
		currentTime = Date.now()
		elapsed = currentTime - @lastTime
		if elapsed > 0
			@lastTime = currentTime
			if @lastTime isnt 0
				elapsed = 1000 if elapsed > 1000
				@process (elapsed + @prevElapsed + @prevElapsed2) / 3
				@prevElapsed2 = @prevElapsed
				@prevElapsed = elapsed

class Target
	@image = undefined
	@animationLength = 10
	@duration = 3000
	constructor: (@x, @y, @radius, @minRadius) ->
		@deltaRadius = @radius - @minRadius
		@ttl = Target.duration
		@destroyed = false

	clickWithin: (x, y) ->
		Math.sqrt(Math.pow(@x + @radius - x, 2) + Math.pow(@y + @radius - y, 2)) <= @radius

	destroy: ->
		@ttl = Target.animationLength
		@destroyed = true

	render: (ctx) ->
		ctx.save()
		# Draw svg
		ctx.globalAlpha = @ttl / Target.animationLength if @destroyed
		ctx.drawImage Target.image, @x, @y, @radius * 2, @radius * 2
		unless @destroyed
			ctx.beginPath()
			ctx.arc @x + @radius, @y + @radius, @radius, 0, 2 * Math.PI, false
			ctx.fillStyle = 'rgba(255, 0, 0, ' + (1 - @ttl / Target.duration) + ')'
			ctx.fill()
		# Add outline
		ctx.beginPath()
		ctx.arc @x + @radius, @y + @radius, @radius + 0.5, 0, 2 * Math.PI, false
		ctx.lineWidth = 1
		ctx.strokeStyle = 'black'
		ctx.stroke()
		ctx.restore()

	tick: (delta) ->
		@ttl -= delta
		if @destroyed
			# Animate growth
			@x -= delta / 2
			@y -= delta / 2
			@radius += delta
		else
			newRadius = @minRadius + @ttl / Target.duration * @deltaRadius
			@x += (@radius - newRadius) / 2
			@y += (@radius - newRadius) / 2
			@radius = newRadius
		return @ttl > 0


class Click
	@timeout = 20
	constructor: (@x, @y) ->
		@ttl = Click.timeout

	render: (ctx) ->
		ctx.save()
		ctx.globalAlpha = @ttl / Click.timeout
		ctx.beginPath()
		ctx.arc @x, @y, 5, 0, 2 * Math.PI, false
		ctx.fillStyle = 'red'
		ctx.fill()
		ctx.lineWidth = 2
		ctx.strokeStyle = 'yellow'
		ctx.stroke()
		ctx.restore()

	tick: (delta) ->
		@ttl -= delta

window.onload = ->
	canvas = document.getElementById 'canvas'
	ctx = canvas.getContext '2d'
	# Handle high-DPI displays
	pixelRatio = window.devicePixelRatio
	canvas.width = window.innerWidth * pixelRatio
	canvas.height = window.innerHeight * pixelRatio
	ctx.scale pixelRatio, pixelRatio
	new Game canvas, ctx, {width: canvas.width / pixelRatio, height: canvas.height / pixelRatio, ratio: pixelRatio}