#define S(a, b, t) smoothstep(a, b, t)
//#define CHEAP_NORMALS
#define USE_POST_PROCESSING

uniform float iTime;
uniform vec3 iResolution;
uniform sampler2D iChannel0;

vec3 N13(float p) {
    //  from DAVE HOSKINS
  vec3 p3 = fract(vec3(p) * vec3(.1031, .11369, .13787));
  p3 += dot(p3, p3.yzx + 19.19);
  return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

vec4 N14(float t) {
  return fract(sin(t * vec4(123., 1024., 1456., 264.)) * vec4(6547., 345., 8799., 1564.));
}
float N(float t) {
  return fract(sin(t * 12345.564) * 7658.76);
}

float Saw(float b, float t) {
  return S(0., b, t) * S(1., b, t);
}

vec2 DropLayer2(vec2 uv, float t) {
  vec2 UV = uv;
  //整体画布跟着匀速运动
  uv.y += t * 0.75;
  vec2 a = vec2(6., 1.);
  vec2 grid = a * 2.;
  /* 放大uv x：12倍 y:2倍 */
  vec2 id = floor(uv * grid);

  float colShift = N(id.x); //得到随机数
  uv.y += colShift; //y轴偏移

  id = floor(uv * grid);  //重新获取y轴偏移后的格子
  vec3 n = N13(id.x * 35.2 + id.y * 2376.1);
  vec2 st = fract(uv * grid) - vec2(.5, 0); //将坐标原点由0,0 移动到0.5,0

  //左右随机错落
  float x = n.x - .5;
  /* y轴上下运动 上快下慢 */
  float y = UV.y * 20.;
  // 增加落痕路径自然扭曲
  float wiggle = sin(y + sin(y));
  x += wiggle * (.5 - abs(x)) * (n.z - .5);
  x *= .7;

  //上下随机错落
  float ti = fract(t + n.z);
  y = (Saw(.85, ti) - .5) * .9 + .5;
  vec2 p = vec2(x, y);
  float d = length((st - p) * a.yx);

  float mainDrop = S(.4, .0, d);
  // 落痕
  float r = sqrt(S(1., y, st.y));
  float cd = abs(st.x - x);

  //雨滴形状
  float trail = S(.23 * r, .15 * r * r, cd);

  //截取前面的一部分落痕
  float trailFront = S(-.02, .02, st.y - y);
  trail *= trailFront * r * r;

  y = UV.y;
  float trail2 = S(.2 * r, .0, cd);
  float droplets = max(0., (sin(y * (1. - y) * 120.) - st.y)) * trail2 * trailFront * n.z;
  //增加落痕路径上的小水滴
  y = fract(y * 10.) + (st.y - .5);
  float dd = length(st - vec2(x, y));
  droplets = S(.3, 0., dd);
  float m = mainDrop + droplets * r * trailFront;

    //m += st.x>a.y*.45 || st.y>a.x*.165 ? 1.2 : 0.;
  return vec2(m, trail);
}

float StaticDrops(vec2 uv, float t) {
  /* uv 放大40倍 */
  uv *= 40.;
  // 得到40个格子
  vec2 id = floor(uv);
  // 将每个格子的中点移动到格子中心位置
  uv = fract(uv) - .5;
  // 获取每个格子的随机数 打散圆心的位置
  vec3 n = N13(id.x * 107.45 + id.y * 3543.654);
  vec2 p = (n.xy - .5) * .7;
  float d = length(uv - p);
  // 随机雨滴随着时间渐入渐出
  float fade = Saw(.025, fract(t + n.z));
  // 降低概率
  float c = S(.3, 0., d) * fract(n.z * 10.) * fade;
  return c;
}

vec2 Drops(vec2 uv, float t, float l0, float l1, float l2) {
  float s = StaticDrops(uv, t) * l0;
  vec2 m1 = DropLayer2(uv, t) * l1;
  vec2 m2 = DropLayer2(uv * 1.85, t) * l2;

  float c = s + m1.x + m2.x;
  c = S(.3, 1., c);

  return vec2(c, max(m1.y * l0, m2.y * l1));
}

void main() {
  /* 
  保持短边为-0.5 , 0.5 
  长的那条边坐标相应放大
   */
  vec2 uv = (gl_FragCoord.xy - .5 * iResolution.xy) / iResolution.y;
  vec2 UV = gl_FragCoord.xy / iResolution.xy;
  float T = iTime;

  float t = T * .2;

  float rainAmount = sin(T * .05) * .3 + .7;

  float maxBlur = mix(3., 6., rainAmount);
  float minBlur = 2.;

  float staticDrops = S(-.5, 1., rainAmount) * 2.;
  float layer1 = S(.25, .75, rainAmount);
  float layer2 = S(.0, .5, rainAmount);

  vec2 c = Drops(uv, t, staticDrops, layer1, layer2);
   #ifdef CHEAP_NORMALS
  vec2 n = vec2(dFdx(c.x), dFdy(c.x));// cheap normals (3x cheaper, but 2 times shittier ;))
    #else
  vec2 e = vec2(.001, 0.);
  //通过贴图颜色(高度)计算法线
  float cx = Drops(uv + e, t, staticDrops, layer1, layer2).x;
  float cy = Drops(uv + e.yx, t, staticDrops, layer1, layer2).x;
  vec2 n = vec2(cx - c.x, cy - c.x);		// expensive normals
    #endif

  vec3 col = textureLod(iChannel0, UV + n, maxBlur).rgb;

    //col = vec3(heart);
  gl_FragColor = vec4(col, 1.);
}