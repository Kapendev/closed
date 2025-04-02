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

## Additional Information

* A `.closed` file beside the source folder can contain arguments for Closed, one per line.
* Paths support both forward slashes and backslashes.
* When `-I=<path>` is passed, `-J=<path>` is automatically added by default.
* On POS*X-like systems, rpath is added and set to origin by default.
* Use `-v=<TRUE|FALSE>` to print the commands being run by Closed.

## Examples

* Building a Program With the LDC Compiler

    ```cmd
    closed build . -c=ldc2
    ```

* Running a [Parin](https://github.com/Kapendev/parin) Script

    ```cmd
    closed run ../parin/packages/setup
    ```

## Why

Why not? It's fun.
