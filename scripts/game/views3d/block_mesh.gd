extends RefCounted
## Procedural beveled-box mesh generator (Fase 1). Everything the 3D board
## needs geometrically is built from code: one unit box with a top chamfer,
## instanced via MultiMesh with per-instance colors. Deterministic, no imports.
##
## Winding is auto-corrected against the analytic face normal, so no face can
## end up inside-out.

static func _add_quad(verts: PackedVector3Array, norms: PackedVector3Array,
		uvs: PackedVector2Array, idx: PackedInt32Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, nrm: Vector3) -> void:
	# Reverse the winding when it disagrees with the outward normal.
	if (b - a).cross(c - a).dot(nrm) < 0.0:
		var t := b
		b = d
		d = t
	var base := verts.size()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(d)
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	for _i in 4:
		norms.append(nrm)
	idx.append(base)
	idx.append(base + 1)
	idx.append(base + 2)
	idx.append(base)
	idx.append(base + 2)
	idx.append(base + 3)

static func beveled_box(w: float, h: float, d: float, c: float) -> ArrayMesh:
	var hx := w * 0.5
	var hy := h * 0.5
	var hz := d * 0.5
	c = clampf(c, 0.001, min(hx, min(hz, hy)) * 0.45)
	# corners
	var b0 := Vector3(-hx, -hy, -hz)
	var b1 := Vector3(hx, -hy, -hz)
	var b2 := Vector3(hx, -hy, hz)
	var b3 := Vector3(-hx, -hy, hz)
	var t0 := Vector3(-hx + c, hy, -hz + c)
	var t1 := Vector3(hx - c, hy, -hz + c)
	var t2 := Vector3(hx - c, hy, hz - c)
	var t3 := Vector3(-hx + c, hy, hz - c)
	var f0 := Vector3(-hx, hy - c, -hz)
	var f1 := Vector3(hx, hy - c, -hz)
	var f2 := Vector3(hx, hy - c, hz)
	var f3 := Vector3(-hx, hy - c, hz)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()

	_add_quad(verts, norms, uvs, idx, b0, b1, b2, b3, Vector3(0, -1, 0))            # bottom
	_add_quad(verts, norms, uvs, idx, t0, t3, t2, t1, Vector3(0, 1, 0))             # top
	_add_quad(verts, norms, uvs, idx, f3, f2, t2, t3, Vector3(0, 1, 1).normalized())  # chamfer +z
	_add_quad(verts, norms, uvs, idx, f1, f0, t0, t1, Vector3(0, 1, -1).normalized()) # chamfer -z
	_add_quad(verts, norms, uvs, idx, f2, f1, t1, t2, Vector3(1, 1, 0).normalized())  # chamfer +x
	_add_quad(verts, norms, uvs, idx, f3, f0, t0, t3, Vector3(-1, 1, 0).normalized()) # chamfer -x
	_add_quad(verts, norms, uvs, idx, f3, f2, b2, b3, Vector3(0, 0, 1))             # side +z
	_add_quad(verts, norms, uvs, idx, f2, f1, b1, b2, Vector3(1, 0, 0))             # side +x
	_add_quad(verts, norms, uvs, idx, f1, f0, b0, b1, Vector3(0, 0, -1))            # side -z
	_add_quad(verts, norms, uvs, idx, f0, f3, b3, b0, Vector3(-1, 0, 0))            # side -x

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
