/*
tris_to_quads_api.h — the C-ABI contract for the tris-to-quads solver
guest. Pascal strings only (length + bytes*, never NUL-terminated).
*/
#ifndef TRIS_TO_QUADS_API_H
#define TRIS_TO_QUADS_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Load a triangle mesh (flat vertex xyz array + flat triangle vertex-
   index array) as the subject of the next solve_* call. Returns 0 on
   success, nonzero on a malformed mesh. */
int32_t tq_load_mesh(const double* vertices_xyz, uint32_t vertex_count,
                      const uint32_t* tri_indices, uint32_t tri_count);

/* Run the box-constrained L-BFGS relaxation + repair pass
   (TrisToQuads.solve in the Lean core) over the loaded mesh. `rho` is
   the penalty weight (TrisToQuads.solve's default is 20.0; pass <= 0 to
   use the default). Returns the number of dissolved edges found (>= 0),
   or a negative value on failure (no mesh loaded). */
int32_t tq_solve(double rho);

/* After tq_solve: the i-th dissolved edge's two triangle ids and the
   objective weight it contributed. Returns 0 on success, nonzero if `i`
   is out of range or tq_solve was not called. */
int32_t tq_dissolved_edge_at(uint32_t i, uint32_t* out_tri_a, uint32_t* out_tri_b,
                              double* out_weight);

#ifdef __cplusplus
}
#endif

#endif /* TRIS_TO_QUADS_API_H */
