# Closed (WIP)

A build system for D projects, inspired by the OpenD build system.
It's designed specifically for building D files.
For projects that require building more than just D files, Closed can be used as part of a larger build process.

## Building

Go inside the root folder and run:

```cmd
dmd source/app.d -of=closed
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
 -b=<TEST|DEBUG|DLL|LIB|OBJ|RELEASE|DLLR|LIBR|OBJR>
 -i=<TRUE|FALSE> (include d files)
 -v=<TRUE|FALSE> (verbose messages)
 -t=<TRUE|FALSE> (temporary output)
 -f=<TRUE|FALSE> (fallback config)
```

## Additional Information

* Closed supports single-file libraries and executables.
* A `.closed` file beside or inside the source folder can contain arguments for Closed, one per line.
* Paths support both forward slashes and backslashes.
* When `-I=<path>` is passed, `-J=<path>` is automatically added by default.
* On POS*X-like systems, rpath is added and set to origin by default.
* Use `-v=<TRUE|FALSE>` to print the commands being run by Closed.

## Why

Why not? It's fun.
