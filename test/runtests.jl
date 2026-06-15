# Copyright (c) 2026 Martin Kirk Bonde, James Daniel Foster and contributors
# Copyright (c) 2020-2023 GAMS Software GmbH
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestGDXInterface

using GDXInterface
using Test

import DataFrames
import Tables

# ```gams
# Set i /a, b, c/;
# Parameter p(i) / a 1.5, b 2.5, c 3.5 /;
# Free Variable x(i);
# Positive Variable y(i);
# x.l(i) = ord(i) * 10;
# x.m(i) = ord(i) * 0.1;
# y.l(i) = ord(i) * 5;
# y.up(i) = 100;
# Equation dummy; dummy.. sum(i, x(i)) =e= 0;
# execute_unload "gams_gdx_test.gdx", i, p, x, y;
# ```
const GAMS_GDX_TEST = joinpath(@__DIR__, "data", "gams_gdx_test.gdx")

function runtests()
    is_test(f) = startswith("$f", "test_")
    @testset "$name" for name in filter(is_test, names(@__MODULE__; all = true))
        getfield(@__MODULE__, name)()
    end
    return
end

function test_Reading_GDX_file_created_by_GAMS()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    @test :i in list_sets(gdxfile)
    @test :p in list_parameters(gdxfile)
    p = gdxfile[:p]
    @test :value in Tables.columnnames(p)
    @test collect(Tables.getcolumn(p, :value)) == [1.5, 2.5, 3.5]
    return
end

function test_Reading_variables()
    gdxfile = read_gdx(GAMS_GDX_TEST)
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
    return
end

function test_Write_and_read_round_trip()
    supply = (; i = ["seattle", "san-diego"], value = [350.0, 600.0])
    demand =
        (; j = ["new-york", "chicago", "topeka"], value = [325.0, 300.0, 275.0])
    outfile = joinpath(tempdir(), "gdx_jl_write_test.gdx")
    write_gdx(outfile, "supply" => supply, "demand" => demand)
    gdxfile = read_gdx(outfile)
    @test :supply in list_parameters(gdxfile)
    @test :demand in list_parameters(gdxfile)
    @test collect(Tables.getcolumn(gdxfile[:supply], :value)) == [350.0, 600.0]
    @test collect(Tables.getcolumn(gdxfile[:demand], :value)) ==
          [325.0, 300.0, 275.0]
    @test gdxfile.supply == gdxfile[:supply]
    @test gdxfile.demand == gdxfile[:demand]
    rm(outfile; force = true)
    return
end

function test_Multi_dimensional_parameters()
    cost = (;
        i = ["seattle", "seattle", "san-diego", "san-diego"],
        j = ["new-york", "chicago", "new-york", "chicago"],
        value = [2.5, 1.7, 2.5, 1.8],
    )
    outfile = joinpath(tempdir(), "gdx_jl_2d_test.gdx")
    write_gdx(outfile, "cost" => cost)
    gdxfile = read_gdx(outfile)
    result = gdxfile[:cost]
    @test length(Tables.getcolumn(result, :value)) == 4
    col_names = collect(Tables.columnnames(result))
    @test length(col_names) == 3
    @test :value in col_names
    rm(outfile; force = true)
    return
end

function test_Integer_parsing()
    df = (; year = ["2020", "2021", "2022"], value = [1.0, 2.0, 3.0])
    outfile = joinpath(tempdir(), "gdx_jl_int_test.gdx")
    write_gdx(outfile, "data" => df)
    gdxfile = read_gdx(outfile; parse_integers = true)
    @test eltype(Tables.getcolumn(gdxfile[:data], :dim1)) == Int
    gdxfile = read_gdx(outfile; parse_integers = false)
    @test eltype(Tables.getcolumn(gdxfile[:data], :dim1)) == String
    rm(outfile; force = true)
    return
end

function test_GDXFile_show_and_propertynames()
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
    rm(outfile; force = true)
    return
end

function test_Symbol_listing()
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
    rm(outfile; force = true)
    return
end

