initializeViews = (game) ->
	window.addEventListener 'resize', ->
			game.dimens.width = window.innerWidth
			game.dimens.height = window.innerHeight
		, true

	Vue.transition 'countdown',
		type: 'animation'
		afterLeave: ->
			game.views.countdown.hide()
			game.startGame()

	game.views =
		menu:
			new Vue
				el: '#menu'
				data:
					show: true
				methods:
					select: (event) ->
						@show = false
						switch event.target.innerHTML.toLowerCase()
							when 'instructions' then game.views.instructions.show = true
							when 'change mode' then game.views.modes.show = true
							when 'settings' then game.views.settings.show = true
							when 'start' then game.views.countdown.start()
		instructions:
			new Vue
				el: '#instructions'
				data:
					show: false
				methods:
					back: ->
						@show = false
						game.views.menu.show = true
		modes:
			new Vue
				el: '#modes'
				data:
					show: false
				methods:
					back: ->
						@show = false
						game.views.menu.show = true
					select: (event) ->
						if event.target.innerHTML.toLowerCase() is 'custom'
							@show = false
							game.views.custom.show = true
							return
						needInitialization = false
						for own name, property of Game.modes[event.target.innerHTML.toLowerCase()]
							needInitialization ||= game.mode[name] isnt property
							game.mode[name] = property
						game.initialize() if needInitialization
		custom:
			new Vue
				el: '#custom'
				data:
					show: false
					mode: game.mode
				methods:
					select: (event) ->
						@show = false
						switch event.target.innerHTML.toLowerCase()
							when 'save'
								game.initialize()
								game.views.menu.show = true
								console.log Game.modes
		settings:
			new Vue
				el: '#settings'
				data:
					show: false
					fullscreen: false
				methods:
					back: ->
						@show = false
						game.views.menu.show = true
					toggleFullscreen: ->
						if document.fullscreenElement? or document.webkitFullscreenElement? or
						document.mozFullScreenElement? or document.msFullscreenElement?
							document.exitFullscreen?()
							document.mozCancelFullScreen?()
							document.webkitExitFullscreen?()
							document.msExitFullscreen?()
						else
							el = document.documentElement
							el.requestFullscreen?()
							el.msRequestFullscreen?()
							el.mozRequestFullScreen?()
							el.webkitRequestFullscreen?()
						@fullscreen = not @fullscreen
		gameover:
			new Vue
				el: '#end'
				data:
					show: false
					stats: game.stats
				methods:
					restart: ->
						game.initialize()
						@show = false
						game.views.countdown.start()
					showMenu: ->
						game.initialize()
						@show = false
						game.views.menu.show = true
		countdown:
			new Vue
				el: '#countdown'
				data:
					show: false
					animate: false
				methods:
					start: ->
						@show = true
						@animate = true
					hide: ->
						@show = false
						setTimeout =>
								@animate = false
							, 300
		game:
			new Vue
				el: '#svg'
				data:
					mouse: true
					time: game.mode.time
					totalTime: game.mode.time
					targets: game.targets
					clicks: game.clicks
					dimens: game.dimens
				computed:
					styles: ->
						cursor:
							if @mouse then 'auto' else 'none'
						opacity:
							if game.paused then 0.5 else 1
					length: ->
						return @dimens.width * @time / @totalTime
				methods:
					click: (e, index) ->
						unless game.paused
							@clicks.push
								x: e.pageX
								y: e.pageY
							unless index?
								game.gameOver()
								return
							setTimeout =>
									@clicks.shift()
								, 50
							game.click @targets[index], e.pageX, e.pageY

class Game
	@modes =
		original:
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
			targetCount: 1
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
			time: 5000
	# Assign default properties and fill in unspecified properties with 0
	@setupModes = ->
		defaultProperties =
			rMin: 0.25
			rMax: 0.3
			growth: 0.95
			targetCount: 3
			time: 3000
			delay: false
			showCursor: false
		properties = []
		for own _, mode of @modes
			# Collect unknown properties
			for own property of mode
				unless property of defaultProperties or property in properties
					properties.push property
			# Fill in default properties
			for own property of defaultProperties
				unless mode[property]?
					mode[property] = defaultProperties[property]
		# Fill in unspecified properties
		for own _, mode of @modes
			for property in properties
				unless mode[property]?
					mode[property] = 0

	constructor: (@dimens) ->
		@paused = true
		@stats =
			targets: 0
			bonus: 0
			time: 0
		@targets = []
		@clicks = []
		@mode = {}
		for own name, property of Game.modes.original
			@mode[name] = property
		# For ticking:
		@lastTime = @prevElapsed = @prevElapsed2 = 0
		@initialize()

	click: (target, x, y) ->
		@stats.targets++
		@views.game.time = Math.min @views.game.time + @views.game.totalTime / 3, @views.game.totalTime
		@stats.bonus += target.clickBonus x, y
		@shrinkRadii() if @stats.targets <= 100 and @stats.targets % 10 is 0
		@targets.$remove target
		@generateTarget()

	startGame: ->
		@paused = false
		@views.game.mouse = @mode.showCursor
		@lastTime = Date.now()
		requestAnimationFrame => @tick()

	initialize: ->
		@scalar = Math.min @dimens.width, @dimens.height
		@rMin = @mode.rMin * @scalar
		@rMax = @mode.rMax * @scalar
		if @views? then @views.game.time = @views.game.totalTime = @mode.time
		@stats.targets = 0
		@stats.bonus = 0
		@stats.time = 0
		@targets.pop() for i in [1..@targets.length]
		@clicks.pop() for i in [1..@clicks.length]
		@generateTarget() for i in [1..@mode.targetCount]
		@paused = true

	gameOver: ->
		@views.game.mouse = true
		@views.gameover.show = true
		@paused = true

	generateTarget: ->
		target = new Target Math.getRandom(@rMax, @dimens.width - @rMax),
			Math.getRandom(@rMax, @dimens.height - @rMax),
			Math.getRandom(@rMin, @rMax)
		@targets.push target

	shrinkRadii: ->
		@rMin *= @mode.growth
		@rMax *= @mode.growth

	process: (delta) ->
		if @views.game.time - delta <= 0
			@views.game.time = 0
			@gameOver()
			return
		@views.game.time -= delta
		@stats.time += delta / 1000
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
	constructor: (@x, @y, @r) ->

	clickBonus: (x, y) ->
		return 1 - Math.hypot((@x - x), (@y - y)) / @r

window.onload = ->
	Game.setupModes()
	app = new Game {width: window.innerWidth, height: window.innerHeight}
	# Setup Vue instances for menus
	initializeViews app
