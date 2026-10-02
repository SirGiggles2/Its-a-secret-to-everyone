import sys
NL = chr(10)
old = open('build/scratch/render_adapter.c.old', encoding='utf-8').read().replace(chr(13) + NL, NL)
new = open('build/scratch/render_adapter.c.new', encoding='utf-8').read().replace(chr(13) + NL, NL)


def func(src, name):
    i = src.index(NL + 'void ' + name + '(') + 1
    j = src.index(NL + '}' + NL, i) + 3
    return src[i:j]


pa = new.index('static void cram_write_probe(void)')
pb = new.index(NL + '}' + NL, pa) + 3
i = new.index('static unsigned short s_cram_dma[64];')
j = new.index('void render_cram_defer(')
core = new[pa:pb] + new[i:j]
v = old.replace('void render_cram_set_grayscale(', core + 'void render_cram_set_grayscale(', 1)
for f in sys.argv[1:]:
    v = v.replace(func(old, f), func(new, f))
v += NL + 'void render_cram_defer(unsigned char on) { s_cram_defer = on; }' + NL
open('src/sgdk_adapter/render_adapter.c', 'w', encoding='utf-8', newline=NL).write(v)
print('variant', sys.argv[1:])
