# Inclusive
getRandomInt = (min, max) ->
	Math.floor Math.random() * (max - min + 1) + min

initializeViews = (game) ->
	game.views =
		menu:
			new Vue
				el: '#menu'
				data:
					show: true
				methods:
					selectMode: ->
						this.show = false
						game.views.modes.show = true
					selectSettings: ->
						this.show = false
						game.views.settings.show = true
					startGame: ->
						this.show = false
						setTimeout ->
								game.startGame()
							, 1000
		modes:
			new Vue
				el: '#modes'
				data:
					show: false
				methods:
					back: ->
						this.show = false
						game.views.menu.show = true
					selectMode: (event) ->
						this.back()
		settings:
			new Vue
				el: '#settings'
				data:
					show: false
				methods:
					back: ->
						this.show = false
						game.views.menu.show = true
					enterFullscreen: ->
						el = document.documentElement
						if el.webkitRequestFullscreen?
							el.webkitRequestFullscreen()
						else if el.requestFullscreen
							el.requestFullscreen()
						else if el.msRequestFullscreen
							el.msRequestFullscreen()
						else
							el.mozRequestFullScreen()
						this.back()
		gameover:
			new Vue
				el: '#end'
				data:
					show: false
					stats: game.stats
				methods:
					restart: ->
						game.initialize()
						this.show = false
						setTimeout ->
							game.startGame()
						, 1000
					showMenu: ->
						game.initialize()
						this.show = false
						game.views.menu.show = true

endGame = (game) ->
	game.views.gameover.show = true

class Game
	constructor: (@canvas, @ctx, @dimens) ->
		@delay = undefined
		@paused = true
		@stats =
			targets: 0
			bonus: 0
			time: 0
		Target.image = new Image()
		Target.image.onload = =>
			@initialize()
			return
		Target.image.src = 'target.svg'
		canvas.addEventListener 'mousedown', (e) =>
			@clickHandler e.pageX - e.target.offsetLeft, e.pageY - e.target.offsetTop unless @paused
		# For ticking:
		@lastTime = @prevElapsed = @prevElapsed2 = 0

	clickHandler: (x, y) ->
		if @delay isnt undefined then return
		@clicks.push new Click x, y
		for target in @targets by -1
			if not target.destroyed
				distance = target.clickBonus x, y
				if distance <= target.radius
					@stats.targets++
					@stats.bonus += 1 - distance / target.radius
					@shrinkRadii() if @stats.targets <= 100 and @stats.targets % 10 is 0
					target.destroy() # Signal clicked
					@generateTarget()
					return
		# Didn't click a circle
		@gameOver()
		return

	startGame: ->
		@paused = false
		@canvas.style.cursor = 'none'
		requestAnimationFrame => @tick()

	initialize: ->
		scalar = Math.min @dimens.width, @dimens.height
		@MIN_RADIUS = 0.25 * scalar
		@MAX_RADIUS = 0.3 * scalar
		@delay = undefined
		@stats.targets = 0
		@stats.bonus = 0
		@stats.time = 0
		@targets = []
		@clicks = []
		@generateTarget() for i in [1..3]
		@paused = true
		@render()

	gameOver: ->
		@canvas.style.cursor = 'auto'
		endGame this
		@paused = true
		@render()

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
		needsRender = false
		if @delay isnt undefined
			@delay.time -= delta
			if @delay.time <= 0
				@delay.callback.bind(this)()
				@delay = undefined
			return
		newTargets = []
		for target in @targets
			if not target.destroyed or target.tick delta > 0
				newTargets.push target
			needsRender = needsRender || target.destroyed
		@targets = newTargets
		needsRender = needsRender || @clicks.length > 0
		newClicks = []
		for click in @clicks
			if click.tick delta > 0
				newClicks.push click
		@clicks = newClicks
		@stats.time += delta / 1000
		@render() if needsRender
		@gameOver() if @targets.length is 0

	tick: ->
		requestAnimationFrame => @tick() unless @paused
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
	constructor: (@x, @y, @radius, @minRadius) ->
		@destroyed = false

	clickBonus: (x, y) ->
		Math.sqrt(Math.pow(@x + @radius - x, 2) + Math.pow(@y + @radius - y, 2))

	destroy: ->
		@ttl = Target.animationLength
		@destroyed = true

	render: (ctx) ->
		ctx.save()
		# Draw svg
		ctx.globalAlpha = @ttl / Target.animationLength if @destroyed
		ctx.drawImage Target.image, @x, @y, @radius * 2, @radius * 2
		# Add outline
		ctx.beginPath()
		ctx.arc @x + @radius, @y + @radius, @radius + 0.5, 0, 2 * Math.PI, false
		ctx.lineWidth = 1
		ctx.strokeStyle = 'black'
		ctx.stroke()
		ctx.restore()

	tick: (delta) ->
		# Animate growth
		@x -= delta / 2
		@y -= delta / 2
		@radius += delta
		@ttl -= delta


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
	app = new Game canvas, ctx, {width: canvas.width / pixelRatio, height: canvas.height / pixelRatio, ratio: pixelRatio}
	# Setup Vue instances for menus
	initializeViews app

