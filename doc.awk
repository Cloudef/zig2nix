/#!/ {
    gsub(/^[ \t]+/, "", $0)
    print($0);
    P = 1;
    next;
}

P == 1 {
    gsub(/^[ \t]+/, "", $0)
    print($0);
    if (length($0) > 0) {
        print("");
    }
    P = 0;
}

/#:/ {
    PP = 1;
}

PP == 1 && /^[ \t]*}.*[:;]/ {
    gsub(/^[ \t]+/, "", $0);
    if (substr($0, 0, 2) == "}:") {
        print("}: {};\n");
    } else {
        print("};\n");
    }
    PP = 0
    INDENT -= (INDENT > 0);
}

PP == 1 {
    gsub(/^[ \t]+/, "", $0);
    if (INDENT) {
        print(" ", $0);
    } else {
        print($0);
    }
}

PP == 1 && /{/ { INDENT += 1; }
INDENT > 0 && /}/ { INDENT -= 1; }
