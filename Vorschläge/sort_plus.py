import sys

def count_plus(line):
    return len(line) - len(line.lstrip('+'))

def sort_file(input_path, output_path=None):
    with open(input_path, 'r', encoding='utf-8') as f:
        lines = [line.rstrip('\n') for line in f.readlines()]

    sorted_lines = sorted(lines, key=count_plus)

    result = '\n'.join(sorted_lines)

    out = output_path or input_path
    with open(out, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f"Fertig! {len(sorted_lines)} Zeilen sortiert -> {out}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python sort_plus.py <datei> [ausgabe_datei]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    sort_file(input_file, output_file)
