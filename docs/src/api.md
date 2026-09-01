# API reference

The umbrella `Aletheia` package re-exports the focused package interfaces. The
reference below is grouped by implementation package so that the dependency
boundaries are visible.

```@docs
Aletheia
AletheiaCore
AletheiaData
AletheiaLearn
AletheiaSole
Aletheia.SoleLogics
```

## Core syntax, semantics, relations, and theory

```@autodocs
Modules = [AletheiaCore]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## Scalar data and model families

```@autodocs
Modules = [AletheiaData]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## Inductive logic programming

```@autodocs
Modules = [AletheiaLearn]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## SoleLogics compatibility

The compatibility package is opt-in. It provides the nested
`Aletheia.SoleLogics` vocabulary and its many-valued adapters without adding
those names to the core namespace.

```@autodocs
Modules = [Aletheia.SoleLogics, Aletheia.SoleLogics.ManyValuedLogics]
Public = true
Private = false
Order = [:type, :function, :constant]
```
