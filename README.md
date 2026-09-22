# Downtown Hustle

Protótipo de jogo para Roblox, feito em Luau, com cidade, empregos, veículos, dinheiro e reputação.

## O que já vem pronto

- cidade com avenidas, bairros nos morros, ladeiras, escadas, feira e mirante; a expansão brasileira acrescenta 71 casas e comércios com fachadas, placas e vegetação
- sistema de dinheiro, energia e reputação
- sete objetivos de primeiros passos com progresso, indicação de destino e bônus recebidos uma única vez
- quatro trabalhos com turnos de 18 a 30 segundos, barra de progresso, cancelamento e pagamento ao concluir
- mercadinho com lanches de $60: guarde até cinco e recupere até 25 de energia por consumo
- três rotas alternadas: clube ($650 / 180 s), hospital ($700 / 150 s) e banco ($800 / 150 s)
- carreira de entregador: bônus de $50 por rota a partir de 5 entregas e de $100 a partir de 15
- indicador pessoal com direção e distância até o objetivo, contador de entregas e opção de cancelar
- banco com depósito e saque de até $250 por interação
- apartamento de $850 com renda de $75 a cada minuto desde a compra
- apartamento mobiliado acessível pelo prédio: cama que recupera energia, cozinha, sala e porta de saída
- biblioteca de sete modelos estilizados: Quadrado 88, Mille Urbano, Besouro 72, Kombosa da Feira, Diplomata 79, Sertaneja CS e Circular da Serra; dez veículos gratuitos distribuídos entre o centro e a garagem
- veículos com interação para dirigir, rodas e faróis; carros tombados retornam à vaga após cinco segundos sem motorista
- HUD com carteira, banco, energia e abas Atividade, Objetivos e Cidade; cinco destinos para explorar com direção e distância
- painel recolhível e ajuda pelo botão da interface ou pela tecla `H`
- painel e indicador que reservam espaço para os controles de toque, com rotação automática entre retrato e paisagem
- salvamento de carteira, banco, reputação, imóvel, lanches, turnos, entregas e recompensas de objetivos recebidas; status de salvamento no painel
- atendentes decorativos na central, garagem, clube e mercadinho; pacote visível nas costas durante o transporte

## Como testar no Roblox Studio

1. No Roblox Studio, use **File → Open from File** e abra `build/DowntownHustle.rbxlx`.
2. Pressione **Play**. A cidade é criada pelo servidor quando a simulação começa.
3. Vá até os marcadores verdes e segure `E`, ou use o botão de proximidade no celular. Inicie um turno e permaneça a até 18 studs do ponto, em pé, até a barra completar. A energia é gasta no início; afastar-se, sentar, morrer ou cancelar encerra o turno sem pagamento nem reembolso de energia.
4. Aguarde o carregamento do progresso e siga o indicador amarelo até a central. Confira a oferta no painel, retire o pacote na garagem e entregue no destino indicado antes do prazo. Cada sucesso dá a recompensa da rota e 15 de reputação; só concluir a entrega avança para a próxima oferta.
5. Teste depósito e saque no banco e compre o apartamento no ponto laranja. Depois da compra, use **Entrar** no mesmo ponto. Dentro de casa, segure a interação da cama por dois segundos para recuperar toda a energia e use a porta para voltar à cidade.
6. Use a interação **Dirigir** perto de um carro; no computador, use WASD e espaço para sair.
7. Use **Cancelar** no painel da missão para abandoná-la. O fim do prazo ou a morte também encerram a entrega, sem pagamento. A energia já gasta não é devolvida.
8. No mercadinho rosa ao lado do residencial, compre lanches por $60. Use **Comer (+25)** no painel ou a tecla `B` para consumir. Com energia cheia, o lanche permanece na mochila.
9. Abra a aba **Objetivos** para acompanhar os primeiros passos. Use **Marcar destino** para localizar o próximo ponto e **Receber** quando o requisito estiver cumprido. Ao iniciar um trabalho ou aceitar uma entrega, o painel abre **Atividade** para mostrar prazo, progresso e cancelamento. Você pode voltar aos objetivos durante a atividade. No celular, gire o aparelho e arraste os detalhes para rolar; o painel deixa os controles de movimento livres.
10. Na aba **Cidade**, marque Garagem Brasileira, Bela Vista, Vila dos Ipês, Feira da Estação ou Mirante da Serra. O indicador orienta o passeio; trabalhos e entregas têm prioridade e o passeio retoma ao terminar. **Limpar destino** volta à central quando não há atividade. Marcar um objetivo substitui o destino do passeio.

