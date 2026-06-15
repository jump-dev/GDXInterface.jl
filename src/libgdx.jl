# Copyright (c) 2026 Martin Kirk Bonde, James Daniel Foster and contributors
# Copyright (c) 2020-2023 GAMS Software GmbH
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# =============================================================================
# Constants
# =============================================================================

const GMS_MAX_INDEX_DIM = 20
const GMS_SSSIZE = 256
const GMS_VAL_MAX = 5

# GAMS value position in GDX data
const GAMS_VALUE_LEVEL = 1
const GAMS_VALUE_MARGINAL = 2
const GAMS_VALUE_LOWER = 3
const GAMS_VALUE_UPPER = 4
const GAMS_VALUE_SCALE = 5

# GAMS data types
const GMS_DT_SET = 0
const GMS_DT_PAR = 1
const GMS_DT_VAR = 2
const GMS_DT_EQU = 3
const GMS_DT_ALIAS = 4
const GMS_DT_MAX = 5

# GAMS special values
const GAMS_SV_UNDEF = 1.0e300       # undefined
const GAMS_SV_NA = 2.0e300       # not available / applicable
const GAMS_SV_PINF = 3.0e300       # plus infinity
const GAMS_SV_MINF = 4.0e300       # minus infinity
const GAMS_SV_EPS = 5.0e300       # epsilon
const GAMS_SV_ACR = 10.0e300      # potential / real acronym
const GAMS_SV_NAINT = 2100000000    # not available / applicable for integers

# =============================================================================
# GDX Handle
# =============================================================================

mutable struct GDXHandle
    cptr::Ptr{Cvoid}

    function GDXHandle()
        cptr = Ref{Ptr{Cvoid}}(C_NULL)
        @ccall libgdx.xcreate(cptr::Ptr{Ptr{Cvoid}})::Cvoid
        if cptr[] == C_NULL
            throw(GDXException("Can't create GAMS GDX object", 0))
        end
        gdx = new(cptr[])
        finalizer(gdx) do gdx_i
            @ccall libgdx.xfree(Ref(gdx_i.cptr)::Ptr{Ptr{Cvoid}})::Cvoid
            return
        end
        return gdx
    end
end

Base.cconvert(::Type{Ptr{Cvoid}}, gdx::GDXHandle) = gdx

Base.unsafe_convert(::Type{Ptr{Cvoid}}, gdx::GDXHandle) = gdx.cptr

struct GDXException <: Exception
    msg::String
    n_err::Int
end

function Base.showerror(io::IO, e::GDXException)
    return print(io, "GDX failed: $(e.msg) ($(e.n_err))")
end

function c__gdxopenread(gdx_ptr, file, n_err)
    return @ccall libgdx.c__gdxopenread(
        gdx_ptr::Ptr{Cvoid},
        file::Cstring,
        n_err::Ptr{Cint},
    )::Cint
end

function c__gdxopenwrite(gdx_ptr, file, producer, n_err)
    return @ccall libgdx.c__gdxopenwrite(
        gdx_ptr::Ptr{Cvoid},
        file::Cstring,
        producer::Cstring,
        n_err::Ptr{Cint},
    )::Cint
end

c__gdxclose(gdx) = @ccall libgdx.c__gdxclose(gdx::Ptr{Cvoid})::Cint

function c__gdxsysteminfo(gdx_ptr, sym_count, uel_count)
    return @ccall libgdx.c__gdxsysteminfo(
        gdx_ptr::Ptr{Cvoid},
        sym_count::Ptr{Cint},
        uel_count::Ptr{Cint},
    )::Cint
end

function c__gdxsymbolinfo(gdx_ptr, sym_id, name, dim, type)
    return @ccall libgdx.c__gdxsymbolinfo(
        gdx_ptr::Ptr{Cvoid},
        sym_id::Cint,
        name::Ptr{UInt8},
        dim::Ptr{Cint},
        type::Ptr{Cint},
    )::Cint
end

function c__gdxsymbolinfox(gdx_ptr, sym_id, count, user_info, text)
    return @ccall libgdx.c__gdxsymbolinfox(
        gdx_ptr::Ptr{Cvoid},
        sym_id::Cint,
        count::Ptr{Cint},
        user_info::Ptr{Cint},
        text::Ptr{UInt8},
    )::Cint
end

function c__gdxfindsymbol(gdx_ptr, name, sym_nr)
    return @ccall libgdx.c__gdxfindsymbol(
        gdx_ptr::Ptr{Cvoid},
        name::Cstring,
        sym_nr::Ptr{Cint},
    )::Cint
end

