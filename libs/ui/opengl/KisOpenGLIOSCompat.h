/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#ifdef Q_OS_IOS
// Desktop OpenGL extensions and OpenGL ES use different names for the same
// sized texture formats. Keep the existing renderer code readable while the
// iOS path is validated against the device's advertised extensions.
#ifndef GL_RGBA16
#define GL_RGBA16 0x805B
#endif
#ifndef GL_RGBA16F_ARB
#define GL_RGBA16F_ARB 0x881A
#endif
#ifndef GL_HALF_FLOAT_ARB
#define GL_HALF_FLOAT_ARB 0x140B
#endif
#ifndef GL_RGBA_FLOAT16_ATI
#define GL_RGBA_FLOAT16_ATI 0x881A
#endif
#ifndef GL_RGBA32F_ARB
#define GL_RGBA32F_ARB 0x8814
#endif
#ifndef GL_RGBA_FLOAT32_ATI
#define GL_RGBA_FLOAT32_ATI 0x8814
#endif
#ifndef GL_MULTISAMPLE_EXT
#define GL_MULTISAMPLE_EXT 0x809D
#endif
#endif
