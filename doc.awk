IN_SCRIPT == 0 && /#!/ {
    PRINT = 1;
    if (SCOLON > 0) {
        print("");
        SCOLON = 0;
        INDENT = 0;
    }
}

IN_SCRIPT == 0 && /#:!/ {
    PRINT = 1;
    COLON = 1;
}

IN_SCRIPT == 0 && COLON == 1 && /}:/ {
    PRINT = 0;
    COLON = 0;
    SCOLON = 0;
    INDENT = 0;
    print("}: { ... };\n");
}

{ COMMENT = 0 };

/#/ { COMMENT = 1 };

PRINT == 1 && COMMENT == 0 && IN_SCRIPT == 0 && /(=|with|inherit)/ { SCOLON += 1; }

INDENT > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /}[);: ]+/ && ! /[ ]+{/ { INDENT -= 1; }
INDENT > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /^[ ]*in[ ]+/ { INDENT -= 1; }
SCOLON > 0 && COMMENT == 0 && IN_SCRIPT == 1 && /'';/ { INDENT -= 1; IN_SCRIPT = 0; }

PRINT == 1 {
    gsub(/^[ \t]+/, "", $0);
    for (i = 0; i < INDENT; i++) printf(" ");
    print($0);
}

SCOLON > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /[ ]+{/ && ! /}[);: ]+/ { INDENT += 1; }A
SCOLON > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /[ ]+let/ { INDENT += 1; }
SCOLON > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /''$/ { INDENT += 1; IN_SCRIPT = 1; }

SCOLON > 0 && COMMENT == 0 && IN_SCRIPT == 0 && /;/ {
    SCOLON -= 1;
    if (SCOLON == 0) {
        PRINT = 0;
        INDENT = 0;
        print("");
    }
}

PRINT == 1 && SCOLON == 0 && IN_SCRIPT == 0 && /^\s*$/ {
    PRINT = 0;
}
