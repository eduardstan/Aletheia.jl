# One-dataset showcase

This bundle runs the same four synthetic records through crisp, many-valued,
probabilistic, graph, and neural-symbolic readings. `records.csv` is generated
for this repository and contains no third-party data.

From the repository root:

```sh
julia --project=examples/showcase -e 'using Pkg; Pkg.instantiate()'
julia --project=examples/showcase examples/showcase/showcase.jl
```

The script uses seed `0x5EED_2025`, although the committed dataset and model are
fully deterministic. It performs no data download at run time. The umbrella
suite runs the same journey in `test/showcase.jl`.
