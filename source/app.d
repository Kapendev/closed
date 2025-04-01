#!/bin/env -S dmd -run

// [Noby Script]

// It's another build system thing :)
// Made for fun.

// TODO: Make rpath work on OSX.
// TODO: Add -q=<TRUE|FALSE> to hide cmd lines.
// TODO: Add -r=<argument> to add run args when running.
// TODO: Add -v=<version name>.
// TODO: Add -s=<section name>. The config can work like an INI file where you can pick a section of arguments.
// TODO: Add more build types. Ideas: lib, dll, o, ...
// TODO: Add test mode.

enum usageInfo = `
Usage:
 closed <mode> <source> [arguments...]
`[1 .. $ - 1];

enum modeInfo = `
Modes:
 b, build
 r, run
`[1 .. $ - 1];

enum argumentsInfo = `
Arguments:
 -I=<source folder>
 -J=<assets folder>
 -L=<linker flags>
 -a=<arguments file>
 -o=<output file>
 -c=<dmd|ldc2|gdc>
 -b=<DEBUG|RELEASE>
`[1 .. $ - 1];

enum Argument : ubyte {
    none,
    I,
    J,
    L,
    a,
    o,
    c,
    b,
}

enum Build : ubyte {
    none,
    DEBUG,
    RELEASE,
}

enum Compiler : ubyte {
    none,
    dmd,
    ldc2,
    gdc,
}

struct CompilerOptions {
    IStr[] dFiles;
    IStr[] iDirs;
    IStr[] jDirs;
    IStr[] lFlags;
    IStr argumentsPath;
    IStr outputPath;
    Compiler compiler;
    Build build;
}

Argument strToArgument(IStr value) {
    // "You can do that with metaprogramming!"
    // No. Go away.
    with (Argument) switch (value) {
        case "I": return I;
        case "J": return J;
        case "L": return L;
        case "a": return a;
        case "o": return o;
        case "c": return c;
        case "b": return b;
        default: return none;
    }
}

Build strToBuild(IStr value) {
    with (Build) switch (value) {
        case "DEBUG": return DEBUG;
        case "RELEASE": return RELEASE;
        default: return none;
    }
}

Compiler strToCompiler(IStr value) {
    with (Compiler) switch (value) {
        case "dmd": return dmd;
        case "ldc2": return ldc2;
        case "gdc": return gdc;
        default: return none;
    }
}

IStr compilerToStr(Compiler value) {
    with (Compiler) switch (value) {
        case dmd: return "dmd";
        case ldc2: return "ldc2";
        case gdc: return "gdc";
        default: return "none";
    }
}

int applyArgumentsToOptions(ref CompilerOptions options, ref IStr[] arguments) {
    foreach (arg; arguments) {
        if (arg.length <= 2 || arg.findStart("=") == -1) {
            echof("Argument `%s` is not valid.", arg);
            return 1;
        }
        auto left = arg[0 .. 2];
        auto right = arg[3 .. $];
        auto kind = strToArgument(left[1 .. $]);
        with (Argument) final switch (kind) {
            case none:
                echof("Argument `%s` is not valid.", arg);
                return 1;
            case I:
                auto iDir = right.pathFmt();
                if (!iDir.isD) {
                    echof("Value `%s` is not a folder.", right);
                    return 1;
                }
                options.iDirs ~= iDir;
                options.jDirs ~= iDir;
                options.dFiles ~= find(iDir, ".d", true);
                break;
            case J:
                auto jDir = right.pathFmt();
                if (!jDir.isD) {
                    echof("Value `%s` is not a folder.", right);
                    return 1;
                }
                options.jDirs ~= jDir;
                break;
            case L:
                options.lFlags ~= right;
                break;
            case a:
                if (options.argumentsPath.length) {
                    echo("An arguments path already exists.");
                    return 1;
                }
                options.argumentsPath = right.pathFmt();
                break;
            case o:
                if (options.outputPath.length) {
                    echo("An output path already exists.");
                    return 1;
                }
                options.outputPath = right.pathFmt();
                break;
            case c:
                if (options.compiler) {
                    echo("A compiler already exists.");
                    return 1;
                }
                options.compiler = strToCompiler(right);
                if (options.compiler == Compiler.none) {
                    echof("Compiler `%s` is not valid.", right);
                    return 1;
                }
                break;
            case b:
                if (options.build) {
                    echo("A build type already exists.");
                    return 1;
                }
                options.build = strToBuild(right);
                if (options.build == Build.none) {
                    echof("Build type `%s` is not valid.", right);
                    return 1;
                }
        }
    }
    arguments.length = 0;
    return 0;
}

