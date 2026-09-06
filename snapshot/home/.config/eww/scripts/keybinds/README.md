# Catálogo de atalhos

Super + F1 abre/fecha o painel Eww `shortcuts`. A busca ignora maiúsculas,
e as ações completas e suas fontes aparecem ao passar o mouse sobre as linhas.
Os botões no topo filtram pelo nome do aplicativo; Todos limpa o filtro.

Arquivos:
- `../../shortcuts.yuck` e `../../shortcuts.scss`: interface e aparência.
- `../keybinds.py`: coleta, busca e abertura. Cache: `~/.cache/eww/keybinds.json`.
- `hypr.lua`: avalia o módulo de binds com dispatchers inertes; expande loops
  e submaps sem executar as ações vinculadas às teclas.
- `nvim.lua`: lê os mapas globais da configuração em uma instância headless,
  mapas Oil e o callback LspAttach do grupo Lsp desta configuração.
- `descriptions.json`: descrições amigáveis para os atalhos atuais do Hyprland.
  A ação original continua disponível na dica da linha.

Cobertura: configuração Lua do Hyprland; todas as tabelas do servidor Tmux
ativo (incluindo padrões, plugins, mouse e copy-mode); mapas globais Nvim
carregados na inicialização, Oil, LSP local e teclas explicitamente configuradas
no blink.cmp; keymap.toml do Yazi; bindkey explícitos do .zshrc.
Não é um inventário de todos os comandos nativos do Vim ou de todos os mapas
locais de buffers/plugins que só surgem durante edição. Ghostty e Zathura
não tinham atalhos personalizados nos arquivos inspecionados.

O Tmux precisa estar em execução para consultar seus mapas efetivos; se não
estiver acessível, o painel informa isso. Novos provedores/configurações com
outros formatos precisam ser adicionados ao coletor. Nenhuma ação exibida é
executada ao clicar na lista. Atualização automática a cada abertura.

Verificação manual: `../keybinds.py collect`; abrir/fechar duas vezes;
buscar um aplicativo; buscar um texto inexistente e conferir o estado vazio.
