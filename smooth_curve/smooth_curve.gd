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

# Required to use this class in @tool scripts. Comment-out if not using in
# @tool scripts. See https://github.com/godotengine/godot/issues/81250
@tool

# Generate a smooth Curve3D from a set of points. The curve will pass through
# all points and will be continuous at the first and second derivative at
# each of those points.
#
# Derived from Kirby Baker’s Mathematics of Computer Graphics course at UCLA.
# https://www.math.ucla.edu/%7Ebaker/149.1.02w/handouts/dd_splines.pdf.
# Following descriptions use the same convention for variable names: S is the
# ordered list of points specified explicitly by the user (using
# append_point()) that must lie on the generated curve. S[i] is the i'th
# such point. B is the ordered list of "control points" calculated based
# on the above reference. B[i] is the control point for the corresponding S[i].
# All B[i]'s must be (re)calculated whenever a new point is specified.
# From the S and B values the Curve3D control points are (re)calculated
# for '_curve'.
#
# Possible improvements: Currently recompute the inverse matrix every time a point is added,
# for a large number of points this could become a performance issue. One solution is
# to cache inverse matrices so any given size is only computed once. Another solution is to
# note that, in practice, adding a new point only impacts the B values for the previous
# 'n' points, where 'n' is on the order of 4-8. So could limit recalculation of B's to only
# the last 'n' points, which would limit the maximum size inverse to be order 'n' (and it
# could also be cached).
#
class_name SmoothCurve extends RefCounted

# The Curve3D representing the curve that contains the specified points, S.
# This curve is lazily smoothed by adjusting the in/out control points for each
# S[i] in the Curve3D.
var _curve : Curve3D = Curve3D.new()

# True if new points have been added since the curve has been smoothed.
var _needs_smoothing : bool = false

# Remove all points from the curve.
func reset() -> void:
	_curve.clear_points()
	_needs_smoothing = false

# Append a point to the list of points required to be on the curve (that is,
# append a point to S).
func append_point(pt : Vector3) -> void:
	_curve.add_point(pt)
	_needs_smoothing = true

# Update the position of the last added point, if any.
func update_last_point(pt : Vector3) -> void:
	if _curve.point_count > 0:
		_curve.set_point_position(_curve.point_count - 1, pt)
		_needs_smoothing = true

# Return the number of points added to the curve by 'append_point()'.
func point_count() -> int:
	return _curve.point_count

# Return the distance from the 'idx' point on the curve to a given point, 'pt'.
# Return NAN if 'idx' is not the index of a point on the curve.
func point_distance(idx : int, pt : Vector3) -> float:
	assert((idx >= 0) and (idx < _curve.point_count))
	if (idx < 0) or (idx >= _curve.point_count):
		return NAN
	return pt.distance_to(_curve.get_point_position(idx))

