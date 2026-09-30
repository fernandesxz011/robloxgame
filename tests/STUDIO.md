# Verificação no Roblox Studio

## Situação da revisão documental — 30/09/2026

A compilação, as **132 verificações com mocks em sete suítes** (incluindo 17 de veículos) e a geração pelo Rojo passaram nesta revisão. O arquivo gerado não contém `VehicleUnits`, apesar de o cliente e o serviço de veículos exigirem esse módulo. O mapeamento precisa ser corrigido antes de repetir os testes de Play em uma importação limpa. Consulte o [README](../README.md).

As seções abaixo preservam os relatos técnicos de sessões anteriores. Seus números e resultados são registros históricos, não uma execução atual confirmada. As capturas mencionadas em `build/` não estão versionadas; a pasta é ignorada pelo Git. Nesta revisão não foram executados Roblox Studio, física, multiplayer ou persistência real.

## Evidências da expansão — 15/09/2026

A compilação, os **127 testes com mocks em sete suítes** e a geração de `build/DowntownHustle.rbxlx` passaram com a expansão brasileira. O build inclui os 12 casos de `python tests/run_vehicles.py`, cobrindo catálogo, autorização, direção em rampas e ciclo de vida do serviço. Os executores usam temporários em `build/tests`, com limpeza ao terminar. Mocks não simulam física, rede ou controles de assento da engine.

A expansão acrescenta 71 casas e comércios nos bairros e morros, feira, mirante e garagem. O catálogo reúne sete modelos e a frota tem dez veículos gratuitos, três no centro e sete na garagem. A aba Cidade oferece cinco destinos: Garagem Brasileira, Bela Vista, Vila dos Ipês, Feira da Estação e Mirante da Serra.

### Confirmado no Studio em 15/09/2026

| Verificação | Evidência |
| --- | --- |
| Rojo e inicialização | Plugin conectado em `localhost:34872`; Play com o mapa expandido carregado. |
| Geometria do mapa replicado | `studio_city_check.lua` foi executado na visualização do cliente e imprimiu `STUDIO_CITY_CHECK_OK`: 19 ruas, 144 degraus, 71 construções, cinco destinos e `problems=[]`. Esse resultado cobre as consultas geométricas do script no mapa replicado. |
| Atividade e Cidade no desktop | `STUDIO_HUD_CHECK_OK` nas duas abas, em viewport 1016×611, com `scrollHeight=258`; Cidade apresentou `cityRows=5`. |
| Marcar a garagem | O clique em **Marcar** na linha da garagem mudou o indicador para esse destino, com direção e distância. |
| Frota em repouso | Consulta confirmou dez veículos de sete modelos. Em todos, o chassi era a raiz física e `UpVector.Y > 0.9`, indicando que estavam em pé. Entrada e direção ainda não foram verificadas nesta rodada. |

Capturas dessa rodada: mapa e check (`../build/studio-expansion-check.png`, arquivo local não versionado), aba Cidade (`../build/studio-city-hud.png`, arquivo local não versionado) e preparação para dirigir (`../build/studio-drive-ready.png`, arquivo local não versionado).

**Pendente na engine:** entrada e direção dos sete modelos atuais, percursos completos pelos bairros e ladeiras, colisões e controles por toque da aba Cidade e dos veículos. As consultas de geometria, HUD e frota acima delimitam a cobertura confirmada; não equivalem a testar esses percursos ou a física com motorista.

### Checks para executar em Play

Abra o build atualizado, inicie **Play** e mantenha **Output** aberto. Cole o conteúdo do arquivo indicado na barra de comandos e execute com **Ctrl+Enter**, depois de o cenário ou a interface estabilizar:

| Script | Visualização | Verifica e resultado esperado |
| --- | --- | --- |
| `tests/studio_city_check.lua` | Servidor, no início de Play | Inclinação e corredores livres das ruas, apoio das escadas, contagem de construções e acesso aos cinco destinos. Imprime `STUDIO_CITY_CHECK` com as contagens e `STUDIO_CITY_CHECK_OK` se não encontrar problemas. |
| `tests/studio_hud_check.lua` | Cliente | Área segura do painel e indicador, espaço para analógico/pulo, três abas, textos, linhas de Cidade, botões e alcance da rolagem. Imprime `STUDIO_HUD_CHECK_OK`. Repita nas três abas, com Cidade marcada e limpa, após rolar, recolher/abrir e girar entre retrato e paisagem. |