int main(string[] args) {
    if (args.length <= 2) {
        echo(usageInfo);
        echo(modeInfo);
        echo(argumentsInfo);
        return 1;
    }
    if (!args[2].isD) {
        echof("Source `%s` is not a folder.", args[2]);
        return 1;
    }

    IStr mode = args[1];
    IStr source = args[2];
    IStr[] arguments = cast(IStr[]) args[3 .. $]; // No one cares.
    auto options = CompilerOptions();

    // Build the compiler options.
    options.dFiles ~= find(source, ".d", true);
    options.jDirs ~= source;
    if (applyArgumentsToOptions(options, arguments)) return 1;
    if (options.argumentsPath.length == 0) {
        options.argumentsPath = ".closed";
    }
    if (options.argumentsPath.isF) {
        auto content = cat(options.argumentsPath);
        auto lineStart = 0;
        foreach (i, c; content) {
            if (c != '\n') continue;
            auto line = content[lineStart .. i].trim();
            if (line.length) arguments ~= line;
            lineStart = cast(int) (i + 1);
        }
    }
    if (applyArgumentsToOptions(options, arguments)) return 1;
    // Add default compiler options if needed.
    if (options.outputPath.length == 0) {
        options.outputPath = join(".", pwd.basename);
    }
    if (options.compiler == Compiler.none) {
        version (OSX) options.compiler = Compiler.ldc2;
        else options.compiler = Compiler.dmd;
    }
    if (options.build == Build.none) {
        options.build = Build.DEBUG;
    }
    options.lFlags ~= "-L.";

    // Build the cmd.
    if (options.dFiles.length == 0) {
        echo("No D source files given.");
        return 1;
    }
    IStr[] dc = [options.compiler.compilerToStr()];
    dc ~= options.dFiles;
    foreach (dir; options.iDirs) {
        dc ~= "-I" ~ dir;
    }
    foreach (dir; options.jDirs) {
        dc ~= "-J" ~ dir;
    }
    foreach (flag; options.lFlags) {
        if (options.compiler == Compiler.gdc) {
            dc ~= "-Xlinker";
            dc ~= flag;
        } else {
            dc ~= "-L" ~ flag;
        }
    }
    if (options.compiler == Compiler.gdc) {
        dc ~= "-o" ~ options.outputPath;
    } else {
        dc ~= "-of" ~ options.outputPath;
    }
    if (options.build == Build.RELEASE) {
        if (0) {
        } else if (options.compiler == Compiler.ldc2) {
            dc ~= "--release";
        } else if (options.compiler == Compiler.dmd) {
            dc ~= "-release";
        } else if (options.compiler == Compiler.gdc) {
            dc ~= "-O2";
        }
    }
    version (linux) {
        if (options.compiler == Compiler.gdc) {
            dc ~= "-Xlinker";
            dc ~= "-rpath=$ORIGIN";
        } else {
            dc ~= "-L-rpath=$ORIGIN";
        }
    }

    // Run the cmd.
    if (cmd(dc)) {
        echo("Something failed.");
        return 1;
    }
    foreach (file; find(".", ".o")) rm(file);
    switch (mode) {
        case "build", "b":
            return 0;
        case "run", "r":
            if (options.outputPath[0] == '.' || options.outputPath[0] == pathSep) {
                return cmd(options.outputPath);
            }
            return cmd(join(".", options.outputPath));
        default:
            echof("Mode `%s` doesn't exist.", mode);
            return 1;
    }
}

// [Noby Library]

Level minLogLevel    = Level.info;
bool isCmdLineHidden = false;

enum cloneExt = "._clone";

alias Sz   = size_t;        /// The result of sizeof, ...
alias Str  = char[];        /// A string slice of chars.
alias IStr = const(char)[]; /// A string slice of constant chars.

enum Level : ubyte {
    none,
    info,
    warning,
    error,
}

version (Windows) {
    enum pathSep = '\\';
    enum pathSepStr = "\\";
    enum pathSepOther = '/';
    enum pathSepOtherStr = "/";
} else {
    enum pathSep = '/';
    enum pathSepStr = "/";
    enum pathSepOther = '\\';
    enum pathSepOtherStr = "\\";
}

bool isX(IStr path) {
    import std.file;
    return path.exists;
}

bool isF(IStr path) {
    import std.file;
    return path.isX && path.isFile;
}

bool isD(IStr path) {
    import std.file;
    return path.isX && path.isDir;
}

void echo(A...)(A args) {
    import std.stdio;
    writeln(args);
}

void echon(A...)(A args) {
    import std.stdio;
    write(args);
}

void echof(A...)(IStr text, A args) {
    import std.stdio;
    writefln(text, args);
}

void echofn(A...)(IStr text, A args) {
    import std.stdio;
    writef(text, args);
}

void cp(IStr source, IStr target) {
    import std.file;
    copy(source, target);
}

