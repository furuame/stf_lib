function(setup_stf_linker set_compiler_options)
  if (STF_LINK_SETUP_DONE AND STF_COMPILER_SETUP_DONE)
    message("-- ${PROJECT_NAME} link-time optimization and compiler flags handled by parent project")
  else()
    set(STF_LINK_FLAGS -Wno-stringop-overflow)
    set(STF_COMPILE_FLAGS )
    if(DEFINED ENV{LD})
      set(LD $ENV{LD})
    else()
      set(LD ld)
    endif()

    # Don't need to change default linker on OS X
    if (NOT APPLE)
      execute_process(COMMAND ${LD} -v
                      OUTPUT_VARIABLE LD_VERSION)
      string(STRIP ${LD_VERSION} LD_VERSION)
      string(REGEX MATCH "[^ \t\r\n]+$" LD_VERSION ${LD_VERSION})
      message("-- ld version is ${LD_VERSION}")

      find_program(GOLD "ld.gold")
      find_program(LLD "ld.lld")

      if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        if(LLD)
          message("-- Using lld to link")
          set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=lld)
        elseif(${LD_VERSION} VERSION_GREATER_EQUAL "2.21")
          message("-- Using ld to link")
        elseif(GOLD)
          message("-- Using gold to link")
          set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=gold)
        else()
          message(FATAL_ERROR "Either ld.lld or ld.gold are required when compiling with clang")
        endif()
      else()
        if(${LD_VERSION} VERSION_GREATER_EQUAL "2.21")
          message("-- Using ld to link")
        elseif(GOLD)
          message("-- Using gold to link")
          set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fuse-ld=gold)
        else()
          message(FATAL_ERROR "ld.gold is required when compiling with gcc")
        endif()
      endif()
    endif()

    if (CMAKE_BUILD_TYPE MATCHES "^[Dd]ebug")
      set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O0 -g -pipe -fno-omit-frame-pointer)
      set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -O0 -g -pipe -fno-omit-frame-pointer)
      set(NO_STF_LTO 1)
    elseif (CMAKE_BUILD_TYPE MATCHES "^[Ff]ast[Dd]ebug")
      set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O3 -g -pipe -fno-omit-frame-pointer)
      set(NO_STF_LTO 1)
    else()
      set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -O3 -pipe)
      set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -O3 -pipe)

      # Enable more aggressive inlining in Clang
      if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -mllvm -inline-threshold=1024)
      endif()

      if (CMAKE_BUILD_TYPE MATCHES "^[Pp]rofile")
        set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -g -fno-omit-frame-pointer)
        set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -g -fno-omit-frame-pointer)
        if(STF_ENABLE_GPROF)
          set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -pg)
          set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -pg)
        endif()
      else()
        set(STF_LINK_FLAGS ${STF_LINK_FLAGS} -fomit-frame-pointer)
        set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} -fomit-frame-pointer)
      endif()
    endif()

    if(STF_LINK_SETUP_DONE)
      message("-- ${PROJECT_NAME} link-time optimization handled by parent project")
    elseif(NOT NO_STF_LTO)
      message("-- Enabling link-time optimization in ${PROJECT_NAME}")

      if(FULL_LTO)
        message("--  Full LTO: enabled")
        set(LTO_FLAGS -flto)
      else()
        if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
          message("--  Full LTO: disabled")
          set(LTO_FLAGS -flto=thin)
        else()
          message("--  Full LTO: enabled")
          set(LTO_FLAGS -flto)
        endif()
      endif()

      set(STF_COMPILE_FLAGS ${STF_COMPILE_FLAGS} ${LTO_FLAGS})
      set(STF_LINK_FLAGS ${STF_LINK_FLAGS} ${LTO_FLAGS})

    else()
      message("-- Disabling link-time optimization in ${PROJECT_NAME}")
    endif()

    if(set_compiler_options)
      if(STF_COMPILER_SETUP_DONE)
        message("--  ${PROJECT_NAME} compiler options handled by parent project")
      else()
        message("--  Set optimized STF compiler options: enabled")
        add_compile_options(${STF_COMPILE_FLAGS})
        set(STF_COMPILER_SETUP_DONE true PARENT_SCOPE)
      endif()
    else()
      message("--  Set optimized STF compiler options: disabled")
    endif()

    if(NOT STF_LINK_SETUP_DONE)
      add_link_options(${STF_LINK_FLAGS})
      set(STF_LINK_SETUP_DONE true PARENT_SCOPE)
    endif()
  endif()

  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if (CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
      set(CMAKE_AR "ar" PARENT_SCOPE)
    else()
      unset(LLVM_AR)
      unset(LLVM_AR CACHE)
      # using regular Clang or AppleClang
      find_program(LLVM_AR "llvm-ar")
      if (NOT LLVM_AR)
        unset(LLVM_AR)
        unset(LLVM_AR CACHE)
        find_program(LLVM_AR "llvm-ar-9")
        if (NOT LLVM_AR)
          message(FATAL_ERROR "llvm-ar is needed to link trace_tools on this system")
        else()
          set(CMAKE_AR "llvm-ar-9" PARENT_SCOPE)
        endif()
      else()
        set(CMAKE_AR "llvm-ar" PARENT_SCOPE)
      endif()
    endif()
  else ()
    set(CMAKE_AR  "gcc-ar" PARENT_SCOPE)
  endif()

  set(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> qcs <TARGET> <LINK_FLAGS> <OBJECTS>" PARENT_SCOPE)
  set(CMAKE_CXX_ARCHIVE_FINISH   true PARENT_SCOPE)
endfunction()
