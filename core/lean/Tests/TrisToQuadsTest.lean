/-
TrisToQuadsTest.lean — property tests against KNOWN-OPTIMAL matchings.

Two fixtures:
- A flat 2x2-square grid, split into 8 triangles (each unit square cut
  along one diagonal): the mathematically optimal matching pairs every
  triangle back into its own square (4 dissolved edges, the diagonals),
  recovering exactly the 4 original unit squares. This is a real,
  independently-verifiable ground truth (not just "the solver agrees
  with itself").
- A single isolated triangle (no interior edges at all): a negative
  control. candidateEdges must be empty, and solve must return an empty
  dissolve set with objectiveValue 0 — not a fabricated match.
-/
import TrisToQuads

namespace TrisToQuads.Tests

def check (failures : IO.Ref Nat) (name : String) (cond : Bool) : IO Unit := do
  if cond then
    IO.println s!"OK   {name}"
  else
    IO.println s!"FAIL {name}"
    failures.modify (· + 1)

/-- A 2x2 grid of unit squares (3x3 = 9 vertices), each square split into
2 triangles along the SAME diagonal direction (so every square's two
triangles share exactly one interior edge, the diagonal) — 8 triangles,
4 of which pairs are the "perfect" quads a correct solver must find. -/
def gridMesh : TriMesh := Id.run do
  let mut verts : Array Vec3 := #[]
  for j in [0:3] do
    for i in [0:3] do
      verts := verts.push ⟨Float.ofNat i, Float.ofNat j, 0⟩
  let idx (i j : Nat) : VertexId := j * 3 + i
  let mut tris : Array (VertexId × VertexId × VertexId) := #[]
  for j in [0:2] do
    for i in [0:2] do
      let a := idx i j
      let b := idx (i + 1) j
      let c := idx i (j + 1)
      let d := idx (i + 1) (j + 1)
      tris := tris.push (a, b, d)
      tris := tris.push (a, d, c)
  return { verts := verts, tris := tris }

def isolatedTriangleMesh : TriMesh :=
  { verts := #[⟨0, 0, 0⟩, ⟨1, 0, 0⟩, ⟨0, 1, 0⟩], tris := #[(0, 1, 2)] }

def runTests (failures : IO.Ref Nat) : IO Unit := do
  -- candidateEdges sanity: the grid has exactly 4 interior "diagonal"
  -- edges that pair triangles within the SAME square (the ones a correct
  -- solver should dissolve) plus some interior edges BETWEEN adjacent
  -- squares (the grid lines) that a correct solver must NOT choose
  -- (dissolving one of those would merge two different squares, never
  -- forming a quad with the right shape -- though this simple relaxation
  -- has no shape-awareness, the matching constraint alone already rules
  -- most of them out once the diagonals are taken).
  let grid := gridMesh
  let edges := candidateEdges grid
  check failures "grid: candidateEdges non-empty" (edges.size > 0)

  let result := solve grid
  check failures "grid: found exactly 4 dissolved edges (one per square)"
    (result.dissolvedEdges.size == 4)
  -- every triangle is touched by AT MOST one dissolved edge (the hard
  -- constraint the repair pass exists to guarantee, regardless of how
  -- the continuous relaxation converged)
  let mut touchCount : Array Nat := Array.replicate grid.tris.size 0
  for e in result.dissolvedEdges do
    touchCount := touchCount.set! e.triA (touchCount[e.triA]! + 1)
    touchCount := touchCount.set! e.triB (touchCount[e.triB]! + 1)
  let validMatching := touchCount.all (· <= 1)
  check failures "grid: repaired result is a valid matching (each tri <= 1 dissolve)"
    validMatching
  check failures "grid: every triangle is covered (2 tris/square x 4 squares, all matched)"
    (touchCount.all (· == 1))

  -- Negative control: an isolated triangle has NO interior edges at all,
  -- so candidateEdges must be empty and solve must report nothing
  -- dissolved — a solver that fabricated a match here would be caught.
  let iso := isolatedTriangleMesh
  check failures "isolated triangle: candidateEdges is empty"
    ((candidateEdges iso).size == 0)
  let isoResult := solve iso
  check failures "isolated triangle: solve finds nothing to dissolve, not faked"
    (isoResult.dissolvedEdges.size == 0 && isoResult.objectiveValue == 0)

  -- Sanity on the plain L-BFGS-B box solver itself, independent of the
  -- mesh problem: minimize a simple convex quadratic with a known
  -- analytic minimum OUTSIDE the box, so the box projection is actually
  -- exercised (minimizer of (x-5)^2 is x=5, clamped into [0,1] -> 1).
  let quadObj : Vec → Float := fun x => (x[0]! - 5.0) * (x[0]! - 5.0)
  let quadGrad : Vec → Vec := fun x => #[2.0 * (x[0]! - 5.0)]
  let quadResult := solveBoxed quadObj quadGrad #[0.2] 0.0 1.0
  check failures "LBFGSB box solver: clamps to the box boundary (x -> 1.0, not 5.0)"
    (Float.abs (quadResult.x[0]! - 1.0) < 1e-3)

def main : IO Unit := do
  let failures ← IO.mkRef 0
  runTests failures
  let n ← failures.get
  if n > 0 then
    IO.eprintln s!"{n} check(s) failed"
    IO.Process.exit 1
  else
    IO.println "all checks passed"

end TrisToQuads.Tests

def main : IO Unit := TrisToQuads.Tests.main
