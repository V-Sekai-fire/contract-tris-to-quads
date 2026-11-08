/*
main.c — contract-tris-to-quads guest shim: a static RISC-V64 Linux
executable exposing api/tris_to_quads_api.h to a godot-sandbox host.

STAGE 1 of 3, same honest-stub pattern as sinew-mocap/measure's
guest/main.c: this shim exists so the guest BUILDS and its symbol/
.sandbox_variant section gates pass. tq_load_mesh does a real shape
check; tq_solve and tq_dissolved_edge_at are explicit STUBS that report
failure (negative/nonzero), never a fabricated result -- the real
TrisToQuads.lean solve (core/lean/TrisToQuads/Solve.lean, verified
against a known-optimal grid matching and a negative control, see
core/lean's own test suite) is not wired in or ported to run ON this
guest yet. Stage 2 is a host-side oracle call into the Lean executable;
stage 3 is the actual Lean-to-RISC-V runtime port.
*/
#include "../api/tris_to_quads_api.h"

__attribute__((used, retain, section(".sandbox_variant")))
static const unsigned char sandbox_variant_marker[8] = {'S', 'B', 'X', 'V', 40, 0, 0, 0};

int32_t tq_load_mesh(const double* vertices_xyz, uint32_t vertex_count,
                      const uint32_t* tri_indices, uint32_t tri_count) {
  (void)vertices_xyz;
  (void)tri_indices;
  if (vertex_count == 0 || tri_count == 0) {
    return 1;
  }
  return 0;
}

int32_t tq_solve(double rho) {
  (void)rho;
  return -1; /* stage 1: no real solve wired in yet */
}

int32_t tq_dissolved_edge_at(uint32_t i, uint32_t* out_tri_a, uint32_t* out_tri_b,
                              double* out_weight) {
  (void)i;
  (void)out_tri_a;
  (void)out_tri_b;
  (void)out_weight;
  return 1; /* stage 1: nothing to report */
}

int main(void) { return 0; }