# Return the Curve3D representing the smooth curve.
func curve() -> Curve3D:
	# Lazily smooth the curve if needed...
	if _needs_smoothing:
		_needs_smoothing = false
		# _curve contains the S points. Overwrite existing in/out control points for each of those
		# points by first calculating B from S, and then calculating Curve3D control points from
		# B and S.
		if _curve.point_count <= 2:
			# For a curve consisting of 1 or 2 points, simply use the points
			# directly as the smooth curve is a straight line.
			pass
		else:
			# Calculate B from S... For all cases B[0] = S[0] and B[n-1] = S[n-1].
			var n := _curve.point_count
			var B : Array[Vector3] = []
			B.append(_curve.get_point_position(0))

			if _curve.point_count == 3:
				# With 3 points only B[1] needs to be calculated. We have:
				# S[1] = 1/6 B[0] + 2/3 B[1] + 1/6 B[2]
				# -> S[1] = 1/6 S[0] + 2/3 B[1] + 1/6 S[2]
				# -> B[1] = 3/2 (S[1] - 1/6 (S[0] + S[2]))
				B.append(1.5 * (_curve.get_point_position(1) -
								(1.0 / 6.0) * (_curve.get_point_position(0) + _curve.get_point_position(2))))
			else:
				# With 4 or more points, multiple B[i] must be solved for simultaneously using
				# AB = S*, where S* is an nx1 matrix calculated from S, and A is the  "1 4 1" nxn
				# square matrix:
				#
				#   [ 4 1 0 0 0 ...
				#     1 4 1 0 0 ...
				#     0 1 4 1 0 ...
				#          ...
				#     ... 0 1 4 1 0
				#     ...   0 1 4 1
				#     ...     0 1 4 ]
				#
				# The order of A is n - 2. To solve for B need to find the inverse of A and
				# use: B = A'S*, where A' is the inverse of A. In general finding the inverse of a
				# matrix is difficult, but because of the regular structure of the "1 4 1" matrix
				# it is straight-forward.
				var inverse := _inverse_4_1_4(n - 2)
				var inverse_denominator : int = inverse[-1]

				# Create the S* array...
				var Sstar : Array[Vector3] = []
				for i in range(1, n - 1):
					var pt := _curve.get_point_position(i)
					if i == 1:
						Sstar.append((6 * pt) - _curve.get_point_position(0))
					elif i == (n - 2):
						Sstar.append((6 * pt) - _curve.get_point_position(n - 1))
					else:
						Sstar.append(6 * pt)

				# Calculate B[1] to B[n - 2]
				for i in range(n - 2):
					var inverse_row : Array[int] = inverse[i]
					assert(inverse_row.size() == Sstar.size())
					var b : Vector3 = Vector3.ZERO
					for idx in range(inverse_row.size()):
						b += inverse_row[idx] * Sstar[idx] / inverse_denominator
					B.append(b)

			# B[n-1] = S[n-1]
			B.append(_curve.get_point_position(n - 1))

			# From S and B, set in/out control points for _curve.
			for i in range(n):
				var pt := _curve.get_point_position(i)
				if i == 0:
					_curve.set_point_in(i, Vector3.ZERO)
				else:
					var cp_in : Vector3 = (0.3333 * B[i - 1]) + (0.6667 * B[i])
					_curve.set_point_in(i, cp_in - pt)
				if i == (n - 1):
					_curve.set_point_out(i, Vector3.ZERO)
				else:
					var cp_out : Vector3 = (0.6667 * B[i]) + (0.3333 * B[i + 1])
					_curve.set_point_out(i, cp_out - pt)
	return _curve

# Return the inverse of the "4 1 4" matrix of size 'order'. 'order' must be >= 2. Return
# value as an array. First 'order' entries are the rows of the inverse matrix, each row
# represented by an Array[int]. The row values represent the numerator of the element.
# The last returned array entry is an 'int' that represents the denominator of each element.
# An empty Array is returned if there is an error.
func _inverse_4_1_4(order : int) -> Array:
	assert(order >= 2)
	if order < 2:
		return []

	# As described in https://en.wikipedia.org/wiki/Tridiagonal_matrix#Inversion, we calculate
	# theta[i] and phi[i] using recurrent relationships and then from those values
	# we can calculate all elements in the inverse. For the "1 4 1" matrix it is greatly
	# simplified bacause a[i] forall i = 4 and b[i], c[i] forall i = 1.

	# theta[0] = 1, theta[1] = 4, theta[i] = 4 * theta[i-1] - theta[i-2]
	var theta : Array[int] = [ 1, 4 ]
	for i in range(2, order + 2):
		theta.append(4 * theta[i - 1] - theta[i - 2])

	# phi, for "1 4 1" matrix phi = reverse(theta)
	var phi := theta.duplicate()
	phi.reverse()

	var ret : Array = []

	# Create the inverse, the formulas from the above reference use 1-based 'i' and 'j' for
	# row and column index, respectively... the same is done here.
	for r in range(order):
		var i : int = r + 1
		var row : Array[int] = []
		for c in range(order):
			var j : int = c + 1
			if i < j:
				var s : int = -1 if ((i + j) % 2) == 1 else 1
				row.append(s * theta[i - 1] * phi[j + 1])
			elif i > j:
				var s : int = -1 if ((i + j) % 2) == 1 else 1
				row.append(s * theta[j - 1] * phi[i + 1])
			else:
				row.append(theta[i - 1] * phi[j + 1])
		ret.append(row)

	ret.append(theta[order])
	return ret
