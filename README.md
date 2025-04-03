# Closed (WIP)

A build system for D projects, inspired by the OpenD build system.
It's designed specifically for building D files.
For projects that require building more than just D files, Closed can be used as part of a larger build process.

## Building

Go inside the root folder and run:

```cmd
dmd source/closed.d
```

Alternatively, you can use Closed with:

```cmd
closed build .
```

## Examples

* Building a Program With the LDC Compiler

    ```cmd
    closed build . -c=ldc2
    ```

* Running a [Parin](https://github.com/Kapendev/parin) Script

    ```cmd
    closed run ../parin/packages/setup
    ```

## Help Message

```
Usage:
 closed <mode> <source> [arguments...]
Modes:
 build
 run
 test
Arguments:
 -I=<source folder>
 -J=<assets folder>
 -L=<linker flag>
 -D=<d flag>
 -V=<version name>
 -R=<run argument>
 -a=<arguments file>
 -s=<section name>
 -o=<output file>
 -c=<dmd|ldc2|gdc>
 -b=<DEBUG|DLL|LIB|OBJ|RELEASE|DLLR|LIBR|OBJR>
 -i=<TRUE|FALSE> (include d files)
 -v=<TRUE|FALSE> (verbose messages)
 -f=<TRUE|FALSE> (fallback config)
```

## Additional Information

* Supports single-file libraries and executables.
* Can function as a library with the version identifier `ClosedLibrary`.
* A `.closed` file in or beside the source folder can contain arguments, one per line.
* Paths in a `.closed` file are relative to the source folder.
* Supports both forward slashes and backslashes in paths.
* Passing `-I=<path>` automatically adds `-J=<path>` by default.
* On POS*X-like systems, rpath is added and set to origin by default.
* Use `-v=<TRUE|FALSE>` to print the commands being run.

## Why

Why not? It's fun.
