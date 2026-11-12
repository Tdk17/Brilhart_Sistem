'use strict';
// Parse is supplied by Back4App Cloud Code. All fiscal data is server-owned.
const { randomUUID } = require('node:crypto');
const { FiscalError, check, clean, hash } = require('./domain');
const { readConfig } = require('./config');
const { FocusProvider } = require('./focus_provider');
const { FiscalService } = require('./service');
const MASTER = { useMasterKey: true };
const privateClasses = ['FiscalInvoice', 'FiscalLock', 'FiscalSequence'];
function row(object) { return { ...object.get('data'), id: object.id, createdAt: object.createdAt?.toISOString() }; }
function pointerId(value) { return typeof value === 'string' ? value : value?.id || value?.objectId; }
class ParseFiscalRepository {
  async ensureIntegrity() {
    if (this.integrityVerified) return;
    const key = 'integrity' + randomUUID();
    const probes = [];
    let unique = false;
    try {
      for (let i = 0; i < 2; i++) {
        const probe = new Parse.Object('FiscalLock');
        probe.setACL(new Parse.ACL()); probe.set('key', key);
        try { await probe.save(null, MASTER); probes.push(probe); }
        catch (e) { if (i === 1 && e.code === 137) unique = true; else throw e; }
      }
    } finally { for (const probe of probes) await probe.destroy(MASTER); }
    check(unique, 'Índice único de FiscalLock.key ausente. Emissão bloqueada até corrigir a instalação.');
    this.integrityVerified = true;
  }
  async service(id) {
    const o = await new Parse.Query('Service').get(id, MASTER);
    return { id: o.id, clientId: pointerId(o.get('clientId') || o.get('client')), status: o.get('status'),
      value: o.get('value'), description: o.get('description'), serviceType: o.get('serviceType') };
  }
  async client(id) {
    check(id, 'Serviço sem cliente vinculado.');
    const o = await new Parse.Query('Client').get(id, MASTER);
    return { id: o.id, name: o.get('name'), fiscal: o.get('fiscal') || {} };
  }
  async byReference(reference) {
    const o = await new Parse.Query('FiscalInvoice').equalTo('reference', reference).first(MASTER);
    return o ? row(o) : null;
  }
  async invoice(id) { return row(await new Parse.Query('FiscalInvoice').get(id, MASTER)); }
  async create(data, actor) {
    const o = new Parse.Object('FiscalInvoice'); o.setACL(new Parse.ACL());
    o.set('reference', data.reference); o.set('data', { ...data, history: [{ action: 'created', actor, at: new Date().toISOString() }] });
    return row(await o.save(null, MASTER));
  }
  async save(data, actor, action) {
    const o = await new Parse.Query('FiscalInvoice').get(data.id, MASTER);
    const { id, createdAt, ...stored } = data;
    stored.history = [...(o.get('data').history || []), { action, actor, status: data.status, at: new Date().toISOString() }];
    o.set('data', stored); return row(await o.save(null, MASTER));
  }
  async withLock(key, work) {
    await this.ensureIntegrity();
    const lock = new Parse.Object('FiscalLock'); lock.setACL(new Parse.ACL()); lock.set('key', key); lock.set('owner', randomUUID());
    try { await lock.save(null, MASTER); }
    catch (e) { if (e.code === 137) throw new FiscalError('Esta operação fiscal já está em andamento. Aguarde e consulte novamente.'); throw e; }
    // A crashed process needs operator reconciliation. Never steal a fiscal lock on a timer.
    try { return await work(); } finally { await lock.destroy(MASTER); }
  }
  async nextDps(config) {
    const key = hash([config.issuer.cnpj, config.environment, config.series]);
    return this.withLock('sequence' + key, async () => {
      let seq = await new Parse.Query('FiscalSequence').equalTo('key', key).first(MASTER);
      if (!seq) { seq = new Parse.Object('FiscalSequence'); seq.setACL(new Parse.ACL()); seq.set('key', key); seq.set('lastNumber', config.lastDpsNumber); }
      const number = seq.get('lastNumber') + 1;
      check(Number.isSafeInteger(number) && number <= 999999999999999, 'Numeração DPS esgotada.');
      seq.set('lastNumber', number); await seq.save(null, MASTER); return number;
    });
  }
}
function publicInvoice(invoice) {
  const { payload, history, snapshot, ...rest } = invoice;
  const { taxFields, ...summary } = snapshot || {};
  const { xmlPath, pdfPath, issuerCnpj, ...safe } = rest;
  return { ...safe, summary, canDownloadXml: Boolean(xmlPath), canDownloadPdf: Boolean(pdfPath) };
}
async function authorize(request) {
  check(request.user, 'Faça login para acessar o módulo fiscal.');
  const role = await new Parse.Query(Parse.Role).containedIn('name', ['Admin', 'Fiscal']).equalTo('users', request.user).first(MASTER);
  check(role, 'Seu usuário precisa da permissão Fiscal ou Admin.');
  return request.user.id;
}
function registerFiscal() {
  for (const className of privateClasses) {
    Parse.Cloud.beforeSave(className, request => { check(request.master, 'Escrita fiscal permitida somente pelo servidor.'); });
    Parse.Cloud.beforeDelete(className, request => { check(request.master, 'Exclusão fiscal permitida somente pelo servidor.'); });
    Parse.Cloud.beforeFind(className, request => { check(request.master, 'Use as funções fiscais autenticadas.'); });
  }
  const define = (name, handler) => Parse.Cloud.define(name, async request => {
    try { const actor = await authorize(request); return await handler(request.params || {}, actor); }
    catch (e) {
      if (e instanceof FiscalError) throw new Parse.Error(Parse.Error.VALIDATION_ERROR, e.message);
      if (e instanceof Parse.Error) throw e;
      throw new Parse.Error(Parse.Error.SCRIPT_FAILED, 'Não foi possível concluir a operação fiscal. Consulte a situação antes de reenviar.');
    }
  });
  const repo = new ParseFiscalRepository();
  const service = () => new FiscalService(repo, new FocusProvider(), readConfig());
  define('v1-fiscal-config-get', async () => {
    const c = readConfig();
    return { ready: c.ready, missing: c.missing, environment: c.environment || 'homologacao', mode: c.mode,
      issuer: c.issuer || {}, profiles: c.profiles.map(p => ({ id: p.id, label: p.label, serviceTypes: p.serviceTypes })) };
  });
  define('v1-fiscal-services-list', async input => {
    const q = new Parse.Query('Service').equalTo('status', 'Concluído');
    if (input.serviceId) q.equalTo('objectId', clean(input.serviceId));
    if (clean(input.search)) q.contains('description', clean(input.search).slice(0, 100));
    const rows = await q.descending('updatedAt').limit(30).find(MASTER);
    const items = [];
    for (const o of rows) {
      const s = await repo.service(o.id);
      try { const c = await repo.client(s.clientId); items.push({ ...s, clientName: c.name, recipient: { name: c.name, ...c.fiscal } }); }
      catch (e) { if (!(e instanceof FiscalError) && e.code !== 101) throw e; }
    }
    return { items };
  });
  define('v1-fiscal-invoices-list', async input => {
    const q = new Parse.Query('FiscalInvoice');
    if (input.serviceId) q.equalTo('data.serviceId', clean(input.serviceId));
    if (input.status) q.equalTo('data.status', clean(input.status));
    const offset = Number.isInteger(input.offset) && input.offset > 0 ? Math.min(input.offset, 10000) : 0;
    const rows = await q.descending('createdAt').skip(offset).limit(31).find(MASTER);
    return { items: rows.slice(0, 30).map(o => publicInvoice(row(o))), hasMore: rows.length > 30 };
  });
  define('v1-fiscal-invoices-preview', async input => {
    const snapshot = await service().preview(input);
    const { taxFields, ...summary } = snapshot;
    return { summary, previewHash: snapshot.previewHash };
  });
  define('v1-fiscal-invoices-issue', async (input, actor) => publicInvoice(await service().issue(input, actor)));
  define('v1-fiscal-invoices-refresh', async (input, actor) => publicInvoice(await service().refresh(clean(input.id), actor)));
  define('v1-fiscal-invoices-cancel', async (input, actor) => publicInvoice(await service().cancel(clean(input.id), input.reason, actor)));
  define('v1-fiscal-invoices-download', async input => service().download(clean(input.id), input.kind));
}
module.exports = { registerFiscal, ParseFiscalRepository, publicInvoice, authorize };
