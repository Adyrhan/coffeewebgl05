'use strict'

class CanvasRenderer
	debug: false
	getVertexShaderSource: =>
		"
		attribute vec3 aVertexPosition;
		attribute vec4 aVertexColor;

		uniform mat4 uMVMatrix;
		uniform mat4 uPMatrix;

		varying vec4 vColor;
		
		void main(void) {
			gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
			vColor = aVertexColor;
		}
		"

	getFragmentShaderSource: =>
		"
		precision mediump float;

		varying vec4 vColor;

		void main(void) {
			gl_FragColor = vColor;
		}
		"

	getShader: (shaderType) =>
		shader = null
		source = null
		if shaderType == "fragment"
			shader = @gl.createShader @gl.FRAGMENT_SHADER
			source = @getFragmentShaderSource()
		else if shaderType == "vertex"
			shader = @gl.createShader @gl.VERTEX_SHADER
			source = @getVertexShaderSource()
		else
			return null

		@gl.shaderSource shader, source
		@gl.compileShader shader

		if !@gl.getShaderParameter shader, @gl.COMPILE_STATUS
			console.log @gl.getShaderInfoLog shader
			return null

		shader

	initShaders: =>
		fragmentShader = @getShader "fragment"
		vertexShader = @getShader "vertex"

		@shaderProgram = @gl.createProgram()

		@gl.attachShader @shaderProgram, vertexShader
		@gl.attachShader @shaderProgram, fragmentShader
		@gl.linkProgram @shaderProgram

		if !@gl.getProgramParameter @shaderProgram, @gl.LINK_STATUS
			console.log "Couldn't initialize shaders"
			return false

		@gl.useProgram @shaderProgram

		@shaderProgram.vertexPositionAttribute = @gl.getAttribLocation @shaderProgram, "aVertexPosition"
		@gl.enableVertexAttribArray @shaderProgram.vertexPositionAttribute

		@shaderProgram.vertexColorAttribute = @gl.getAttribLocation @shaderProgram, "aVertexColor"
		@gl.enableVertexAttribArray @shaderProgram.vertexColorAttribute

		@shaderProgram.pMatrixUniform = @gl.getUniformLocation @shaderProgram, "uPMatrix"
		@shaderProgram.mvMatrixUniform = @gl.getUniformLocation @shaderProgram, "uMVMatrix"

		true

	setMatrixUniforms: =>
		@gl.uniformMatrix4fv @shaderProgram.pMatrixUniform, false, @pMatrix
		@gl.uniformMatrix4fv @shaderProgram.mvMatrixUniform, false, @mvMatrix

	constructor: ->
		@pyramidVertexPositionBuffer = null
		@pyramidVertexColorBuffer = null
		@cubeVertexPositionBuffer = null
		@cubeVertexColorBuffer = null
		@cubeVertexIndexBuffer = null
		@mvMatrix = mat4.create()
		@pMatrix = mat4.create()
		@gl = null
		@shaderProgram = null
		@rPyramid = 0
		@rCube = 0
		@lastTime = 0
		@mvMatrixStack = []
	
	logGLCall: (call, args) =>
		console.log "gl."+call+" "+ WebGLDebugUtils.glFunctionArgsToString(call, args)

	initGL: (canvasId) => 
		canvas = document.getElementById canvasId
		
		if canvas is null
			console.log "Couldn't retrieve canvas from DOM"
			return null

		if @debug
			gl = WebGLDebugUtils.makeDebugContext canvas.getContext("webgl"), undefined, @logGLCall
		else
			gl = canvas.getContext("webgl")
		
		gl.viewportWidth = canvas.width
		gl.viewportHeight = canvas.height

		if gl is null
			console.log "Couldn't retrieve WebGL context"
			return null
		else
			console.log "Drawing buffer is ("+gl.drawingBufferWidth+"x"+gl.drawingBufferHeight+")"
			gl

	initBuffers: =>
		@pyramidVertexPositionBuffer = @gl.createBuffer()
		
		vertices = [
			 0.0,  1.0,  0.0,
		    -1.0, -1.0,  1.0,
			 1.0, -1.0,  1.0,

			 0.0,  1.0,  0.0,
			 1.0, -1.0,  1.0,
			 1.0, -1.0, -1.0,

			 0.0,  1.0,  0.0,
			 1.0, -1.0, -1.0,
			-1.0, -1.0, -1.0,

			 0.0,  1.0,  0.0,
			-1.0, -1.0, -1.0,
			-1.0, -1.0,  1.0
		]
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @pyramidVertexPositionBuffer
		@gl.bufferData @gl.ARRAY_BUFFER, new Float32Array(vertices), @gl.STATIC_DRAW 
		@pyramidVertexPositionBuffer.itemSize = 3
		@pyramidVertexPositionBuffer.numItems = 12

		@pyramidVertexColorBuffer = @gl.createBuffer()

		colors = [
			1.0, 0.0, 0.0, 1.0,
			0.0, 1.0, 0.0, 1.0,
			0.0, 0.0, 1.0, 1.0,

			1.0, 0.0, 0.0, 1.0,
			0.0, 0.0, 1.0, 1.0,
			0.0, 1.0, 0.0, 1.0,

			1.0, 0.0, 0.0, 1.0,
			0.0, 1.0, 0.0, 1.0,
			0.0, 0.0, 1.0, 1.0, 

			1.0, 0.0, 0.0, 1.0,
			0.0, 0.0, 1.0, 1.0,
			0.0, 1.0, 0.0, 1.0
		]

		@gl.bindBuffer @gl.ARRAY_BUFFER, @pyramidVertexColorBuffer
		@gl.bufferData @gl.ARRAY_BUFFER, new Float32Array(colors), @gl.STATIC_DRAW
		@pyramidVertexColorBuffer.itemSize = 4
		@pyramidVertexColorBuffer.numItems = 12

		@cubeVertexPositionBuffer = @gl.createBuffer()

		vertices = [
			# Front face
			-1.0, -1.0,  1.0,
			 1.0, -1.0,  1.0,
			 1.0,  1.0,  1.0,
			-1.0,  1.0,  1.0,
			# Back face
			-1.0, -1.0, -1.0,
			-1.0,  1.0, -1.0,
			 1.0,  1.0, -1.0,
			 1.0, -1.0, -1.0,
			# Top face
			-1.0,  1.0, -1.0,
			-1.0,  1.0,  1.0,
			 1.0,  1.0,  1.0,
			 1.0,  1.0, -1.0,
			# Bottom face
			-1.0, -1.0, -1.0,
			 1.0, -1.0, -1.0,
			 1.0, -1.0,  1.0,
			-1.0, -1.0,  1.0,
			# Right face
			 1.0, -1.0, -1.0,
			 1.0,  1.0, -1.0,
			 1.0,  1.0,  1.0,
			 1.0, -1.0,  1.0,
			# Left face
			-1.0, -1.0, -1.0,
			-1.0, -1.0,  1.0,
			-1.0,  1.0,  1.0,
			-1.0,  1.0, -1.0,
		]

		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexPositionBuffer
		@gl.bufferData @gl.ARRAY_BUFFER, new Float32Array(vertices), @gl.STATIC_DRAW
		@cubeVertexPositionBuffer.itemSize = 3
		@cubeVertexPositionBuffer.numItems = 24

		@cubeVertexColorBuffer = @gl.createBuffer()

		
		colors = [
			[1.0, 0.0, 0.0, 1.0],     # Front face
			[1.0, 1.0, 0.0, 1.0],     # Back face
			[0.0, 1.0, 0.0, 1.0],     # Top face
			[1.0, 0.5, 0.5, 1.0],     # Bottom face
			[1.0, 0.0, 1.0, 1.0],     # Right face
			[0.0, 0.0, 1.0, 1.0],     # Left face
		];

		unpackedColors = []
		(((unpackedColors.push val for val in x) for _ in [1..4]) for x in colors)
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexColorBuffer
		@gl.bufferData @gl.ARRAY_BUFFER, new Float32Array(unpackedColors), @gl.STATIC_DRAW
		@cubeVertexColorBuffer.itemSize = 4
		@cubeVertexColorBuffer.numItems = 24

		@cubeVertexIndexBuffer = @gl.createBuffer()
		@gl.bindBuffer @gl.ELEMENT_ARRAY_BUFFER, @cubeVertexIndexBuffer

		indices = [
			0, 1, 2,  0, 2, 3,       # Front face
			4, 5, 6,  4, 6, 7,       # Back face
			8, 9, 10,  8, 10, 11,    # Top face
			12, 13, 14,  12, 14, 15, # Bottom face
			16, 17, 18,  16, 18, 19, # Right face
			20, 21, 22,  20, 22, 23  # Left face
		]

		@gl.bufferData @gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), @gl.STATIC_DRAW
		@cubeVertexIndexBuffer.numItems = 36
		@cubeVertexIndexBuffer.itemSize = 1

	start: =>
		textElem = document.getElementById "ptag"
		textElem.innerHTML = "Initializing..."

		@gl = @initGL "canvas"
		if @gl is null
			console.log "initGL failed!"
			textElem.innerHTML = "WebGL initialization failed :("
			return

		console.log "initialized!"
		textElem.innerHTML = "WebGL initialized!"

		if !@initShaders()
			return
		@initBuffers()

		@gl.clearColor 0.0, 0.0, 0.0, 1.0
		@gl.enable @gl.DEPTH_TEST

		@tick()

	tick: =>
		requestAnimFrame @tick
		@drawScene()
		@animate()

	animate: =>
		timeNow = new Date().getTime()
		if @lastTime != 0
			elapsed = timeNow-@lastTime

			@rPyramid += (90 * elapsed) / 1000.0
			@rCube += (75 * elapsed) / 1000.0
		@lastTime = timeNow

	mvPushMatrix: =>
		copy = mat4.create()
		mat4.set @mvMatrix, copy
		@mvMatrixStack.push copy

	mvPopMatrix: =>
		if @mvMatrixStack.length == 0
			throw "No matrix on stack to pop"
		@mvMatrix = @mvMatrixStack.pop()

	degToRad: (degrees) => degrees * Math.PI / 180

	drawScene: =>
		@gl.viewport 0, 0, @gl.viewportWidth, @gl.viewportHeight
		@gl.clear @gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT
		
		mat4.perspective 45, @gl.viewportWidth / @gl.viewportHeight, 0.1, 100.0, @pMatrix
		
		mat4.identity @mvMatrix

		mat4.translate @mvMatrix, [-1.5, 0.0, -7.0]

		@mvPushMatrix()
		
		mat4.rotate @mvMatrix, @degToRad(@rPyramid), [0,1,0]
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @pyramidVertexPositionBuffer
		@gl.vertexAttribPointer @shaderProgram.vertexPositionAttribute, @pyramidVertexPositionBuffer.itemSize, @gl.FLOAT, false, 0, 0
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @pyramidVertexColorBuffer
		@gl.vertexAttribPointer @shaderProgram.vertexColorAttribute, @pyramidVertexColorBuffer.itemSize, @gl.FLOAT, false, 0, 0
		
		@setMatrixUniforms()
		@gl.drawArrays @gl.TRIANGLES, 0, @pyramidVertexPositionBuffer.numItems

		@mvPopMatrix()

		mat4.translate @mvMatrix, [3.0, 0.0, 0.0]
		
		@mvPushMatrix()
		
		mat4.rotate @mvMatrix, @degToRad(@rCube), [1,1,1]

		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexPositionBuffer
		@gl.vertexAttribPointer @shaderProgram.vertexPositionAttribute, @cubeVertexPositionBuffer.itemSize, @gl.FLOAT, false, 0, 0
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexColorBuffer
		@gl.vertexAttribPointer @shaderProgram.vertexColorAttribute, @cubeVertexColorBuffer.itemSize, @gl.FLOAT, false, 0, 0

		@gl.bindBuffer @gl.ELEMENT_ARRAY_BUFFER, @cubeVertexIndexBuffer
		@setMatrixUniforms()
		@gl.drawElements @gl.TRIANGLES, @cubeVertexIndexBuffer.numItems, @gl.UNSIGNED_SHORT, 0

		@mvPopMatrix()

window.canvasRenderer = CanvasRenderer