function c__gdxsymbolgetdomainx(gdx_ptr, sym_nr, domains)
    return @ccall libgdx.c__gdxsymbolgetdomainx(
        gdx_ptr::Ptr{Cvoid},
        sym_nr::Cint,
        domains::Ptr{Ptr{UInt8}},
    )::Cint
end

function c__gdxsymbolsetdomainx(gdx_ptr, sym_nr, domain_ids)
    return @ccall libgdx.c__gdxsymbolsetdomainx(
        gdx_ptr::Ptr{Cvoid},
        sym_nr::Cint,
        domain_ids::Ptr{Cstring},
    )::Cint
end

function c__gdxaddalias(gdx_ptr, id1, id2)
    return @ccall libgdx.c__gdxaddalias(
        gdx_ptr::Ptr{Cvoid},
        id1::Cstring,
        id2::Cstring,
    )::Cint
end

function c__gdxgetelemtext(gdx_ptr, text_nr, text, node)
    return @ccall libgdx.c__gdxgetelemtext(
        gdx_ptr::Ptr{Cvoid},
        text_nr::Cint,
        text::Ptr{UInt8},
        node::Ptr{Cint},
    )::Cint
end

function c__gdxaddsettext(gdx_ptr, text, text_nr)
    return @ccall libgdx.c__gdxaddsettext(
        gdx_ptr::Ptr{Cvoid},
        text::Cstring,
        text_nr::Ptr{Cint},
    )::Cint
end

function c__gdxumuelget(gdx_ptr, uel_nr, uel, uel_map)
    return @ccall libgdx.c__gdxumuelget(
        gdx_ptr::Ptr{Cvoid},
        uel_nr::Cint,
        uel::Ptr{UInt8},
        uel_map::Ptr{Cint},
    )::Cint
end

function c__gdxuelregisterstrstart(gdx_pt)
    return @ccall libgdx.c__gdxuelregisterstrstart(gdx_ptr::Ptr{Cvoid})::Cint
end

function c__gdxuelregisterstr(gdx_ptr, uel, uel_nr)
    return @ccall libgdx.c__gdxuelregisterstr(
        gdx_ptr::Ptr{Cvoid},
        uel::Cstring,
        uel_nr::Ptr{Cint},
    )::Cint
end

function c__gdxuelregisterdone(gdx_ptr)
    return @ccall libgdx.c__gdxuelregisterdone(gdx_ptr::Ptr{Cvoid})::Cint
end

function c__gdxdatareadrawstart(gdx_ptr, start, n_rec)
    return @ccall libgdx.c__gdxdatareadrawstart(
        gdx_ptr::Ptr{Cvoid},
        start::Cint,
        n_rec::Ptr{Cint},
    )::Cint
end

function c__gdxdatareadraw(gdx_ptr, idx, vals, dim)
    return @ccall libgdx.c__gdxdatareadraw(
        gdx_ptr::Ptr{Cvoid},
        idx::Ptr{Cint},
        vals::Ptr{Cdouble},
        dim::Ptr{Cint},
    )::Cint
end

function c__gdxdatareadstrstart(gdx_ptr, start, n_err)
    return @ccall libgdx.c__gdxdatareadstrstart(
        gdx_ptr::Ptr{Cvoid},
        start::Cint,
        n_err::Ptr{Cint},
    )::Cint
end

function c__gdxdatareadstr(gdx_ptr, keystr, vals, dim_first)
    return @ccall libgdx.c__gdxdatareadstr(
        gdx_ptr::Ptr{Cvoid},
        keystr::Ptr{Ptr{UInt8}},
        vals::Ptr{Cdouble},
        dim_first::Ptr{Cint},
    )::Cint
end

function c__gdxdatareaddone(gdx_ptr)
    return @ccall libgdx.c__gdxdatareaddone(gdx_ptr::Ptr{Cvoid})::Cint
end

function c__gdxdatawritestrstart(gdx_ptr, name, text, dim, typ, user_info)
    return @ccall libgdx.c__gdxdatawritestrstart(
        gdx_ptr::Ptr{Cvoid},
        name::Cstring,
        text::Cstring,
        dim::Cint,
        typ::Cint,
        user_info::Cint,
    )::Cint
end

function c__gdxdatawritestr(gdx_ptr, keys, vals)
    return @ccall libgdx.c__gdxdatawritestr(
        gdx_ptr::Ptr{Cvoid},
        keys::Ptr{Cstring},
        vals::Ptr{Cdouble},
    )::Cint
end

function c__gdxdatawritedone(gdx)
    return @ccall libgdx.c__gdxdatawritedone(gdx::Ptr{Cvoid})::Cint
end
