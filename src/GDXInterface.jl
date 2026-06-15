# Copyright (c) 2026 Martin Kirk Bonde, James Daniel Foster and contributors
# Copyright (c) 2020-2023 GAMS Software GmbH
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module GDXInterface

import DataAPI
import Tables

using gdx_jll: libgdx

include("gdx_c_api.jl")
include("GDXFile.jl")

# GDXInterface exports all symbols not starting with `_`. If you don't want all
# of these symbols in your environment, then use `import GDXInterface` instead
# of `using GDXInterface`.

const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]
_is_sym(sym) = !startswith("$sym", "_") && Base.isidentifier(sym)
for sym in filter(_is_sym, names(@__MODULE__; all = true))
    if !(sym in _EXCLUDE_SYMBOLS)
        @eval export $sym
    end
end

end # module GDXInterface
