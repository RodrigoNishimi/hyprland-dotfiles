# Barra de status — "Hyprland Rice Kit"

Os arquivos que o eww lê (`bar.yuck`, `bar.scss`) e a geometria que o
Hyprland lê (`~/.config/hypr/conf/rice.lua`) são **gerados**. A fonte é
este diretório.

```
lua/
├── palette.lua   # GERADO por `theme set` (template eww-palette.lua.in)
├── tokens.lua    # os tokens do kit: paleta, geometria, tipografia, ícones
├── yuck.lua      # escritor de s-expressões
├── bar.lua       # a barra como árvore de widgets  -> bar.yuck
├── style.lua     # a folha de estilo               -> bar.scss
├── hypr.lua      # gaps/raio/blur/sombra           -> hypr/conf/rice.lua
└── build.lua     # ponto de entrada
```

Para mudar qualquer coisa, mexa em `tokens.lua` e rode:

```bash
lua ~/.config/eww/lua/build.lua && eww reload && hyprctl reload
```

`theme set` já faz isso sozinho (ver `reload_apps` em `~/.local/bin/theme`):
reescreve `palette.lua`, roda o build e recarrega o eww.

## O que não é gerado

`eww.yuck` e `eww.scss` continuam escritos à mão — são a barra de usuário
(`usrctl`), os painéis de wifi, menu e calendário, o player e as fontes de
dados que a barra consome. `eww.yuck` puxa a barra com `(include "bar.yuck")`
e `eww.scss` termina com `@import "bar";`.

## Duas armadilhas do GTK3

- **`eventbox` ignora `min-width`/`min-height`.** Ele não desenha por
  gadget, então só fundo e raio chegam nele. Toda ilha clicável é um
  eventbox de área de clique (`.tn-hit`) com uma `box` por dentro, que é
  quem recebe as classes de desenho.
- **`/* */` no SCSS gerado quebra o eww.** O comentário sobrevive à
  compilação e, com acento, faz o grass prefixar `@charset "UTF-8"` — que
  o eww recusa. Por isso `style.lua` só emite comentários `//`.

E uma do compositor: não existe `backdrop-filter` no GTK. O vidro fosco do
kit é `blur` + `ignore_alpha` numa `layer_rule` do Hyprland, em
`conf/appearance.lua`.
