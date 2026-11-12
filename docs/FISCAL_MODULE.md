# NFS-e no MVP do Brilhart

## Escopo e situação da entrega

O MVP inclui a central de NFS-e, vinculada aos registros `Service`. O operador seleciona um serviço concluído, informa/confere os dados fiscais do cliente, escolhe um enquadramento previamente aprovado e confirma o envio. A tela acompanha processamento, autorização, rejeição e cancelamento, com acesso ao XML, ao PDF quando fornecido e ao portal de consulta.

Este repositório originalmente contém o frontend e o contrato de API, sem o código das funções operacionais existentes. O novo diretório `cloud/` entrega **as funções fiscais**. Elas precisam ser acrescentadas à aplicação Back4App que já implementa clientes, serviços e autenticação. Publicar o Flutter no GitHub Pages **não instala Cloud Code**.

Conector inicial: **Focus NFe**, isolado em `focus_provider.js`, com endpoints municipal (`nfse`) e nacional (`nfsen`). Não foi contratada conta, não foram carregados certificados nem realizadas emissões externas. Credenciais, município, enquadramento contábil e homologação da empresa continuam necessários. O conector pode ser substituído mantendo o contrato da interface.

## Fluxo de telas

1. **Produção → abrir serviço → Emitir / consultar NFS-e**: abre `/notas-fiscais?serviceId=...` filtrada pelo serviço.
2. **Notas fiscais**: exibe ambiente, pendências de configuração, lista paginada e filtro de situação. Os indicadores são identificados como referentes à página exibida.
3. **Emitir NFS-e**: busca serviços concluídos; carrega cliente, descrição e valor do servidor. Não exige digitar IDs nem permite trocar o valor da ordem.
4. **Conferir dados**: revisão do cliente, emitente, valor, competência e perfil fiscal. O servidor gera um hash da revisão; mudanças posteriores impedem o envio até nova conferência.
5. **Confirmar emissão**: cria a tentativa e envia ao provedor. Uma resposta de recebimento não significa autorização.
6. **Consultar situação**: consulta sob a mesma referência. Após autorização, permite baixar arquivos disponibilizados. O PDF municipal pode não existir; nesse caso, há consulta no portal quando fornecida.
7. **Revisar e reenviar**: apenas para não enviada ou rejeição confirmada; mantém referência e DPS. Situação incerta não gera outra nota.
8. **Solicitar cancelamento**: exige justificativa de 15 a 255 caracteres, confere autorização no provedor e aguarda confirmação do cancelamento. Disponibilidade e prazo dependem do órgão emissor.

Não há emissão automática ao salvar orçamento ou concluir serviço. Não há emissão fiscal offline: falhas de conexão exigem consulta do resultado quando a conexão voltar.

## Organização do código

| Arquivo | Responsabilidade |
|---|---|
| `lib/features/fiscal/fiscal_page.dart` | Lista, filtros, preparação, conferência, arquivos e cancelamento |
| `lib/core/router/app_router.dart` | Rota protegida e entrada pelo serviço |
| `cloud/main.js` | Registra o módulo, sem substituir as funções operacionais do servidor |
| `cloud/functions/fiscal/index.js` | Cloud Functions, autorização e persistência Parse |
| `cloud/functions/fiscal/config.js` | Configuração privada, pendências e habilitação |
| `cloud/functions/fiscal/domain.js` | Validações, snapshot, referência e montagem do payload |
| `cloud/functions/fiscal/service.js` | Emissão, consulta, reenvio, cancelamento e transições |
| `cloud/functions/fiscal/focus_provider.js` | HTTP autenticado e download protegido |
| `cloud/test/fiscal.test.js` | Cenários fiscais sem chamadas externas |
| `test/fiscal_page_test.dart` | Layout desktop/mobile e bloqueio sem configuração |

## Dados e autorização

Aplicação de uma única empresa. O módulo não constitui isolamento de múltiplas empresas; esse cenário exige um modelo adicional de autorização por empresa.

A sessão deve pertencer diretamente a uma role Parse `Fiscal` ou `Admin`. Essa role é administrada no servidor, nunca por um campo editável de `_User`. Leitura e operações fiscais usam a mesma role no MVP. Restringir CLP/ACL das roles e impedir criação/edição de usuários por clientes não autorizados é pré-requisito do backend.

Classes fiscais privadas, com ACL vazia e todas as permissões públicas/autenticadas de CLP desabilitadas:

| Classe | Campos de nível superior | Índices obrigatórios |
|---|---|---|
| `FiscalInvoice` | `reference: String`, `data: Object` | `reference` único |
| `FiscalLock` | `key: String`, `owner: String` | `key` único |
| `FiscalSequence` | `key: String`, `lastNumber: Number` | `key` único |

Criar as classes/campos pelo Schema/Back4App e os índices únicos pelo acesso MongoDB ou suporte do provedor. O arquivo `cloud/setup-indexes.mongo.js` contém os comandos. Não executar no banco errado. Não apagar registros para resolver índices duplicados: conciliar antes.

