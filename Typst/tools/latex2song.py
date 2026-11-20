"""
latex2song.py - übernimmt Songs aus einem LaTeX-Liederbuch (songs/*.tex,
chords.tex, griffe-zusatz.tex, main.tex) in dieses Typst-Projekt.
Einmaliges Umzugswerkzeug; der LaTeX-Ordner wird nur gelesen.

Aufruf (im Typst-Ordner):
    python tools/latex2song.py <latex-ordner> africa summer-of-69 ...
    python tools/latex2song.py <latex-ordner> --alle          alle Songs + Griffe
    python tools/latex2song.py <latex-ordner> --alle --buch   ... und main.typ
                                                             neu (überschreibt!)

Ergebnis: songs/<name>.txt, griffe.txt, griffe-zusatz.txt (, main.typ)

Format der Textdateien (siehe README.md):
    titel: ...            Kopf: ein Feld pro Zeile, Ende mit ---
    interpret: ...
    info: ...
    griff: Bb  x,x,.,.,.,.  3:3:3,4:3:4  [Bund]  [Barré]
    ---
    [G   Bm]              Akkorde
    {Chorus:}             Label (kursiv, grau)
    <(Zweitstimme)>       Zweitstimme / Zusatzinfo (kursiv, grau)
    @griffe{C, G}  @griffe[1]{C, G}
    @schlagmuster{datei}[Beschriftung]
    @illustration[Breite]{datei}{x}{y}[trim=l b r t]
    @anmerkung{Text}
    @seite                neue Seite
"""
import re
import sys
from pathlib import Path

ZIEL = Path(__file__).resolve().parents[1]   # dieses Typst-Projekt
DST = ZIEL / "songs"
LATEX = None  # LaTeX-Ordner (Argument)


def read_group(s, i, open_ch="{", close_ch="}"):
    """Liest eine Klammergruppe ab Position i (s[i] == open_ch). -> (inhalt, ende)"""
    assert s[i] == open_ch, (s[i:i + 30], open_ch)
    depth = 0
    j = i
    while j < len(s):
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j + 1
        j += 1
    raise ValueError("Klammer nicht geschlossen: " + s[i:i + 40])


def skip_ws(s, i):
    while i < len(s) and s[i] in " \t\r\n":
        i += 1
    return i


def read_args(s, i, spec):
    """spec z.B. 'omo' (o = optional [..], m = Pflicht {..})."""
    args = []
    for kind in spec:
        if kind == "m":
            j = skip_ws(s, i)
            a, i = read_group(s, j)
            args.append(a)
        else:
            if i < len(s) and s[i] == "[":
                a, i = read_group(s, i, "[", "]")
                args.append(a)
            else:
                args.append(None)
    return args, i


SIMPLE = {
    "#": "#", "%": "%", "&": "&", "|": "|", " ": " ", "_": "_",
}
WORDS = {"dots": "…", "textperiodcentered": "·", "newpage": "@seite"}


def plain(s):
    """LaTeX-Escapes in einem Textstück auflösen."""
    s = re.sub(r"\\([#%&|_ ])", r"\1", s)
    s = s.replace("\\dots", "…").replace("\\textperiodcentered", "·")
    s = s.replace("~", "\u00a0")
    return s


def griff_def(args):
    name, marks, dots, bund, barre = args
    fields = [plain(name).strip(), marks.replace(" ", ""), dots.replace(" ", "") or "-"]
    if bund is not None or barre is not None:
        fields.append(bund.strip() if bund else "-")
    if barre is not None:
        fields.append(barre.replace(" ", ""))
    return "  ".join(fields)


