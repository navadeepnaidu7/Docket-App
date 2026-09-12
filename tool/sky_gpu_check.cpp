// Offscreen Android GPU check. No Activity, window, or app data is touched.
// Build with the Android NDK: clang++ -static-libstdc++ -lEGL -lGLESv2 -lz.
// Args: generated GLES fragment shader, output PNG, optional time in seconds.
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <zlib.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

static GLuint compile(GLenum type, const char* source) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &source, nullptr);
  glCompileShader(shader);
  GLint ok = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[8192]; glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
    fprintf(stderr, "%s\n", log); exit(2);
  }
  return shader;
}

static void bigEndian(FILE* f, unsigned value) {
  unsigned char bytes[] = {static_cast<unsigned char>(value >> 24),
    static_cast<unsigned char>(value >> 16), static_cast<unsigned char>(value >> 8),
    static_cast<unsigned char>(value)};
  fwrite(bytes, 1, 4, f);
}

static void chunk(FILE* f, const char* type, const unsigned char* data, size_t size) {
  bigEndian(f, size); fwrite(type, 1, 4, f);
  if (size) fwrite(data, 1, size, f);
  uLong crc = crc32(0, reinterpret_cast<const Bytef*>(type), 4);
  if (size) crc = crc32(crc, data, size);
  bigEndian(f, crc);
}

int main(int argc, char** argv) {
  if (argc < 3) return 1;
  const int width = 390, height = 205;
  EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (!eglInitialize(display, nullptr, nullptr)) { fprintf(stderr, "EGL init failed\n"); return 2; }
  const EGLint attrs[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
    EGL_OPENGL_ES2_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8,
    EGL_ALPHA_SIZE, 8, EGL_NONE};
  EGLConfig config; EGLint count;
  eglChooseConfig(display, attrs, &config, 1, &count);
  if (!count) return 3;
  const EGLint surfaceAttrs[] = {EGL_WIDTH, width, EGL_HEIGHT, height, EGL_NONE};
  const EGLint contextAttrs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLSurface surface = eglCreatePbufferSurface(display, config, surfaceAttrs);
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttrs);
  if (!eglMakeCurrent(display, surface, surface, context)) return 4;
  fprintf(stderr, "GPU: %s\n", glGetString(GL_RENDERER));
  std::ifstream file(argv[1]);
  std::string fragment((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
  const char* vertex = "attribute vec2 position; varying highp vec2 _fragCoord;"
    "void main(){gl_Position=vec4(position,0.,1.);"
    "_fragCoord=vec2((position.x+1.)*195.,(1.-position.y)*102.5);}";
  GLuint vs = compile(GL_VERTEX_SHADER, vertex);
  GLuint fs = compile(GL_FRAGMENT_SHADER, fragment.c_str());
  GLuint program = glCreateProgram();
  glAttachShader(program, vs); glAttachShader(program, fs);
  glBindAttribLocation(program, 0, "position"); glLinkProgram(program);
  GLint linked; glGetProgramiv(program, GL_LINK_STATUS, &linked);
  if (!linked) { char log[8192]; glGetProgramInfoLog(program, sizeof(log), nullptr, log); fprintf(stderr, "%s\n", log); return 5; }
  glUseProgram(program);
  glUniform2f(glGetUniformLocation(program, "uSize"), width, height);
  const char* names[] = {"uPanelHeight", "uTime", "uClouds", "uStorm", "uDusk", "uNight", "uPull", "uRain", "uMotion"};
  float values[] = {204.4f, argc > 3 ? static_cast<float>(atof(argv[3])) : 2.f, .91f, 0, 0, 0, 1, 0, 1};
  for (int i = 0; i < 9; i++) glUniform1f(glGetUniformLocation(program, names[i]), values[i]);
  const GLfloat positions[] = {-1,-1, 1,-1, -1,1, 1,1};
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, positions);
  glEnableVertexAttribArray(0); glViewport(0, 0, width, height);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); glFinish();
  std::vector<unsigned char> rgba(width * height * 4);
  glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
  if (glGetError() != GL_NO_ERROR) return 6;
  std::vector<unsigned char> rows((width * 4 + 1) * height);
  for (int y = 0; y < height; y++) {
    std::copy(rgba.begin() + (height - y - 1) * width * 4,
      rgba.begin() + (height - y) * width * 4, rows.begin() + y * (width * 4 + 1) + 1);
  }
  uLongf length = compressBound(rows.size());
  std::vector<unsigned char> compressed(length);
  compress2(compressed.data(), &length, rows.data(), rows.size(), 6);
  FILE* output = fopen(argv[2], "wb"); if (!output) return 7;
  const unsigned char signature[] = {137,80,78,71,13,10,26,10};
  fwrite(signature, 1, 8, output);
  const unsigned char header[] = {0,0,1,134, 0,0,0,205, 8,6,0,0,0};
  chunk(output, "IHDR", header, 13);
  chunk(output, "IDAT", compressed.data(), length);
  chunk(output, "IEND", nullptr, 0); fclose(output);
  glDeleteProgram(program); glDeleteShader(vs); glDeleteShader(fs);
  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroyContext(display, context); eglDestroySurface(display, surface); eglTerminate(display);
  return 0;
}