Para conferir a expansão, execute `tests/studio_city_check.lua` na barra de comandos em **Play → servidor**. Para conferir as três abas, rolagem e espaço dos controles de toque, execute `tests/studio_hud_check.lua` em **Play → cliente**, repetindo em retrato e paisagem. Os scripts apenas consultam o cenário e a interface. Veja [tests/STUDIO.md](tests/STUDIO.md) para instruções e cobertura.

### Primeiros passos

| Objetivo | Requisito | Bônus |
| --- | --- | --- |
| Primeiro trabalho | Concluir um turno | $100 |
| Lanche na mochila | Comprar um lanche | $75 |
| Primeira entrega | Concluir uma entrega | $150 |
| Sua reserva | Ter $500 no banco ao receber o bônus | $125 |
| Seu apartamento | Comprar o apartamento | $200 |
| Rotina de trabalho | Concluir cinco turnos | $250 |
| Entregador da cidade | Concluir três entregas | $300 |

Os objetivos são recebidos em sequência e não expiram, com $1.200 em bônus no total. O progresso anterior conta, e lanches comprados continuam contando depois de consumidos. Os lanches guardados em perfis antigos entram no histórico de compras ao carregar, inclusive se forem consumidos antes do segundo objetivo. Cada bônus soma dinheiro à carteira sem gastar o saldo do banco. Receber o bônus avança para o próximo objetivo; reconectar não libera novamente recompensas já recebidas.

Marcar um objetivo serve como orientação. Trabalhos e entregas em andamento têm prioridade no indicador, e dentro de casa a indicação fica oculta. Os objetivos não impedem explorar ou escolher outra atividade.

### Turnos de trabalho

| Local | Duração | Energia inicial | Pagamento base |
| --- | --- | --- | --- |
| Restaurante | 18 s | 15 | $180 |
| Central de táxis | 20 s | 20 | $230 |
| Centro de encomendas | 25 s | 25 | $300 |
| Negócio da rua | 30 s | 32 | $420 |

Cada turno concluído concede oito de reputação e um ponto no contador de turnos. O pagamento inclui um bônus igual à reputação no início dividida por dez, arredondada para baixo. O negócio da rua também aumenta o nível de procurado em três, até o máximo de cinco. Há cinco segundos de intervalo após concluir ou cancelar. Durante um turno, é preciso terminar ou cancelar antes de aceitar uma entrega ou entrar em casa; trabalhos e entregas são atividades exclusivas.

Para compilar todos os scripts, executar os testes e atualizar o arquivo, execute no PowerShell, na pasta do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

