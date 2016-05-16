# Inclusive
getRandomInt = (min, max) ->
	Math.floor Math.random() * (max - min + 1) + min

initializeViews = (game) ->
	window.addEventListener 'resize', ->
			pixelRatio = window.devicePixelRatio
			game.dimens.width = window.innerWidth
			game.dimens.height = window.innerHeight
			game.canvas.width = game.dimens.width * pixelRatio
			game.canvas.height = game.dimens.height * pixelRatio
			game.ctx.scale pixelRatio, pixelRatio
			game.render()
		, true
	game.views =
		menu:
			new Vue
				el: '#menu'
				data:
					show: true
				methods:
					select: (event) ->
						this.show = false
						switch event.target.innerHTML.toLowerCase()
							when 'instructions' then game.views.instructions.show = true
							when 'change mode' then game.views.modes.show = true
							when 'settings' then game.views.settings.show = true
							when 'start'
								setTimeout ->
									game.startGame()
								, 1000
		instructions:
			new Vue
				el: '#instructions'
				data:
					show: false
				methods:
					back: ->
						this.show = false
						game.views.menu.show = true
		modes:
			new Vue
				el: '#modes'
				data:
					show: false
				methods:
					back: ->
						this.show = false
						game.views.menu.show = true
					select: (event) ->
						prevMode = game.mode
						game.mode = Game.modes[event.target.innerHTML.toLowerCase()]
						unless prevMode is game.mode
							game.initialize()
						this.back()
		settings:
			new Vue
				el: '#settings'
				data:
					show: false
					fullscreen: false
				methods:
					back: ->
						this.show = false
						game.views.menu.show = true
					toggleFullscreen: ->
						if document.fullscreenElement? or document.webkitFullscreenElement? or
						document.mozFullScreenElement? or document.msFullscreenElement?
							if document.exitFullscreen
								document.exitFullscreen()
							else if document.mozCancelFullScreen
								document.mozCancelFullScreen()
							else if document.webkitExitFullscreen
								document.webkitExitFullscreen()
						else
							el = document.documentElement
							if el.webkitRequestFullscreen
								el.webkitRequestFullscreen()
							else if el.requestFullscreen
								el.requestFullscreen()
							else if el.msRequestFullscreen
								el.msRequestFullscreen()
							else
								el.mozRequestFullScreen()
						this.fullscreen = not this.fullscreen
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
		canvas:
			new Vue
				el: '#canvas'
				data:
					mouse: true
				computed:
					styles: ->
						cursor:
							if this.mouse then 'auto' else 'none'

endGame = (game) ->
	game.views.gameover.show = true

class Game
	@modes =
		normal:
			rMin: 0.25
			rMax: 0.3
			growth: 0.95
			targetCount: 3
			time: 3000
		flick:
			rMin: 0.2
			rMax: 0.2
			growth: 0.98
			targetCount: 1
			time: 2000
		reaction:
			rMin: 0.15
			rMax: 0.15
			growth: 1
			delay: true
			time: 1500
		accuracy:
			rMin: 0.1
			rMax: 0.1
			growth: 0.98
			targetCount: 2
			time: 4000
		practice:
			rMin: 0.25
			rMax: 0.3
			growth: 1
			targetCount: 3
			showCursor: true
	constructor: (@canvas, @ctx, @dimens) ->
		@paused = true
		@stats =
			targets: 0
			bonus: 0
			time: 0
		@mode = Game.modes.normal
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
		@clicks.push new Click x, y
		for target in @targets by -1
			if not target.destroyed
				distance = target.clickBonus x, y
				if distance <= target.radius
					@stats.targets++
					@time = Math.min @time + @mode.time / 3, @mode.time
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
#		@canvas.style.cursor = 'none'
		@views.canvas.mouse = @mode.showCursor
		requestAnimationFrame => @tick()

	initialize: ->
		scalar = Math.min @dimens.width, @dimens.height
		@rMin = @mode.rMin * scalar
		@rMax = @mode.rMax * scalar
		@time = @mode.time
		@stats.targets = 0
		@stats.bonus = 0
		@stats.time = 0
		@targets = []
		@clicks = []
		@generateTarget() for i in [1..@mode.targetCount]
		@paused = true
		@render()
		return

	gameOver: ->
#		@canvas.style.cursor = 'auto'
		@views.canvas.mouse = true
		endGame this
		@paused = true
		@render()
		return

	generateTarget: ->
		target = new Target getRandomInt(0, @dimens.width - 2 * @rMax),
			getRandomInt(0, @dimens.height - 2 * @rMax),
			getRandomInt(@rMin, @rMax),
			@rMin * 0.7
		@targets.push target
		return

	shrinkRadii: ->
		@rMin *= @mode.growth
		@rMax *= @mode.growth
		return

	render: (fullRender=true) ->
		if (fullRender)
			# Clear screen
			@ctx.clearRect 0, 0, @dimens.width, @dimens.height
			for target in @targets
				target.render @ctx
			for click in @clicks
				click.render @ctx
		@ctx.save()
		@ctx.fillStyle = 'white'
		@ctx.fillRect 0, @dimens.height - 10, @dimens.width, 10
		@ctx.fillStyle = 'red'
		@ctx.fillRect @time / @mode.time * @dimens.width, @dimens.height - 10, @dimens.width, 10
		@ctx.restore()
		return

	process: (delta) ->
		needsRender = false
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
		@time -= delta
		@stats.time += delta / 1000
		@render(needsRender)
		@gameOver() if @targets.length is 0 or @time < 0
		return

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
		return

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
		return

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
	app = new Game canvas, ctx, {width: window.innerWidth, height: window.innerHeight}
	# Setup Vue instances for menus
	initializeViews app

