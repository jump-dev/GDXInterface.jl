# Tests for GDXFile API

# For reference: script to create test file "gams_gdx_test.gdx" using GAMS
#=
gms_script = """
Set i /a, b, c/;
Parameter p(i) / a 1.5, b 2.5, c 3.5 /;
Free Variable x(i);
Positive Variable y(i);
x.l(i) = ord(i) * 10;
x.m(i) = ord(i) * 0.1;
y.l(i) = ord(i) * 5;
y.up(i) = 100;
Equation dummy; dummy.. sum(i, x(i)) =e= 0;
execute_unload "gams_gdx_test.gdx", i, p, x, y;
"""
=#

@testset "GDXFile API" begin
    test_gdx = joinpath(TEST_DATA_DIR, "gams_gdx_test.gdx")
    ispath(test_gdx)

    @testset "Reading GDX file created by GAMS" begin
        gdxfile = read_gdx(test_gdx)

        @test :i in list_sets(gdxfile)
        @test :p in list_parameters(gdxfile)

        p = gdxfile[:p]
        @test :value in Tables.columnnames(p)
        @test collect(Tables.getcolumn(p, :value)) == [1.5, 2.5, 3.5]
    end

    @testset "Reading variables" begin
        gdxfile = read_gdx(test_gdx)

        @test :x in list_variables(gdxfile)
        @test :y in list_variables(gdxfile)

        x = gdxfile[:x]
        @test :level in Tables.columnnames(x)
        @test :marginal in Tables.columnnames(x)
        @test :lower in Tables.columnnames(x)
        @test :upper in Tables.columnnames(x)
        @test collect(Tables.getcolumn(x, :level)) == [10.0, 20.0, 30.0]
        @test collect(Tables.getcolumn(x, :marginal)) ≈ [0.1, 0.2, 0.3]

        y = gdxfile[:y]
        @test collect(Tables.getcolumn(y, :level)) == [5.0, 10.0, 15.0]
        @test all(Tables.getcolumn(y, :lower) .== 0.0)
        @test all(Tables.getcolumn(y, :upper) .== 100.0)
    end

    @testset "Write and read round-trip" begin
        supply = (; i = ["seattle", "san-diego"], value = [350.0, 600.0])
        demand = (; j = ["new-york", "chicago", "topeka"], value = [325.0, 300.0, 275.0])

        outfile = joinpath(tempdir(), "gdx_jl_write_test.gdx")
        write_gdx(outfile, "supply" => supply, "demand" => demand)

        gdxfile = read_gdx(outfile)

        @test :supply in list_parameters(gdxfile)
        @test :demand in list_parameters(gdxfile)
        @test collect(Tables.getcolumn(gdxfile[:supply], :value)) == [350.0, 600.0]
        @test collect(Tables.getcolumn(gdxfile[:demand], :value)) == [325.0, 300.0, 275.0]

        @test gdxfile.supply == gdxfile[:supply]
        @test gdxfile.demand == gdxfile[:demand]

        rm(outfile, force=true)
    end

    @testset "Multi-dimensional parameters" begin
        cost = (;
            i = ["seattle", "seattle", "san-diego", "san-diego"],
            j = ["new-york", "chicago", "new-york", "chicago"],
            value = [2.5, 1.7, 2.5, 1.8]
        )

        outfile = joinpath(tempdir(), "gdx_jl_2d_test.gdx")
        write_gdx(outfile, "cost" => cost)

        gdxfile = read_gdx(outfile)
        result = gdxfile[:cost]

        @test length(Tables.getcolumn(result, :value)) == 4
        col_names = collect(Tables.columnnames(result))
        @test length(col_names) == 3
        @test :value in col_names

        rm(outfile, force=true)
    end

    @testset "Integer parsing" begin
        df = (; year = ["2020", "2021", "2022"], value = [1.0, 2.0, 3.0])

        outfile = joinpath(tempdir(), "gdx_jl_int_test.gdx")
        write_gdx(outfile, "data" => df)

        gdxfile = read_gdx(outfile, parse_integers=true)
        @test eltype(Tables.getcolumn(gdxfile[:data], :dim1)) == Int

        gdxfile = read_gdx(outfile, parse_integers=false)
        @test eltype(Tables.getcolumn(gdxfile[:data], :dim1)) == String

        rm(outfile, force=true)
    end

    @testset "GDXFile show and propertynames" begin
        tbl = (; i = ["a", "b"], value = [1.0, 2.0])
        outfile = joinpath(tempdir(), "gdx_jl_show_test.gdx")
        write_gdx(outfile, "param" => tbl)

        gdxfile = read_gdx(outfile)

        io = IOBuffer()
        show(io, gdxfile)
        output = String(take!(io))
        @test occursin("GDXFile:", output)
        @test occursin("param", output)

        props = propertynames(gdxfile)
        @test :param in props

        rm(outfile, force=true)
    end

    @testset "Symbol listing" begin
        t1 = (; i = ["a"], value = [1.0])
        t2 = (; j = ["x"], value = [2.0])

        outfile = joinpath(tempdir(), "gdx_jl_list_test.gdx")
        write_gdx(outfile, "param1" => t1, "param2" => t2)

        gdxfile = read_gdx(outfile)

        params = list_parameters(gdxfile)
        @test :param1 in params
        @test :param2 in params
        @test length(params) == 2

        syms = list_symbols(gdxfile)
        @test length(syms) == 2

        rm(outfile, force=true)
    end

    @testset "GDXFile full round-trip (sets, params, variables)" begin
        gdx1 = read_gdx(test_gdx)

        outfile = joinpath(tempdir(), "gdx_jl_roundtrip.gdx")
        write_gdx(outfile, gdx1)
        gdx2 = read_gdx(outfile)

        @test sort(list_symbols(gdx1)) == sort(list_symbols(gdx2))

        @test collect(Tables.getcolumn(gdx1[:p], :value)) == collect(Tables.getcolumn(gdx2[:p], :value))

        @test collect(Tables.getcolumn(gdx1[:x], :level)) == collect(Tables.getcolumn(gdx2[:x], :level))
        @test collect(Tables.getcolumn(gdx1[:x], :marginal)) ≈ collect(Tables.getcolumn(gdx2[:x], :marginal))
        @test collect(Tables.getcolumn(gdx1[:y], :level)) == collect(Tables.getcolumn(gdx2[:y], :level))
        @test collect(Tables.getcolumn(gdx1[:y], :upper)) == collect(Tables.getcolumn(gdx2[:y], :upper))

        i1_col = collect(Tables.getcolumn(gdx1[:i], first(Tables.columnnames(gdx1[:i]))))
        i2_col = collect(Tables.getcolumn(gdx2[:i], first(Tables.columnnames(gdx2[:i]))))
        @test sort(i1_col) == sort(i2_col)

        rm(outfile, force=true)
    end

    @testset "Special values round-trip" begin
        tbl = (; i = ["a", "b", "c", "d", "e"], value = [NaN, Inf, -Inf, 42.0, -0.0])
        outfile = joinpath(tempdir(), "gdx_jl_special.gdx")
        write_gdx(outfile, "special" => tbl)

        gdxfile = read_gdx(outfile)
        result = Tables.getcolumn(gdxfile[:special], :value)
        @test isnan(result[1])
        @test result[2] == Inf
        @test result[3] == -Inf
        @test result[4] == 42.0
        @test result[5] === -0.0

        rm(outfile, force=true)
    end

    @testset "Scalar (0-dim) parameters" begin
        tbl = (; value = [42.0])
        outfile = joinpath(tempdir(), "gdx_jl_scalar.gdx")
        write_gdx(outfile, "scalar_param" => tbl)

        gdxfile = read_gdx(outfile)
        @test :scalar_param in list_parameters(gdxfile)
        @test collect(Tables.getcolumn(gdxfile[:scalar_param], :value)) == [42.0]
        @test length(collect(Tables.columnnames(gdxfile[:scalar_param]))) == 1

        rm(outfile, force=true)
    end

    @testset "Selective reading (only keyword)" begin
        gdx_full = read_gdx(test_gdx)
        gdx_partial = read_gdx(test_gdx, only=[:p, :x])

        @test length(gdx_partial) == 2
        @test :p in list_parameters(gdx_partial)
        @test :x in list_variables(gdx_partial)
        @test !haskey(gdx_partial, :i)
        @test !haskey(gdx_partial, :y)
        @test collect(Tables.getcolumn(gdx_partial[:p], :value)) == collect(Tables.getcolumn(gdx_full[:p], :value))

        gdx_str = read_gdx(test_gdx, only=["i"])
        @test length(gdx_str) == 1
        @test :i in list_sets(gdx_str)
    end

    @testset "Error handling" begin
        @test_throws GDXException read_gdx("nonexistent_file_12345.gdx")
    end

    @testset "get_symbol" begin
        gdxfile = read_gdx(test_gdx)

        sym_p = get_symbol(gdxfile, :p)
        @test sym_p isa GDXParameter
        @test sym_p.name == "p"
        @test sym_p.records == gdxfile[:p]

        sym_x = get_symbol(gdxfile, :x)
        @test sym_x isa GDXVariable

        sym_i = get_symbol(gdxfile, "i")
        @test sym_i isa GDXSet
    end

    @testset "GDXFile iteration and length" begin
        gdxfile = read_gdx(test_gdx)
        @test length(gdxfile) == length(list_symbols(gdxfile))

        count = 0
        for (k, v) in gdxfile
            count += 1
            @test k isa Symbol
            @test v isa GDXSymbol
        end
        @test count == length(gdxfile)
    end

    @testset "Writing equations" begin
        eq_tbl = (;
            i = ["a", "b"],
            level = [1.0, 2.0],
            marginal = [0.5, 0.6],
            lower = [-Inf, -Inf],
            upper = [Inf, Inf],
            scale = [1.0, 1.0]
        )
        eq = GDXEquation("myeq", "test equation", ["i"], 0, eq_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:myeq => eq))

        outfile = joinpath(tempdir(), "gdx_jl_eq_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        @test :myeq in list_equations(gdx2)
        @test collect(Tables.getcolumn(gdx2[:myeq], :level)) == [1.0, 2.0]
        @test collect(Tables.getcolumn(gdx2[:myeq], :marginal)) == [0.5, 0.6]

        rm(outfile, force=true)
    end

    @testset "Writing sets standalone" begin
        set_tbl = (; dim1 = ["x", "y", "z"])
        s = GDXSet("myset", "test set", ["*"], set_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:myset => s))

        outfile = joinpath(tempdir(), "gdx_jl_set_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        @test :myset in list_sets(gdx2)
        col = collect(Tables.getcolumn(gdx2[:myset], first(Tables.columnnames(gdx2[:myset]))))
        @test sort(col) == ["x", "y", "z"]

        rm(outfile, force=true)
    end

    @testset "Variable/Equation type enums" begin
        gdxfile = read_gdx(test_gdx)

        sym_x = get_symbol(gdxfile, :x)
        @test sym_x.vartype isa VariableType
        @test sym_x.vartype == VarFree

        sym_y = get_symbol(gdxfile, :y)
        @test sym_y.vartype == VarPositive

        v = GDXVariable("test", "", String[], 3, (; level=[0.0], marginal=[0.0], lower=[0.0], upper=[0.0], scale=[1.0]))
        @test v.vartype == VarPositive

        e = GDXEquation("test", "", String[], 0, (; level=[0.0], marginal=[0.0], lower=[0.0], upper=[0.0], scale=[1.0]))
        @test e.equtype == EqE
    end

    @testset "Case-insensitive symbol lookup" begin
        gdxfile = read_gdx(test_gdx)

        @test gdxfile[:p] == gdxfile[:P]
        @test gdxfile["p"] == gdxfile["P"]
        @test haskey(gdxfile, :P)
        @test haskey(gdxfile, :p)

        @test get_symbol(gdxfile, :P) === get_symbol(gdxfile, :p)
        @test get_symbol(gdxfile, "P") === get_symbol(gdxfile, "p")

        sym = get_symbol(gdxfile, :p)
        @test sym.name == "p"

        gdx2 = read_gdx(test_gdx, only=[:P, :X])
        @test length(gdx2) == 2
        @test :p in list_parameters(gdx2)
        @test :x in list_variables(gdx2)
    end

    @testset "Symbol ordering is preserved" begin
        gdxfile = read_gdx(test_gdx)
        syms = list_symbols(gdxfile)

        iter_syms = Symbol[k for (k, _) in gdxfile]
        @test iter_syms == syms

        outfile = joinpath(tempdir(), "gdx_jl_order_test.gdx")
        write_gdx(outfile, gdxfile)
        gdx2 = read_gdx(outfile)
        @test list_symbols(gdx2) == syms

        rm(outfile, force=true)
    end

    @testset "Set element text round-trip" begin
        set_tbl = (;
            dim1 = ["seattle", "san-diego", "topeka"],
            element_text = ["rainy city", "sunny city", ""]
        )
        s = GDXSet("cities", "transport cities", ["*"], set_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:cities => s))

        outfile = joinpath(tempdir(), "gdx_jl_elemtext_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        result = gdx2[:cities]
        @test :element_text in Tables.columnnames(result)
        et = Tables.getcolumn(result, :element_text)
        @test et[1] == "rainy city"
        @test et[2] == "sunny city"
        @test et[3] == ""

        rm(outfile, force=true)
    end

    @testset "Set without element text has no extra column" begin
        set_tbl = (; dim1 = ["a", "b", "c"])
        s = GDXSet("simple", "no text", ["*"], set_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:simple => s))

        outfile = joinpath(tempdir(), "gdx_jl_notext_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        @test !(:element_text in Tables.columnnames(gdx2[:simple]))

        rm(outfile, force=true)
    end

    @testset "Alias round-trip" begin
        set_tbl = (; dim1 = ["a", "b", "c"])
        s = GDXSet("i", "original set", ["*"], set_tbl)
        a = GDXAlias("j", "alias for i", "i")
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :j => a))

        outfile = joinpath(tempdir(), "gdx_jl_alias_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        @test :i in list_sets(gdx2)
        @test :j in list_aliases(gdx2)

        alias_sym = get_symbol(gdx2, :j)
        @test alias_sym isa GDXAlias
        @test alias_sym.alias_for == "i"

        @test gdx2[:j] == gdx2[:i]

        rm(outfile, force=true)
    end

    @testset "GDXAlias show" begin
        a = GDXAlias("j", "", "i")
        io = IOBuffer()
        show(io, a)
        @test occursin("j", String(take!(io)))
    end

    @testset "Domain preservation on round-trip (issue #3)" begin
        set_tbl = (; i = ["a", "b", "c"])
        s = GDXSet("i", "index set", ["*"], set_tbl)
        par_tbl = (; i = ["a", "b", "c"], value = [10.0, 20.0, 30.0])
        p = GDXParameter("x", "A parameter over i", ["i"], par_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :x => p))

        outfile = joinpath(tempdir(), "gdx_jl_domain_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        x2 = get_symbol(gdx2, :x)
        @test x2.domain == ["i"]
        @test first(Tables.columnnames(gdx2[:x])) == :i

        rm(outfile, force=true)
    end

    @testset "Domain preservation for variables (issue #3)" begin
        set_tbl = (; i = ["a", "b", "c"])
        s = GDXSet("i", "index set", ["*"], set_tbl)
        var_tbl = (;
            i = ["a", "b", "c"],
            level = [1.0, 2.0, 3.0],
            marginal = [0.0, 0.0, 0.0],
            lower = [-Inf, -Inf, -Inf],
            upper = [Inf, Inf, Inf],
            scale = [1.0, 1.0, 1.0]
        )
        v = GDXVariable("y", "A variable over i", ["i"], VarFree, var_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :y => v))

        outfile = joinpath(tempdir(), "gdx_jl_domain_var_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        y2 = get_symbol(gdx2, :y)
        @test y2.domain == ["i"]
        @test first(Tables.columnnames(gdx2[:y])) == :i

        rm(outfile, force=true)
    end

    @testset "Domain preservation for equations (issue #3)" begin
        set_tbl = (; i = ["a", "b"])
        s = GDXSet("i", "index set", ["*"], set_tbl)
        eq_tbl = (;
            i = ["a", "b"],
            level = [1.0, 2.0],
            marginal = [0.5, 0.6],
            lower = [-Inf, -Inf],
            upper = [Inf, Inf],
            scale = [1.0, 1.0]
        )
        eq = GDXEquation("myeq", "test eq", ["i"], EqE, eq_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :myeq => eq))

        outfile = joinpath(tempdir(), "gdx_jl_domain_eq_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        eq2 = get_symbol(gdx2, :myeq)
        @test eq2.domain == ["i"]
        @test first(Tables.columnnames(gdx2[:myeq])) == :i

        rm(outfile, force=true)
    end

    @testset "Multi-dimensional domain preservation (issue #3)" begin
        si = GDXSet("i", "rows", ["*"], (; i = ["a", "b"]))
        sj = GDXSet("j", "cols", ["*"], (; j = ["x", "y"]))
        par_tbl = (;
            i = ["a", "a", "b", "b"],
            j = ["x", "y", "x", "y"],
            value = [1.0, 2.0, 3.0, 4.0]
        )
        p = GDXParameter("cost", "transport cost", ["i", "j"], par_tbl)
        gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => si, :j => sj, :cost => p))

        outfile = joinpath(tempdir(), "gdx_jl_domain_2d_test.gdx")
        write_gdx(outfile, gdxfile)

        gdx2 = read_gdx(outfile)
        cost2 = get_symbol(gdx2, :cost)
        @test cost2.domain == ["i", "j"]
        cnames = collect(Tables.columnnames(gdx2[:cost]))
        @test cnames[1:2] == [:i, :j]

        rm(outfile, force=true)
    end

    @testset "Domain preservation with GAMS-generated file (issue #3)" begin
        gdx1 = read_gdx(test_gdx)

        p1 = get_symbol(gdx1, :p)
        original_domain = p1.domain

        outfile = joinpath(tempdir(), "gdx_jl_gams_domain_rt.gdx")
        write_gdx(outfile, gdx1)

        gdx2 = read_gdx(outfile)
        p2 = get_symbol(gdx2, :p)
        @test p2.domain == original_domain

        x1 = get_symbol(gdx1, :x)
        x2 = get_symbol(gdx2, :x)
        @test x2.domain == x1.domain

        rm(outfile, force=true)
    end

    @testset "Setting symbols via indexing" begin
        gdxfile = GDXFile("")

        tbl = (; i = ["a", "b"], value = [1.0, 2.0])
        p = GDXParameter("p", "test param", ["i"], tbl)
        gdxfile[:p] = p

        @test :p in list_parameters(gdxfile)
        @test collect(Tables.getcolumn(gdxfile[:p], :value)) == [1.0, 2.0]

        tbl2 = (; j = ["x", "y"], value = [3.0, 4.0])
        p2 = GDXParameter("q", "another param", ["j"], tbl2)
        gdxfile["q"] = p2

        @test :q in list_parameters(gdxfile)
        @test collect(Tables.getcolumn(gdxfile[:q], :value)) == [3.0, 4.0]
    end

    @testset "DataFrame sink" begin
        gdxfile = read_gdx(test_gdx, DataFrame)

        p = gdxfile[:p]
        @test p isa DataFrame
        @test "value" in names(p)
        @test p.value == [1.5, 2.5, 3.5]

        x = gdxfile[:x]
        @test x isa DataFrame
        @test x.level == [10.0, 20.0, 30.0]
    end

    @testset "DataFrame metadata description" begin
        df = DataFrame(i = ["a", "b"], value = [1.0, 2.0])
        metadata!(df, "description", "from metadata", style=:default)

        outfile = joinpath(tempdir(), "gdx_jl_metadata_desc.gdx")
        write_gdx(outfile, "meta_param" => df)

        gdxfile = read_gdx(outfile)
        @test get_symbol(gdxfile, :meta_param).description == "from metadata"

        rm(outfile, force=true)
    end

    @testset "Tables.jl interface on GDXSymbol" begin
        gdxfile = read_gdx(test_gdx)
        sym_p = get_symbol(gdxfile, :p)

        @test Tables.istable(typeof(sym_p))
        @test Tables.columnaccess(typeof(sym_p))

        cols = Tables.columns(sym_p)
        @test :value in Tables.columnnames(cols)

        schema = Tables.schema(sym_p)
        @test schema !== nothing
        @test :value in schema.names

        alias = GDXAlias("j", "", "i")
        @test !Tables.istable(typeof(alias))
    end
end
