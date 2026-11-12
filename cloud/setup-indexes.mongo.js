// Execute with mongosh ONLY on the intended Back4App application's database.
// Create Parse classes/fields and deny all CLP first, as described in docs/FISCAL_MODULE.md.
// Existing duplicates must be reconciled; never delete fiscal invoices to force an index.
db.FiscalInvoice.createIndex({ reference: 1 }, { name: 'fiscal_reference_unique', unique: true });
db.FiscalLock.createIndex({ key: 1 }, { name: 'fiscal_lock_unique', unique: true });
db.FiscalSequence.createIndex({ key: 1 }, { name: 'fiscal_sequence_unique', unique: true });
db.FiscalInvoice.createIndex({ 'data.serviceId': 1, _created_at: -1 });
db.FiscalInvoice.createIndex({ 'data.status': 1, _created_at: -1 });
