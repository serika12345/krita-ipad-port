/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#ifdef Q_OS_IOS
// Krita's shared GLES renderer keeps its GLES 2 fallbacks compiled alongside
// the GLES 3 path. Apple's controlled GLES 3 headers omit these GLES 2
// extension tokens even though the fallback code is selected only after a
// runtime version/extension check.
#ifndef GL_HALF_FLOAT_OES
#define GL_HALF_FLOAT_OES 0x8D61
#endif
#ifndef GL_RGBA32F_EXT
#define GL_RGBA32F_EXT 0x8814
#endif

// GL_EXT_multisample_compatibility uses the desktop token, which is absent
// from Apple's GLES headers even though QOpenGLContext can advertise the
// extension at runtime.
#ifndef GL_MULTISAMPLE_EXT
#define GL_MULTISAMPLE_EXT 0x809D
#endif
#endif
