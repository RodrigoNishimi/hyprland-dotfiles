# Hyprland de Rodrigo Nishimi — Arch Linux

Inclui Hyprland em Lua, Eww (barra, painéis, OSD, notificações, mídia e catálogo de atalhos), Hyprlock/Hypridle/Hyprpaper/Hyprsunset, Mako, Rofi, temas, wallpapers, fontes locais, Ghostty/Alacritty, Zsh, tmux, Neovim, Yazi e configurações de aparência. Quickshell e Waybar são preservados como alternativas; a sessão inicia Eww. O tema capturado é Tokyo Night, teclado brasileiro.

## Instalar

Em uma instalação Arch com usuário normal, acesso a sudo, Git, Python 3 e um helper AUR (`paru` ou `yay`):

```bash
git clone https://github.com/RodrigoNishimi/hyprland-dotfiles.git
cd hyprland-dotfiles
./install.sh --dry-run
./install.sh
```

O instalador usa o helper para instalar `packages.txt`, habilita NetworkManager, Bluetooth, power-profiles-daemon e RTKit, aplica os arquivos, prepara TPM e recompila a barra/fontes. A lista inclui pacotes AUR: a compilação pode pedir interação. Drivers de GPU e a instalação básica do Arch ficam por conta da máquina de destino. As versões observadas constam em `snapshot/versions.txt`; não são travadas nem instaladas em massa.

**O instalador sobrescreve arquivos gerenciados sem fazer backup.** Arquivos extras são preservados. Links de configuração são substituídos por cópias sem escrever no destino antigo. Não há alteração automática do shell de login, recarga da sessão ou reinicialização. Depois, entre em uma sessão Hyprland com UWSM. Zinit e plugins do Neovim podem ser baixados na primeira abertura.

```bash
# Apenas aplicar os arquivos, sem instalar pacotes ou habilitar serviços:
./install.sh --skip-packages

# Reproduzir também os monitores e variáveis NVIDIA da máquina original:
./install.sh --monitors original --gpu original
```

Por padrão, usa modo preferido dos monitores, posicionamento automático e escala 1; remove as variáveis que forçavam NVIDIA para permitir a seleção normal do driver. Para HiDPI, ajuste `~/.config/hypr/conf/monitors.lua`. O snapshot original permanece preservado. Requer Hyprland compatível com a API Lua usada na versão 0.56.2 desta máquina; configurações antigas em hyprlang não são equivalentes.

## Backup e atualização

```bash
# Backup manual das configurações atuais (ignorado pelo Git):
./backup.sh

# Atualizar o snapshot versionado com suas alterações atuais:
./backup.sh --update
git diff --stat
git diff
git add snapshot
git commit -m "Atualiza customizações do desktop"
git push
```

`--update` sincroniza também remoções no snapshot e mantém a captura intermediária em `.capture-*`. Nenhum comando de backup faz commit ou push automaticamente. Para aplicar um backup manual:

```bash
python3 manage.py install --source backups/AAAAMMDD-HHMMSS --monitors original --gpu original
lua ~/.config/eww/lua/build.lua
fc-cache -f ~/.local/share/fonts
```

O backup cobre somente as configurações e recursos selecionados em `manage.py`; não é uma imagem do sistema. Não inclui SSH/GPG, credenciais do GitHub, perfis de navegador, históricos, caches, configurações das ferramentas de IA ou conexões Wi-Fi salvas. Inclui o avatar e imagens da interface. Os inventários `explicit.txt` e `foreign.txt` são referências, não listas para reinstalação automática.

## Organização e manutenção

- `snapshot/home/`: arquivos capturados; `@@HOME@@` e `@@ASSETS@@` são resolvidos ao instalar.
- `snapshot/manifest.json`: raízes gerenciadas.
- `snapshot/home/.local/share/hyprland-dotfiles/`: temas, templates e wallpapers; helpers `theme` e `rofi-script` foram adaptados para esse destino.
- `manage.py`: captura e aplicação portáveis usando apenas a biblioteca padrão Python.
- `install.sh`: dependências e preparação da sessão Arch.
- `backup.sh`: captura manual e atualização do snapshot.

Edite as fontes Lua do Eww e execute `lua ~/.config/eww/lua/build.lua` para gerar a barra. Use `./backup.sh --update` após customizar o desktop. O antigo gerenciador Stow `dots` não é instalado: este repositório usa cópias gerenciadas pelo novo instalador.

```bash
python3 -m unittest discover -s tests -v
python3 audit.py
bash -n install.sh backup.sh
```

Os testes incluem aplicação em HOME temporário, repetição, preservação de arquivos extras e alvos de symlinks, captura sem backups antigos, geração Eww, `Hyprland --verify-config` e a primeira inicialização do Neovim. O teste completo requer Lua, Hyprland, Neovim e ferramentas de compilação; não inicia uma sessão Hyprland nova. A instalação dos pacotes não foi executada novamente na máquina de origem.

`audit.py` compara conteúdo e permissões dos arquivos gerenciados com uma captura atual, normalizando os caminhos e adaptações dos helpers. Na revisão de 06/09/2026 foram conferidos 320 arquivos em 51 raízes. A revisão incluiu plugins locais do Neovim (`~/plugins`), preferências nwg-look, associações MIME, o lançador de URI e o ignore global do Git. As referências antigas do Telescope e tmux-sessionizer foram atualizadas; o gerenciador antigo `dots` foi aposentado. Credenciais, perfis de navegador e histórico de versões antigas não fazem parte dessa contagem.
