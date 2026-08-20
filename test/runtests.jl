using Test
using Aqua
using JET
using Aletheia

@testset "Aletheia" begin
    Aqua.test_all(Aletheia)
    if pkgversion(JET) < v"0.11"
        JET.test_package(Aletheia; target_defined_modules=true)
    else
        JET.test_package(Aletheia; target_modules=(Aletheia,), analyze_from_definitions=true)
    end
end
