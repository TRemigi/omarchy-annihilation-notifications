// Developer tool. Runs one of this plugin's fragment shaders on Mesa's software GL (headless EGL) and writes the
// frame as a PAM image (premultiplied RGBA), so a shader can be checked and previewed without a GPU or a compositor.
// Any uniform in the shader's `ubuf` block is set from the environment: U_<name>=v or U_<name>=v1,v2,v3,v4.
//
//   /usr/lib/qt6/bin/qsb -x "glsl,100 es" -o /tmp/s.frag shaders/toastrim.frag.qsb
//   gcc -O2 test/shader-harness.c -o /tmp/harness -lEGL -lGLESv2
//   U_size=400,120 U_card=10,10,380,100 U_energy=1 EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 \
//     /tmp/harness /tmp/s.frag 400 120 out.pam
//
// qt_TexCoord0 has y = 0 at the top, as in Qt, and qt_Opacity is 1 unless U_qt_Opacity is given. This tests the
// shader, not the Qt integration, and llvmpipe timings are not GPU timings. Derived from the theme repo's
// extras/dev/shader-harness.c, with the uniforms made generic.
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern char **environ;

static char *slurp(const char *p) { FILE *f = fopen(p, "rb"); if (!f) { perror(p); exit(1); } fseek(f, 0, SEEK_END); long n = ftell(f); rewind(f); char *b = malloc(n + 1); fread(b, 1, n, f); b[n] = 0; fclose(f); return b; }
static GLuint compile(GLenum type, const char *src) {
  GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, NULL); glCompileShader(s);
  GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) { char log[4096]; glGetShaderInfoLog(s, sizeof log, NULL, log); fprintf(stderr, "shader compile failed:\n%s\n", log); exit(2); }
  return s;
}

int main(int argc, char **argv) {
  if (argc < 5) { fprintf(stderr, "usage: harness shader.frag W H out.pam\n"); return 1; }
  int W = atoi(argv[2]), H = atoi(argv[3]);
  EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint maj, min; if (!eglInitialize(dpy, &maj, &min)) { fprintf(stderr, "eglInitialize failed 0x%x\n", eglGetError()); return 3; }
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE };
  EGLConfig cfg; EGLint n; if (!eglChooseConfig(dpy, ca, &cfg, 1, &n) || n < 1) { fprintf(stderr, "no config 0x%x\n", eglGetError()); return 4; }
  EGLint pa[] = { EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE }; EGLSurface surf = eglCreatePbufferSurface(dpy, cfg, pa);
  EGLint xa[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE }; EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, xa);
  if (!eglMakeCurrent(dpy, surf, surf, ctx)) { fprintf(stderr, "makecurrent failed 0x%x\n", eglGetError()); return 5; }

  const char *vs = "attribute vec2 pos; varying vec2 qt_TexCoord0; void main(){ qt_TexCoord0 = vec2(pos.x*0.5+0.5, 0.5-pos.y*0.5); gl_Position = vec4(pos,0.0,1.0); }";
  GLuint prog = glCreateProgram(); glAttachShader(prog, compile(GL_VERTEX_SHADER, vs)); glAttachShader(prog, compile(GL_FRAGMENT_SHADER, slurp(argv[1])));
  glBindAttribLocation(prog, 0, "pos"); glLinkProgram(prog); GLint ok; glGetProgramiv(prog, GL_LINK_STATUS, &ok);
  if (!ok) { char log[4096]; glGetProgramInfoLog(prog, sizeof log, NULL, log); fprintf(stderr, "link failed:\n%s\n", log); return 6; }
  glUseProgram(prog);

  float I4[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
  glUniformMatrix4fv(glGetUniformLocation(prog, "ubuf.qt_Matrix"), 1, GL_FALSE, I4);
  glUniform1f(glGetUniformLocation(prog, "ubuf.qt_Opacity"), 1.f);
  int set = 0;
  for (char **e = environ; *e; e++) {
    if (strncmp(*e, "U_", 2) != 0) continue;
    char *eq = strchr(*e, '='); if (!eq) continue;
    char name[128]; snprintf(name, sizeof name, "ubuf.%.*s", (int)(eq - *e - 2), *e + 2);
    float v[4] = {0, 0, 0, 0}; int k = sscanf(eq + 1, "%f,%f,%f,%f", &v[0], &v[1], &v[2], &v[3]);
    GLint loc = glGetUniformLocation(prog, name);
    if (loc < 0) { fprintf(stderr, "warning: no uniform %s in the shader\n", name); continue; }
    switch (k) { case 1: glUniform1f(loc, v[0]); break; case 2: glUniform2f(loc, v[0], v[1]); break; case 3: glUniform3f(loc, v[0], v[1], v[2]); break; case 4: glUniform4f(loc, v[0], v[1], v[2], v[3]); break; default: continue; }
    set++;
  }
  fprintf(stderr, "set %d uniforms\n", set);

  GLuint fbo, tex; glGenTextures(1, &tex); glBindTexture(GL_TEXTURE_2D, tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo); glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
  glViewport(0, 0, W, H); glClearColor(0, 0, 0, 0); glClear(GL_COLOR_BUFFER_BIT);
  float quad[] = { -1,-1, 1,-1, -1,1, 1,1 }; glEnableVertexAttribArray(0); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); glFinish();
  unsigned char *px = malloc((size_t)W * H * 4); glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, px);
  FILE *o = fopen(argv[4], "wb"); fprintf(o, "P7\nWIDTH %d\nHEIGHT %d\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n", W, H);
  for (int y = H - 1; y >= 0; y--) fwrite(px + (size_t)y * W * 4, 1, (size_t)W * 4, o);
  fclose(o); return 0;
}
