'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { documentId, prepare, buildPayload, normalizeResponse, reference } = require('../functions/fiscal/domain');
const { readConfig } = require('../functions/fiscal/config');
const { FocusProvider, ProviderError } = require('../functions/fiscal/focus_provider');
const { FiscalService } = require('../functions/fiscal/service');
const config = { ready: true, namespace: 'test', environment: 'homologacao', mode: 'national', series: 1,
  issuer: { cnpj: '11222333000181', legalName: 'Empresa de testes', municipalityCode: '4202404' },
  profiles: [{ id: 'test', label: 'Perfil de teste', serviceTypes: ['Teste'], fields: {
    codigo_tributacao_nacional_iss: '010701', codigo_opcao_simples_nacional: '1', regime_especial_tributacao: '0', tributacao_iss: 1, tipo_retencao_iss: 1 } }] };
const service = { id: 'service1', clientId: 'client1', status: 'Concluído', value: 1500.25, description: 'Serviço de teste', serviceType: 'Teste' };
const client = { id: 'client1', name: 'Cliente de teste' };
const input = { serviceId: service.id, profileId: 'test', competence: '2026-01-01', serviceMunicipality: '4202404',
  recipient: { name: 'Cliente de teste', document: '529.982.247-25', street: 'Rua de Teste', number: '12', district: 'Centro', municipalityCode: '4202404', state: 'SC', postalCode: '89010-000' } };
function fixture(providerOverrides = {}) {
  let note; let sends = 0; let number = 0; const locks = new Set(); const events = [];
  const repo = {
    service: async () => ({ ...service }), client: async () => client,
    byReference: async () => note ? structuredClone(note) : null,
    invoice: async () => structuredClone(note), nextDps: async () => ++number,
    create: async data => (note = { ...data, id: 'invoice1' }),
    save: async (data, actor, action) => { events.push(action); return (note = structuredClone(data)); },
    withLock: async (key, work) => { assert(!locks.has(key), 'concurrent operation'); locks.add(key); try { return await work(); } finally { locks.delete(key); } },
  };
  const provider = {
    send: async () => { sends++; return { status: 'processando_autorizacao' }; },
    consult: async () => ({ status: 'autorizado', numero: '12', caminho_xml_nota_fiscal: '/note.xml', url_danfse: '/note.pdf' }),
    cancel: async () => ({ status: 'cancelado' }),
    download: async () => ({ base64: 'ZmlsZQ==' }), ...providerOverrides,
  };
  return { app: new FiscalService(repo, provider, config), repo, provider, sends: () => sends, note: () => note, events };
}
async function reviewed(app) { return { ...input, previewHash: (await app.preview(input)).previewHash }; }