O plugin Rojo 7.7.0 foi instalado no Studio desta máquina. Para reinstalá-lo, execute `.\.tools\rojo\rojo.exe plugin install`. Abra `build/DowntownHustle.rbxlx` no Studio e inicie o servidor local em um terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\serve.ps1
```

No Studio, abra **Plugins → Rojo 7.7.0 → Rojo** e conecte a `localhost:34872`. O painel deve mostrar **DowntownHustle** e o botão **Disconnect**. Enquanto o servidor estiver ativo, alterações em `src` chegam ao editor. Se a porta já estiver em uso pelo servidor deste projeto, mantenha essa instância; não é preciso iniciar outra. A configuração segue o [formato oficial do Rojo](https://rojo.space/docs/v7/project-format/).

Ao alterar a estrutura ou as propriedades em `default.project.json`, reinicie o servidor local e reconecte o plugin para aplicar a nova configuração. Esse procedimento foi necessário nesta máquina ao adicionar a orientação automática em `StarterGui`.

As ferramentas locais em `.tools` foram obtidas das releases oficiais de [Rojo 7.7.0](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0) e [Luau 0.737](https://github.com/luau-lang/luau/releases/tag/0.737). Elas e o arquivo gerado não entram no controle de versão.

## Validação e limites desta versão

- O comando de build requer Python e as ferramentas locais acima; ele compila todos os scripts Luau antes de gerar o arquivo.
- As sete suítes usam `tests/luau_runner.py` para criar arquivos temporários em `build/tests` e removê-los ao terminar. Isso evita a restrição de acesso às pastas temporárias do Python 3.13 no ambiente de execução do Windows e permite rodar o Luau em caminhos com acentos.
- Em 15/09/2026, a compilação, os 127 testes locais das sete suítes e a geração de `build/DowntownHustle.rbxlx` passaram com a expansão brasileira.
- No Play de 15/09/2026, o Rojo estava conectado em `localhost:34872` e o mapa expandido carregou. `STUDIO_CITY_CHECK_OK`, executado no cliente sobre o mapa replicado, confirmou 19 ruas, 144 degraus, 71 construções, cinco destinos e `problems=[]`. `STUDIO_HUD_CHECK_OK` passou em Atividade e Cidade no viewport 1016×611, com área de rolagem de 258 px e cinco linhas de destinos. Marcar a garagem atualizou o indicador de direção e distância. A consulta da frota confirmou dez veículos de sete modelos, todos com chassi como raiz física e `UpVector.Y > 0.9`. Capturas e limites estão em [tests/STUDIO.md](tests/STUDIO.md).
- Execute `python tests/run.py` para repetir os 35 testes de interações, rotas, carreira, prazo, renda, objetivos, integração entre atividades e bloqueio durante o carregamento.
- Execute `python tests/run_player_data.py` para repetir os 17 testes de salvamento: normalização, migração de perfis antigos, leitura, gravação, falhas, duas sessões, reconexão, renovação atrasada, saída durante leitura e encerramento durante salvamento.
- Execute `python tests/run_housing.py` para repetir os 11 testes de apartamento: dono, distância, carregamento, entrada, saída, descanso, reentrada, respawn e liberação de espaços.
- Execute `python tests/run_jobs.py` para repetir os 24 testes de turnos: duração, reserva de energia, pagamento único, distância, cancelamento, morte, dois jogadores e intervalo.
- Execute `python tests/run_inventory.py` para repetir os 11 testes de lanches: compra, consumo, limite, saldo, distância, intervalo, dois jogadores e bloqueio com dados indisponíveis.
- Execute `python tests/run_objectives.py` para repetir os 17 testes de progressão, requisitos, resgate único, jogadores independentes e atualização do painel.
- Execute `python tests/run_vehicles.py` para repetir os 12 testes de catálogo, entrada, autorização de controles, limites, plano de direção em rampas, recuperação e limpeza do serviço. Essa suíte integra o build. Os 127 testes usam objetos simulados em Luau; não executam física, rede, controles de assento da engine nem acessam o DataStore real.
- Evidências históricas, anteriores à expansão: em 10–11/09/2026, o Studio confirmou sincronização dos dez scripts da época, trabalho, lanches, objetivos, entrega ao clube, direção da antiga SportsCar e recuperação de capotamento preparado por comando. No iPhone XR, o HUD de duas abas e os controles de toque passaram em retrato e paisagem. A abertura de 15/09/2026 anterior à expansão confirmou cidade, personagem e HUD. Esses registros não validam os sete modelos atuais nem a aba Cidade; consulte [tests/STUDIO.md](tests/STUDIO.md).
- Os checks de mapa e HUD no Studio são separados das sete suítes locais. Entrada e direção dos veículos atuais, percursos pelas ladeiras, Cidade por toque, colisões, transporte do pacote no carro, outros aparelhos e multiplayer ainda precisam de validação na versão atual.
- A persistência real ainda precisa de teste em uma experiência publicada; o fallback no Studio mantém o progresso apenas durante aquela sessão quando a API está indisponível.
- O primeiro aluguel chega 60 segundos após a compra, com verificação a cada segundo no servidor.
- A cama restaura 100 de energia e aceita um descanso a cada oito segundos. Entrar em casa não pausa o prazo da entrega. Morrer ou reaparecer devolve o jogador à cidade; a propriedade comprada continua salva.
- O nível de procurado é um indicador; ainda não há perseguição por NPCs.

## Salvamento do progresso

O servidor salva a cada 60 segundos, ao sair e ao encerrar. O saldo, a reputação, o apartamento, os lanches, as compras de lanches, os contadores de turnos e entregas concluídos e os bônus de objetivos recebidos são restaurados ao entrar novamente. Perfis antigos recebem zero nos novos contadores sem perder o progresso existente. Energia, nível de procurado, turnos e entregas em andamento e relógios de aluguel reiniciam; não há renda offline.

No Studio, o jogo usa `DowntownHustle_PlayerData_Studio_v1`, separado do armazenamento da experiência publicada (`DowntownHustle_PlayerData_v1`). Para testar a persistência real no Studio, publique uma experiência de teste e habilite **Enable Studio Access to API Services** nas configurações de segurança. Consulte a [documentação oficial de DataStore](https://create.roblox.com/docs/cloud-services/data-stores).

Se a API estiver indisponível no Studio, o painel informa que o progresso é apenas da sessão, e essa sessão não fará gravações posteriores. Em servidores publicados, falhas de carregamento interrompem a entrada para preservar os dados existentes. Uma sessão ativa reserva o perfil por até 180 segundos, renovados nos salvamentos; após uma interrupção inesperada, pode ser necessário aguardar a reserva expirar para reconectar.

Se uma renovação estiver aguardando resposta quando o prazo da sessão vencer, as interações ficam suspensas até a confirmação. A saída do jogador e o encerramento do servidor compartilham a mesma gravação final, incluindo quando um salvamento automático ainda está em andamento.

## Estrutura principal

- `src/ServerScriptService/GameServer.server.lua` — lógica da cidade, empregos e veículos
- `src/ServerScriptService/CityBuilder.lua` — construção das ruas, prédios e cenário
- `src/ServerScriptService/BrazilianCity.lua` — bairros, relevo, comércios, garagem e cinco destinos da expansão
- `src/ServerScriptService/VehicleCatalog.lua` — sete modelos e dez posições da frota
- `src/ServerScriptService/VehicleService.lua` — montagem, entrada, direção e recuperação dos veículos
- `src/ServerScriptService/DeliveryRoutes.lua` — rotas, recompensas e carreira
- `src/ServerScriptService/PlayerData.lua` — persistência e controle de sessão
- `src/ServerScriptService/WorldCharacters.lua` — atendentes visuais e pacote do jogador
- `src/ServerScriptService/Housing.lua` — interiores, entrada, cama e saída do apartamento
- `src/ServerScriptService/JobService.lua` — turnos, reserva de energia e pagamento validado pelo servidor
- `src/ServerScriptService/InventoryService.lua` — compra e consumo de lanches
- `src/ServerScriptService/ObjectiveService.lua` — primeiros passos, requisitos e resgate de recompensas
- `src/StarterPlayer/StarterPlayerScripts/GameClient.client.lua` — HUD e interface do jogador
- `default.project.json` — configuração do Rojo
- `scripts/build.ps1` — compilação, testes e geração do arquivo para o Studio
- `scripts/serve.ps1` — servidor local do Rojo para sincronizar com o Studio

## Melhorias futuras recomendadas

- sistema de policiais e wanted level
- validação de persistência e multiplayer no Studio
- mais imóveis e lojas
- NPCs com diálogos e rotas
- mais rotas e tipos de missão
- economia mais profunda e eventos aleatórios
