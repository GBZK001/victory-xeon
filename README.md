# VIctory Xeon — fork para PCs com Xeon antigo e placa NVIDIA sem ReBAR

Fork do **[P1nkman](https://codeberg.org/p1nkman/p1nkman-VI)**, que por sua vez é uma build de integração do
**[VIctory](https://github.com/Marvisak/VIctory)**: a camada de compatibilidade que roda no Windows um jogo de
**Xbox Series** a partir dos **arquivos que você mesmo tem**.

Este repositório **não é o P1nkman oficial**. É uma variante ajustada para um PC específico e parecido com
muitos outros: **CPU de servidor antiga e muitos núcleos lentos, PCIe 3.0 e sem Resizable BAR**.

> **Não há arquivos, código ou recursos de nenhum jogo aqui.** É preciso ter a sua própria cópia. Nada aqui tem
> ligação com o desenvolvedor ou a editora do jogo, nem é aprovado por eles.

## O PC de referência

| Peça | Modelo |
|---|---|
| CPU | Xeon E5-2670 v3 (12 núcleos / 24 threads Haswell, ~2,6 GHz), placa X99 |
| RAM | 32 GB DDR4-2133, 4 canais |
| GPU | RTX 5060 Ti 16 GB em **PCIe 3.0 x8**, **sem ReBAR** |
| Sistema | Windows 10 22H2 + **Agility SDK 1.620** do D3D12 |

Neste PC o limite é a **CPU**, e não a placa. As mudanças abaixo atacam isso.

## O que este fork muda em relação ao P1nkman

**Rodar no Windows 10:**
- **Agility SDK do D3D12**, para ter o Shader Model 6.6 no Windows 10. Basta apontar `VICTORY_D3D12_DIR` para a
  pasta com o `D3D12Core.dll`.

**Usar os núcleos e a placa:**
- `VICTORY_WIDE_THREADS` e `VICTORY_PIPELINE_THREADS`: escolhem quantas threads fazem as cópias e comparações de
  memória e montam os pipelines. O padrão do upstream limitava a 6 e 8, o que deixa parada a maior parte de um
  Xeon. Aqui usamos 12.
- **Pré-tradução com `--jobs`:** `victory translate --warm all --jobs 20` traduz todos os shaders em ~4 min, contra
  ~8,5 min com o padrão de 4 threads.
- **Hash rápido** nas tabelas que cada desenho consulta, no lugar do SipHash.
- Com o **Modo de desenvolvedor** do Windows ligado, `VICTORY_D3D12_BACKGROUND=0` impede o driver de recompilar
  shaders em segundo plano, o que ocupava ~3 núcleos.

**Imagem:**
- `VICTORY_WAVE_PAIRS_OFF=<hashes>`: tira programas específicos da forma de tradução "em pares" (wave64 em placas
  de 32 lanes). Assim, a iluminação de partículas deixou de sair preta (chuva) sem estragar as sombras.
- `VICTORY_DENY_SHADERS=<hashes>`: deixa de fora pipelines de programas listados. Usado para dois programas de água
  que deixam blocos escuros e para os 30 passes de skinning do ray tracing, que ninguém lê sem ray tracing.

**Diagnóstico:**
- `VICTORY_DENY_FILE=<arquivo>`: bloqueia programas **com o jogo rodando**, relendo o arquivo a cada 0,5 s.
  Aceita hashes ou `parte N/M`, que pega uma fração de todos os pipelines e serve para dividir a busca ao meio.
  Foi assim que achamos o que escurecia a água e a chuva.
- `VICTORY_VIRTUAL_PAD=<arquivo>`: um controle virtual por texto, somado ao controle real
  (ex.: `A RT=1 LX=-0.5`). Serve para pular cenas e pilotar em testes sem foco na janela.

## Como usar

1. Instale o Rust (veja `rust-toolchain.toml`) e compile:
   ```
   cargo build --release -p victory
   ```
2. Copie o **Agility SDK** (`D3D12Core.dll` e `d3d12SDKLayers.dll`, versão 1.620) para uma pasta `D3D12` ao lado
   do repositório.
3. Abra `scripts\jogar-xeon.cmd`, troque a linha `JOGO=` pela pasta da sua cópia e rode `jogar-xeon.cmd traduzir`
   uma vez, para traduzir os shaders antes de jogar.
4. Rode `scripts\jogar-xeon.cmd`.

A **primeira** abertura depois de uma build nova ou de um driver novo monta milhares de pipelines e fica lenta e
escura por alguns minutos. Isso acontece uma vez só.

## Estado (27/11/2026, no PC de referência)

- **Desempenho:** 5–7 fps no mar e 4–5 fps em terra.
- **Funcionando:** boca e expressões, chuva sem pingos pretos, mar sem os retângulos escuros.
- **Ainda com defeito:**
  - água rasa escura;
  - objetos que perdem a textura por um quadro;
  - quedas raras com "device removed".

## Créditos e licença

O código é do **[VIctory](https://github.com/Marvisak/VIctory)** e dos forks integrados pelo **P1nkman**. Os
créditos completos estão no repositório do P1nkman. A ideia de deixar de fora o skinning do ray tracing e a chave
`VICTORY_D3D12_BACKGROUND` vêm do fork **edsuuu/VI-BR-PORT**.

Licença **GPL-3.0-or-later**, a mesma do VIctory. Veja `LICENSE`.
