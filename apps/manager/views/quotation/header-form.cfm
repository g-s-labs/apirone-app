<cfoutput>

	<div>

		<nav>
			<div class="nav nav-tabs" id="nav-tab" role="tablist">
				<button class="nav-link active" id="nav-general-tab" data-bs-toggle="tab" data-bs-target="##nav-general" type="button" role="tab">Dati generali</button>
				<button class="nav-link" id="nav-billing-tab" data-bs-toggle="tab" data-bs-target="##nav-billing" type="button" role="tab">Indirizzo di fatturazione</button>
				<button class="nav-link" id="nav-shipping-tab" data-bs-toggle="tab" data-bs-target="##nav-shipping" type="button" role="tab">Indirizzo di spedizione</button>
				<button class="nav-link" id="nav-fiscal-tab" data-bs-toggle="tab" data-bs-target="##nav-fiscal" type="button" role="tab">Dati fiscali</button>
				<!--- <button class="nav-link" id="nav-discount-tab" data-bs-toggle="tab" data-bs-target="##nav-discount" type="button" role="tab">Sconti/Costi</button> --->
				<button class="nav-link" id="nav-assignment-tab" data-bs-toggle="tab" data-bs-target="##nav-assignment" type="button" role="tab">Assegnatari</button>
				<button class="nav-link" id="nav-claim-tab" data-bs-toggle="tab" data-bs-target="##nav-claim" type="button" role="tab">Reclamo</button>
				<!--- <button class="nav-link" id="nav-plan-tab" data-bs-toggle="tab" data-bs-target="##nav-plan" type="button" role="tab" hidden>Planimentria</button> --->
				<!--- <button class="nav-link" id="nav-shippings-tab" data-bs-toggle="tab" data-bs-target="##nav-shippings" type="button" role="tab" hidden>Spedizioni</button> --->
			</div>
		</nav>
		<div class="tab-content" id="nav-tabContent">

			<!---
				general
			--->
			<div class="tab-pane quotation-panel fade show active row" id="nav-general" role="tabpanel">

				<div class="col-6 co-md-12">

					<div class="row d-flex align-items-center mb-3">
						<label class="col-3 text-end">Nome </label>
						<div class="col-9">
							<input type="text" name="name" id="quotationNameInput" class="form-control" data-bind="value: detailForm.data.name" required>
						</div>
					</div>

					<!----
					<div class="row d-flex align-items-center mb-3">
						<label class="col-3 text-end">Numero </label>
						<div class="col-9">
							<input type="text" name="quotationNumber" id="quotationNumberInput" class="form-control" data-bind="value: detailForm.data.quotationNumber">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="col-3 text-end">Versione </label>
						<div class="col-9">
							<input type="text" class="form-control" data-bind="value: detailForm.data.versionNumber" readonly>
						</div>
					</div>
					----->

					<div class="row d-flex align-items-center mb-3">
						<label class="col-3 text-end">Lingua </label>
						<div class="col-9">
							<select name="lang" class="form-control"
								data-bind="source: languages, value: detailForm.data.lang"
								data-value-field="id"
								data-text-field="name"
								required
							>
							</select>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Data prevista evasione</label>
						<div class="col-9">
							<input type="date" class="form-control"
								data-bind="value: detailForm.data.dataEvasione">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Rif. Libero</label>
						<div class="col-9">
							<input type="text" class="form-control" maxlength="100"
								data-bind="value: detailForm.data.rifLibero">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">PO</label>
						<div class="col-9">
							<input type="text" class="form-control" maxlength="50"
								data-bind="value: detailForm.data.po">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Settore </label>
						<div class="col-9">
							<input type="text" class="form-control" data-bind="value: detailForm.data.industryLabel" readonly>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3" data-bind="visible: detailForm.data.dataConfermaOrdine">
						<label class="text-end col-3">Data conferma ordine</label>
						<div class="col-9">
							<input type="date" class="form-control" data-bind="value: detailForm.data.dataConfermaOrdine" readonly>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Cliente </label>
						<div class="col-6">
							<input type="text" name="customer" class="form-control" id="qt-customer"
								data-bind="source: crmCustomers, value: detailForm.data.customer"
								data-text-field="displayLabel"
								data-role="autocomplete"
								data-value-primitive="false"
								data-minlength="4"
								data-filter="contains">
						</div>
						<div class="col-3">
							<input type="text" class="form-control" maxlength="15" placeholder="SDI"
								data-bind="value: detailForm.data.codiceSdi" readonly>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Opportunità</label>
						<div class="col-9">
							<input type="text" name="opportunity" class="form-control" id="qt-opportunity"
								data-bind="source: crmOpportunities, value: detailForm.data.opportunity"
								data-role="autocomplete"
								data-text-field="name"
								data-value-primitive="false"
								data-minlength="4"
								data-filter="contains"
							>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Lead</label>
						<div class="col-9">
							<input type="text" name="lead" class="form-control" id="qt-lead"
								data-bind="source: crmLeads, value: detailForm.data.lead"
								data-role="autocomplete"
								data-text-field="name"
								data-value-primitive="false"
								data-minlength="4"
								data-filter="contains"
							>
						</div>
					</div>

					<div class="row d-flex align-items-center">
						<label class="text-end col-3"></label>
						<div class="col-9">
							<input type="hidden" name="requireAnyOfCustomerLeadOrOpportunity">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Data documento</label>
						<div class="col-9">
							<input type="date" class="form-control"
								data-bind="value: detailForm.data.quotationDate">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Data validità</label>
						<div class="col-9">
							<input type="date" class="form-control"
								data-bind="value: detailForm.data.validityDate">
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Post-it</label>
						<div class="col-9">
							<textarea name="note" class="form-control" rows="2"
								data-bind="value: detailForm.data.note">
							</textarea>
						</div>
					</div>

					<div class="row d-flex align-items-center mb-3">
						<label class="text-end col-3">Referente amministrativo</label>
						<div class="col-9">
							<input type="text" class="form-control" maxlength="70"
								data-bind="value: detailForm.data.referenteAmministrativo">
						</div>
					</div>

				</div>

			</div>

			<!---
				billing
			--->
			<div class="tab-pane quotation-panel fade" id="nav-billing" role="tabpanel">

				<div class="row">
					<div class="col-6">

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Nome</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.name" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Ragione sociale</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.company" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Partita Iva</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.vatNumber" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Telefono</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.phone" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Indirizzo</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.street" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Città</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.city" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">CAP</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.postalCode" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Nazione</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.countryLabel" readonly>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Provincia</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.customer.state" readonly>
							</div>
						</div>

						<div class="mb-3 row" data-bind="visible: detailForm.data.id">
							<div class="col-sm-9 offset-sm-3 mt-1 fs-10 le-14">
								ID: <span data-bind="text: detailForm.data.customer.id"></span><br>
							</div>
						</div>

					</div>
				</div>

			</div>

			<!---
				shipping
			--->
			<div class="tab-pane quotation-panel fade" id="nav-shipping" role="tabpanel">

				<div class="row">
					<div class="col-6">

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Indirizzo</label>
							<div class="col-9">
								<select class="form-control" id="qt-shipping-profile"
									data-role="dropdownlist"
									data-bind="source: detailForm.data.customer.shippingProfiles"
									data-value-field="shortId"
									data-text-field="displayName"
								>
								</select>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Indirizzo</label>
							<div class="col-9">
								<input type="text" class="form-control" id="sp-street" disabled>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Città</label>
							<div class="col-9">
								<input type="text" class="form-control" id="sp-city" disabled>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">CAP</label>
							<div class="col-9">
								<input type="text" class="form-control" id="sp-postal-code" disabled>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Nazione</label>
							<div class="col-9">
								<input type="text" class="form-control" id="sp-country-iso" disabled>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Provincia</label>
							<div class="col-9">
								<input type="text" class="form-control" id="sp-state" disabled>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Referente spedizione</label>
							<div class="col-9">
								<input type="text" class="form-control" data-bind="value: detailForm.data.referenteSpedizione">
							</div>
						</div>

					</div>

				</div>

			</div>

			<!---
				dati fiscali
			--->
			<div class="tab-pane fade" id="nav-fiscal" role="tabpanel">

				<div class="row mb-3">

					<div class="col-6">

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Pagamento</label>
							<div class="col-9">
								<select name="paymentMethod" class="form-control"
									data-bind="source: paymentMethods, value: detailForm.data.paymentMethod"
									data-value-field="id"
									data-text-field="name"
								>
								</select>
							</div>
						</div>

						<!--- solo con pagamento 26 SCADENZE DA IMPUTARE ( syncCustomPaymentMethod ) --->
						<div class="form-group row mb-3" data-bind="visible: showCustomPaymentMethod">
							<label class="col-3 control-label text-sm-end pt-2">Modalità di pagamento</label>
							<div class="col-9">
								<input type="text" class="form-control" maxlength="255" data-bind="value: detailForm.data.customPaymentMethod">
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Aliquota IVA</label>
							<div class="col-9">
								<select name="paymentMethod" class="form-control"
									data-bind="source: vatCodes, value: detailForm.data.vatCode"
									data-value-field="id"
									data-text-field="name">
								</select>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Valuta</label>
							<div class="col-9">
								<select name="currency" class="form-control"
									data-bind="source: currencies, value: detailForm.data.currency"
									data-value-field="id"
									data-text-field="name">
								</select>
							</div>
						</div>

					</div>

				</div>

			</div>

			<!---
				claim ( fattura del reclamo )
			--->
			<div class="tab-pane fade" id="nav-claim" role="tabpanel">

				<div class="row mb-3">

					<div class="col-6">

						<!---
							Tendine a cascata ( anno -> numero -> alfa ) sulle fatture con partita
							aperta copiate da Verticale ( verticale_claim_invoices ): popolate in
							app-quotation-header.js ( refreshClaimLists ).
						--->
						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Anno fattura</label>
							<div class="col-9">
								<select id="qt-claim-anno" class="form-control qt-claim-ddl"
									data-role="dropdownlist"
									data-bind="source: claimAnni, value: detailForm.data.reclamoAnno"
									data-value-field="id"
									data-text-field="name"
									data-value-primitive="true">
								</select>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Numero fattura</label>
							<div class="col-9">
								<select id="qt-claim-numero" class="form-control qt-claim-ddl"
									data-role="dropdownlist"
									data-bind="source: claimNumeri, value: detailForm.data.reclamoNumero"
									data-value-field="id"
									data-text-field="name"
									data-value-primitive="true"
									data-filter="startswith">
								</select>
							</div>
						</div>

						<div class="form-group row mb-3">
							<label class="col-3 control-label text-sm-end pt-2">Alfa fattura</label>
							<div class="col-9">
								<select id="qt-claim-alfa" class="form-control qt-claim-ddl"
									data-role="dropdownlist"
									data-bind="source: claimAlfa, value: detailForm.data.reclamoAlfa"
									data-value-field="id"
									data-text-field="name"
									data-value-primitive="true">
								</select>
							</div>
						</div>

					</div>

				</div>

			</div>

			<!---
				assignment
			--->
			<div class="tab-pane fade" id="nav-assignment" role="tabpanel">

				<div class="row mb-3"><div class="offset-sm-3 col-sm-9"><p class="text-muted fst-italic small mb-0">Sono visibili solo gli account per i quali è stato compilato l'ID utente Verticale.</p></div></div>

				<div class="form-group row mb-3">
					<label class="col-sm-3 control-label text-sm-end pt-2">Commerciale</label>
					<div class="col-sm-9">
						<select name="saleUser" class="form-control"
							data-bind="source: saleUsers, value: detailForm.data.salesAgent"
							data-value-field="id"
							data-text-field="name">
						</select>
					</div>
				</div>

				<div class="form-group row mb-3">
					<label class="col-sm-3 control-label text-sm-end pt-2">Tecnico</label>
					<div class="col-sm-9">
						<select name="saleUser" class="form-control"
							data-bind="source: techUsers, value: detailForm.data.graphicTechnician"
							data-value-field="id"
							data-text-field="name">
						</select>
					</div>
				</div>

				<div class="row mb-3 mt-4"><div class="offset-sm-3 col-sm-9"><p class="text-muted fst-italic small mb-0">Sono visibili solo gli account per i quali è stato compilato l'ID agente Verticale.</p></div></div>

				<div class="form-group row mb-3">
					<label class="col-sm-3 control-label text-sm-end pt-2">Agenti</label>
					<div class="col-sm-9" style="margin-top: 6px;">
						Nessun agente
                		<input type="checkbox" name="nessunAgente" data-bind="checked: detailForm.data.nessunAgente" class="form-check-input" />
					</div>
				</div>

				<div data-bind="visible: showAgenti">
					<div class="form-group row mb-3 align-items-center">
						<label class="col-sm-3 control-label text-sm-end pt-2">Agente 1</label>
						<div class="col-sm-6">
							<select name="agente1" class="form-control"
								data-bind="source: agentiList, value: detailForm.data.agente1"
								data-value-field="id"
								data-text-field="name">
							</select>
						</div>
						<div class="col-sm-3">
							<div class="input-group">
								<input type="number" class="form-control" placeholder="Provv." min="0" max="100" step="0.01" autocomplete="off"
									data-bind="value: detailForm.data.commission1">
								<span class="input-group-text">%</span>
							</div>
						</div>
					</div>

					<div class="form-group row mb-3 align-items-center">
						<label class="col-sm-3 control-label text-sm-end pt-2">Agente 2</label>
						<div class="col-sm-6">
							<select name="agente2" class="form-control"
								data-bind="source: agentiList, value: detailForm.data.agente2, enabled: agente2Enabled"
								data-value-field="id"
								data-text-field="name">
							</select>
						</div>
						<div class="col-sm-3">
							<div class="input-group">
								<input type="number" id="agente-commission-2" class="form-control" placeholder="Provv." min="0" max="100" step="0.01" autocomplete="off"
									data-bind="value: detailForm.data.commission2">
								<span class="input-group-text">%</span>
							</div>
						</div>
					</div>

					<div class="form-group row mb-3 align-items-center">
						<label class="col-sm-3 control-label text-sm-end pt-2">Agente 3</label>
						<div class="col-sm-6">
							<select name="agente3" class="form-control"
								data-bind="source: agentiList, value: detailForm.data.agente3, enabled: agente3Enabled"
								data-value-field="id"
								data-text-field="name">
							</select>
						</div>
						<div class="col-sm-3">
							<div class="input-group">
								<input type="number" id="agente-commission-3" class="form-control" placeholder="Provv." min="0" max="100" step="0.01" autocomplete="off"
									data-bind="value: detailForm.data.commission3">
								<span class="input-group-text">%</span>
							</div>
						</div>
					</div>

					<div class="form-group row mb-3 align-items-center">
						<label class="col-sm-3 control-label text-sm-end pt-2">Agente 4</label>
						<div class="col-sm-6">
							<select name="agente4" class="form-control"
								data-bind="source: agentiList, value: detailForm.data.agente4, enabled: agente4Enabled"
								data-value-field="id"
								data-text-field="name">
							</select>
						</div>
						<div class="col-sm-3">
							<div class="input-group">
								<input type="number" id="agente-commission-4" class="form-control" placeholder="Provv." min="0" max="100" step="0.01" autocomplete="off"
									data-bind="value: detailForm.data.commission4">
								<span class="input-group-text">%</span>
							</div>
						</div>
					</div>

					<div class="form-group row mb-3 align-items-center">
						<label class="col-sm-3 control-label text-sm-end pt-2">Agente 5</label>
						<div class="col-sm-6">
							<select name="agente5" class="form-control"
								data-bind="source: agentiList, value: detailForm.data.agente5, enabled: agente5Enabled"
								data-value-field="id"
								data-text-field="name">
							</select>
						</div>
						<div class="col-sm-3">
							<div class="input-group">
								<input type="number" id="agente-commission-5" class="form-control" placeholder="Provv." min="0" max="100" step="0.01" autocomplete="off"
									data-bind="value: detailForm.data.commission5">
								<span class="input-group-text">%</span>
							</div>
						</div>
					</div>
				</div>

			</div>

		</div>

	</div>

</cfoutput>
<style>
	#quotation-status-history-grid {
		max-height: 500px !important;
		overflow-y: auto;
		overflow-x: hidden;
	}
</style>