module GDXInterface

import DataFrames
import gdx_jll
const LIBGDX = gdx_jll.libgdx

include("gdx_c_api.jl")
include("GDXFile.jl")

# GDX file access exports
export GDXFile,
    GDXSymbol, GDXSet, GDXParameter, GDXVariable, GDXEquation, GDXAlias
export GDXException
export VariableType,
    VarUnknown,
    VarBinary,
    VarInteger,
    VarPositive,
    VarNegative,
    VarFree,
    VarSOS1,
    VarSOS2,
    VarSemiCont,
    VarSemiInt
export EquationType, EqE, EqG, EqL, EqN, EqX, EqC, EqB
export read_gdx, write_gdx
export list_sets,
    list_aliases, list_parameters, list_variables, list_equations, list_symbols
export get_symbol

end # module GDXInterface