void rm(IStr path) {
    import std.file;
    if (path.isX) remove(path);
}

void mv(IStr source, IStr target) {
    cp(source, target);
    rm(source);
}

void mkdir(IStr path, bool isRecursive = false) {
    import std.file;
    if (!path.isX) {
        if (isRecursive) mkdirRecurse(path);
        else std.file.mkdir(path);
    }
}

void rmdir(IStr path, bool isRecursive = false) {
    import std.file;
    if (path.isX) {
        if (isRecursive) rmdirRecurse(path);
        else std.file.rmdir(path);
    }
}

IStr pwd() {
    import std.file;
    return getcwd();
}

IStr cat(IStr path) {
    import std.file;
    return path.isX ? readText(path) : "";
}

IStr[] ls(IStr path = ".", bool isRecursive = false) {
    import std.file;
    IStr[] result = [];
    foreach (file; dirEntries(cast(string) path, isRecursive ? SpanMode.breadth : SpanMode.shallow)) {
        result ~= file.name;
    }
    return result;
}

IStr[] find(IStr path, IStr ext, bool isRecursive = false) {
    import std.file;
    IStr[] result = [];
    foreach (file; dirEntries(cast(string) path, isRecursive ? SpanMode.breadth : SpanMode.shallow)) {
        if (file.endsWith(ext)) result ~= file.name;
    }
    return result;
}

IStr basename(IStr path) {
    auto end = findEnd(path, pathSepStr);
    if (end == -1) return ".";
    else return path[end + 1 .. $];
}

IStr join(IStr[] args...) {
    if (args.length == 0) return ".";
    Str result = [];
    auto length = 0;
    foreach (i, arg; args) {
        result ~= arg;
        if (i != args.length - 1) {
            result ~= pathSep;
        }
    }
    return result;
}

IStr pathFmt(IStr path) {
    if (path.length == 0) return ".";
    Str result = [];
    foreach (i, c; path) {
        if (c == pathSepOther) {
            result ~= pathSep;
        } else {
            result ~= c;
        }
    }
    return result;
}

IStr read() {
    import std.stdio;
    return readln().trim();
}

IStr readYesNo(IStr text, IStr firstValue = "?") {
    auto result = firstValue;
    while (true) {
        if (result.length == 0) result = "Y";
        if (result.isYesOrNo) break;
        echon(text, " [Y/n] ");
        result = read();
    }
    return result;
}

IStr fmt(A...)(IStr text, A args...) {
    import std.format;
    return format(text, args);
}

bool isYes(IStr arg) {
    return (arg.length == 1 && (arg[0] == 'Y' || arg[0] == 'y'));
}

bool isNo(IStr arg) {
    return (arg.length == 1 && (arg[0] == 'N' || arg[0] == 'n'));
}

bool isYesOrNo(IStr arg) {
    return arg.isYes || arg.isNo;
}

void clear(IStr path = ".", IStr ext = "") {
    foreach (file; ls(path)) {
        if (file.endsWith(ext)) rm(file);
    }
}

void paste(IStr path, IStr content, bool isOnlyMaking = false) {
    import std.file;
    if (isOnlyMaking) {
        if (!path.isX) write(path, content);
    } else {
        write(path, content);
    }
}

void clone(IStr path) {
    if (path.isX) cp(path, path ~ cloneExt);
}

void restore(IStr path, bool isOnlyRemoving = false) {
    auto clonePath = path ~ cloneExt;
    if (clonePath.isX) {
        if (!isOnlyRemoving) paste(path, cat(clonePath));
        rm(clonePath);
    }
}

void log(Level level, IStr text) {
    if (minLogLevel == 0 || minLogLevel > level) return;
    with (Level) final switch (level) {
        case info:    echo("[INFO] ", text); break;
        case warning: echo("[WARNING] ", text); break;
        case error:   echo("[ERROR] ", text); break;
        case none:    break;
    }
}

void logi(IStr text) {
    log(Level.info, text);
}

void logw(IStr text) {
    log(Level.warning, text);
}

void loge(IStr text) {
    log(Level.error, text);
}

void logf(A...)(Level level, IStr text, A args) {
    log(level, text.fmt(args));
}

int cmd(IStr[] args...) {
    import std.process;
    if (!isCmdLineHidden) echo("[CMD] ", args);
    try {
        return spawnProcess(args).wait();
    } catch (Exception e) {
        return 1;
    }
}

/// Returns true if the character is a symbol (!, ", ...).
pragma(inline, true);
bool isSymbol(char c) {
    return (c >= '!' && c <= '/') || (c >= ':' && c <= '@') || (c >= '[' && c <= '`') || (c >= '{' && c <= '~');
}

