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
 -b=<DEBUG|RELEASE|SMALL>
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
    SMALL,
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

int applyArgumentsToOptions(ref CompilerOptions options, ref IStr[] arguments, bool isUsingProjectPath) {
    foreach (arg; arguments) {
        if (arg.length <= 3 || arg.findStart("=") == -1) {
            echof("Argument `%s` is invalid.", arg);
            return 1;
        }
        auto left = arg[0 .. 2];
        auto right = arg[3 .. $].trim().pathTrimEnd().pathFormat();
        if (right.length == 0) {
            echof("Argument `%s` is invalid.", arg);
            return 1;
        }
        auto kind = toEnum!Argument(left[1 .. $]);
        // Assumes `right` is a local path and also handles flags.
        auto rightPath = right;
        if (rightPath.length >= 2 && rightPath[0] == '-' && rightPath[1].isAlpha) {
            rightPath = rightPath[2 .. $];
            if (rightPath.startsWith('=')) rightPath = rightPath[1 .. $];
        }
        rightPath = isUsingProjectPath ? pathConcat(options.sourceParentDir, rightPath) : rightPath;
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
                    options.lFlags ~= "-L" ~ rightPath;
                } else {
                    options.lFlags ~= right;
                }
                break;
            case D:
                if (0) {
                } else if (right.startsWith("-I")) {
                    options.dFlags ~= "-I" ~ rightPath;
                } else if (right.startsWith("-J")) {
                    options.dFlags ~= "-J" ~ rightPath;
                } else if (right.startsWith("-i")) {
                    options.dFlags ~= "-i=" ~ rightPath;
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
                options.argumentsFile = rightPath.dup();
                break;
            case s:
                if (options.sectionName.length) {
                    echof("`%s`: A section name already exists.", arg);
                    return 1;
                }
                options.sectionName = right.dup();
                break;
            case o:
                if (options.outputFile.length) {
                    echof("`%s`: An output file already exists.", arg);
                    return 1;
                }
                options.outputFile = rightPath.dup();
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

int closedMain(IStr[] args) {
    if (args.length == 1) { echo(info); return 1; }
    if (args[1] == "please") { echo("Say it again!"); return 1; }
    if (args[1] == "thanks") { echo("Thank you!"); return 1; }
    isCmdLineHidden = true;

    // Prepare the compiler options.
    auto options = CompilerOptions();
    options.iDirs.reserve(128);
    options.jDirs.reserve(128);
    options.lFlags.reserve(128);
    options.dFlags.reserve(128);
    options.dFiles.reserve(1024);

    options.mode = toEnum!Mode(args[1]);
    if (options.mode == Mode.none) { echof("Mode `%s` doesn't exist.", args[1]); return 1; }
    IStr[] arguments = null;
    if (args.length == 2 || args[2][0] == '-') {
        options.sourceDir = ".";
        arguments = args[2 .. $];
    } else {
        options.sourceDir = args[2].pathFormat();
        arguments = args[3 .. $];
    }
    options.sourceDir = options.sourceDir.pathTrimEnd().dup();
    if (options.sourceDir.isD) {
        auto dir1 = pathConcat(options.sourceDir, "source");
        auto dir2 = pathConcat(options.sourceDir, "src");
        if (0) {}
        else if (dir1.isD) options.sourceDir = dir1.dup();
        else if (dir2.isD) options.sourceDir = dir2.dup();
        options.dFiles ~= find(options.sourceDir, ".d", true);
    } else if (options.sourceDir.isF && options.sourceDir.endsWith(".d")) {
        options.dFiles ~= options.sourceDir;
        options.sourceDir = options.sourceDir.pathDirName.dup();
        options.isSingleFile = true;
    } else {
        echof("Source `%s` is not a valid folder or file.", args[2]);
        return 1;
    }
    options.sourceParentDir = pathConcat(options.sourceDir, "..").dup();
    // Build the compiler options.
    if (applyArgumentsToOptions(options, arguments, false)) return 1;
    if (options.argumentsFile.length == 0 && options.fallback != Boolean.FALSE) {
        options.argumentsFile = pathConcat(options.sourceDir, ".closed");
        if (!options.argumentsFile.isF) {
            options.argumentsFile = pathConcat(options.sourceParentDir, ".closed");
        }
        options.argumentsFile = options.argumentsFile.dup();
    }
    if (parseArgumentsFile(options, arguments)) return 1;
    if (applyArgumentsToOptions(options, arguments, true)) return 1;
    // Add default compiler options if needed.
    if (options.outputFile.length == 0) {
        if (options.isSingleFile) {
            auto name1 = options.dFiles[0][0 .. $ - 2];
            auto name2 = name1.pathBaseName;
            options.outputFile = pathConcat(options.sourceDir, (name2 == ".") ? name1 : name2).dup();
        } else {
            options.outputFile = pathConcat(options.sourceParentDir, pwd.pathBaseName).dup();
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
        if (options.mode == Mode.test) {
            options.target = Target.exe;
        } else {
            echof("Mode `%s` for target `%s` is invalid.", options.mode, options.target);
            return 1;
        }
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
                case dmd : dc ~= "-debug"  ; dc ~= "-dw" ; break;
                case ldc2: dc ~= "-d-debug"; dc ~= "--dw"; break;
                case gdc : dc ~= "-fdebug" ; break;
            }
            dc ~= "-g";
            break;
        case RELEASE:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-release" ; dc ~= "-inline"           ; dc ~= "-O" ; break;
                case ldc2: dc ~= "--release"; dc ~= "-enable-inlining"  ; dc ~= "-O3"; break;
                case gdc : dc ~= "-frelease"; dc ~= "-finline-functions"; dc ~= "-O2"; break;
            }
            break;
        case SMALL:
            with (Compiler) final switch (options.compiler) {
                case none: break;
                case dmd : dc ~= "-release" ; dc ~= "-O" ; break;
                case ldc2: dc ~= "--release"; dc ~= "-Oz"; break;
                case gdc : dc ~= "-frelease"; dc ~= "-Os"; break;
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
        version(Windows) foreach (file; find(options.outputFile.pathDirName, ".obj")) rm(file);
        else foreach (file; find(options.outputFile.pathDirName, ".o")) rm(file);
    }
    if (options.mode == Mode.run || options.mode == Mode.test) {
        IStr[] dr = [];
        if (options.outputFile[0] == '.' || options.outputFile[0] == pathSep) {
            dr ~= options.outputFile;
        } else {
            dr ~= pathConcat(".", options.outputFile);
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
        return closedMain(cast(IStr[]) args);
    }
}

unittest {
    // This is here to avoid running the tool when testing.
}

// [Noby Library]

Level minLogLevel    = Level.info;
bool isCmdLineHidden = false;

enum cloneExt = "._clone";

enum Level : ubyte {
    none,
    info,
    warning,
    error,
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

IStr format(A...)(IStr text, A args...) {
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

// The following code is copied from Joka: https://github.com/Kapendev/joka/blob/main/source/joka/ascii.d

alias Sz      = size_t;         /// The result of sizeof, ...

alias Str     = char[];         /// A string slice of chars.
alias Str16   = wchar[];        /// A string slice of wchars.
alias Str32   = dchar[];        /// A string slice of dchars.
alias IStr    = const(char)[];  /// A string slice of constant chars.
alias IStr16  = const(wchar)[]; /// A string slice of constant wchars.
alias IStr32  = const(dchar)[]; /// A string slice of constant dchars.

alias CStr    = char*;          /// A C string of chars.
alias CStr16  = wchar*;         /// A C string of wchars.
alias CStr32  = dchar*;         /// A C string of dchars.
alias ICStr   = const(char)*;   /// A C string of constant chars.
alias ICStr16 = const(wchar)*;  /// A C string of constant wchars.
alias ICStr32 = const(dchar)*;  /// A C string of constant dchars.

/// A type representing error values.
enum Fault : ubyte {
    none,      /// Not an error.
    some,      /// A generic error.
    bug,       /// An implementation error.
    invalid,   /// An invalid data error.
    overflow,  /// An overflow error.
    assertion, /// An assertion error.
    cantParse, /// A parse error.
    cantFind,  /// A wrong path error.
    cantOpen,  /// An open permissions error.
    cantClose, /// A close permissions error.
    cantRead,  /// A read permissions error.
    cantWrite, /// A write permissions error.
}

enum digitChars = "0123456789";                          /// The set of digits.
enum upperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";          /// The set of uppercase letters.
enum lowerChars = "abcdefghijklmnopqrstuvwxyz";          /// The set of lowercase letters.
enum alphaChars = upperChars ~ lowerChars;               /// The set of letters.
enum spaceChars = " \t\v\r\n\f";                         /// The set of whitespace characters.
enum symbolChars = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"; /// The set of symbol characters.

version (Windows) {
    enum pathSep = '\\';
    enum pathSepStr = "\\";
    enum pathSepOther = '/';
    enum pathSepOtherStr = "/";
} else {
    enum pathSep = '/';          /// The primary OS path separator as a character.
    enum pathSepStr = "/";       /// The primary OS path separator as a string.
    enum pathSepOther = '\\';    /// The complementary OS path separator as a character.
    enum pathSepOtherStr = "\\"; /// The complementary OS path separator as a string.
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

/// Returns the length of the C string.
@trusted
Sz cStrLength(ICStr str) {
    Sz result = 0;
    while (str[result] != '\0') result += 1;
    return result;
}

/// Returns true if the two strings are equal, ignoring case.
bool equalsNoCase(IStr str, IStr other) {
    if (str.length != other.length) return false;
    foreach (i; 0 .. str.length) if (toUpper(str[i]) != toUpper(other[i])) return false;
    return true;
}

/// Returns true if the string is equal to the specified character, ignoring case.
bool equalsNoCase(IStr str, char other) {
    return equalsNoCase(str, charToStr(other));
}

/// Returns true if the string starts with the specified substring.
bool startsWith(IStr str, IStr start) {
    if (str.length < start.length) return false;
    return str[0 .. start.length] == start;
}

/// Returns true if the string starts with the specified character.
bool startsWith(IStr str, char start) {
    return startsWith(str, charToStr(start));
}

/// Returns true if the string ends with the specified substring.
bool endsWith(IStr str, IStr end) {
    if (str.length < end.length) return false;
    return str[$ - end.length .. $] == end;
}

/// Returns true if the string ends with the specified character.
bool endsWith(IStr str, char end) {
    return endsWith(str, charToStr(end));
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

/// Counts the number of occurrences of the specified character in the string.
int countItem(IStr str, char item) {
    return countItem(str, charToStr(item));
}

/// Finds the starting index of the first occurrence of the specified substring in the string, or returns -1 if not found.
int findStart(IStr str, IStr item) {
    if (str.length < item.length || item.length == 0) return -1;
    foreach (i; 0 .. str.length - item.length + 1) {
        if (str[i .. i + item.length] == item) return cast(int) i;
    }
    return -1;
}

/// Finds the starting index of the first occurrence of the specified character in the string, or returns -1 if not found.
int findStart(IStr str, char item) {
    return findStart(str, charToStr(item));
}

/// Finds the ending index of the first occurrence of the specified substring in the string, or returns -1 if not found.
int findEnd(IStr str, IStr item) {
    if (str.length < item.length || item.length == 0) return -1;
    foreach_reverse (i; 0 .. str.length - item.length + 1) {
        if (str[i .. i + item.length] == item) return cast(int) i;
    }
    return -1;
}

/// Finds the ending index of the first occurrence of the specified character in the string, or returns -1 if not found.
int findEnd(IStr str, char item) {
    return findEnd(str, charToStr(item));
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

/// Advances the string by the specified number of characters.
IStr advanceStr(IStr str, Sz amount) {
    if (str.length < amount) return str[$ .. $];
    else return str[amount .. $];
}

/// Copies characters from the source string to the destination string starting at the specified index.
@trusted
Fault copyChars(Str str, IStr source, Sz startIndex = 0) {
    if (str.length < source.length + startIndex) return Fault.overflow;
    foreach (i, c; source) str[startIndex + i] = c;
    return Fault.none;
}

/// Copies characters from the source string to the destination string starting at the specified index and adjusts the length of the destination string.
Fault copyStr(ref Str str, IStr source, Sz startIndex = 0) {
    auto fault = copyChars(str, source, startIndex);
    if (fault) return fault;
    str = str[0 .. startIndex + source.length];
    return Fault.none;
}

/// Concatenates the strings.
/// Writes into the buffer and returns the result.
IStr concatIntoBuffer(Str buffer, IStr[] args...) {
    if (args.length == 0) return ".";
    auto result = buffer;
    auto length = 0;
    foreach (i, arg; args) {
        result.copyChars(arg, length);
        length += arg.length;
    }
    result = result[0 .. length];
    return result;
}

/// Concatenates the strings using a static buffer and returns the result.
IStr concat(IStr[] args...) {
    static char[512][4] buffers = void;
    static byte bufferIndex = 0;

    if (args.length == 0) return ".";
    bufferIndex = (bufferIndex + 1) % buffers.length;
    return concatIntoBuffer(buffers[bufferIndex][], args);
}

/// Returns the directory of the path, or "." if there is no directory.
IStr pathDirName(IStr path) {
    auto end = findEnd(path, pathSepStr);
    if (end == -1) return ".";
    else return path[0 .. end];
}

/// Returns the extension of the path.
IStr pathExtName(IStr path) {
    auto end = findEnd(path, ".");
    if (end == -1) return "";
    else return path[end .. $];
}

/// Returns the base name of the path.
IStr pathBaseName(IStr path) {
    auto end = findEnd(path, pathSepStr);
    if (end == -1) return path;
    else return path[end + 1 .. $];
}

/// Returns the base name of the path without the extension.
IStr pathBaseNameNoExt(IStr path) {
    return path.pathBaseName[0 .. $ - path.pathExtName.length];
}

/// Removes path separators from the beginning of the path.
IStr pathTrimStart(IStr path) {
    IStr result = path;
    while (result.length > 0) {
        if (result[0] == pathSep || result[0] == pathSepOther) result = result[1 .. $];
        else break;
    }
    return result;

}

/// Removes path separators from the end of the path.
IStr pathTrimEnd(IStr path) {
    IStr result = path;
    while (result.length > 0) {
        if (result[$ - 1] == pathSep || result[$ - 1] == pathSepOther) result = result[0 .. $ - 1];
        else break;
    }
    return result;
}

/// Removes path separators from the beginning and end of the path.
IStr pathTrim(IStr path) {
    return path.pathTrimStart().pathTrimEnd();
}

/// Formats the path to a standard form, normalizing separators.
IStr pathFormat(IStr path) {
    static char[512][4] buffers = void;
    static byte bufferIndex = 0;

    if (path.length == 0) return ".";
    bufferIndex = (bufferIndex + 1) % buffers.length;
    auto result = buffers[bufferIndex][];
    foreach (i, c; path) {
        if (c == pathSepOther) {
            result[i] = pathSep;
        } else {
            result[i] = c;
        }
    }
    result = result[0 .. path.length];
    return result;
}

/// Concatenates the paths, ensuring proper path separators between them.
IStr pathConcat(IStr[] args...) {
    static char[512][4] buffers = void;
    static byte bufferIndex = 0;

    if (args.length == 0) return ".";
    bufferIndex = (bufferIndex + 1) % buffers.length;
    auto result = buffers[bufferIndex][];
    auto length = 0;
    auto isFirst = true;
    foreach (i, arg; args) {
        if (arg.length == 0) continue;
        auto cleanArg = arg;
        if (cleanArg[0] == pathSep || cleanArg[0] == pathSepOther) {
            cleanArg = cleanArg.pathTrimStart();
            if (isFirst) {
                result[length] = pathSep;
                length += 1;
            }
        }
        cleanArg = cleanArg.pathTrimEnd();
        result.copyChars(cleanArg, length);
        length += cleanArg.length;
        if (i != args.length - 1) {
            result[length] = pathSep;
            length += 1;
        }
        isFirst = false;
    }
    if (length == 0) return ".";
    result = result[0 .. length];
    return result;
}

/// Skips over the next occurrence of the specified separator in the string, returning the substring before the separator and updating the input string to start after the separator.
IStr skipValue(ref inout(char)[] str, IStr sep) {
    if (str.length < sep.length || sep.length == 0) {
        str = str[$ .. $];
        return "";
    }
    foreach (i; 0 .. str.length - sep.length) {
        if (str[i .. i + sep.length] == sep) {
            auto line = str[0 .. i];
            str = str[i + sep.length .. $];
            return line;
        }
    }
    auto line = str[0 .. $];
    if (str[$ - sep.length .. $] == sep) {
        line = str[0 .. $ - 1];
    }
    str = str[$ .. $];
    return line;
}

/// Skips over the next occurrence of the specified separator in the string, returning the substring before the separator and updating the input string to start after the separator.
IStr skipValue(ref inout(char)[] str, char sep) {
    return skipValue(str, charToStr(sep));
}

/// Skips over the next line in the string, returning the substring before the line break and updating the input string to start after the line break.
IStr skipLine(ref inout(char)[] str) {
    return skipValue(str, '\n');
}

/// Converts the boolean value to its string representation.
IStr boolToStr(bool value) {
    return value ? "true" : "false";
}

/// Converts the character to its string representation.
IStr charToStr(char value) {
    static char[1] buffer = void;

    auto result = buffer[];
    result[0] = value;
    result = result[0 .. 1];
    return result;
}

/// Converts the unsigned long value to its string representation.
IStr unsignedToStr(ulong value) {
    static char[64] buffer = void;

    auto result = buffer[];
    if (value == 0) {
        result[0] = '0';
        result = result[0 .. 1];
    } else {
        auto digitCount = 0;
        for (auto temp = value; temp != 0; temp /= 10) {
            result[$ - 1 - digitCount] = (temp % 10) + '0';
            digitCount += 1;
        }
        result = result[$ - digitCount .. $];
    }
    return result;
}

/// Converts the signed long value to its string representation.
IStr signedToStr(long value) {
    static char[64] buffer = void;

    auto result = buffer[];
    if (value < 0) {
        auto temp = unsignedToStr(-value);
        result[0] = '-';
        result.copyStr(temp, 1);
    } else {
        auto temp = unsignedToStr(value);
        result.copyStr(temp, 0);
    }
    return result;
}

/// Converts the double value to its string representation with the specified precision.
IStr doubleToStr(double value, ulong precision = 2) {
    static char[64] buffer = void;

    if (precision == 0) {
        return signedToStr(cast(long) value);
    }

    auto result = buffer[];
    auto cleanNumber = value;
    auto rightDigitCount = 0;
    while (cleanNumber != cast(double) (cast(long) cleanNumber)) {
        rightDigitCount += 1;
        cleanNumber *= 10;
    }

    // Add extra zeros at the end if needed.
    // I do this because it makes it easier to remove the zeros later.
    if (precision > rightDigitCount) {
        foreach (j; 0 .. precision - rightDigitCount) {
            rightDigitCount += 1;
            cleanNumber *= 10;
        }
    }

    // Digits go in the buffer from right to left.
    auto cleanNumberStr = signedToStr(cast(long) cleanNumber);
    auto i = result.length;
    // Check two cases: 0.NN, N.NN
    if (cast(long) value == 0) {
        if (value < 0.0) {
            cleanNumberStr = cleanNumberStr[1 .. $];
        }
        i -= cleanNumberStr.length;
        result.copyChars(cleanNumberStr, i);
        foreach (j; 0 .. rightDigitCount - cleanNumberStr.length) {
            i -= 1;
            result[i] = '0';
        }
        i -= 2;
        result.copyChars("0.", i);
        if (value < 0.0) {
            i -= 1;
            result[i] = '-';
        }
    } else {
        i -= rightDigitCount;
        result.copyChars(cleanNumberStr[$ - rightDigitCount .. $], i);
        i -= 1;
        result[i] = '.';
        i -= cleanNumberStr.length - rightDigitCount;
        result.copyChars(cleanNumberStr[0 .. $ - rightDigitCount], i);
    }
    // Remove extra zeros at the end if needed.
    if (precision < rightDigitCount) {
        result = result[0 .. cast(Sz) ($ - rightDigitCount + precision)];
    }
    return result[i .. $];
}

/// Converts the C string to a string.
@trusted
IStr cStrToStr(ICStr value) {
    return value[0 .. value.cStrLength];
}

/// Converts the enum value to its string representation.
IStr enumToStr(T)(T value) {
    switch (value) {
        static foreach (m; __traits(allMembers, T)) {
            mixin("case T.", m, ": return m;");
        }
        default: assert(0, "WTF!");
    }
}

/// Converts the string value to its enum representation.
// NOTE: This function is adapted from Joka and modified for Noby.
T toEnum(T)(IStr str) {
    switch (str) {
        static foreach (m; __traits(allMembers, T)) {
            mixin("case m: return T.", m, ";");
        }
        default: return T.init;
    }
}