Os dois scripts apenas consultam objetos. São checks de engine separados das sete suítes locais e não substituem caminhar pelos acessos ou dirigir os veículos. A execução registrada do check de cidade em 15/09 ocorreu no cliente sobre o mapa replicado; a tabela indica a visualização do servidor para repetir a conferência do mapa completo.

## Evidências históricas — antes da expansão

Na abertura de 15/09/2026 anterior à expansão, o Play confirmou cidade, personagem, veículos no cenário e HUD com carteira de $1.500, banco de $0, energia e oferta de entrega. O registro foi salvo em `build/studio-play.png`. O Studio ficou aberto em Play; o servidor Rojo foi iniciado em `127.0.0.1:34872`, mas a conexão do plugin não foi confirmada naquela rodada. Essa conferência cobriu apenas a inicialização da versão anterior.

Em 10/09/2026, foi validado no Studio desta máquina: abertura de `DowntownHustle.rbxlx`, conexão do Rojo 7.7.0 em `localhost:34872`, chegada e remoção de uma alteração temporária e comparação dos dez scripts da época. A conexão continuava ativa em 11/09/2026. A versão anterior tinha 115 testes locais em seis suítes.

Os testes de trabalhos, entregas e direção abaixo usaram movimento, interações de proximidade e botões do jogo. A barra de comandos foi usada para consultar atributos e posições, sem alterar saldos ou contadores. No caso específico de recuperação do carro tombado, um comando no servidor preparou a posição invertida e zerou as velocidades; o retorno à vaga ocorreu pela lógica do jogo. As sessões estavam em `SessionOnly`, sem testar gravação no DataStore real.

| Verificação realizada em 10–11/09/2026 | Evidência no Studio |
| --- | --- |
| Inicialização e carregamento sem API | Cidade, personagem e HUD renderizados; dados prontos e status `SessionOnly`. |
| Trabalho no restaurante | Ao concluir o turno, carteira de $1.500 para $1.680, `WorkActive=false`, `WorkCompletions=1` e primeiro objetivo disponível. |
| Objetivos, mercadinho e consumo | Resgate de $100, compra de um lanche por $60, consumo e resgate de $75. Estado final verificado: carteira $1.795, dois objetivos recebidos, um lanche comprado e nenhum restante. |
| Cancelamento de trabalho | Em outra sessão, um turno concluído deixou $1.680; iniciar e cancelar o seguinte manteve esse saldo e apenas um turno concluído, com mensagem de cancelamento. |
| Entrega ao clube | Aceitação e retirada exibiram prazo e pacote nas costas. A consulta posterior confirmou uma entrega concluída, missão encerrada, pacote removido, reputação 23 após um trabalho e oferta seguinte `Entrega hospitalar`. |
| Interface durante atividades | Iniciar turno ou aceitar entrega a partir de Objetivos abriu Atividade com relógio e botão Cancelar. Receber e Marcar destino ficaram visíveis no painel de desktop sem rolagem. |
| Entrada na SportsCar após correção | `E` sentou o personagem sem deslocar o carro até ele. A posição foi consultada no servidor, e `GetNetworkOwner()` retornou `nil`, mantendo a física no servidor. |
| Direção da SportsCar | `W` por 1 s avançou aproximadamente 34,23 studs; soltar o controle parou o veículo, com velocidade consultada igual a zero. `W+D` por 0,6 s mudou a direção, a ré recuou aproximadamente 17,8 studs e espaço retirou o motorista sem devolver o carro à vaga. |
| Recuperação de capotamento em cenário controlado | Com o banco vazio, `PivotTo` no servidor colocou a SportsCar invertida e zerou suas velocidades. Após 6 s, a consulta confirmou retorno à vaga em aproximadamente `(-18, 2.6000, 36)`, com `UpVector.Y > 0.9`, cobrindo a recuperação programada após 5 s tombado e desocupado. O capotamento não foi provocado por colisão durante a direção. |
| iPhone XR, paisagem e retrato | `studio_hud_check.lua` passou com áreas úteis de 801×392 e 412×814, incluindo rotação durante uma missão. Painel e indicador ficaram dentro da área segura e fora dos retângulos do analógico e do pulo; os detalhes tiveram 190 e 258 pixels de altura, respectivamente. O painel recolhido também passou em retrato. |
| Controles e navegação por toque | Arrastar o analógico moveu o personagem aproximadamente 30,17 studs; pressionar o botão de pulo gerou o estado `Jumping`. Gestos rolaram Objetivos e Ajuda, Marcar destino ativou o indicador e recolher/abrir preservou a aba escolhida. |
| Missão por toque e mudança de orientação | A interação de proximidade aceitou a entrega em retrato e abriu Atividade. Após girar para paisagem, Cancelar permaneceu acessível e encerrou a missão, preservando $1.500 e zero entregas concluídas. |

