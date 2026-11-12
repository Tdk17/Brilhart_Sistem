'use strict';
const { check, text, reference, prepare, buildPayload, normalizeResponse } = require('./domain');
const { requireReady } = require('./config');
class FiscalService {
  constructor(repository, provider, config) { this.repo = repository; this.provider = provider; this.config = config; }
  async preview(input) {
    requireReady(this.config);
    const service = await this.repo.service(text(input.serviceId, 'Serviço', 80));
    const client = await this.repo.client(service.clientId);
    return prepare(this.config, service, client, input);
  }
  async apply(invoice, response, actor, action) {
    const update = normalizeResponse(response, invoice.status);
    if (invoice.status === 'cancelled') update.status = 'cancelled';
    if (invoice.status === 'authorized' && !['authorized', 'cancelled', 'cancelling'].includes(update.status)) update.status = 'authorized';
    const merged = { ...invoice, status: update.status, providerStatus: update.providerStatus,
      message: update.message, lastCheckedAt: new Date().toISOString() };
    for (const key of ['number', 'verificationCode', 'protocol', 'xmlPath', 'pdfPath', 'consultationUrl']) if (update[key]) merged[key] = update[key];
    return this.repo.save(merged, actor, action);
  }
  async issue(input, actor) {
    requireReady(this.config);
    const ref = reference(this.config, text(input.serviceId, 'Serviço', 80));
    return this.repo.withLock(ref, async () => {
      let invoice = await this.repo.byReference(ref);
      if (invoice && !['rejected', 'not_sent'].includes(invoice.status)) return invoice;
      if (invoice?.status === 'rejected') {
        try { invoice = await this.apply(invoice, await this.provider.consult(invoice), actor, 'consult_before_retry'); }
        catch { throw new Error('Não foi possível confirmar a rejeição; consulte a nota antes de reenviar.'); }
        if (invoice.status !== 'rejected') return invoice;
      }
      const snapshot = await this.preview(input);
      if (invoice) check(invoice.mode === snapshot.mode && invoice.snapshot.series === snapshot.series,
        'O padrão fiscal ou a série mudou. Concilie a tentativa existente antes de reenviar.');
      check(input.previewHash === snapshot.previewHash, 'Os dados mudaram. Revise a nota novamente antes de emitir.');
      if (snapshot.mode === 'municipal') check(snapshot.competence === new Date().toISOString().slice(0, 10), 'Neste conector municipal, a competência deve ser a data de emissão.');
      if (!invoice) {
        invoice = await this.repo.create({ reference: ref, serviceId: snapshot.serviceId,
          clientId: snapshot.clientId, environment: snapshot.environment, mode: snapshot.mode,
          issuerCnpj: snapshot.issuer.cnpj, status: 'not_sent', snapshot,
          ...(snapshot.mode === 'national' ? { dpsNumber: await this.repo.nextDps(this.config) } : {}) }, actor);
      }
      const payload = buildPayload(snapshot, new Date().toISOString(), invoice.dpsNumber);
      invoice = await this.repo.save({ ...invoice, snapshot, payload, status: 'processing', message: '', lastAttemptAt: new Date().toISOString() }, actor, 'issue_requested');
      try {
        const result = await this.provider.send(invoice, payload);
        return await this.apply(invoice, result, actor, 'issue_response');
      } catch (e) {
        const definitelyNotSent = [400, 401, 403].includes(e.status);
        return this.repo.save({ ...invoice, status: definitelyNotSent ? 'not_sent' : 'unknown',
          message: e.message || 'Consulte a nota para confirmar a situação.' }, actor, 'issue_unconfirmed');
      }
    });
  }
  async refresh(id, actor) {
    const original = await this.repo.invoice(id);
    return this.repo.withLock(original.reference, async () => {
      const invoice = await this.repo.invoice(id);
      try { return await this.apply(invoice, await this.provider.consult(invoice), actor, 'consult'); }
      catch (e) {
        return this.repo.save({ ...invoice, message: e.status === 404
          ? 'Referência não localizada. Solicite conciliação fiscal antes de qualquer reenvio.'
          : e.message || 'Consulta indisponível.' }, actor, 'consult_failed');
      }
    });
  }
  async cancel(id, reason, actor) {
    reason = text(reason, 'Justificativa', 255);
    check(reason.length >= 15, 'A justificativa precisa ter pelo menos 15 caracteres.');
    const original = await this.repo.invoice(id);
    return this.repo.withLock(original.reference, async () => {
      let invoice = await this.repo.invoice(id);
      if (invoice.status === 'cancelled') return invoice;
      invoice = await this.apply(invoice, await this.provider.consult(invoice), actor, 'consult_before_cancel');
      if (invoice.status === 'cancelled') return invoice;
      check(invoice.status === 'authorized', 'Somente uma NFS-e autorizada pode ser cancelada.');
      invoice = await this.repo.save({ ...invoice, status: 'cancelling', cancellationReason: reason }, actor, 'cancel_requested');
      try {
        const result = await this.provider.cancel(invoice, reason);
        return await this.apply(invoice, result, actor, 'cancel_response');
      } catch (e) {
        return this.repo.save({ ...invoice, status: 'cancelling', message: 'Cancelamento sem confirmação. Consulte a nota. ' + (e.message || '') }, actor, 'cancel_unconfirmed');
      }
    });
  }
  async download(id, kind) {
    check(['xml', 'pdf'].includes(kind), 'Formato de documento inválido.');
    const invoice = await this.repo.invoice(id);
    check(['authorized', 'cancelled'].includes(invoice.status), 'Documento ainda não autorizado.');
    return this.provider.download(invoice, kind);
  }
}
module.exports = { FiscalService };
