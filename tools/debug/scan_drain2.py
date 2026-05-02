import re, os

# Map: z??_snake -> Pascal variants to check
def snake_to_pascal_variants(snake):
    parts = snake.split('_')
    # Capitalize each part
    base = ''.join(p.capitalize() if not p.isdigit() else p for p in parts)
    yield base
    # Try with digit not separated: e.g. init_mode13_sub3 -> InitMode13Sub3 already covered
    # Try keeping underscores after digits: InitMode13_Sub3
    out = ''
    for idx, p in enumerate(parts):
        if idx > 0 and (p[0].isdigit() or parts[idx-1][-1].isdigit()):
            out += '_' + (p.capitalize() if not p.isdigit() else p)
        else:
            out += p.capitalize() if not p.isdigit() else p
    yield out

# For each gen fwd, check if corresponding ASM Pascal label is undrained
for gen_fn in sorted(os.listdir('src/gen')):
    if not gen_fn.startswith('z_') or not gen_fn.endswith('.c'): continue
    bank = gen_fn[2:4]
    with open('src/gen/' + gen_fn) as f:
        gen_content = f.read()
    with open('src/zelda_translated/z_' + bank + '.asm') as f:
        asm_content = f.read()

    wiring = []
    for m in re.finditer(r'\bz\d+_(\w+)\s*\(', gen_content):
        snake = m.group(1)
        for pascal in snake_to_pascal_variants(snake):
            mp = re.search(r'^' + re.escape(pascal) + r':\s*\n((?:\s*(?:;[^\n]*)?\n)*?)\s*([^\n;]+)', asm_content, re.M)
            if mp:
                first = mp.group(2).strip()
                if first.startswith('dc.'): break
                if first.startswith('jmp') and 'c_' in first: break  # drained
                # undrained!
                wiring.append((pascal, snake, first[:60]))
                break

    if wiring:
        seen = set()
        uniq = []
        for w in wiring:
            if w[0] not in seen:
                seen.add(w[0])
                uniq.append(w)
        print('=== z_' + bank + '.asm === wiring candidates: ' + str(len(uniq)))
        for p, s, f in uniq:
            print('  ' + p + ' (snake=' + s + ')  first: ' + f)
        print()