def convert_body(body, warn):
    out = []
    i = 0
    n = len(body)
    while i < n:
        c = body[i]
        if c == "\\":
            m = re.match(r"\\([a-zA-Z]+|.)", body[i:])
            cmd = m.group(1)
            i += len(m.group(0))
            if cmd == "cl":
                (a,), i = read_args(body, i, "m")
                out.append("[" + plain(a) + "]")
            elif cmd == "slbl":
                (a,), i = read_args(body, i, "m")
                out.append("{" + plain(a) + "}")
            elif cmd in ("voice", "info"):
                (a,), i = read_args(body, i, "m")
                out.append("<" + plain(a) + ">")
            elif cmd == "griffe":
                (k, a), i = read_args(body, i, "om")
                lst = ", ".join(x.strip() for x in plain(a).split(","))
                out.append("@griffe" + (f"[{k}]" if k else "") + "{" + lst + "}")
            elif cmd == "schlagmuster":
                (sc, f, cap), i = read_args(body, i, "omo")
                if sc:
                    warn(f"Schlagmuster-Skalierung [{sc}] ignoriert")
                out.append("@schlagmuster{" + f + "}" + (f"[{plain(cap)}]" if cap else ""))
            elif cmd == "illustration":
                (w, f, x, y, opt), i = read_args(body, i, "ommmo")
                s = "@illustration" + (f"[{w}]" if w else "") + "{" + f + "}{" + x.replace(" ", "") + "}{" + y.replace(" ", "") + "}"
                if opt:
                    s += "[" + opt.strip() + "]"
                out.append(s)
            elif cmd == "anmerkung":
                (a,), i = read_args(body, i, "m")
                a = " ".join(plain(a).split())
                # (eine Zeile, die nur aus @anmerkung besteht, lässt Typst
                # ganz weg - wie LaTeX, das das Zeilenende danach schluckt)
                out.append("@anmerkung{" + a + "}")
            elif cmd == "newpage":
                out.append("@seite")
            elif cmd in SIMPLE:
                out.append(SIMPLE[cmd])
            elif cmd in WORDS:
                out.append(WORDS[cmd])
            elif cmd in ("`", "'"):
                out.append(cmd)  # in alltt wörtlich
            elif cmd == "\\":
                out.append("")  # \\ in alltt: nichts zusätzlich
            else:
                warn(f"unbekannter Befehl \\{cmd}")
                out.append("\\" + cmd)
        elif c == "%":
            # Kommentar bis Zeilenende (inkl. Zeilenende, wie in LaTeX)
            j = body.find("\n", i)
            i = n if j < 0 else j + 1
        elif c in "[]{}<>@":
            if c in "{}":
                i += 1  # Gruppierungsklammern ohne Befehl
                continue
            out.append("\\" + c)
            i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def convert(name):
    src = LATEX / "songs" / f"{name}.tex"
    text = src.read_text(encoding="utf8")
    warnings = []
    warn = lambda w: warnings.append(w)

    start = text.find("\\begin{song}")
    if start < 0:
        print(f"  {name}: kein \\begin{{song}} gefunden - übersprungen")
        return
    pre = text[:start]
    (titel, interpret, info), i = read_args(text, start + len("\\begin{song}"), "mmm")
    end = text.rindex("\\end{song}")
    body = text[i:end]
    if body.startswith("\n"):
        body = body[1:]

    head = [f"titel: {plain(titel).strip()}", f"interpret: {plain(interpret).strip()}"]
    if info.strip():
        head.append(f"info: {plain(info).strip()}")
    for m in re.finditer(r"\\defgriff", pre):
        args, _ = read_args(pre, m.end(), "mmmoo")
        head.append("griff: " + griff_def(args))

    body = convert_body(body, warn).rstrip() + "\n"
    # Leerzeilen am Ende (in LaTeX meist nur Platzhalter) zusammenfassen
    body = re.sub(r"\n{3,}$", "\n", body)
    out = "\n".join(head) + "\n---\n" + body
    (DST / f"{name}.txt").write_text(out, encoding="utf8")
    for w in warnings:
        print(f"  {name}: {w}")


def convert_chords(src, dst):
    text = (LATEX / src).read_text(encoding="utf8")
    lines = [f"# aus {src} erzeugt (Name  Marken  Punkte  [Bund]  [Barré])",
             "# leer = leeres Griffbrett, / = neue Zeile in der Grifftabelle"]
    for raw in text.splitlines():
        s = raw.strip()
        if s.startswith("%"):
            lines.append("#" + s.lstrip("%"))
            continue
        for m in re.finditer(r"\\griff\b|\\leergriff|\\\\", s):
            if m.group(0) == "\\\\":
                lines.append("/")  # Zeilenende in der Grifftabelle
            elif m.group(0) == "\\leergriff":
                lines.append("leer")
            else:
                args, _ = read_args(s, m.end(), "mmmoo")
                lines.append(griff_def(args))
    (ZIEL / dst).write_text("\n".join(lines) + "\n", encoding="utf8")


def convert_book():
    """Kategorien + Songlisten aus main.tex -> main.typ"""
    text = (LATEX / "main.tex").read_text(encoding="utf8")
    text = "\n".join(l.split("%")[0] for l in text.splitlines())  # Kommentare weg
    out = [
        "// Liederbuch: Kategorien und Songs (Dateinamen aus songs/, ohne .txt),",
        "// je Kategorie ALPHABETISCH nach Titel (= Inhaltsverzeichnis).",
        "// Bauen: typst compile --font-path fonts main.typ",
        '#import "lib/buch.typ": liederbuch',
        "",
        "#liederbuch((",
    ]
    for m in re.finditer(r"\\category\{([^}]*)\}\s*\\songliste\{([^}]*)\}", text):
        ids = [s.strip() for s in m.group(2).split(",") if s.strip()]
        out.append(f'  (titel: "{m.group(1)}", songs: (')
        out += [f'    "{i}",' for i in ids]
        out.append("  )),")
    out.append("))")
    (ZIEL / "main.typ").write_text("\n".join(out) + "\n", encoding="utf8")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    LATEX = Path(sys.argv[1]).resolve()
    args = sys.argv[2:]
    buch = "--buch" in args
    names = [a for a in args if a != "--buch"]
    DST.mkdir(parents=True, exist_ok=True)
    if names == ["--alle"]:
        names = sorted(p.stem for p in (LATEX / "songs").glob("*.tex") if p.stat().st_size > 0)
    if buch:
        convert_book()
    for n in names:
        convert(n)
    convert_chords("chords.tex", "griffe.txt")
    convert_chords("griffe-zusatz.tex", "griffe-zusatz.txt")
    print(f"{len(names)} Songs umgewandelt.")
