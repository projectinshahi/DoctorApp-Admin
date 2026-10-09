#!/usr/bin/env python3
"""Make a six-option question CSV importable by a four-option backend.

A stopgap, not a fix: the server this panel talks to still answers
    "E" must be one of A, B, C, D
so a question whose answer is E is refused outright, and option_e is dropped
from every other row on the way in. Run this only while that is true - once
the backend takes A to F, upload the original file instead.

    python3 tools/four_option_fallback.py questions.csv

It writes questions.4opt.csv beside it and says what it changed:
  * answer E  -> option D and option E are swapped so the answer rides in D.
                 The option that was D moves to E, which this backend ignores,
                 so that question imports with one distractor missing.
  * no options -> the row is dropped; a question with nothing to choose from
                 cannot import, and the paper has to be fixed by hand.
"""
import csv
import sys
from pathlib import Path

LETTERS = 'abcdef'


def main(path: Path) -> int:
    rows = list(csv.DictReader(path.open(newline='', encoding='utf-8')))
    if not rows:
        print('No rows in that file.')
        return 1

    fields = list(rows[0].keys())
    swapped, dropped, kept = [], [], []

    for row in rows:
        order = (row.get('question_order') or '?').strip()
        filled = [c for c in LETTERS if (row.get(f'option_{c}') or '').strip()]

        if not filled:
            dropped.append(order)
            continue

        if (row.get('correct_option') or '').strip().upper() == 'E':
            if not (row.get('option_e') or '').strip():
                dropped.append(order)  # answer points at an option that is not there
                continue
            row['option_d'], row['option_e'] = row['option_e'], row['option_d']
            row['correct_option'] = 'D'
            swapped.append(order)

        kept.append(row)

    out = path.with_suffix('.4opt.csv')
    with out.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(kept)

    print(f'{out.name}: {len(kept)} rows')
    if swapped:
        print(f'  answer moved E -> D on {len(swapped)}: {", ".join(swapped)}')
        print('  each of those imports with one distractor short.')
    if dropped:
        print(f'  dropped {len(dropped)} with no usable options: {", ".join(dropped)}')
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(main(Path(sys.argv[1])))
