# Godot 4 Examples and Utilities

Examples and utilities for Godot 4.

## Smooth Curve3D / 2D

[smooth_curve](smooth_curve) contains a Godot 4 project that contains
the [SmoothCurve](smooth_curve/smooth_curve.gd) class that generates a
smooth Curve3D from a set of points. The curve will pass through all
specified points and will be continuous at the first and second
derivative at each of those points.

An example @tool script that runs in the editor can be found in
[smooth_curve_test.gd](smooth_curve/smooth_curve_test.gd). Open the
SmoothCurveTest scene in the editor, select the Marker3D node, move
the Marker3D and press space-bar to add a point to the curve.

This [video](https://youtu.be/MkfzrjHayyg) demonstrates how this looks.

## Procedurally Control Positions for Particle Emission

The particle system provides options for the surface over which
particles will be emitted (for example, point, sphere, etc.). But what
if you want to emit the particles over an irregular shape, and/or you
want to change those emission points dynamically and procedurally? The
particle system doesn't seem to have an API to directly set the
emission points, but you can do so indirectly by encoding the XYZ
position(s) in an image texture.

An example @tool script that demonstrates how to do this can be found
in [particle_emit_test.gd](smooth_curve/particle_emit_test.gd). This
example is similar to the SmoothCurve example except that it emits
particles along the smooth curve3D and changes particle emission
points as the curve changes. Open the ParticleEmitTest scene in the
editor, select the Marker3D node, move the Marker3D and press
space-bar to add a point to the curve. Notice how the particle
emission points change to match the new position of the curve.
