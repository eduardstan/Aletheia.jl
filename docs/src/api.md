# API reference

The umbrella `Aletheia` package re-exports the focused interfaces in this
monorepo. The reference below is grouped by implementation package so that the
shared Core boundary and each data, inference, graph, learning, compatibility,
audit, and neural-symbolic layer remain visible. Narrative guides are linked
from the [one-engine overview](engine.md).

```@docs
Aletheia
AletheiaCore
AletheiaData
AletheiaLearn
AletheiaSole
AletheiaCircuits
AletheiaGraphs
AletheiaAudit
AletheiaNeSy
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

## Compatibility adapter

`AletheiaSole` is an opt-in adapter package. Its compatibility vocabulary and
many-valued boundary stay outside the Core namespace. The complete mapping and
consumer evidence are in the [Coming from SoleLogics](compatibility.md) on-ramp.

```@autodocs
Modules = [Aletheia.SoleLogics, Aletheia.SoleLogics.ManyValuedLogics]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## Distribution-semantics circuits

```@autodocs
Modules = [AletheiaCircuits]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## Typed knowledge graphs

```@autodocs
Modules = [AletheiaGraphs]
Public = true
Private = false
Order = [:type, :function, :constant]
```

## Audit artifacts

```@autodocs
Modules = [AletheiaAudit]
Public = true
Private = false
Order = [:type, :function, :constant]
```

See [Audit artifacts](audit.md) for the trace and metric contract.

## Neural-symbolic interface

```@autodocs
Modules = [AletheiaNeSy]
Public = true
Private = false
Order = [:type, :function, :constant]
```

See [Neural-symbolic interface](nesy.md) for the validated neural boundary and
finite extraction contract.
