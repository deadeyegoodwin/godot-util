# Copyright 2024, David Goodwin. All rights reserved.
#
# BSD 3-Clause License
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# To run in editior make sure @tool is uncommented below and also in in
# smooth_curve.gd.
@tool

# Demonstates emitting particles along an arbitrary surface and changing the
# emission points dynamically. For this example, particles are emitted along a
# curve3D but any particle positions can be used.
class_name ParticleEmitTest extends Node

## The bake interval that determines how frequently there are particle emission
## points along the curve.
@export_range(0.005, 1.0) var curve_bake_interval : float = 0.01

## Remove all points from the smooth curve.
@export var reset_points : bool = false :
	set(v) :
		_reset_curves()

# Define an epsilon that can be used to make sure two adjacent curve points are
# not too close together.
const _curve_point_epsilon : float = 0.005

# The particles...
@onready var _particles := $GPUParticles3D

# The Marker3D used to specify a point to add to the curve.
@onready var _marker := $Marker3D

# The smoothed curve containing the points added using the marker. Created
# by SmoothCurve with control points so that the curve is smooth.
var _smooth_curve := SmoothCurve.new()

# The particle emission positions must be represented in an Image. Create this image
# once and update it as necessary as the emission positions changes.
const _max_emission_positions : int = 1024
var _emission_image := Image.create(_max_emission_positions, 1, false, Image.FORMAT_RGBF)

func _ready() -> void:
	_refresh_particle_emission_positions()

# Remove all points from the smooth curves.
func _reset_curves() -> void:
	_smooth_curve.reset()
	_refresh_particle_emission_positions()

func _process(_delta : float) -> void:
	# Space-bar adds a new point to the curves. Don't allow two adjacent points
	# to be added at the same position (this also acts to debounce the input).
	var pt_cnt := _smooth_curve.point_count()
	var same_pos : bool = false
	if pt_cnt > 1:
		same_pos = (_smooth_curve.point_distance(pt_cnt - 2, _marker.position) <= _curve_point_epsilon)
	if (pt_cnt == 0) or (not same_pos):
		if Input.is_key_pressed(KEY_SPACE):
			# When the first point is added to the curve, we actually
			# add two points, so that we can dynamically update the position for
			# the next point using update_last_point() below.
			if pt_cnt == 0:
				_smooth_curve.append_point(
					_marker.position + Vector3(_curve_point_epsilon, _curve_point_epsilon, 0))
			_smooth_curve.append_point(_marker.position)
			_refresh_particle_emission_positions()
		elif _smooth_curve.point_count() > 1:
			_smooth_curve.update_last_point(_marker.position)
			_refresh_particle_emission_positions()

# Update the particle emission points.
func _refresh_particle_emission_positions() -> void:
	var curve3d := _smooth_curve.curve()

	curve3d.bake_interval = curve_bake_interval
	var pts := curve3d.get_baked_points()
	var cnt := pts.size()
	if cnt == 0:
		_particles.amount = 1
		_particles.process_material.emission_point_count = 0
	else:
		# If there are more points on the curve then there are particle
		# emission points, then need to skip some of the curve points.
		var step : float = max(1.0, float(cnt) / _max_emission_positions)
		for idx in range(min(cnt, _max_emission_positions)):
			var pt := pts[int(float(idx) * step)]
			_emission_image.set_pixel(idx, 0, Color(pt.x, pt.y, pt.z))
		var image_texture := ImageTexture.create_from_image(_emission_image)
		_particles.process_material.emission_point_texture = image_texture
		# We set the number of particles to match the number of emission points,
		# but that is not required. We could have a constant value for amount
		# or we could set it to something unrelated to the number of emission
		# points.
		_particles.process_material.emission_point_count = min(cnt, _max_emission_positions)
		_particles.amount = min(cnt, _max_emission_positions)
