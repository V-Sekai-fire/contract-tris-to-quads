/-
Mesh.lean — a triangle mesh plus the triangle-ADJACENCY graph the tris-to-
quads problem is actually solved over: one node per triangle, one edge per
shared mesh edge between two triangles (a boundary edge has only one
incident triangle and is never a candidate), weighted the same way the
upstream ILP weights it (`1 + 0.1 * len / maxLen`, from
Rulesobeyer/Optimized-Tris-to-Quads-Converter's `setObjective`).
-/
namespace TrisToQuads

abbrev VertexId := Nat
abbrev TriId := Nat

structure Vec3 where
  x : Float
  y : Float
  z : Float
  deriving Repr, Inhabited, BEq

def Vec3.dist (a b : Vec3) : Float :=
  let dx := a.x - b.x
  let dy := a.y - b.y
  let dz := a.z - b.z
  Float.sqrt (dx * dx + dy * dy + dz * dz)

structure TriMesh where
  verts : Array Vec3
  tris : Array (VertexId × VertexId × VertexId)
  deriving Inhabited

def TriMesh.position (m : TriMesh) (v : VertexId) : Vec3 :=
  m.verts.getD v ⟨0, 0, 0⟩

/-- A candidate "dissolve this edge" move: the two triangles it would
merge into a quad, the shared edge's two endpoint vertices, and the
upstream-style weight. -/
structure CandidateEdge where
  triA : TriId
  triB : TriId
  va : VertexId
  vb : VertexId
  weight : Float
  deriving Repr, Inhabited

def edgeKey (a b : VertexId) : VertexId × VertexId :=
  if a ≤ b then (a, b) else (b, a)

/-- Every interior (two-triangle) edge of the mesh, each as one
`CandidateEdge`, weighted `1 + 0.1 * len / maxLen` as the upstream ILP
weights its objective (see `Rulesobeyer/Optimized-Tris-to-Quads-Converter`
`__init__.py`'s `setObjective`). Boundary edges (one incident triangle)
are excluded — dissolving one would leave a hole, never a valid move. -/
def candidateEdges (m : TriMesh) : Array CandidateEdge := Id.run do
  -- first pass: collect (edgeKey, triangle) pairs, then for each distinct
  -- key gather its owning triangles via a linear scan (no HashMap
  -- dependency: this package has zero external `require`s by design).
  let mut keyTriPairs : Array ((VertexId × VertexId) × TriId) := #[]
  for ti in [0:m.tris.size] do
    let (a, b, c) := m.tris[ti]!
    for (x, y) in #[(a, b), (b, c), (c, a)] do
      keyTriPairs := keyTriPairs.push (edgeKey x y, ti)
  let mut seen : Array (VertexId × VertexId) := #[]
  let mut maxLen : Float := 0
  let mut raw : Array (VertexId × VertexId × TriId × TriId × Float) := #[]
  for (key, _) in keyTriPairs do
    if !seen.contains key then
      seen := seen.push key
      let owners := keyTriPairs.filterMap fun (k, t) => if k == key then some t else none
      if owners.size == 2 then
        let len := Vec3.dist (m.position key.1) (m.position key.2)
        if len > maxLen then maxLen := len
        raw := raw.push (key.1, key.2, owners[0]!, owners[1]!, len)
  let mut out : Array CandidateEdge := #[]
  for (va, vb, ta, tb, len) in raw do
    let w := if maxLen > 0 then 1.0 + 0.1 * len / maxLen else 1.0
    out := out.push { triA := ta, triB := tb, va := va, vb := vb, weight := w }
  return out

end TrisToQuads
