# Checklist: P1nkman em NVIDIA (wave32), com foco em 8 GB de VRAM e 16 GB de RAM

Feita a partir dos nossos testes, numa RTX intermediária de 16 GB, e do que os principais forks mediram em 25/11/2026. Exemplo de alvo: Ryzen 5 5600, 16 GB de RAM, RTX 5050 de 8 GB.

## 1. Para rodar (usuário)

- [ ] **Use a versão atual deste repositório.** A base dele (soldsawn) traduz os shaders de "waves de 64" do console para a NVIDIA, que só tem waves de 32. Sem isso, a NVIDIA recusa shaders de água e de efeitos (no nosso teste, um fork só de AMD recusou 9 de 9).
- [ ] **Rode o `iniciar-p1nkman.cmd 8gb`**: turbo + perfil Series S + texturas reduzidas + reserva menor de memória da placa.
  - O perfil Series S dá ao jogo menos memória (o console Series S tem menos que o Series X) e uma resolução interna menor. Com o perfil Series X, o processo chegou a ~15 GB de RAM no nosso teste, o que estoura um PC de 16 GB.
- [ ] **Arquivo de paginação** gerenciado pelo Windows (ou 32 GB fixos) **num SSD**. Feche navegador, Discord etc. antes de jogar.
- [ ] **Driver NVIDIA atual** e "Agendamento de GPU acelerado por hardware" (HAGS) ligado (o soldsawn testou assim).
- [ ] **Rode `iniciar-p1nkman.cmd traduzir` uma vez** antes de jogar. Na primeira entrada na partida, espere sem fechar: as pipelines da placa são montadas uma vez e ficam salvas.
- [ ] **Não use `VICTORY_RESOLUTION`.** O remendo de resolução deixou a imagem num canto e travou a partida numa RTX. Para resolução menor, use o perfil Series S (já incluído no modo `8gb`).
- [ ] Referência de outros testes em 8 GB: o soldsawn mediu **8–10 FPS a 1080p numa RTX 4060 Laptop de 8 GB**. Uma RTX 2060 Super ficou em ~3 FPS (wardevsa).

## 2. Shaders e wave32 (quem quer desenvolver)

- [ ] **Nenhum shader recusado.** Teste offline, sem abrir o jogo:
  `set VICTORY_HOST_MAX_WAVE=32` e `victory.exe translate <shaders.rpf> --validate --pipelines --list`. A meta é 0 pipelines recusadas. `VICTORY_WAVE_WHY=1` diz por que um programa ainda pede wave64.
- [ ] **Tradutor em pares para wave64** (PR #854 do fxceless, de PiloteCode): já está nesta base. É a peça que resolve a NVIDIA.
- [ ] **Boca parada nas falas:** a animação do rosto é uma rede neural na GPU (`compute_graph_ops:*`) que move dados em 16 bits. O tradutor os lia como float por uma view de inteiros, e a NVIDIA devolvia 0. A correção é o PR #927 do fxceless (tippythetaidum), ainda não incorporado aqui. É o próximo passo.
- [ ] **Sombras por ray tracing** (`shadowmask:CS_TraceShadowRays_*`, 5 programas): falham com "a descriptor read only as data". O Neptune (skornuta/victory-fork) tem `emit/descriptor_data.rs` para isso.
- [ ] **Construtor de ray tracing**: 5 dos 53 programas dele ainda não têm pipeline na NVIDIA, e por isso ele fica desligado.
- [ ] **Mesh shaders com saída acima de 32 KiB** (71 falham no validador): o PR #854 trata parte disso, ligando a saída deles ao pixel shader.
- [ ] **Teto de 1.000.000 de descritores da NVIDIA**: o jogo pede ~1,24 milhão. O excedente lê vazio e as vagas extras podem se esgotar (com o relay e os envios adiantados, mais ainda).

## 3. Vulkan

- O VIctory e todos os forks usam **Direct3D 12**; não existe caminho Vulkan no Windows.
- No **Linux**, roda por Proton/vkd3d-proton, que traduz D3D12 para Vulkan (veja Marvisak/VIctory #1528). Lá, wave32 e mesh shaders dependem do driver Vulkan da NVIDIA e do vkd3d.

## 4. Onde está o FPS (vale para qualquer placa)

O quadro é limitado pela **CPU**, não pela placa: no nosso teste, o preparo dos envios gastava ~60–90 ms, com a placa ociosa boa parte do tempo. Os maiores ganhos medidos pela comunidade:

- [ ] **Registros de descritores deixados para os próprios draws** (avatarmanz): 280 → 124 ms na máquina dele.
- [ ] **Preparo numa thread própria, com refreshes e registros espalhados** (avatarmanz): 103 → 75 ms.
- [ ] **Chamadas de lista traduzidas por 8 threads** (`VICTORY_THIN`, avatarmanz): 75 → 68 ms. Num Ryzen 5600 (6 núcleos), ajustar o número de threads.
- [ ] **Copiar de volta só o que o jogo lê**: o fxceless mediu que 99,8% do que é copiado de volta ninguém lê. Ninguém implementou ainda.

## 5. Como medir

- [ ] Painel do P1nkman (canto da tela): FPS, ms por quadro, espera da GPU, preparo na CPU, cópia de volta, descartados e RAM.
- [ ] No log, a linha `… fps, … ms/frame (… preparing … on the GPU … copying back …)` aparece a cada ~5 s. Compare a **mediana na mesma cena**, depois do aquecimento.
- [ ] "Descartados" inclui as etapas do construtor de ray tracing desligado; não é tudo imagem faltando.
