# Closed

A build system for D projects, inspired by the OpenD build system.

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

* When `-I=<path>` is passed, `-J=<path>` is automatically added by default.
* On POS*X-like systems, rpath is set to origin by default.
* `-L=-L.` is automatically added by default.

## Why

Why not? It's fun.
