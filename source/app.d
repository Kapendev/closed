#!/bin/env -S dmd -run

// [Noby Script]

// I will ignore stuff that I don't use for now.
// It's FOSS, fix it yourself or something.

// TODO: Check GDC lib output one day.
// TODO: Check GDC betterC output one day.
// TODO: Make rpath work on OSX one day.
// TODO: Turn OS stuff into a variable maybe.

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
 -L=<linker flag>
 -D=<d flag>
 -V=<version name>
 -R=<run argument>
 -a=<arguments file>
 -s=<section name>
 -o=<output file>
 -c=<dmd|ldc2|gdc>
 -b=<TEST|DEBUG|DLL|LIB|OBJ|RELEASE|DLLR|LIBR|OBJR>
 -i=<TRUE|FALSE>
 -q=<TRUE|FALSE>
`[1 .. $ - 1];

enum Argument : ubyte {
    none,
    I,
    J,
    L,
    D,
    V,
    R,
    a,
    s,
    o,
    c,
    b,
    i,
    q,
}

enum Boolean : ubyte {
    none,
    TRUE,
    FALSE,
}

enum Build : ubyte {
    none,
    TEST,
    DEBUG,
    DLL,
    LIB,
    OBJ,
    RELEASE,
    DLLR,
    LIBR,
    OBJR,
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
    IStr[] dFlags;
    IStr[] rArguments;
    IStr[] versionNames;
    IStr argumentsFile;
    IStr sectionName;
    IStr outputPath;
    Compiler compiler;
    Build build;
    Boolean quiet;
    Boolean include;
}

IStr enumToStr(T)(T value) {
    switch (value) {
        static foreach (m; __traits(allMembers, T)) {
            mixin("case T.", m, ": return m;");
        }
        default: assert(0, "WTF!");
    }
}

T toEnum(T)(IStr str) {
    switch (str) {
        static foreach (m; __traits(allMembers, T)) {
            mixin("case m: return T.", m, ";");
        }
        default: return T.init;
    }
}

int applyArgumentsToOptions(ref CompilerOptions options, ref IStr[] arguments) {
    foreach (arg; arguments) {
        if (arg.length <= 2 || arg.findStart("=") == -1) {
            echof("Argument `%s` is invalid.", arg);
            return 1;
        }
        auto left = arg[0 .. 2];
        auto right = arg[3 .. $].trim().pathFmt();
        auto kind = toEnum!Argument(left[1 .. $]);
        with (Argument) final switch (kind) {
            case none:
                echof("`%s`: Not a valid argument.", arg);
                return 1;
            case I:
                if (!right.isD) {
                    echof("`%s`: Value is not a folder.", arg, right);
                    return 1;
                }
                options.iDirs ~= right;
                options.jDirs ~= right;
                if (options.include != Boolean.FALSE) {
                    options.dFiles ~= find(right, ".d", true);
                }
                break;
            case J:
                if (!right.isD) {
                    echof("`%s`: Value is not a folder.", arg, right);
                    return 1;
                }
                options.jDirs ~= right;
                break;
            case L:
                options.lFlags ~= right;
                break;
            case D:
                options.dFlags ~= right;
                break;
            case V:
                options.versionNames ~= right;
                break;
            case R:
                options.rArguments ~= right;
                break;
            case a:
                if (options.argumentsFile.length) {
                    echof("`%s`: An arguments file already exists.", arg);
                    return 1;
                }
                if (!right.isF) {
                    echof("`%s`: Value is not a file.", arg, right);
                    return 1;
                }
                options.argumentsFile = right;
                break;
            case s:
                if (options.sectionName.length) {
                    echof("`%s`: A section name already exists.", arg);
                    return 1;
                }
                options.sectionName = right;
                break;
            case o:
                if (options.outputPath.length) {
                    echof("`%s`: An output path already exists.", arg);
                    return 1;
                }
                options.outputPath = right;
                break;
            case c:
                if (options.compiler) {
                    echof("`%s`: A compiler already exists.", arg);
                    return 1;
                }
                options.compiler = toEnum!Compiler(right);
                if (options.compiler == Compiler.none) {
                    echof("`%s`: Compiler `%s` is invalid.", arg, right);
                    return 1;
                }
                break;
            case b:
                if (options.build) {
                    echof("`%s`: A build type already exists.", arg);
                    return 1;
                }
                options.build = toEnum!Build(right);
                if (options.build == Build.none) {
                    echof("`%s`: Build type `%s` is invalid.", arg, right);
                    return 1;
                }
                break;
            case i:
                if (options.include) {
                    echof("`%s`: Include already has a value.", arg);
                    return 1;
                }
                options.include = toEnum!Boolean(right);
                if (options.include == Boolean.none) {
                    echof("`%s`: Value `%s` for include is invalid.", arg, right);
                    return 1;
                }
                break;
            case q:
                if (options.quiet) {
                    echof("`%s`: Quiet already has a value.", arg);
                    return 1;
                }
                options.quiet = toEnum!Boolean(right);
                if (options.quiet == Boolean.none) {
                    echof("`%s`: Value `%s` for quiet is invalid.", arg, right);
                    return 1;
                }
                break;
        }
    }
    arguments.length = 0;
    return 0;
}

int parseArgumentsFile(ref CompilerOptions options, ref IStr[] arguments) {
    if (!options.argumentsFile.isF) return 0;
    auto hasSelectedSection = false;
    auto content = cat(options.argumentsFile);
    auto lineStart = 0;
    auto lineNumber = 0;
    foreach (i, c; content) {
        if (c != '\n') continue;
        auto line = content[lineStart .. i].trim();
        lineNumber += 1;
        if (line.length == 0) continue;
        if (line[0] == '[') {
            if (hasSelectedSection) {
                break;
            } else {
                if (line[$ - 1] != ']') {
                    echof("%s:%s: Invalid section.", options.argumentsFile, lineNumber);
                    return 1;
                }
                auto name = line[1 .. $ - 1].trim();
                if (options.sectionName.length == 0 || name == options.sectionName) {
                    hasSelectedSection = true;
                }
            }
        } else {
            if (options.sectionName.length == 0) {
                hasSelectedSection = true;
            }
            if (hasSelectedSection) {
                arguments ~= line;
            }
        }
        lineStart = cast(int) (i + 1);
    }
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
    options.iDirs ~= source;
    options.jDirs ~= source;
    if (applyArgumentsToOptions(options, arguments)) return 1;
    if (options.argumentsFile.length == 0) options.argumentsFile = ".closed";
    if (parseArgumentsFile(options, arguments)) return 1;
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
    IStr[] dc = [enumToStr(options.compiler)];
    dc ~= options.dFiles;
    foreach (dir; options.iDirs) {
        dc ~= "-I" ~ dir;
    }
    foreach (dir; options.jDirs) {
        dc ~= "-J" ~ dir;
    }
    foreach (flag; options.dFlags) {
        dc ~= flag;
    }
    foreach (flag; options.lFlags) {
        if (options.compiler == Compiler.gdc) {
            dc ~= "-Xlinker";
            dc ~= flag;
        } else {
            dc ~= "-L" ~ flag;
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
    foreach (name; options.versionNames) {
        if (0) {
        } else if (options.compiler == Compiler.ldc2) {
            dc ~= "-d-version=" ~ name;
        } else if (options.compiler == Compiler.gdc) {
            dc ~= "-fversion=" ~ name;
        } else if (options.compiler == Compiler.dmd) {
            dc ~= "-version=" ~ name;
        }
    }
    if (options.compiler == Compiler.gdc) {
        dc ~= "-o" ~ options.outputPath;
    } else {
        dc ~= "-of" ~ options.outputPath;
    }
    version (Windows) {
        if (options.build == Build.DEBUG || options.build == Build.RELEASE) {
            if (!dc[$ - 1].endsWith(".exe")) dc[$ - 1] ~= ".exe";
        }
    }
    if (options.build == Build.TEST) {
        version (Windows) {
            if (!dc[$ - 1].endsWith("-test.exe")) dc[$ - 1] ~= "-test.exe";
        } else {
            if (!dc[$ - 1].endsWith("-test")) dc[$ - 1] ~= "-test";
        }
    }
    if (options.build == Build.DLL || options.build == Build.DLLR) {
        version (Windows) {
            if (!dc[$ - 1].endsWith(".dll")) dc[$ - 1] ~= ".dll";
        } else version (OSX) {
            if (!dc[$ - 1].endsWith(".dylib")) dc[$ - 1] ~= ".dylib";
        } else {
            if (!dc[$ - 1].endsWith(".so")) dc[$ - 1] ~= ".so";
        }
    }
    if (options.build == Build.LIB || options.build == Build.LIBR) {
        version (Windows) {
            if (!dc[$ - 1].endsWith(".lib")) dc[$ - 1] ~= ".lib";
        } else {
            if (!dc[$ - 1].endsWith(".a")) dc[$ - 1] ~= ".a";
        }
    }
    if (options.build == Build.OBJ || options.build == Build.OBJR) {
        version (Windows) {
            if (!dc[$ - 1].endsWith(".obj")) dc[$ - 1] ~= ".obj";
        } else {
            if (!dc[$ - 1].endsWith(".o")) dc[$ - 1] ~= ".o";
        }
    }
    if (options.build >= Build.RELEASE) {
        with (Compiler) final switch (options.compiler) {
            case none: break;
            case dmd : dc ~= "-release"; break;
            case ldc2: dc ~= "--release"; break;
            case gdc : dc ~= "-O2"; break;
        }
    }
    with (Build) switch (options.build) {
        case TEST:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-unittest"; dc ~= "-main"; break;
                case ldc2 : dc ~= "--unittest"; dc ~= "--main"; break;
                case gdc : dc ~= "-funittest"; dc ~= "-fmain"; break;
            }
            break;
        case DLL:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-shared"; break;
                case ldc2: dc ~= "--shared"; break;
                case gdc : dc ~= "-shared"; dc ~= "-fPIC"; break;
            }
            break;
        case LIB:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-lib"; break;
                case ldc2: dc ~= "--lib"; dc ~= "-oq"; break;
                case gdc : dc ~= "-c"; break; // NOTE: No idea, just copied what DUB does.
            }
            break;
        case OBJ:
            dc ~= "-c";
            break;
        default:
            break;
    }
    if (options.quiet == Boolean.TRUE) {
        isCmdLineHidden = true;
    }

    // Run the cmd.
    if (cmd(dc)) {
        echo("Compilation failed.");
        return 1;
    }
    if (options.build != Build.OBJ && options.build != Build.OBJR) {
        version(Windows) {
            foreach (file; find(".", ".obj")) rm(file);
        } else {
            foreach (file; find(".", ".o")) rm(file);
        }
    }
    switch (mode) {
        case "build", "b":
            return 0;
        case "run", "r":
            if (options.build != Build.TEST && options.build != Build.DEBUG && options.build != Build.RELEASE) {
                echo("Cannot run library.");
                return 1;
            }
            IStr[] dr = [];
            if (options.outputPath[0] == '.' || options.outputPath[0] == pathSep) {
                dr ~= options.outputPath;
            } else {
                dr ~= join(".", options.outputPath);
            }
            foreach (argument; options.rArguments) dr ~= argument;
            return cmd(dr);
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
