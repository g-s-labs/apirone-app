<cfoutput>
	<div id="quotation-total-pricing-box" class="container py-3 quotation-totals-box">
		<div>
			<div class="d-flex hand justify-content-between" data-bind="click: collapseTotals">
				<div id="qt-totals-title">
					<h3 data-bind="text: detail.title"></h3>
				</div>
				<div 
					style="font-size: 1.5em;"
					id="qt-item-totals-symbol" 
					data-bind="text:detail.symbol"
					></div>
			</div>

			<div class="quotation-totals-content" id="quotation-totals-content" data-bind="invisible:detail.isCollapsed">
			
				<!--- 
					total princing
				--->
				<div id="quotation-totals-general-content">
					<div class="d-flex align-items-center justify-content-between" >
						<div>
							<div>Placche:</div>
							<span data-bind="text: pricing.counters.plates" data-format="n2"></span> pz 
							<br>
							<i data-bind="text: pricing.counters.platesTotalPrice" data-format="n2"></i>
						</div>
						<div>
							<div>Segnaletiche:</div>
							<span data-bind="text: pricing.counters.signages" data-format="n2"></span> pz 
							<br>
							<i data-bind="text: pricing.counters.signagesTotalPrice" data-format="n2"></i>
						</div>
						<div>
							<div>Accessori:</div>
							<span data-bind="text: pricing.counters.accessories" data-format="n2"></span> pz 
							<br>
							<i data-bind="text: pricing.counters.accessoriesTotalPrice" data-format="n2"></i>
						</div>
						<div>
							<div>Servizi:</div>
							<span data-bind="text: pricing.counters.articles" data-format="n2"></span> pz 
							<br>
							<i data-bind="text: pricing.counters.articlesTotalPrice" data-format="n2"></i>
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-8">Totale merce</div>
						<div class="col-4 text-end">
							<span data-bind="text: pricing.data.totalGoods" data-format="n2"></span> &euro;
						</div>
					</div>
					<div class="row mt-3 mb-2" style="color: yellow; text-decoration: underline;" data-bind="visible: showCosts">
						<div class="col-8">Costo produzione</div>
						<div class="col-4 text-end">
							<span data-bind="text: pricing.data.costs" data-format="n2"></span> &euro;
						</div>
					</div>
					<div class="row mt-3 mb-2 align-items-center d-flex">
						<div class="col-4">Sconti</div>
						<div class="col-4 d-flex align-items-center">
							<input class="form-control text-end me-1" name="discount1"
								placeholder="%" data-bind="value: pricing.data.discount1, enabled: canEdit">
								<span>%</span>
						</div>
						<div class="col-4 d-flex align-items-center">
							<input class="form-control text-end me-1" name="discount2" 
								placeholder="%" data-bind="value: pricing.data.discount2, enabled: canEdit">
								<span>%</span>
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-4 mt-2">Spese di trasporto</div>
						<div class="col-4">
							<input class="form-control" name="noteTrasporto" maxlength="20"
								placeholder="Note di trasporto" title="Note di trasporto ( max 20 caratteri )"
								data-bind="value: pricing.data.noteTrasporto, enabled: canEdit">
						</div>
						<div class="col-4 d-flex align-items-center">
							<input class="form-control text-end me-1" name="shippingCost" 
								placeholder="€" data-bind="value: pricing.data.shippingCost, enabled: canEdit">
								<span>&euro;</span>
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-8 mt-2">Subtotale</div>
						<div class="col-4 text-end">
							<span data-bind="text: pricing.data.subtotalBeforeFlat" data-format="n2"></span> &euro;
						</div>
					</div>
					<div class="row mt-3 mb-2" id="quotation-totals-flat-discount-row">
						<div class="col-8 mt-2">Sconto incondizionato</div>
						<div class="col-4 d-flex align-items-center">
							<input class="form-control text-end me-1" name="flatDiscount" 
								placeholder="€" data-bind="value: pricing.data.flatDiscount, enabled: canEdit">
							<span>&euro;</span>
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-8">Imponibile</div>
						<div class="col-4 text-end">
							<span data-bind="text: pricing.data.taxable" data-format="n2"></span> &euro;
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-8">Iva <span data-bind="text: pricing.data.vatPercentage"></span>%</div>
						<div class="col-4 text-end">
							<span data-bind="text: pricing.data.vatAmount" data-format="n2"></span> &euro;
						</div>
					</div>
					<div class="row mt-3 mb-2">
						<div class="col-6"><b>TOTALE</b></div>
						<div class="col-6 text-end fs-16" >
							<b><span data-bind="text: pricing.data.total" data-format="n2"></span> &euro;</b>
						</div>
					</div>
					<div class="d-flex justify-content-end gap-2">
						<div class="py-2 text-end d-flex align-items-center gap-2">
							<div class="status" id="quotation-totals-general-loading"></div>
							#button(bind="click:updateTotals, enabled: canEdit", variant="default", label="Salva", size="sm", icon="fa-save")#
						</div>
					</div>
				</div>			

			</div>
		</div>
	</div>
</cfoutput>