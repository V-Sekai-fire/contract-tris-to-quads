import Lake
open Lake DSL

-- Lean4 port of the "optimal tris-to-quads" problem
-- (V-Sekai-archive/Optimized-Tris-to-Quads-Converter, itself a fork of
-- SaitoTsutomu/Tris-Quads-Ex): the upstream Blender add-on solves it as
-- an exact 0/1 ILP via PuLP/CBC (maximize a weighted sum of "dissolve
-- this edge" binary variables subject to "each triangle touches at most
-- one dissolved edge"). iFire: "use our lbfgs-b to solve tri to quads" --
-- this package is a from-scratch Lean4 continuous relaxation of that
-- same ILP (box-constrained x_e in [0,1] plus a quadratic penalty for
-- the per-triangle constraint) solved with a real two-loop-recursion
-- L-BFGS optimizer with gradient projection onto the box, NOT a binding
-- to sinew-mocap/solve's existing core/lbfgsb Slang/GPU pipeline (that
-- one is wired to the cloth-drape problem's own kernel table and is not
-- a general bound-constrained solver entry point) -- see
-- TrisToQuads/LBFGSB.lean's module doc for the honest scope line.
package TrisToQuads where

@[default_target] lean_lib TrisToQuads

lean_exe tris_to_quads_test where
  root := `Tests.TrisToQuadsTest
