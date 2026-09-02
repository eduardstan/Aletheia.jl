@testset "algebra laws with generated inputs" begin
    @check function godel_meet_commutative(
        a=Supposition.Data.Integers{Int8}(), b=Supposition.Data.Integers{Int8}()
    )
        x = UInt8(mod(Int(a), 3) + 1)
        y = UInt8(mod(Int(b), 3) + 1)
        return meet(G3, x, y) == meet(G3, y, x)
    end
end