/// Returns true if the character is a digit (0-9).
pragma(inline, true);
bool isDigit(char c) {
    return c >= '0' && c <= '9';
}

/// Returns true if the character is an uppercase letter (A-Z).
pragma(inline, true);
bool isUpper(char c) {
    return c >= 'A' && c <= 'Z';
}

/// Returns true the character is a lowercase letter (a-z).
pragma(inline, true);
bool isLower(char c) {
    return c >= 'a' && c <= 'z';
}

/// Returns true if the character is an alphabetic letter (A-Z or a-z).
pragma(inline, true);
bool isAlpha(char c) {
    return isLower(c) || isUpper(c);
}

/// Returns true if the character is a whitespace character (space, tab, ...).
pragma(inline, true);
bool isSpace(char c) {
    return (c >= '\t' && c <= '\r') || (c == ' ');
}

/// Returns true if the string represents a C string.
pragma(inline, true);
bool isCStr(IStr str) {
    return str.length != 0 && str[$ - 1] == '\0';
}

/// Converts the character to uppercase if it is a lowercase letter.
char toUpper(char c) {
    return isLower(c) ? cast(char) (c - 32) : c;
}

/// Converts all lowercase letters in the string to uppercase.
void toUpper(Str str) {
    foreach (ref c; str) c = toUpper(c);
}

/// Converts the character to lowercase if it is an uppercase letter.
char toLower(char c) {
    return isUpper(c) ? cast(char) (c + 32) : c;
}

/// Converts all uppercase letters in the string to lowercase.
void toLower(Str str) {
    foreach (ref c; str) c = toLower(c);
}

/// Returns true if the string starts with the specified substring.
bool startsWith(IStr str, IStr start) {
    if (str.length < start.length) return false;
    return str[0 .. start.length] == start;
}

/// Returns true if the string ends with the specified substring.
bool endsWith(IStr str, IStr end) {
    if (str.length < end.length) return false;
    return str[$ - end.length .. $] == end;
}

/// Counts the number of occurrences of the specified substring in the string.
int countItem(IStr str, IStr item) {
    int result = 0;
    if (str.length < item.length || item.length == 0) return result;
    foreach (i; 0 .. str.length - item.length) {
        if (str[i .. i + item.length] == item) {
            result += 1;
            i += item.length - 1;
        }
    }
    return result;
}

/// Finds the starting index of the first occurrence of the specified substring in the string, or returns -1 if not found.
int findStart(IStr str, IStr item) {
    if (str.length < item.length || item.length == 0) return -1;
    foreach (i; 0 .. str.length - item.length + 1) {
        if (str[i .. i + item.length] == item) return cast(int) i;
    }
    return -1;
}

/// Finds the ending index of the first occurrence of the specified substring in the string, or returns -1 if not found.
int findEnd(IStr str, IStr item) {
    if (str.length < item.length || item.length == 0) return -1;
    foreach_reverse (i; 0 .. str.length - item.length + 1) {
        if (str[i .. i + item.length] == item) return cast(int) i;
    }
    return -1;
}

/// Finds the first occurrence of the specified item in the slice, or returns -1 if not found.
int findItem(IStr[] items, IStr item) {
    foreach (i, it; items) if (it == item) return cast(int) i;
    return -1;
}

/// Finds the first occurrence of the specified start in the slice, or returns -1 if not found.
int findItemThatStartsWith(IStr[] items, IStr start) {
    foreach (i, it; items) if (it.startsWith(start)) return cast(int) i;
    return -1;
}

/// Finds the first occurrence of the specified end in the slice, or returns -1 if not found.
int findItemThatEndsWith(IStr[] items, IStr end) {
    foreach (i, it; items) if (it.endsWith(end)) return cast(int) i;
    return -1;
}

/// Removes whitespace characters from the beginning of the string.
IStr trimStart(IStr str) {
    IStr result = str;
    while (result.length > 0) {
        if (isSpace(result[0])) result = result[1 .. $];
        else break;
    }
    return result;
}

/// Removes whitespace characters from the end of the string.
IStr trimEnd(IStr str) {
    IStr result = str;
    while (result.length > 0) {
        if (isSpace(result[$ - 1])) result = result[0 .. $ - 1];
        else break;
    }
    return result;
}

/// Removes whitespace characters from both the beginning and end of the string.
IStr trim(IStr str) {
    return str.trimStart().trimEnd();
}

/// Removes the specified prefix from the beginning of the string if it exists.
IStr removePrefix(IStr str, IStr prefix) {
    if (str.startsWith(prefix)) return str[prefix.length .. $];
    else return str;
}

/// Removes the specified suffix from the end of the string if it exists.
IStr removeSuffix(IStr str, IStr suffix) {
    if (str.endsWith(suffix)) return str[0 .. $ - suffix.length];
    else return str;
}