Antes da correção dos carros, o registro `CAR_ROOT_CONFIRMED` mostrou o `HumanoidRootPart` do motorista como raiz física da SportsCar ocupada. Ao criar a solda do banco, o veículo mudava de posição e orientação para se alinhar ao personagem. Definir `chassis.RootPriority = 127`, mantendo o chassi com massa, fez a raiz permanecer no veículo. A seleção da raiz considera massa, prioridade e critérios de tamanho/tipo, conforme a [documentação oficial de assemblies](https://create.roblox.com/docs/physics/assemblies). Os testes de direção da tabela foram feitos depois dessa correção. O build com os ajustes de servidor e interface desta etapa passou nos 115 testes locais.

Naquela versão, o painel passou a calcular espaço livre considerando os controles nativos de toque. A configuração `StarterGui.ScreenOrientation = Sensor` permite alternar retrato e paisagem; sua chegada ao editor foi confirmada após reiniciar o servidor Rojo e reconectar o plugin. O check geométrico de então cobriu Atividade e Objetivos; Cidade foi acrescentada posteriormente.

O Play foi encerrado após as verificações de 10–11/09, mantendo o projeto conectado ao Rojo no editor. A tabela acima valida apenas os casos explicitamente registrados naquela versão.

## Matriz de verificação da versão atual

Os cenários abaixo descrevem a cobertura desejada. Em 15/09, foram conferidos o mapa replicado, Atividade e Cidade no desktop, a marcação da garagem e o estado da frota em repouso. Entrada e direção dos modelos atuais, percursos, colisões variadas, pacote no carro, toque, outros aparelhos, multiplayer e persistência real continuam pendentes.

Abra `build/DowntownHustle.rbxlx` e use **Play**. A cidade aparece quando o servidor inicia. Mantenha **Output** aberto para identificar erros.

| Cenário | Resultado esperado |
| --- | --- |
| Entrada sem API de DataStore no Studio | O painel termina de carregar e informa que os dados existem apenas na sessão. As interações passam a funcionar. |
| Experiência de teste publicada com API habilitada | O progresso carrega; conclua uma entrega, deposite dinheiro, compre um imóvel, saia e entre novamente. Saldos, imóvel, reputação e contador devem permanecer. |
| Três entregas seguidas | O destino alterna clube, hospital e banco. A recompensa e o prazo correspondem à oferta. Entregar no destino de outra rota não paga. |
| Cancelar, morrer ou deixar o prazo terminar | O pacote desaparece e o indicador retoma o passeio selecionado, ou volta à central se não houver passeio. Nenhuma recompensa é paga. |
| Cinco e quinze entregas | A carreira muda para Profissional e Especialista; as próximas ofertas ganham bônus de $50 e $100. |
| Entrada e direção dos veículos | Use Dirigir: o personagem deve se alinhar ao banco, mantendo a posição do veículo. Acelere, solte, vire e dê ré. Sair por espaço deixa um veículo em pé onde foi estacionado. Repetir nos sete modelos atuais e com outros avatares. |
| Bairros, ladeiras e acessos | Caminhe até Bela Vista, Vila dos Ipês, feira e mirante; confira escadas, entradas dos comércios e ligação com o centro. Dirija nos trechos inclinados e confirme contato com a pista, frenagem e curvas sem bloquear nas guias. |
| Carro e pacote | Dirija durante uma entrega. O pacote acompanha o avatar sem interferir na física. Este caso continua pendente. |
| Colisão e capotamento | Teste guias, prédios e outros carros. Saia de um carro tombado e aguarde cinco segundos: ele volta à vaga. O registro antigo de recuperação da SportsCar não valida os modelos atuais; repita com capotamento preparado e provocado por colisão. |
| Dois clientes, pelo teste de servidor e clientes | Cada jogador tem saldo, indicador, missão e pacote independentes. Um assento ocupado não aceita outro motorista. |
| Emulador de celular, retrato e paisagem | Ajuda, cancelar, rolagem, recolher e os controles nativos continuam acessíveis. A seta indica destinos fora da tela. |
| Aluguel | A primeira renda chega um minuto após comprar ou entrar com imóvel; não há renda retroativa pelo tempo fora do jogo. |
| Apartamento comprado | O ponto laranja passa a mostrar Meu apartamento / Entrar. Entre a pé, use a cama para recuperar energia e a porta para voltar. Reentrar não cobra novamente. |
| Apartamento em dois clientes | Cada dono entra em seu próprio interior. Um jogador não consegue usar a cama ou a saída do interior do outro. |
| Entrega dentro de casa | O prazo continua. O indicador fica oculto dentro de casa e retorna ao sair; cancelar ou deixar expirar não paga recompensa. |
| Morte e respawn em casa | O personagem reaparece na cidade, os indicadores retornam e o apartamento pode ser acessado novamente. A propriedade não é perdida. |
| Turno em cada ponto verde | A energia é debitada uma vez no início; a barra avança durante 18, 20, 25 ou 30 segundos. Ao concluir perto do ponto, o saldo recebe a recompensa indicada e o contador aumenta uma vez. |
| Interrupção do turno | Afastar-se mais de 18 studs, sentar em um carro, morrer ou cancelar encerra a atividade sem pagamento ou devolução de energia. Voltar ao ponto não retoma o turno. |
| Trabalho e outras atividades | Durante um turno, os pontos de nova entrega e apartamento ficam indisponíveis. Durante uma entrega, os trabalhos ficam indisponíveis. Cancelar libera a outra atividade. |
| Mercadinho e mochila | Comprar desconta $60 e acrescenta um lanche, até cinco. Comer ou B consome um e restaura até 25 de energia; energia cheia não consome. A mochila cheia e saldo insuficiente não geram cobrança. |
| Lanches no carro e em casa | É possível consumir vivo, sentado ou dentro do apartamento. O intervalo de dois segundos impede consumo repetido imediato. |
| Reconexão após trabalho e compra | Em uma experiência com API, conclua um turno, compre dois lanches, saia e entre: o contador, os lanches e os saldos retornam. Turnos em andamento não retornam. |
| Turnos e lanches em dois clientes | Os jogadores podem trabalhar no mesmo ponto com relógios, saldo e inventário independentes. Cancelar ou comer em um cliente não afeta o outro. |
| Objetivos em conta nova | A aba Objetivos começa no primeiro trabalho, mostra requisito e bônus. Concluir um turno libera Receber; tocar duas vezes paga só $100 e avança uma etapa. |
| Progresso anterior | Uma conta com trabalho, entregas e imóvel já conquistados pode receber os bônus correspondentes em sequência. Comprar e consumir o lanche antes de chegar ao objetivo não perde o progresso. |
| Reserva no banco | Depositar $500 libera o bônus; sacar antes de receber bloqueia-o novamente. Receber acrescenta $125 à carteira e preserva os $500 do banco. |
| Marcar objetivo | Fora de atividades, o indicador aponta para o local escolhido. Iniciar trabalho ou entrega prioriza a atividade. Receber o bônus encerra o rastreio do objetivo anterior. Em casa, o indicador fica oculto. |
| Passeio pela aba Cidade | Marque cada um dos cinco destinos e confira direção, distância e nome. Trabalho e entrega têm prioridade e o passeio retoma ao terminar. Marcar objetivo substitui o passeio; Limpar destino retorna à central quando livre. Em casa, o indicador fica oculto. |
| Iniciar atividade com outra aba ou painel recolhido | Começar um turno ou aceitar uma entrega abre Atividade e mostra prazo e Cancelar. Depois, é possível escolher Objetivos ou Cidade; retirar o pacote, concluir ou cancelar não força outra troca de aba. |
| Abas no celular | Atividade, Objetivos, Cidade, ajuda, receber, marcar/limpar destino e rolagem funcionam em retrato e paisagem, sem sobrepor os controles nativos. A aba de objetivos indica quando há bônus disponível. |
| Recompensas após reconectar | Em uma experiência com API, receba bônus, saia e entre. O contador de objetivos e o dinheiro retornam juntos, sem poder receber novamente o mesmo bônus. |
| Fim dos primeiros passos | Depois de receber os sete bônus, o painel informa conclusão, remove o resgate e permite continuar trabalhos e entregas normalmente. |

Ao testar persistência, o Studio usa um DataStore separado do jogo publicado. Testes de lease, falha de leitura e concorrência também estão em `tests/run_player_data.py`, com serviços simulados.
