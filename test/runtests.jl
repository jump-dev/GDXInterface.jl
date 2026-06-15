# Copyright (c) 2026 Martin Kirk Bonde, James Daniel Foster and contributors
# Copyright (c) 2020-2023 GAMS Software GmbH
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import Test: @testset, @test, @test_throws
import Tables
import DataFrames: DataFrame, names, metadata!
using GDXInterface

const TEST_DATA_DIR = joinpath(@__DIR__, "test_data")
ispath(TEST_DATA_DIR)

println("\n" * "-"^30 * "\nGDXFile Tests\n" * "-"^30)
include("test_gdxfile.jl")
