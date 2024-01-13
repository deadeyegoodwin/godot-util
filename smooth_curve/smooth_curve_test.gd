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

# Demonstates SmoothCurve generating smooth curves by setting the
# control points in Curve3D so that the 1st and 2nd derivative of the curve
# are equal at each curve point selected by the user. To add points to the
# curve move the $Marker3D to the desired position and press <Spacebar>. Two lines
# are drawn: one using straight line segments, and the other using
# SmoothCurve to create a smooth curve.
#
# Properties on SmoothCurveTest:
#   Curve Bake Interval : See Curve3D.bake_interval. Controls how accurately
#                         the straight line-segments used to represent the
#                         curve approximate the actual curve. Lower values
#                         give better accuracy.
#   Reset Points: Select to remove all points from the curves. New points
#                 can then be added using $Marker3D.
class_name SmoothCurveTest extends Node

## The bake-interval for the smooth and non-smooth curve. Controls how many
## straight line segments are generated to approximate the curve. Smaller values
## generate more / shorter line segments.
@export_range(0.0001, 1, 0.0001) var curve_bake_interval : float = 0.005 :
	set(v) :
		curve_bake_interval = v; _update_meshes()

## Remove all points from the smooth and non-smooth curves.
@export var reset_points : bool = false :
	set(v) :
		_reset_curves()

# The CSGPolygon used to visualize the curves doesn't like have two adjacent
# Curve3D points being close together. Define an epsilon that can be used to
# make sure two adjacent points are not too close together.
const _curve_point_epsilon : float = 0.005

# The Marker3D used to specify a point to add to the curve.
@onready var _marker := $Marker3D

# The meshes that draw the smooth and non-smooth curves.
@onready var _smooth_curve_mesh := $SmoothCurve
@onready var _nonsmooth_curve_mesh := $NonSmoothCurve

# The non-smoothed curve containing the points added using the marker. This
# curve does not specify control points and so is composed to straight
# line segments.
@onready var _nonsmooth_curve : Curve3D = $NonSmoothCurve/Path3D.curve

# The smoothed curve containing the points added using the marker. Created
# by SmoothCurve with control points so that the curve is smooth.
var _smooth_curve := SmoothCurve.new()

# Remove all points from both non-smooth and smooth curves.
func _reset_curves() -> void:
	_nonsmooth_curve.clear_points()
	_smooth_curve.reset()
	_update_meshes()

# Update meshes representing smooth and non-smooth curves.
func _update_meshes() -> void:
	if _smooth_curve_mesh != null:
		var c := _smooth_curve.curve()
		c.bake_interval = curve_bake_interval
		_smooth_curve_mesh.get_node(_smooth_curve_mesh.path_node).curve = c
	if _nonsmooth_curve_mesh != null:
		var c := _nonsmooth_curve
		c.bake_interval = curve_bake_interval
		_nonsmooth_curve_mesh.get_node(_nonsmooth_curve_mesh.path_node).curve = c

func _process(_delta : float) -> void:
	# Space-bar adds a new point to the curves. Don't allow two adjacent points
	# to be added at the same position (this also acts to debounce the input).
	var pt_cnt := _nonsmooth_curve.point_count
	var same_pos : bool = false
	if pt_cnt > 0:
		same_pos = (_nonsmooth_curve.get_point_position(pt_cnt - 1) == _marker.position)
	if (pt_cnt == 0) or (not same_pos):
		if Input.is_key_pressed(KEY_SPACE):
			# Just add a point to the non-smooth curve...
			_nonsmooth_curve.add_point(_marker.position)
			# For the smooth curve, when the first point is added, we actually
			# add two points, so that we can dynamically update the position for
			# the next point using update_last_point() below.
			if pt_cnt == 0:
				_smooth_curve.append_point(
					_marker.position + Vector3(_curve_point_epsilon, _curve_point_epsilon, 0))
			_smooth_curve.append_point(_marker.position)
			_update_meshes()
		elif _smooth_curve.point_count() > 1:
			_smooth_curve.update_last_point(_marker.position)
			_update_meshes()
