//
//  Defines.swift
//  Satin
//
//  Created by Reza Ali on 7/23/19.
//  Copyright © 2019 Reza Ali. All rights reserved.
//

import simd

public let maxBuffersInFlight: Int = 3

public let worldForwardDirection = simd_make_float3(0, 0, 1)
public let worldUpDirection = simd_make_float3(0, 1, 0)
public let worldRightDirection = simd_make_float3(1, 0, 0)

//enum STNVertexIndex {
//    STNVertexIndexVertices: Int = 0,
//    STNVertexIndexVertexUniforms = 1,
//    STNVertexIndexShadowUniforms = 2,
//    STNVertexIndexCustomUniforms0 = 3,
//    STNVertexIndexCustomUniforms1 = 4,
//    STNVertexIndexCustomUniforms2 = 5,
//    STNVertexIndexCustomUniforms3 = 6
//}