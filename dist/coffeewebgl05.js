(function() {
  'use strict';
  var CanvasRenderer,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  CanvasRenderer = (function() {
    CanvasRenderer.prototype.debug = false;

    CanvasRenderer.prototype.getVertexShaderSource = function() {
      return "		attribute vec3 aVertexPosition;		attribute vec2 aTextureCoord;		uniform mat4 uMVMatrix;		uniform mat4 uPMatrix;		varying vec2 vTextureCoord;				void main(void) {			gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);			vTextureCoord = aTextureCoord;		}		";
    };

    CanvasRenderer.prototype.getFragmentShaderSource = function() {
      return "		precision mediump float;		varying vec2 vTextureCoord;		uniform sampler2D uSampler;		void main(void) {			gl_FragColor = texture2D(uSampler, vec2(vTextureCoord.s, vTextureCoord.t));		}		";
    };

    CanvasRenderer.prototype.getShader = function(shaderType) {
      var shader, source;
      shader = null;
      source = null;
      if (shaderType === "fragment") {
        shader = this.gl.createShader(this.gl.FRAGMENT_SHADER);
        source = this.getFragmentShaderSource();
      } else if (shaderType === "vertex") {
        shader = this.gl.createShader(this.gl.VERTEX_SHADER);
        source = this.getVertexShaderSource();
      } else {
        return null;
      }
      this.gl.shaderSource(shader, source);
      this.gl.compileShader(shader);
      if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
        console.log(this.gl.getShaderInfoLog(shader));
        return null;
      }
      return shader;
    };

    CanvasRenderer.prototype.initShaders = function() {
      var fragmentShader, vertexShader;
      fragmentShader = this.getShader("fragment");
      vertexShader = this.getShader("vertex");
      this.shaderProgram = this.gl.createProgram();
      this.gl.attachShader(this.shaderProgram, vertexShader);
      this.gl.attachShader(this.shaderProgram, fragmentShader);
      this.gl.linkProgram(this.shaderProgram);
      if (!this.gl.getProgramParameter(this.shaderProgram, this.gl.LINK_STATUS)) {
        console.log("Couldn't initialize shaders");
        return false;
      }
      this.gl.useProgram(this.shaderProgram);
      this.shaderProgram.vertexPositionAttribute = this.gl.getAttribLocation(this.shaderProgram, "aVertexPosition");
      this.gl.enableVertexAttribArray(this.shaderProgram.vertexPositionAttribute);
      this.shaderProgram.textureCoordAttribute = this.gl.getAttribLocation(this.shaderProgram, "aTextureCoord");
      this.gl.enableVertexAttribArray(this.shaderProgram.textureCoordAttribute);
      this.shaderProgram.pMatrixUniform = this.gl.getUniformLocation(this.shaderProgram, "uPMatrix");
      this.shaderProgram.mvMatrixUniform = this.gl.getUniformLocation(this.shaderProgram, "uMVMatrix");
      this.shaderProgram.samplerUniform = this.gl.getUniformLocation(this.shaderProgram, "uSampler");
      return true;
    };

    CanvasRenderer.prototype.setMatrixUniforms = function() {
      this.gl.uniformMatrix4fv(this.shaderProgram.pMatrixUniform, false, this.pMatrix);
      return this.gl.uniformMatrix4fv(this.shaderProgram.mvMatrixUniform, false, this.mvMatrix);
    };

    function CanvasRenderer() {
      this.drawScene = __bind(this.drawScene, this);
      this.degToRad = __bind(this.degToRad, this);
      this.mvPopMatrix = __bind(this.mvPopMatrix, this);
      this.mvPushMatrix = __bind(this.mvPushMatrix, this);
      this.animate = __bind(this.animate, this);
      this.tick = __bind(this.tick, this);
      this.handleLoadedTexture = __bind(this.handleLoadedTexture, this);
      this.initTexture = __bind(this.initTexture, this);
      this.startRender = __bind(this.startRender, this);
      this.start = __bind(this.start, this);
      this.initBuffers = __bind(this.initBuffers, this);
      this.initGL = __bind(this.initGL, this);
      this.logGLCall = __bind(this.logGLCall, this);
      this.setMatrixUniforms = __bind(this.setMatrixUniforms, this);
      this.initShaders = __bind(this.initShaders, this);
      this.getShader = __bind(this.getShader, this);
      this.getFragmentShaderSource = __bind(this.getFragmentShaderSource, this);
      this.getVertexShaderSource = __bind(this.getVertexShaderSource, this);
      this.cubeVertexPositionBuffer = null;
      this.cubeVertexIndexBuffer = null;
      this.cubeVertexTextureCoordBuffer = null;
      this.mvMatrix = mat4.create();
      this.pMatrix = mat4.create();
      this.gl = null;
      this.shaderProgram = null;
      this.xRot = 0;
      this.yRot = 0;
      this.zRot = 0;
      this.lastTime = 0;
      this.mvMatrixStack = [];
      this.texture = null;
    }

    CanvasRenderer.prototype.logGLCall = function(call, args) {
      return console.log("gl." + call + " " + WebGLDebugUtils.glFunctionArgsToString(call, args));
    };

    CanvasRenderer.prototype.initGL = function(canvasId) {
      var canvas, gl;
      canvas = document.getElementById(canvasId);
      if (canvas === null) {
        console.log("Couldn't retrieve canvas from DOM");
        return null;
      }
      if (this.debug) {
        gl = WebGLDebugUtils.makeDebugContext(canvas.getContext("webgl"), void 0, this.logGLCall);
      } else {
        gl = canvas.getContext("webgl");
      }
      gl.viewportWidth = canvas.width;
      gl.viewportHeight = canvas.height;
      if (gl === null) {
        console.log("Couldn't retrieve WebGL context");
        return null;
      } else {
        console.log("Drawing buffer is (" + gl.drawingBufferWidth + "x" + gl.drawingBufferHeight + ")");
        return gl;
      }
    };

    CanvasRenderer.prototype.initBuffers = function() {
      var indices, textureCoords, vertices;
      this.cubeVertexPositionBuffer = this.gl.createBuffer();
      vertices = [-1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0];
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.cubeVertexPositionBuffer);
      this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(vertices), this.gl.STATIC_DRAW);
      this.cubeVertexPositionBuffer.itemSize = 3;
      this.cubeVertexPositionBuffer.numItems = 24;
      this.cubeVertexTextureCoordBuffer = this.gl.createBuffer();
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.cubeVertexTextureCoordBuffer);
      textureCoords = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
      this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(textureCoords), this.gl.STATIC_DRAW);
      this.cubeVertexTextureCoordBuffer.itemSize = 2;
      this.cubeVertexTextureCoordBuffer.numItems = 24;
      this.cubeVertexIndexBuffer = this.gl.createBuffer();
      this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.cubeVertexIndexBuffer);
      indices = [0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 13, 14, 12, 14, 15, 16, 17, 18, 16, 18, 19, 20, 21, 22, 20, 22, 23];
      this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), this.gl.STATIC_DRAW);
      this.cubeVertexIndexBuffer.numItems = 36;
      return this.cubeVertexIndexBuffer.itemSize = 1;
    };

    CanvasRenderer.prototype.start = function() {
      var textElem;
      textElem = document.getElementById("ptag");
      textElem.innerHTML = "Initializing...";
      this.gl = this.initGL("canvas");
      if (this.gl === null) {
        console.log("initGL failed!");
        textElem.innerHTML = "WebGL initialization failed :(";
        return;
      }
      console.log("initialized!");
      textElem.innerHTML = "WebGL initialized!";
      if (!this.initShaders()) {
        return;
      }
      this.initBuffers();
      return this.initTexture();
    };

    CanvasRenderer.prototype.startRender = function() {
      this.gl.clearColor(0.0, 0.0, 0.0, 1.0);
      this.gl.enable(this.gl.DEPTH_TEST);
      return this.tick();
    };

    CanvasRenderer.prototype.initTexture = function() {
      var _this = this;
      this.texture = this.gl.createTexture();
      this.texture.image = new Image();
      this.texture.image.onload = function() {
        return _this.handleLoadedTexture(_this.texture);
      };
      return this.texture.image.src = "img/woodtexture512.jpg";
    };

    CanvasRenderer.prototype.handleLoadedTexture = function(texture) {
      this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
      this.gl.pixelStorei(this.gl.UNPACK_FLIP_Y_WEBGL, true);
      this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, this.gl.RGBA, this.gl.UNSIGNED_BYTE, texture.image);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
      this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
      this.gl.bindTexture(this.gl.TEXTURE_2D, null);
      return this.startRender();
    };

    CanvasRenderer.prototype.tick = function() {
      requestAnimFrame(this.tick);
      this.drawScene();
      return this.animate();
    };

    CanvasRenderer.prototype.animate = function() {
      var elapsed, timeNow;
      timeNow = new Date().getTime();
      if (this.lastTime !== 0) {
        elapsed = timeNow - this.lastTime;
        this.xRot += (90 * elapsed) / 1000.0;
        this.yRot += (90 * elapsed) / 1000.0;
        this.zRot += (90 * elapsed) / 1000.0;
      }
      return this.lastTime = timeNow;
    };

    CanvasRenderer.prototype.mvPushMatrix = function() {
      var copy;
      copy = mat4.create();
      mat4.set(this.mvMatrix, copy);
      return this.mvMatrixStack.push(copy);
    };

    CanvasRenderer.prototype.mvPopMatrix = function() {
      if (this.mvMatrixStack.length === 0) {
        throw "No matrix on stack to pop";
      }
      return this.mvMatrix = this.mvMatrixStack.pop();
    };

    CanvasRenderer.prototype.degToRad = function(degrees) {
      return degrees * Math.PI / 180;
    };

    CanvasRenderer.prototype.drawScene = function() {
      this.gl.viewport(0, 0, this.gl.viewportWidth, this.gl.viewportHeight);
      this.gl.clear(this.gl.COLOR_BUFFER_BIT | this.gl.DEPTH_BUFFER_BIT);
      mat4.perspective(45, this.gl.viewportWidth / this.gl.viewportHeight, 0.1, 100.0, this.pMatrix);
      mat4.identity(this.mvMatrix);
      mat4.translate(this.mvMatrix, [0, 0.0, -5.0]);
      mat4.rotate(this.mvMatrix, this.degToRad(this.xRot), [1, 0, 0]);
      mat4.rotate(this.mvMatrix, this.degToRad(this.yRot), [0, 1, 0]);
      mat4.rotate(this.mvMatrix, this.degToRad(this.zRot), [0, 0, 1]);
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.cubeVertexPositionBuffer);
      this.gl.vertexAttribPointer(this.shaderProgram.vertexPositionAttribute, this.cubeVertexPositionBuffer.itemSize, this.gl.FLOAT, false, 0, 0);
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.cubeVertexTextureCoordBuffer);
      this.gl.vertexAttribPointer(this.shaderProgram.textureCoordAttribute, this.cubeVertexTextureCoordBuffer.itemSize, this.gl.FLOAT, false, 0, 0);
      this.gl.activeTexture(this.gl.TEXTURE0);
      this.gl.bindTexture(this.gl.TEXTURE_2D, this.texture);
      this.gl.uniform1i(this.shaderProgram.samplerUniform, 0);
      this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.cubeVertexIndexBuffer);
      this.setMatrixUniforms();
      return this.gl.drawElements(this.gl.TRIANGLES, this.cubeVertexIndexBuffer.numItems, this.gl.UNSIGNED_SHORT, 0);
    };

    return CanvasRenderer;

  })();

  window.canvasRenderer = CanvasRenderer;

}).call(this);

/*
//@ sourceMappingURL=coffeewebgl05.js.map
*/