test('CPF, numeric CNPJ and Receita alphanumeric example keep their check digits', () => {
  assert.equal(documentId('529.982.247-25'), '52998224725');
  assert.equal(documentId('11.222.333/0001-81'), '11222333000181');
  assert.equal(documentId('12.ABC.345/01DE-35'), '12ABC34501DE35');
  for (const value of ['11111111111', '00000000000000', '52998224724', '12ABC34501DE36', 'x52998224725']) assert.equal(documentId(value), '');
});
test('server value and allowed tax profile override all client price/tax fields', () => {
  const result = prepare(config, service, client, { ...input, value: 0.01, taxFields: {} });
  assert.equal(result.value, 1500.25);
  const payload = buildPayload(result, '2026-01-02T12:00:00Z', 9);
  assert.equal(payload.valor_servico, 1500.25); assert.equal(payload.numero_dps, 9);
  assert.equal(payload.cpf_tomador, '52998224725'); assert(!('cnpj_tomador' in payload));
  assert.equal(payload.codigo_tributacao_nacional_iss, '010701');
});
test('invalid dates, empty customer, unapproved profiles and incomplete services fail before send', () => {
  for (const patch of [{ competence: '2026-02-30' }, { competence: '2099-01-01' }, { recipient: {} }, { profileId: 'foreign' }]) assert.throws(() => prepare(config, service, client, { ...input, ...patch }));
  assert.throws(() => prepare(config, { ...service, status: 'Cancelado' }, client, input));
  assert.throws(() => prepare(config, { ...service, value: -1 }, client, input));
  assert.throws(() => prepare(config, { ...service, serviceType: 'Outro' }, client, input));
});
test('missing credentials and configuration leave emission disabled', () => {
  const c = readConfig({}); assert.equal(c.ready, false); assert(c.missing.length > 3);
});
test('unknown status can never authorize a note', () => {
  assert.equal(normalizeResponse({}).status, 'unknown');
  assert.equal(normalizeResponse({ status: 'novo_status' }).status, 'unknown');
  assert.equal(normalizeResponse({ status: 'processando_autorizacao' }).status, 'processing');
  assert.equal(normalizeResponse({ status: 'erro_cancelamento' }, 'cancelling').status, 'authorized');
});
test('environment separates references, changing municipal/national mode does not bypass deduplication', () => {
  assert.notEqual(reference(config, '1'), reference({ ...config, environment: 'producao' }, '1'));
  assert.equal(reference(config, '1'), reference({ ...config, mode: 'municipal' }, '1'));
});
test('repeat issuance and lost browser response reuse the existing invoice', async () => {
  const f = fixture(); const request = await reviewed(f.app);
  const first = await f.app.issue(request, 'user'); const second = await f.app.issue(request, 'user');
  assert.equal(first.id, second.id); assert.equal(second.status, 'processing'); assert.equal(f.sends(), 1);
  await f.app.refresh(first.id, 'user'); assert.equal(f.note().status, 'authorized');
  await f.app.issue(request, 'user'); assert.equal(f.sends(), 1);
});
test('stale preview blocks fiscal submission', async () => {
  const f = fixture(); const request = await reviewed(f.app);
  f.repo.service = async () => ({ ...service, value: 1600 });
  await assert.rejects(f.app.issue(request, 'user'), /dados mudaram/); assert.equal(f.sends(), 0);
});
test('timeout leaves an uncertain note and subsequent clicks never POST again', async () => {
  let sends = 0;
  const f = fixture({ send: async () => { sends++; throw new ProviderError('timeout', 0); } });
  const request = await reviewed(f.app); await f.app.issue(request, 'user');
  assert.equal(f.note().status, 'unknown'); await f.app.issue(request, 'user'); assert.equal(sends, 1);
  await f.app.refresh('invoice1', 'user'); assert.equal(f.note().status, 'authorized');
});
test('404 consultation after timeout never releases a note for reissue', async () => {
  const f = fixture({ send: async () => { throw new ProviderError('timeout', 0); }, consult: async () => { throw new ProviderError('missing', 404); } });
  await f.app.issue(await reviewed(f.app), 'user'); await f.app.refresh('invoice1', 'user');
  assert.equal(f.note().status, 'unknown'); assert.match(f.note().message, /conciliação/);
});
test('concurrent issuance cannot send twice', async () => {
  const f = fixture(); const request = await reviewed(f.app);
  const results = await Promise.allSettled([f.app.issue(request, 'user'), f.app.issue(request, 'user')]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1); assert.equal(f.sends(), 1);
});
test('a confirmed rejection permits a corrected retry on the same ref/DPS', async () => {
  const f = fixture({ send: async () => ({ status: 'erro_autorizacao', erros: [{ mensagem: 'corrigir' }] }), consult: async () => ({ status: 'erro_autorizacao' }) });
  const request = await reviewed(f.app); const first = await f.app.issue(request, 'user');
  const second = await f.app.issue(request, 'user'); assert.equal(first.reference, second.reference); assert.equal(first.dpsNumber, second.dpsNumber);
});
test('cancellation requires justification and provider confirmation; cancelled notes do not reissue', async () => {
  const f = fixture(); const request = await reviewed(f.app); await f.app.issue(request, 'user');
  await assert.rejects(f.app.cancel('invoice1', 'curto', 'user'));
  await f.app.cancel('invoice1', 'Cancelamento solicitado pelo cliente', 'user');
  assert.equal(f.note().status, 'cancelled'); await f.app.issue(request, 'user'); assert.equal(f.sends(), 1);
  await f.app.refresh('invoice1', 'user'); assert.equal(f.note().status, 'cancelled');
});
test('uncertain cancellation stays pending until consultation', async () => {
  const f = fixture({ cancel: async () => { throw new ProviderError('timeout', 0); } });
  await f.app.issue(await reviewed(f.app), 'user'); await f.app.cancel('invoice1', 'Cancelamento solicitado pelo cliente', 'user');
  assert.equal(f.note().status, 'cancelling');
});
test('downloads before authorization are blocked', async () => {
  const f = fixture(); await f.app.issue(await reviewed(f.app), 'user');
  await assert.rejects(f.app.download('invoice1', 'xml'), /não autorizado/);
});
test('provider uses real endpoint/auth, preserves async response and never exposes the token', async () => {
  let request;
  const p = new FocusProvider({ FOCUS_NFE_TOKEN_HOMOLOGACAO: 'test-token' }, async (url, options) => { request = { url, options }; return { ok: true, json: async () => ({ status: 'processando_autorizacao' }) }; });
  const result = await p.send({ environment: 'homologacao', mode: 'national', reference: 'abc' }, {});
  assert.equal(request.url, 'https://homologacao.focusnfe.com.br/v2/nfsen?ref=abc');
  assert.equal(request.options.headers.Authorization, 'Basic ' + Buffer.from('test-token:').toString('base64'));
  assert.deepEqual(result, { status: 'processando_autorizacao' });
});
test('download denies arbitrary hosts and strips auth on approved external PDF hosts', async () => {
  const inv = { environment: 'homologacao', mode: 'national', reference: 'abc', pdfPath: 'https://example.com/a.pdf' };
  const calls = [];
  const fetcher = async (url, options) => { calls.push({ url, options }); return { ok: true, status: 200, body: [Buffer.from('%PDF-1.4 test')] }; };
  const p = new FocusProvider({ FOCUS_NFE_TOKEN_HOMOLOGACAO: 'test', FISCAL_DOCUMENT_HOSTS: 'docs.example.com' }, fetcher);
  await assert.rejects(p.download(inv, 'pdf'), /liberação/); assert.equal(calls.length, 0);
  const result = await p.download({ ...inv, pdfPath: 'https://docs.example.com/a.pdf' }, 'pdf');
  assert.equal(calls[0].options.headers.Authorization, undefined); assert.equal(result.contentType, 'application/pdf');
});
