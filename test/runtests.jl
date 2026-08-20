using Test
using Aqua
using JET
using Aletheia

@testset "Aletheia" begin
    Aqua.test_all(Aletheia)
    JET.report_package(Aletheia)
end
