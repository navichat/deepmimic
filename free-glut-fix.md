# FreeGLUT Build Fix for OpenGL Linking Errors

## Problem

When building FreeGLUT as part of the DeepMimic setup, the build failed with many errors like:

```
undefined reference to `glDisable'
undefined reference to `glXGetProcAddressARB'
undefined reference to `glReadBuffer'
... (and many more OpenGL/GLX/GLU symbols)
```

This is due to the linker not being explicitly told to link against the OpenGL, GLU, and related libraries on some Linux systems, even if the development packages are installed.

## Solution

We modified the FreeGLUT CMake configuration to **explicitly add the required OpenGL libraries** to the linker command for UNIX builds.

### What was changed

In `libs/freeglut-3.0.0/CMakeLists.txt`, inside the main UNIX (non-Windows) build block, we added:

```cmake
    # Explicitly add OpenGL and GLU libraries for UNIX
    LIST(APPEND LIBS GL GLU GLX OpenGL)
```

This ensures that the linker command includes `-lGL -lGLU -lGLX -lOpenGL` when building FreeGLUT and its demos, resolving the undefined reference errors.

### Where to apply

Look for this section in `CMakeLists.txt` (around the main `ELSE()` for UNIX):

```cmake
ELSE()
    # on UNIX we need to make sure:
    # ...
    IF(FREEGLUT_GLES)
        SET(LIBNAME freeglut-gles)
    ELSE()
        IF(FREEGLUT_REPLACE_GLUT)
            SET(LIBNAME glut)
        ELSE()
            SET(LIBNAME freeglut)
        ENDIF()
    ENDIF()

    # Explicitly add OpenGL and GLU libraries for UNIX
    LIST(APPEND LIBS GL GLU GLX OpenGL)

    IF(FREEGLUT_BUILD_SHARED_LIBS)
        ...
```

### Why this works

This change guarantees that the linker is given all the necessary OpenGL-related libraries, regardless of how CMake's `FIND_PACKAGE(OpenGL)` or other detection logic behaves on a given Linux distribution.

## How to re-apply this fix

1. Open `libs/freeglut-3.0.0/CMakeLists.txt` in your project.
2. Find the main UNIX build block (search for `# on UNIX we need to make sure:`).
3. Add the following line after the `SET(LIBNAME ...)` logic:
   ```cmake
   LIST(APPEND LIBS GL GLU GLX OpenGL)
   ```
4. Save the file and re-run the build (e.g., `cmake . && make`).

## Notes
- This fix is only needed for UNIX/Linux systems. Windows builds use different logic.
- If you update or replace the FreeGLUT source, you may need to re-apply this change.
- If you encounter similar linker errors in the future, double-check that these libraries are being linked. 