`FiscalInvoice.data` contém `serviceId`, `clientId`, `environment`, `mode`, `issuerCnpj`, `status`, `snapshot`, `payload`, `dpsNumber`, `number`, `verificationCode`, `protocol`, caminhos de arquivos, mensagens e histórico. Cada alteração salva o histórico junto do registro, incluindo ator, ação, situação e horário. O payload original não é exposto ao frontend.

`Service` deve conter `status`, `value` numérico em reais com até duas casas, `description`, `serviceType` e `clientId` (String) ou `client` (Pointer para Client). `Client` deve conter `name`. Opcionalmente, `Client.fiscal` pode trazer `name`, `document`, `street`, `number`, `district`, `municipalityCode`, `state`, `postalCode` e `email` para preenchimento inicial. A correção no formulário fiscal fica no snapshot da nota; não altera silenciosamente o cadastro do cliente.

O backend bloqueia leituras/escritas diretas nas classes fiscais. Antes da primeira operação com trava em cada processo, testa se o índice único de `FiscalLock.key` está sendo aplicado de fato. Sem ele, não emite.

## Configuração do servidor

Usar Node.js 20 ou superior, com `fetch` e `AbortSignal.timeout`. O módulo não depende de pacotes npm externos. O Parse é fornecido pelo Back4App.

No `main.js` existente, acrescentar:

```js
require('./functions/fiscal').registerFiscal();
```

Manter as demais funções já publicadas. Enviar `functions/fiscal/` preservando a estrutura de pastas.

Variáveis privadas do ambiente Back4App:

| Variável | Finalidade |
|---|---|
| `FISCAL_CONFIG_JSON` | JSON de configuração da empresa e perfis |
| `FOCUS_NFE_TOKEN_HOMOLOGACAO` | Token do emitente para homologação |
| `FOCUS_NFE_TOKEN_PRODUCAO` | Token do emitente para produção |
| `FISCAL_SCHEMA_READY` | `true` somente depois de criar classes, CLP e índices |
| `FISCAL_DOCUMENT_HOSTS` | Hosts HTTPS exatos de arquivos externos retornados pelo provedor, separados por vírgula |

Nunca colocar tokens, certificado PFX/P12, senha de certificado ou Master Key em `--dart-define`, GitHub Pages, código Flutter ou arquivos versionados. Certificado e credenciamento ficam configurados no provedor conforme o município e a empresa. Tokens devem continuar disponíveis para consulta de notas históricas de ambos os ambientes.

Partir de `cloud/config.example.json`, desabilitado e sem dados fiscais inventados. Preencher:

- `namespace`: identificador permanente e exclusivo da instalação. **Não alterar depois de emitir**, pois participa da referência idempotente.
- `environment`: `homologacao` ou `producao`.
- `mode`: `national` ou `municipal`, conforme o município/cadastro da empresa.
- `issuer`: CNPJ normalizado, razão social, código IBGE e inscrição municipal quando aplicável.
- `series` e `lastDpsNumber`: para nacional, série exclusiva da integração e último número já utilizado. O contador persistido prevalece depois da primeira emissão. Não reutilizar a série em outro emissor.
- `profiles`: enquadramentos aprovados para os tipos de serviço reais do cadastro. Cada perfil tem `id`, `label`, `serviceTypes` e `fields`.
- `enabled`: `true` apenas com os itens anteriores configurados.

Os exemplos de testes usam dados fictícios exclusivamente para verificar o código. Não são orientação de tributação para a Brilhart.

### Perfis fiscais

Os campos são os nomes da API Focus, preenchidos pelo responsável técnico após validar a tributação com o contador. **Não há alíquota, CNAE ou código de serviço presumido para laqueamento.**

Nacional: `fields` inclui `codigo_tributacao_nacional_iss`, `codigo_opcao_simples_nacional`, `regime_especial_tributacao`, `tributacao_iss` e `tipo_retencao_iss`; incluir demais campos aplicáveis ao regime e às regras atuais, como NBS, IBS/CBS e percentuais de tributos. Os layouts de homologação e produção podem divergir. O servidor preenche emitente, tomador, valores, descrição, competência, série e número DPS.

Municipal: `fields` inclui `natureza_operacao`, `optante_simples_nacional` e `servico` com `item_lista_servico`, `iss_retido`, alíquota/códigos e demais parâmetros aplicáveis. O servidor preenche prestador, tomador, valor, descrição e local da prestação. Neste conector, a competência municipal deve ser a data de emissão, para não aceitar uma data que o payload municipal genérico não represente.

Perfis são configurações de tributação, não substituem cálculo contábil. Operações com retenções/deduções variáveis, serviço no exterior, substituições, faturamento parcial ou múltiplos códigos na mesma ordem precisam de extensão específica antes de usar esses casos. O MVP emite o valor integral de um serviço concluído e não gera uma segunda nota para serviço já autorizado/cancelado.

## Contrato das Cloud Functions

Todas usam `POST /functions/<nome>` e sessão Parse, com envelope `{ "result": ... }`.

