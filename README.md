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

Para instalar também os aplicativos e utilitários opcionais de `packages-extra.txt`, use `./install.sh --extra`. Essa opção instala as duas listas sem duplicatas e continua aplicando o desktop. Serviços extras, como Docker e PostgreSQL, precisam ser configurados separadamente. `./install.sh --extra --dry-run` permite conferir a aplicação sem alterações; `--skip-packages` pula ambas as listas.

**O instalador sobrescreve arquivos gerenciados sem fazer backup.** Arquivos extras são preservados. Links de configuração são substituídos por cópias sem escrever no destino antigo. Não há alteração automática do shell de login, recarga da sessão ou reinicialização. Depois, entre em uma sessão Hyprland com UWSM. Zinit e plugins do Neovim podem ser baixados na primeira abertura.

Antes de instalar pacotes ou habilitar serviços, o script verifica o snapshot e os conflitos de tipo entre arquivos e diretórios no destino. `--dry-run` faz essa mesma preparação em um diretório temporário, sem alterar o HOME de destino. Essa checagem não é uma transação: falhas de disco ou permissões durante a aplicação ainda podem interromper a cópia. Execute `./backup.sh` antes se precisar preservar as configurações gerenciadas atuais.

```bash
# Apenas aplicar os arquivos, sem instalar pacotes ou habilitar serviços:
./install.sh --skip-packages

# Reproduzir também os monitores e variáveis NVIDIA da máquina original:
./install.sh --monitors original --gpu original
```

Por padrão, usa modo preferido dos monitores, posicionamento automático e escala 1; remove as variáveis que forçavam NVIDIA para permitir a seleção normal do driver. Para HiDPI, ajuste `~/.config/hypr/conf/monitors.lua`. O snapshot original permanece preservado. Requer Hyprland compatível com a API Lua usada na versão 0.56.2 desta máquina; configurações antigas em hyprlang não são equivalentes.

## OCR, monitores e janelas instantâneas

| Atalho | Ação |
| --- | --- |
| `Super+Shift+O` | Selecionar uma região e copiar seu texto (português e inglês) |
| `Super+Ctrl+M` | Escolher um perfil de monitores ou salvar a disposição atual |
| `Super+Ctrl+Enter` | Mostrar/ocultar terminal com sessão tmux independente |
| `Super+Ctrl+N` | Mostrar/ocultar notas rápidas no Neovim |
| `Super+Ctrl+E` | Mostrar/ocultar arquivos no Yazi |

OCR também está em Rofi → Trigger; monitores em Rofi → Setup. Cancelar a seleção ou não reconhecer texto preserva o clipboard. A imagem temporária é apagada após o reconhecimento local. O instalador inclui `tesseract`, `tesseract-data-por` e `tesseract-data-eng`; modelos locais em `~/.local/share/tessdata/` também são aceitos quando esses idiomas não estão instalados no sistema.

Perfis: **Notebook** mantém uma tela ativa (prefere a interna); **Mesa** estende as telas; **Apresentação** espelha as externas na principal; **Automático** restaura uma disposição salva ou usa modos preferidos e escala 1. **Salvar disposição atual** memoriza resolução, frequência, escala, posição, rotação e telas desativadas. Preferências ficam em `~/.config/hypr/monitor-profiles.json`, por combinação de conectores e identificação das telas, e são reaplicadas ao entrar, recarregar a configuração ou conectar/desconectar monitores. As regras desses perfis têm precedência sobre `conf/monitors.lua`, inclusive ao instalar com `--monitors original`. Ao desativar ou remover uma tela, o Hyprland transfere seus workspaces para uma tela ativa.

As janelas instantâneas permanecem abertas quando ocultadas; fechar o aplicativo permite recriá-lo no próximo atalho. O workspace especial `magic` continua disponível. As notas ficam em `~/.local/share/quick-notes/notes.md` e devem ser salvas normalmente no editor. O conteúdo das notas não é incluído no backup das configurações; ocultar uma janela também não garante recuperação de conteúdo não salvo após logout ou reinicialização.

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
- `packages.txt` e `packages-extra.txt`: dependências do desktop e pacotes opcionais, respectivamente.
- `backup.sh`: captura manual e atualização do snapshot.

Edite as fontes Lua do Eww e execute `lua ~/.config/eww/lua/build.lua` para gerar a barra. Use `./backup.sh --update` após customizar o desktop. O antigo gerenciador Stow `dots` não é instalado: este repositório usa cópias gerenciadas pelo novo instalador.

```bash
python3 -m unittest discover -s tests -v
bash tests/install-wrapper.sh
bash tests/nvim-fzf-bootstrap.sh
python3 audit.py
bash -n install.sh backup.sh
```

Os testes incluem aplicação em HOME temporário, repetição, preservação de arquivos extras e alvos de symlinks, captura sem backups antigos, geração Eww, `Hyprland --verify-config` e a primeira inicialização do Neovim. O teste completo requer Lua, Hyprland, Neovim e ferramentas de compilação; não inicia uma sessão Hyprland nova. A instalação dos pacotes não foi executada novamente na máquina de origem.

A suíte também verifica se o snapshot pode ser instalado apenas com os arquivos visíveis ao Git, conflitos antes da sobrescrita, validação antes da instalação de pacotes, inventário vazio de pacotes externos, caminhos duplicados no manifesto e preservação dos finais de linha. O helper `ready-tmux` tem uma exceção no `.gitignore` do projeto para não ser omitido por regras globais. Ao adicionar novos arquivos, inclua-os no commit junto com o manifesto.

`audit.py` compara conteúdo e permissões dos arquivos gerenciados com uma captura atual, normalizando os caminhos e adaptações dos helpers. Na revisão de 06/09/2026 foram conferidos 320 arquivos em 51 raízes. A revisão incluiu plugins locais do Neovim (`~/plugins`), preferências nwg-look, associações MIME, o lançador de URI e o ignore global do Git. As referências antigas do Telescope e tmux-sessionizer foram atualizadas; o gerenciador antigo `dots` foi aposentado. Credenciais, perfis de navegador e histórico de versões antigas não fazem parte dessa contagem.