function test_GDXFile_full_round_trip_sets_params_variables()
    gdx1 = read_gdx(GAMS_GDX_TEST)
    outfile = joinpath(tempdir(), "gdx_jl_roundtrip.gdx")
    write_gdx(outfile, gdx1)
    gdx2 = read_gdx(outfile)
    @test sort(list_symbols(gdx1)) == sort(list_symbols(gdx2))
    @test collect(Tables.getcolumn(gdx1[:p], :value)) ==
          collect(Tables.getcolumn(gdx2[:p], :value))
    @test collect(Tables.getcolumn(gdx1[:x], :level)) ==
          collect(Tables.getcolumn(gdx2[:x], :level))
    @test collect(Tables.getcolumn(gdx1[:x], :marginal)) ≈
          collect(Tables.getcolumn(gdx2[:x], :marginal))
    @test collect(Tables.getcolumn(gdx1[:y], :level)) ==
          collect(Tables.getcolumn(gdx2[:y], :level))
    @test collect(Tables.getcolumn(gdx1[:y], :upper)) ==
          collect(Tables.getcolumn(gdx2[:y], :upper))
    i1_col =
        collect(Tables.getcolumn(gdx1[:i], first(Tables.columnnames(gdx1[:i]))))
    i2_col =
        collect(Tables.getcolumn(gdx2[:i], first(Tables.columnnames(gdx2[:i]))))
    @test sort(i1_col) == sort(i2_col)
    rm(outfile; force = true)
    return
end

function test_Special_values_round_trip()
    tbl =
        (; i = ["a", "b", "c", "d", "e"], value = [NaN, Inf, -Inf, 42.0, -0.0])
    outfile = joinpath(tempdir(), "gdx_jl_special.gdx")
    write_gdx(outfile, "special" => tbl)
    gdxfile = read_gdx(outfile)
    result = Tables.getcolumn(gdxfile[:special], :value)
    @test isnan(result[1])
    @test result[2] == Inf
    @test result[3] == -Inf
    @test result[4] == 42.0
    @test result[5] === -0.0
    rm(outfile; force = true)
    return
end

function test_Scalar_0_dim_parameters()
    tbl = (; value = [42.0])
    outfile = joinpath(tempdir(), "gdx_jl_scalar.gdx")
    write_gdx(outfile, "scalar_param" => tbl)
    gdxfile = read_gdx(outfile)
    @test :scalar_param in list_parameters(gdxfile)
    @test collect(Tables.getcolumn(gdxfile[:scalar_param], :value)) == [42.0]
    @test length(collect(Tables.columnnames(gdxfile[:scalar_param]))) == 1
    rm(outfile; force = true)
    return
end

function test_Selective_reading_only_keyword()
    gdx_full = read_gdx(GAMS_GDX_TEST)
    gdx_partial = read_gdx(GAMS_GDX_TEST; only = [:p, :x])
    @test length(gdx_partial) == 2
    @test :p in list_parameters(gdx_partial)
    @test :x in list_variables(gdx_partial)
    @test !haskey(gdx_partial, :i)
    @test !haskey(gdx_partial, :y)
    @test collect(Tables.getcolumn(gdx_partial[:p], :value)) ==
          collect(Tables.getcolumn(gdx_full[:p], :value))
    gdx_str = read_gdx(GAMS_GDX_TEST; only = ["i"])
    @test length(gdx_str) == 1
    @test :i in list_sets(gdx_str)
    return
end

function test_Error_handling()
    @test_throws GDXException read_gdx("nonexistent_file_12345.gdx")
    return
end

function test_get_symbol()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    sym_p = get_symbol(gdxfile, :p)
    @test sym_p isa GDXParameter
    @test sym_p.name == "p"
    @test sym_p.records == gdxfile[:p]
    sym_x = get_symbol(gdxfile, :x)
    @test sym_x isa GDXVariable
    sym_i = get_symbol(gdxfile, "i")
    @test sym_i isa GDXSet
    return
end

function test_GDXFile_iteration_and_length()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    @test length(gdxfile) == length(list_symbols(gdxfile))
    count = 0
    for (k, v) in gdxfile
        count += 1
        @test k isa Symbol
        @test v isa GDXSymbol
    end
    @test count == length(gdxfile)
    return
end

