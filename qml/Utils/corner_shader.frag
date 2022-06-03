varying highp vec2 textureCoords;
uniform sampler2D source;
uniform lowp float qt_Opacity;
uniform highp vec2 start;
uniform highp vec2 center;
uniform highp float delta;
uniform highp float active;

void main() {
    highp vec2 Coord  = max((abs(textureCoords - center) - start) / (center - start), vec2(0.0));
    lowp float Alpha = smoothstep(1.0, 1.0 - delta, length(Coord));
    gl_FragColor = vec4(texture2D(source, textureCoords).rgb * Alpha * active, Alpha) * qt_Opacity;
}
		