| Função | Entrada | Resultado |
|---|---|---|
| `v1-fiscal-config-get` | `{}` | `ready`, `missing`, `environment`, `mode`, `issuer`, perfis sem credenciais |
| `v1-fiscal-services-list` | `search?`, `serviceId?` | Até 30 serviços concluídos com cliente e dados fiscais iniciais |
| `v1-fiscal-invoices-list` | `status?`, `serviceId?`, `offset?` | `items` (30) e `hasMore` |
| `v1-fiscal-invoices-preview` | `serviceId`, `profileId`, `competence`, `serviceMunicipality`, `recipient` | `summary`, `previewHash` |
| `v1-fiscal-invoices-issue` | Campos da revisão + `previewHash` | Nota existente ou criada, com situação efetiva |
| `v1-fiscal-invoices-refresh` | `id` | Situação consultada no provedor |
| `v1-fiscal-invoices-cancel` | `id`, `reason` | Situação efetiva do pedido |
| `v1-fiscal-invoices-download` | `id`, `kind: xml/pdf` | `base64`, `fileName`, `contentType` |

`recipient` contém os campos descritos em `Client.fiscal`. CPF e CNPJ têm validação de dígitos, incluindo CNPJ alfanumérico. O provedor/município também precisa aceitar o formato utilizado.

Status: `not_sent`, `processing`, `unknown`, `authorized`, `rejected`, `denied`, `cancelling`, `cancelled`. Situação desconhecida nunca vira autorização. Arquivos só são baixados para notas autorizadas/canceladas, com identificação do ambiente no nome. XML/PDF são obtidos do provedor; não são PDFs internos com título fiscal.

## Concorrência, reconciliação e documentos

- Referência determinística por instalação, emitente, ambiente e serviço. Não usa chave nova em cada clique.
- Trava persistente por referência, protegida por índice único. Emissão/consulta/cancelamento compartilham a trava.
- Numeração DPS sob trava independente por CNPJ/ambiente/série; números reservados não são reciclados. Uma falha após reserva pode gerar lacuna, que deve ser analisada pelo responsável fiscal.
- Persiste snapshot e payload antes do HTTP. Timeout, resposta inválida, 5xx ou conflito ficam sem confirmação; nenhum reenvio automático.
- Resposta HTTP 400/401/403 é tratada como não enviada. HTTP 422 pode indicar uma referência já recebida, por isso exige consulta/conciliação.
- Se um processo cair, a trava não expira automaticamente. O operador técnico consulta a referência no provedor, concilia o registro e remove **somente a trava correspondente**, com auditoria administrativa. Nunca recriar a referência, limpar histórico ou apagar a nota para liberar o botão.
- Uma nota cancelada mantém seu histórico e não é reutilizada como nova emissão.
- Não contabiliza receita adicional: a nota referencia o serviço já existente, sem duplicar faturamento.
- Downloads são autenticados, limitados a 8 MB e hosts explicitamente permitidos. Tokens só seguem para o host Focus do ambiente correto, inclusive após redirecionamento.
- XML e PDF não têm cópia permanente automática neste MVP. O download permite arquivamento; definir backup fiscal da empresa antes do uso operacional, sem depender apenas de URLs do provedor.
- Consulta é manual, sem polling infinito nem webhook público. Se for acrescentado webhook, autenticar e reconciliar por consulta ao provedor antes de atualizar status.

## Implantação e validação

1. Confirmar município/UF, CNPJ, regime, inscrição municipal e emissor adotado. Confirmar suporte do provedor e eventual contratação antes de ativar.
2. Criar classes, bloquear CLP, criar índices e atribuir roles aos operadores.
3. Acrescentar Cloud Code e configurar ambiente de homologação, certificado/credenciamento e perfil aprovado.
4. Testar serviço concluído, dados inválidos, processamento assíncrono, rejeição, reenvio, clique duplicado, perda de resposta, XML/PDF e cancelamento permitido pelo município.
5. Conciliar uma emissão de homologação no portal/ambiente do emissor. Testes unitários não substituem essa etapa.
6. Só então ativar produção e validar a primeira emissão real com o responsável fiscal.

Testes automatizados: `npm test --prefix cloud`, `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build web --release --base-href /Brilhart_Sistem/`. Workflow `validate.yml` usa credenciais vazias para compilar; não emite documentos e não publica o site. `deploy-pages.yml` continua sendo o fluxo separado de publicação da branch principal.

## Fontes técnicas consultadas em 12/11/2026

- [Portal nacional: documentação atual](https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual)
- [Focus: operações municipal/nacional](https://doc.focusnfe.com.br/docs/nfse-operacoes-disponiveis-na-api)
- [Focus: emissão nacional](https://doc.focusnfe.com.br/reference/emitir_dps_nacional)
- [Focus: campos nacionais em produção](https://campos.focusnfe.com.br/nfse_nacional/EmissaoDPSXml.html)
- [Focus: emissão municipal](https://doc.focusnfe.com.br/reference/emitir_nfse)
- [Focus: referência e reuso](https://doc.focusnfe.com.br/reference/referencia)
- [Receita: cálculo do DV de CNPJ alfanumérico](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj)
- [Parse: Cloud Code](https://docs.parseplatform.org/cloudcode/guide/)