function test_Writing_equations()
    eq_tbl = (;
        i = ["a", "b"],
        level = [1.0, 2.0],
        marginal = [0.5, 0.6],
        lower = [-Inf, -Inf],
        upper = [Inf, Inf],
        scale = [1.0, 1.0],
    )
    eq = GDXEquation("myeq", "test equation", ["i"], 0, eq_tbl)
    gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:myeq => eq))
    outfile = joinpath(tempdir(), "gdx_jl_eq_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    @test :myeq in list_equations(gdx2)
    @test collect(Tables.getcolumn(gdx2[:myeq], :level)) == [1.0, 2.0]
    @test collect(Tables.getcolumn(gdx2[:myeq], :marginal)) == [0.5, 0.6]
    rm(outfile; force = true)
    return
end

function test_Writing_sets_standalone()
    set_tbl = (; dim1 = ["x", "y", "z"])
    s = GDXSet("myset", "test set", ["*"], set_tbl)
    gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:myset => s))
    outfile = joinpath(tempdir(), "gdx_jl_set_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    @test :myset in list_sets(gdx2)
    col = collect(
        Tables.getcolumn(gdx2[:myset], first(Tables.columnnames(gdx2[:myset]))),
    )
    @test sort(col) == ["x", "y", "z"]
    rm(outfile; force = true)
    return
end

function test_Variable_Equation_type_enums()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    sym_x = get_symbol(gdxfile, :x)
    @test sym_x.vartype isa VariableType
    @test sym_x.vartype == VarFree
    sym_y = get_symbol(gdxfile, :y)
    @test sym_y.vartype == VarPositive
    v = GDXVariable(
        "test",
        "",
        String[],
        3,
        (;
            level = [0.0],
            marginal = [0.0],
            lower = [0.0],
            upper = [0.0],
            scale = [1.0],
        ),
    )
    @test v.vartype == VarPositive
    e = GDXEquation(
        "test",
        "",
        String[],
        0,
        (;
            level = [0.0],
            marginal = [0.0],
            lower = [0.0],
            upper = [0.0],
            scale = [1.0],
        ),
    )
    @test e.equtype == EqE
    return
end

function test_Case_insensitive_symbol_lookup()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    @test gdxfile[:p] == gdxfile[:P]
    @test gdxfile["p"] == gdxfile["P"]
    @test haskey(gdxfile, :P)
    @test haskey(gdxfile, :p)
    @test get_symbol(gdxfile, :P) === get_symbol(gdxfile, :p)
    @test get_symbol(gdxfile, "P") === get_symbol(gdxfile, "p")
    sym = get_symbol(gdxfile, :p)
    @test sym.name == "p"
    gdx2 = read_gdx(GAMS_GDX_TEST; only = [:P, :X])
    @test length(gdx2) == 2
    @test :p in list_parameters(gdx2)
    @test :x in list_variables(gdx2)
    return
end

function test_Symbol_ordering_is_preserved()
    gdxfile = read_gdx(GAMS_GDX_TEST)
    syms = list_symbols(gdxfile)
    iter_syms = Symbol[k for (k, _) in gdxfile]
    @test iter_syms == syms
    outfile = joinpath(tempdir(), "gdx_jl_order_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    @test list_symbols(gdx2) == syms
    rm(outfile; force = true)
    return
end

function test_Set_element_text_round_trip()
    set_tbl = (;
        dim1 = ["seattle", "san-diego", "topeka"],
        element_text = ["rainy city", "sunny city", ""],
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
    rm(outfile; force = true)
    return
end

function test_Set_without_element_text_has_no_extra_column()
    set_tbl = (; dim1 = ["a", "b", "c"])
    s = GDXSet("simple", "no text", ["*"], set_tbl)
    gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:simple => s))
    outfile = joinpath(tempdir(), "gdx_jl_notext_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    @test !(:element_text in Tables.columnnames(gdx2[:simple]))
    rm(outfile; force = true)
    return
end

function test_Alias_round_trip()
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
    rm(outfile; force = true)
    return
end

function test_GDXAlias_show()
    a = GDXAlias("j", "", "i")
    io = IOBuffer()
    show(io, a)
    @test occursin("j", String(take!(io)))
    return
end

function test_Domain_preservation_on_round_trip_issue_3()
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
    rm(outfile; force = true)
    return
end

function test_Domain_preservation_for_variables_issue_3()
    set_tbl = (; i = ["a", "b", "c"])
    s = GDXSet("i", "index set", ["*"], set_tbl)
    var_tbl = (;
        i = ["a", "b", "c"],
        level = [1.0, 2.0, 3.0],
        marginal = [0.0, 0.0, 0.0],
        lower = [-Inf, -Inf, -Inf],
        upper = [Inf, Inf, Inf],
        scale = [1.0, 1.0, 1.0],
    )
    v = GDXVariable("y", "A variable over i", ["i"], VarFree, var_tbl)
    gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :y => v))
    outfile = joinpath(tempdir(), "gdx_jl_domain_var_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    y2 = get_symbol(gdx2, :y)
    @test y2.domain == ["i"]
    @test first(Tables.columnnames(gdx2[:y])) == :i
    rm(outfile; force = true)
    return
end

function test_Domain_preservation_for_equations_issue_3()
    set_tbl = (; i = ["a", "b"])
    s = GDXSet("i", "index set", ["*"], set_tbl)
    eq_tbl = (;
        i = ["a", "b"],
        level = [1.0, 2.0],
        marginal = [0.5, 0.6],
        lower = [-Inf, -Inf],
        upper = [Inf, Inf],
        scale = [1.0, 1.0],
    )
    eq = GDXEquation("myeq", "test eq", ["i"], EqE, eq_tbl)
    gdxfile = GDXFile("", Dict{Symbol,GDXSymbol}(:i => s, :myeq => eq))
    outfile = joinpath(tempdir(), "gdx_jl_domain_eq_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    eq2 = get_symbol(gdx2, :myeq)
    @test eq2.domain == ["i"]
    @test first(Tables.columnnames(gdx2[:myeq])) == :i
    rm(outfile; force = true)
    return
end

function test_Multi_dimensional_domain_preservation_issue_3()
    si = GDXSet("i", "rows", ["*"], (; i = ["a", "b"]))
    sj = GDXSet("j", "cols", ["*"], (; j = ["x", "y"]))
    par_tbl = (;
        i = ["a", "a", "b", "b"],
        j = ["x", "y", "x", "y"],
        value = [1.0, 2.0, 3.0, 4.0],
    )
    p = GDXParameter("cost", "transport cost", ["i", "j"], par_tbl)
    gdxfile =
        GDXFile("", Dict{Symbol,GDXSymbol}(:i => si, :j => sj, :cost => p))
    outfile = joinpath(tempdir(), "gdx_jl_domain_2d_test.gdx")
    write_gdx(outfile, gdxfile)
    gdx2 = read_gdx(outfile)
    cost2 = get_symbol(gdx2, :cost)
    @test cost2.domain == ["i", "j"]
    cnames = collect(Tables.columnnames(gdx2[:cost]))
    @test cnames[1:2] == [:i, :j]
    rm(outfile; force = true)
    return
end

function test_Domain_preservation_with_GAMS_generated_file_issue_3()
    gdx1 = read_gdx(GAMS_GDX_TEST)
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
    rm(outfile; force = true)
    return
end

function test_Setting_symbols_via_indexing()
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
    return
end

function test_DataFrame_sink()
    gdxfile = read_gdx(GAMS_GDX_TEST, DataFrames.DataFrame)
    p = gdxfile[:p]
    @test p isa DataFrames.DataFrame
    @test "value" in DataFrames.names(p)
    @test p.value == [1.5, 2.5, 3.5]
    x = gdxfile[:x]
    @test x isa DataFrames.DataFrame
    @test x.level == [10.0, 20.0, 30.0]
    return
end

function test_DataFrame_metadata_description()
    df = DataFrames.DataFrame(; i = ["a", "b"], value = [1.0, 2.0])
    DataFrames.metadata!(df, "description", "from metadata"; style = :default)
    outfile = joinpath(tempdir(), "gdx_jl_metadata_desc.gdx")
    write_gdx(outfile, "meta_param" => df)
    gdxfile = read_gdx(outfile)
    @test get_symbol(gdxfile, :meta_param).description == "from metadata"
    rm(outfile; force = true)
    return
end

function test_Tables_jl_interface_on_GDXSymbol()
    gdxfile = read_gdx(GAMS_GDX_TEST)
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
    return
end

end  # module

TestGDXInterface.runtests()
