# Inclusive
getRandomInt = (min, max) ->
	Math.floor Math.random() * (max - min + 1) + min

class Game
	constructor: (@canvas, @ctx, @dimens) ->
		@MIN_RADIUS = 100
		@MAX_RADIUS = 200
		@targetImage = new Image()
		@targetImage.onload = =>
			@startGame()
			return
		@targetImage.src = 'target.svg'
		canvas.addEventListener 'mousedown', (e) =>
			@clickHandler e.pageX - e.target.offsetLeft, e.pageY - e.target.offsetTop

	clickHandler: (x, y) ->
		for index, target of @targets.slice(0).reverse()
			if target.clickWithin(x, y)
				@score++
				@targets.splice @targets.length - index - 1, 1
				@generateTarget()
				@click = {x, y}
				@render()
				return
		# Didn't click a circle
		console.log @score
		@startGame()
		return

	startGame: ->
		@initialize()
		@generateTarget() for i in [1..3]
		@render()

	initialize: ->
		@score = 0
		@targets = []
		@click =
			x: -1
			y: -1

	generateTarget: ->
		target = new Target getRandomInt(0, @dimens.width - 2 * @MAX_RADIUS), getRandomInt(0, @dimens.height - 2 * @MAX_RADIUS), getRandomInt(@MIN_RADIUS, @MAX_RADIUS)
		@targets.push target

	render: ->
		# Clear screen
		@ctx.clearRect(0, 0, @canvas.width, @canvas.height)
		for target in @targets
			# Draw svg
			@ctx.drawImage(@targetImage, target.x, target.y, target.radius * 2, target.radius * 2)
			# Add outline
			@ctx.beginPath()
			@ctx.arc(target.x + target.radius, target.y + target.radius, target.radius + 0.5, 0, 2 * Math.PI, false)
			@ctx.lineWidth = 1
			@ctx.strokeStyle = 'black'
			@ctx.stroke()
		if @click.x isnt -1 and @click.y isnt -1
			@ctx.beginPath()
			@ctx.arc(@click.x, @click.y, 3, 0, 2 * Math.PI, false)
			@ctx.fillStyle = 'red'
			@ctx.fill()

class Target
	constructor: (@x, @y, @radius) ->

	clickWithin: (x, y) ->
		Math.sqrt(Math.pow(@x + @radius - x, 2) + Math.pow(@y + @radius - y, 2)) <= @radius

window.onload = ->
	canvas = document.getElementById 'canvas'
	ctx = canvas.getContext '2d'
	# Handle high-DPI displays
	pixelRatio = window.devicePixelRatio
	canvas.width = window.innerWidth * pixelRatio
	canvas.height = window.innerHeight * pixelRatio
	ctx.scale pixelRatio, pixelRatio
	new Game canvas, ctx, {width: canvas.width / pixelRatio, height: canvas.height / pixelRatio, ratio: pixelRatio}