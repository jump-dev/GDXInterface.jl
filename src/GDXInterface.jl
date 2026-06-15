# Copyright (c) 2026 Martin Kirk Bonde, James Daniel Foster and contributors
# Copyright (c) 2020-2023 GAMS Software GmbH
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module GDXInterface

import DataAPI
import Tables
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
