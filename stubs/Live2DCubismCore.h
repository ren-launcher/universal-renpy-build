/**
 * Stub Live2DCubismCore.h — Minimal type definitions for building Ren'Py
 * without the proprietary Live2D Cubism Native SDK.
 *
 * All Live2D functions are loaded dynamically via SDL_LoadFunction at runtime,
 * so only type/enum definitions are needed at compile time.
 *
 * Compatible with Cubism SDK for Native 4-r.1.
 * When the real SDK is available, live2d.py extracts it and overwrites this stub.
 */

#ifndef LIVE2D_CUBISM_CORE_H
#define LIVE2D_CUBISM_CORE_H

#include <stdint.h>

/* ── Opaque types ───────────────────────────────────────────────────────── */

typedef struct csmMoc csmMoc;
typedef struct csmModel csmModel;

/* ── Scalar types ───────────────────────────────────────────────────────── */

typedef unsigned int csmVersion;
typedef unsigned int csmMocVersion;
typedef unsigned char csmFlags;

/* ── Alignment constants ────────────────────────────────────────────────── */

enum {
    csmAlignofMoc   = 64,
    csmAlignofModel = 16
};

/* ── Drawable constant flags ────────────────────────────────────────────── */

enum {
    csmBlendAdditive       = 1 << 0,
    csmBlendMultiplicative = 1 << 1,
    csmIsDoubleSided       = 1 << 2,
    csmIsInvertedMask      = 1 << 3
};

/* ── Drawable dynamic flags ─────────────────────────────────────────────── */

enum {
    csmIsVisible                  = 1 << 0,
    csmVisibilityDidChange        = 1 << 1,
    csmOpacityDidChange           = 1 << 2,
    csmDrawOrderDidChange         = 1 << 3,
    csmRenderOrderDidChange       = 1 << 4,
    csmVertexPositionsDidChange   = 1 << 5
};

/* ── Moc file format versions ───────────────────────────────────────────── */

enum {
    csmMocVersion_Unknown = 0,
    csmMocVersion_30      = 1,
    csmMocVersion_33      = 2,
    csmMocVersion_40      = 3
};

/* ── csmVector2 ─────────────────────────────────────────────────────────── */

typedef struct csmVector2 {
    float X;
    float Y;
} csmVector2;

/* ── csmVector4 ─────────────────────────────────────────────────────────── */

typedef struct csmVector4 {
    float X;
    float Y;
    float Z;
    float W;
} csmVector4;

/* ── Log callback ───────────────────────────────────────────────────────── */

typedef void (*csmLogFunction)(const char* message);

#endif /* LIVE2D_CUBISM_CORE_H */
