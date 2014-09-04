'use strict'

class CanvasRenderer
	debug: false
	getVertexShaderSource: =>
		"
		attribute vec3 aVertexPosition;
		attribute vec2 aTextureCoord;

		uniform mat4 uMVMatrix;
		uniform mat4 uPMatrix;

		varying vec2 vTextureCoord;
		
		void main(void) {
			gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
			vTextureCoord = aTextureCoord;
		}
		"

	getFragmentShaderSource: =>
		"
		precision mediump float;

		varying vec2 vTextureCoord;

		uniform sampler2D uSampler;

		void main(void) {
			gl_FragColor = texture2D(uSampler, vec2(vTextureCoord.s, vTextureCoord.t));
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

		@shaderProgram.textureCoordAttribute = @gl.getAttribLocation @shaderProgram, "aTextureCoord"
		@gl.enableVertexAttribArray @shaderProgram.textureCoordAttribute

		@shaderProgram.pMatrixUniform = @gl.getUniformLocation @shaderProgram, "uPMatrix"
		@shaderProgram.mvMatrixUniform = @gl.getUniformLocation @shaderProgram, "uMVMatrix"
		@shaderProgram.samplerUniform = @gl.getUniformLocation @shaderProgram, "uSampler"

		true

	setMatrixUniforms: =>
		@gl.uniformMatrix4fv @shaderProgram.pMatrixUniform, false, @pMatrix
		@gl.uniformMatrix4fv @shaderProgram.mvMatrixUniform, false, @mvMatrix

	constructor: ->
		@cubeVertexPositionBuffer = null
		@cubeVertexIndexBuffer = null
		@cubeVertexTextureCoordBuffer = null
		@mvMatrix = mat4.create()
		@pMatrix = mat4.create()
		@gl = null
		@shaderProgram = null
		@xRot = 0
		@yRot = 0
		@zRot = 0
		@lastTime = 0
		@mvMatrixStack = []
		@texture = null
	
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

		@cubeVertexTextureCoordBuffer = @gl.createBuffer()
		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexTextureCoordBuffer

		textureCoords = [
			# Front face
			0.0, 0.0,
			1.0, 0.0,
			1.0, 1.0,
			0.0, 1.0,

			# Back face
			1.0, 0.0,
			1.0, 1.0,
			0.0, 1.0,
			0.0, 0.0,

			# Top face
			0.0, 1.0,
			0.0, 0.0,
			1.0, 0.0,
			1.0, 1.0,

			# Bottom face
			1.0, 1.0,
			0.0, 1.0,
			0.0, 0.0,
			1.0, 0.0,

			# Right face
			1.0, 0.0,
			1.0, 1.0,
			0.0, 1.0,
			0.0, 0.0,

			# Left face
			0.0, 0.0,
			1.0, 0.0,
			1.0, 1.0,
			0.0, 1.0
		]

		@gl.bufferData @gl.ARRAY_BUFFER, new Float32Array(textureCoords), @gl.STATIC_DRAW
		@cubeVertexTextureCoordBuffer.itemSize = 2
		@cubeVertexTextureCoordBuffer.numItems = 24

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
		@initTexture()

		

	startRender: =>
		@gl.clearColor 0.0, 0.0, 0.0, 1.0
		@gl.enable @gl.DEPTH_TEST

		@tick()		

	initTexture: =>
		@texture = @gl.createTexture()
		@texture.image = new Image()
		@texture.image.onload = => @handleLoadedTexture @texture
		@texture.image.src = "img/woodtexture512.jpg"

	handleLoadedTexture: (texture) =>
		@gl.bindTexture @gl.TEXTURE_2D, texture
		@gl.pixelStorei @gl.UNPACK_FLIP_Y_WEBGL, true
		@gl.texImage2D @gl.TEXTURE_2D, 0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, texture.image
		@gl.texParameteri @gl.TEXTURE_2D, @gl.TEXTURE_MAG_FILTER, @gl.NEAREST
		@gl.texParameteri @gl.TEXTURE_2D, @gl.TEXTURE_MIN_FILTER, @gl.NEAREST
		@gl.bindTexture @gl.TEXTURE_2D, null
		
		@startRender()

	tick: =>
		requestAnimFrame @tick
		@drawScene()
		@animate()

	animate: =>
		timeNow = new Date().getTime()
		if @lastTime != 0
			elapsed = timeNow-@lastTime
			
			@xRot += (90 * elapsed) / 1000.0
			@yRot += (90 * elapsed) / 1000.0
			@zRot += (90 * elapsed) / 1000.0
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

		mat4.translate @mvMatrix, [0, 0.0, -5.0]
		
		mat4.rotate @mvMatrix, @degToRad(@xRot), [1,0,0]
		mat4.rotate @mvMatrix, @degToRad(@yRot), [0,1,0]
		mat4.rotate @mvMatrix, @degToRad(@zRot), [0,0,1]

		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexPositionBuffer
		@gl.vertexAttribPointer @shaderProgram.vertexPositionAttribute, @cubeVertexPositionBuffer.itemSize, @gl.FLOAT, false, 0, 0
		
		@gl.bindBuffer @gl.ARRAY_BUFFER, @cubeVertexTextureCoordBuffer
		@gl.vertexAttribPointer @shaderProgram.textureCoordAttribute, @cubeVertexTextureCoordBuffer.itemSize, @gl.FLOAT, false, 0, 0

		@gl.activeTexture @gl.TEXTURE0
		@gl.bindTexture @gl.TEXTURE_2D, @texture
		@gl.uniform1i @shaderProgram.samplerUniform, 0

		@gl.bindBuffer @gl.ELEMENT_ARRAY_BUFFER, @cubeVertexIndexBuffer
		@setMatrixUniforms()
		@gl.drawElements @gl.TRIANGLES, @cubeVertexIndexBuffer.numItems, @gl.UNSIGNED_SHORT, 0

window.canvasRenderer = CanvasRenderer