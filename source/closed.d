#!/bin/env -S dmd -run

// [Noby Script]

// I will ignore stuff that I don't use for now.
// It's FOSS, fix it yourself or something.

// TODO: Check GDC lib output one day.
// TODO: Make rpath work on OSX one day.
// TODO: Turn OS stuff into a variable maybe.
// TODO: Might need to also clean some stuff, but ehh.

module closed;

enum info = `
Usage:
 closed <mode> [arguments...]
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
 -t=<exe|dll|lib|obj>
 -b=<DEBUG|RELEASE>
 -i=<TRUE|FALSE> (include d files)
 -v=<TRUE|FALSE> (verbose messages)
 -f=<TRUE|FALSE> (fallback config)
`[1 .. $ - 1];

enum Mode : ubyte {
    none,
    build,
    run,
    test,
}

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
    t,
    b,
    i,
    v,
    f,
}

enum Boolean : ubyte {
    none,
    TRUE,
    FALSE,
}

enum Target : ubyte {
    none,
    exe,
    dll,
    lib,
    obj,
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
    IStr[] dFlags;
    IStr[] rArguments;
    IStr[] versionNames;
    IStr sourceDir;
    IStr sourceParentDir;
    IStr argumentsFile;
    IStr sectionName;
    IStr outputFile;
    Mode mode;
    Compiler compiler;
    Target target;
    Build build;
    Boolean include;
    Boolean verbose;
    Boolean fallback;
    bool isSingleFile;
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

int applyArgumentsToOptions(ref CompilerOptions options, ref IStr[] arguments, bool isUsingProjectPath) {
    foreach (arg; arguments) {
        if (arg.length <= 3 || arg.findStart("=") == -1) {
            echof("Argument `%s` is invalid.", arg);
            return 1;
        }
        auto left = arg[0 .. 2];
        auto right = arg[3 .. $].trim().pathFmt();
        if (right.length) {
            right = right[$ - 1] == pathSep ? right[0 .. $ - 1] : right;
        }
        auto kind = toEnum!Argument(left[1 .. $]);
        // Assumes `right` is a local path.
        auto rightPath = isUsingProjectPath ? join(options.sourceParentDir, right) : right;
        with (Argument) final switch (kind) {
            case none:
                echof("Argument `%s` is invalid.", arg);
                return 1;
            case I:
                options.iDirs ~= rightPath;
                options.jDirs ~= rightPath;
                if (options.include != Boolean.FALSE) {
                    options.dFiles ~= find(rightPath, ".d", true);
                }
                break;
            case J:
                options.jDirs ~= rightPath;
                break;
            case L:
                if (right.startsWith("-L")) {
                    auto rightL = "-L" ~ join(options.sourceParentDir, right.findStart("=") == -1 ? right[2 .. $] : right[3 .. $]);
                    options.lFlags ~= rightL;
                } else {
                    options.lFlags ~= right;
                }
                break;
            case D:
                if (0) {
                } else if (right.startsWith("-I")) {
                    auto rightI = "-I" ~ join(options.sourceParentDir, right.findStart("=") == -1 ? right[2 .. $] : right[3 .. $]);
                    options.dFlags ~= rightI;
                } else if (right.endsWith(".d")) {
                    options.dFlags ~= rightPath;
                } else {
                    options.dFlags ~= right;
                }
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
                if (!rightPath.isF) {
                    echof("`%s`: Value `%s` is not a file.", arg, rightPath);
                    return 1;
                }
                options.argumentsFile = rightPath;
                break;
            case s:
                if (options.sectionName.length) {
                    echof("`%s`: A section name already exists.", arg);
                    return 1;
                }
                options.sectionName = right;
                break;
            case o:
                if (options.outputFile.length) {
                    echof("`%s`: An output file already exists.", arg);
                    return 1;
                }
                options.outputFile = rightPath;
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
            case t:
                if (options.target) {
                    echof("`%s`: A target already exists.", arg);
                    return 1;
                }
                options.target = toEnum!Target(right);
                if (options.target == Target.none) {
                    echof("`%s`: Target `%s` is invalid.", arg, right);
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
            case v:
                if (options.verbose) {
                    echof("`%s`: Verbose already has a value.", arg);
                    return 1;
                }
                options.verbose = toEnum!Boolean(right);
                if (options.verbose == Boolean.none) {
                    echof("`%s`: Value `%s` for verbose is invalid.", arg, right);
                    return 1;
                }
                break;
            case f:
                if (options.fallback) {
                    echof("`%s`: Fallback already has a value.", arg);
                    return 1;
                }
                options.fallback = toEnum!Boolean(right);
                if (options.fallback == Boolean.none) {
                    echof("`%s`: Value `%s` for fallback is invalid.", arg, right);
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
        if (0) {
        } else if (line.length == 0) {
        } else if (line[0] == '#') {
        } else if (line[0] == '[') {
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
    if (!hasSelectedSection) {
        echof("Section `%s` doesn't exist.", options.sectionName);
        return 1;
    }
    return 0;
}

int closedMain(string[] args) {
    if (args.length == 1) { echo(info); return 1; }
    if (args[1] == "please") { echo("Say it again!"); return 1; }
    if (args[1] == "thanks") { echo("Thank you!"); return 1; }
    isCmdLineHidden = true;

    // Prepare the compiler options.
    auto options = CompilerOptions();
    options.mode = toEnum!Mode(args[1]);
    if (options.mode == Mode.none) {
        echof("Mode `%s` doesn't exist.", args[1]);
        return 1;
    }
    IStr[] arguments = null;
    if (args.length == 2 || args[2][0] == '-') {
        options.sourceDir = ".";
        arguments = cast(IStr[]) args[2 .. $];
    } else {
        options.sourceDir = args[2].pathFmt();
        arguments = cast(IStr[]) args[3 .. $];
    }
    options.sourceDir = options.sourceDir[$ - 1] == pathSep ? options.sourceDir[0 .. $ - 1] : options.sourceDir;
    if (options.sourceDir.isD) {
        auto dir1 = join(options.sourceDir, "source");
        auto dir2 = join(options.sourceDir, "src");
        if (0) {}
        else if (dir1.isD) options.sourceDir = dir1;
        else if (dir2.isD) options.sourceDir = dir2;
        options.dFiles ~= find(options.sourceDir, ".d", true);
    } else if (options.sourceDir.isF && options.sourceDir.endsWith(".d")) {
        options.dFiles ~= options.sourceDir;
        options.sourceDir = options.sourceDir.dirname;
        options.isSingleFile = true;
    } else {
        echof("Source `%s` is not a valid folder or file.", args[2]);
        return 1;
    }
    options.sourceParentDir = join(options.sourceDir, "..");

    // Build the compiler options.
    if (applyArgumentsToOptions(options, arguments, false)) return 1;
    if (options.argumentsFile.length == 0 && options.fallback != Boolean.FALSE) {
        options.argumentsFile = join(options.sourceDir, ".closed");
        if (!options.argumentsFile.isF) {
            options.argumentsFile = join(options.sourceParentDir, ".closed");
        }
    }
    if (parseArgumentsFile(options, arguments)) return 1;
    if (applyArgumentsToOptions(options, arguments, true)) return 1;
    // Add default compiler options if needed.
    if (options.outputFile.length == 0) {
        if (options.isSingleFile) {
            auto name1 = options.dFiles[0][0 .. $ - 2];
            auto name2 = name1.basename;
            options.outputFile = join(options.sourceDir, (name2 == ".") ? name1 : name2);
        } else {
            options.outputFile = join(options.sourceParentDir, pwd.basename);
        }
    }
    if (options.compiler == Compiler.none) {
        version (OSX) options.compiler = Compiler.ldc2;
        else options.compiler = Compiler.dmd;
    }
    if (options.target == Target.none) {
        options.target = Target.exe;
    }
    if (options.build == Build.none) {
        options.build = Build.DEBUG;
    }
    // Check the options one last time for weird stuff.
    if (options.dFiles.length == 0) {
        echo("No D source files given.");
        return 1;
    }
    if (options.target != Target.exe && options.mode != Mode.build) {
        echof("Mode `%s` for target `%s` is invalid.", options.mode, options.target);
        return 1;
    }
    // Fix the name of the output file if needed.
    if (options.mode != Mode.build) {
        options.outputFile ~= "-temporary";
    }
    version (Windows) {
        if (options.target == Target.exe) {
            if (!options.outputFile.endsWith(".exe")) {
                options.outputFile ~= ".exe";
            }
        }
    }
    with (Target) final switch (options.target) {
        case exe, none:
            break;
        case dll:
            version (Windows) {
                if (!options.outputFile.endsWith(".dll")) options.outputFile ~= ".dll";
            } else version (OSX) {
                if (!options.outputFile.endsWith(".dylib")) options.outputFile ~= ".dylib";
            } else {
                if (!options.outputFile.endsWith(".so")) options.outputFile ~= ".so";
            }
            break;
        case lib:
            version (Windows) {
                if (!options.outputFile.endsWith(".lib")) options.outputFile ~= ".lib";
            } else {
                if (!options.outputFile.endsWith(".a")) options.outputFile ~= ".a";
            }
            break;
        case obj:
            version (Windows) {
                if (!options.outputFile.endsWith(".obj")) options.outputFile ~= ".obj";
            } else {
                if (!options.outputFile.endsWith(".o")) options.outputFile ~= ".o";
            }
            break;
    }

    // Build the cmd.
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
        if (options.lFlags.length && options.target == Target.exe) {
            if (options.compiler == Compiler.gdc) {
                dc ~= "-Xlinker";
                dc ~= "-rpath=$ORIGIN";
            } else {
                dc ~= "-L-rpath=$ORIGIN";
            }
        }
    }
    foreach (name; options.versionNames) {
        with (Compiler) final switch (options.compiler) {
            case none: break;
            case dmd : dc ~= "-version=" ~ name; break;
            case ldc2: dc ~= "-d-version=" ~ name; break;
            case gdc : dc ~= "-fversion=" ~ name; break;
        }
    }
    if (options.compiler == Compiler.gdc) {
        dc ~= "-o" ~ options.outputFile;
    } else {
        dc ~= "-of" ~ options.outputFile;
    }
    with (Build) final switch (options.build) {
        case none:
            break;
        case DEBUG:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-debug"; break;
                case ldc2: dc ~= "-d-debug"; break;
                case gdc : dc ~= "-fdebug"; break;
            }
            break;
        case RELEASE:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-release"; break;
                case ldc2: dc ~= "--release"; break;
                case gdc : dc ~= "-O2"; break;
            }
            break;
    }
    if (options.mode == Mode.test) {
        with (Compiler) final switch (options.compiler) {
            case none: break;
            case dmd : dc ~= "-unittest"; dc ~= "-main"; break;
            case ldc2 : dc ~= "--unittest"; dc ~= "--main"; break;
            case gdc : dc ~= "-funittest"; dc ~= "-fmain"; break;
        }
    }
    with (Target) final switch (options.target) {
        case exe, none:
            break;
        case dll:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-shared"; break;
                case ldc2: dc ~= "--shared"; break;
                case gdc : dc ~= "-shared"; dc ~= "-fPIC"; break;
            }
            break;
        case lib:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-lib"; break;
                case ldc2: dc ~= "--lib"; dc ~= "-oq"; break;
                case gdc : dc ~= "-c"; break; // NOTE: No idea, just copied what DUB does.
            }
            break;
        case obj:
            dc ~= "-c";
            break;
    }
    if (options.verbose == Boolean.TRUE) {
        isCmdLineHidden = false;
    }

    // Run the cmd.
    if (cmd(dc)) {
        echo("Compilation failed.");
        return 1;
    }
    if (options.target != Target.obj) {
        version(Windows) foreach (file; find(options.outputFile.dirname, ".obj")) rm(file);
        else foreach (file; find(options.outputFile.dirname, ".o")) rm(file);
    }
    if (options.mode == Mode.run || options.mode == Mode.test) {
        IStr[] dr = [];
        if (options.outputFile[0] == '.' || options.outputFile[0] == pathSep) {
            dr ~= options.outputFile;
        } else {
            dr ~= join(".", options.outputFile);
        }
        foreach (argument; options.rArguments) dr ~= argument;
        auto status = cmd(dr);
        rm(options.outputFile);
        return status;
    }
    return 0;
}

version (ClosedLibrary) {
} else {
    int main(string[] args) {
        return closedMain(args);
    }
}

unittest {
    // This is here to avoid running the tool when testing.
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

IStr dirname(IStr path) {
    auto end = findEnd(path, pathSepStr);
    if (end == -1) return ".";
    else return path[0 .. end];
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
