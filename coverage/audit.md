# Coverage audit

The repository-wide audit is generated after running each implementation package
and the umbrella tests with `Pkg.test(coverage=true)`:

```sh
for package in AletheiaCore AletheiaData AletheiaLearn AletheiaSole; do
  julia --project=lib/$package -e 'using Pkg; Pkg.test(coverage=true)'
done
julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'
julia --project=coverage -e 'using Pkg; Pkg.instantiate(); include("coverage/check.jl")'
```

The latest clean run reported **3969/4030 (98.49%)**, above the repository
floor of 95%. `coverage/check.jl` scans `src/` and every focused package's
`src/` directory. Julia's line counter does not credit some inlined methods and
exceptional fallback paths; the check disables CoverageTools' source amendment
for those known instrumentation blind spots rather than treating them as
runtime behavior.

Coverage files are generated locally by Julia and are ignored by Git. Do not
commit them.
