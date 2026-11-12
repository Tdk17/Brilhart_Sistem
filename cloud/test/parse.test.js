'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { ParseFiscalRepository, authorize, registerFiscal, publicInvoice } = require('../functions/fiscal');

function parseStub(unique = true) {
  const records = new Map(); let id = 0; const registrations = {};
  class ObjectStub {
    constructor(className) { this.className = className; this.fields = {}; }
    set(key, value) { this.fields[key] = value; }
    get(key) { return this.fields[key]; }
    setACL() {}
    async save() {
      if (unique && [...records.values()].some(r => r.className === this.className && r.get('key') === this.get('key'))) {
        throw Object.assign(new Error('duplicate'), { code: 137 });
      }
      this.id = String(++id); records.set(this.id, this); return this;
    }
    async destroy() { records.delete(this.id); }
  }
  global.Parse = {
    Object: ObjectStub, ACL: class {}, Role: class {},
    Query: class {
      containedIn() { return this; }
      equalTo() { return this; }
      async first() { return null; }
    },
    Cloud: Object.fromEntries(['define', 'beforeSave', 'beforeDelete', 'beforeFind'].map(method => [method, (name, callback) => { registrations[method + ':' + name] = callback; }])),
  };
  return { records, registrations };
}
test('anonymous users and users outside authorized roles cannot access fiscal data', async () => {
  parseStub();
  await assert.rejects(authorize({}), /login/);
  await assert.rejects(authorize({ user: { id: 'user' } }), /permissão/);
});
test('direct queries and changes are denied outside Cloud Code master context', () => {
  const { registrations } = parseStub(); registerFiscal();
  for (const method of ['beforeSave', 'beforeDelete', 'beforeFind']) {
    for (const name of ['FiscalInvoice', 'FiscalLock', 'FiscalSequence']) {
      assert.throws(() => registrations[method + ':' + name]({ master: false }));
      assert.doesNotThrow(() => registrations[method + ':' + name]({ master: true }));
    }
  }
});
test('missing unique index blocks the operation even if schema-ready is incorrectly set', async () => {
  const { records } = parseStub(false); const repo = new ParseFiscalRepository();
  let called = false;
  await assert.rejects(repo.withLock('invoice', async () => { called = true; }), /Índice único/);
  assert.equal(called, false); assert.equal(records.size, 0);
});
test('working unique index permits the operation and releases its lock', async () => {
  const { records } = parseStub(); const repo = new ParseFiscalRepository();
  assert.equal(await repo.withLock('invoice', async () => 42), 42); assert.equal(records.size, 0);
});
test('public projection excludes provider payload, raw file paths and internal audit records', () => {
  const result = publicInvoice({ id: '1', payload: { secret: 'x' }, history: ['internal'], issuerCnpj: 'test',
    xmlPath: '/private.xml', pdfPath: '/private.pdf', snapshot: { taxFields: { serverOnly: true }, value: 10 } });
  assert.equal(result.canDownloadXml, true); assert.equal(result.summary.value, 10);
  for (const key of ['payload', 'history', 'xmlPath', 'pdfPath', 'issuerCnpj']) assert(!(key in result));
  assert(!('taxFields' in result.summary));
});
