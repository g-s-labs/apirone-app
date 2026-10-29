AP.namespace("quotation");

Object.assign(AP.quotation.fields, {
	detailRoot: $("#quotation-detail-root"),
	detailForm: $("#quotation-detail-header-form"),
	zonesModalRoot: $("#zones-modal-root"),
	zoneModalRoot: $("#zone-modal-root"),
	printModalRoot: $("#print-modal-root"),
	statusModalRoot: $("#qt-status-modal-root"),
	documentsModalRoot: $("#qt-documents-modal-root"),
	exportResultModalRoot: $("#qt-export-result-modal-root"),
	totalItemBox: $("#quotation-totals-item"),

	addPlateBtn: $("#qt-add-plate"),
	addSignageBtn: $("#qt-add-signage"),
	addAccessoryBtn: $("#qt-add-accessory"),
	addArticleBtn: $("#qt-add-article"),
});

$(document).ready(function () {
	if (AP.quotation.fields.detailRoot.length) {
		AP.quotation.detail.init();
	}

	["signage-modal", "plate-modal-root", "accessory-modal", "article-modal"].forEach(id => {
		document.getElementById(id)?.addEventListener("hide.bs.modal", () => {
			$('#quotation-total-pricing-box').show()
			AP.quotation.detail.showTotals();
			// Rimuove l'hash dall'URL quando si chiude la modale
			if (window.location.hash) {
				window.history.replaceState(null, null, window.location.pathname + window.location.search);
			}
		});
		document.getElementById(id)?.addEventListener("show.bs.modal", () => {
			$('#quotation-total-pricing-box').hide()
		});
	});

	// Preventivo non modificabile: le modali dei prodotti si aprono in sola lettura.
	// Il CSS ( .qt-readonly in style.css ) nasconde i pulsanti che modificano e blocca
	// il mouse su campi e widget; qui si blocca anche la tastiera ( readonly e niente
	// tab ), a ogni apertura perché parte del contenuto viene ridisegnato.
	if (AP.page.canEdit === false) {
		["signage-modal", "plate-modal-root", "accessory-modal", "article-modal-root"].forEach(id => {
			var modal = document.getElementById(id);
			if (!modal) return;
			modal.classList.add("qt-readonly");
			modal.addEventListener("shown.bs.modal", () => {
				var $modal = $(modal);
				$modal.find("input:not([type=hidden]), textarea").attr("readonly", true);
				$modal.find("input, select, textarea, .k-picker, .k-input, [role=combobox], [role=listbox]").attr("tabindex", -1);
			});
		});
	}
});

AP.quotation.detail = (function () {
	var pub = {};
	var fields = AP.quotation.fields;

	function signageApp() {
		return AP.signage.modal;
	}

	function plateApp() {
		return AP.plate.modal;
	}

	function accessoryApp() {
		return AP.accessory.modal;
	}

	function articleApp() {
		return AP.article.modal;
	}

	function headerApp() {
		return AP.quotation.header;
	}

	function statusApp() {
		return AP.quotation.status;
	}

	function pricingApp() {
		return AP.quotation.totalPricing;
	}

	var initSortable = function () {
		if (!AP.page.canEdit) return;

		["qt-items-plate", "qt-items-signage", "qt-items-accessory"].forEach(function (id) {
			var $el = $("#" + id);
			if (!$el.length) return;

			if ($el.hasClass("ui-sortable")) {
				$el.sortable("destroy");
			}

			$el.sortable({
				items: "> .quotation-item",
				handle: ".qt-item-drag-handle",
				cursor: "grabbing",
				opacity: 0.75,
				tolerance: "pointer",
				forcePlaceholderSize: true,
				placeholder: "quotation-item m-1 col-md-3 qt-sort-placeholder",
				start: function (e, ui) {
					ui.placeholder.height(ui.item.outerHeight());
				},
				stop: function () {
					var ids = $el.find(".quotation-item").map(function () {
						return $(this).data("id");
					}).get().filter(Boolean);

					NM.util.ajax({
						method: "POST",
						url: "/manager/ajax/quotation-items/reorder",
						loading: false, // in sfondo: niente spinner globale
						data: JSON.stringify({ ids: ids }),
						callback: {
							done: function (xhr) {
								if (xhr.status === "INVALID") { NM.form.showMessages(xhr.data); }
							}
						}
					});
				}
			});
		});
	};

	/*
	 * Stato "sto caricando le righe": spinner sopra le liste, tab Placche/Segnaletiche/
	 * Accessori/Servizi disabilitati e liste attenuate. Un contatore gestisce le richieste
	 * sovrapposte (es. cambio tab rapido): lo spinner sparisce quando finisce l'ultima.
	 */
	var itemsLoadingCount = 0;
	/*
	 * Richieste righe in volo, per URL. All'apertura la stessa lista viene chiesta due
	 * volte (checkUrlTab o click sul tab, e il callback di getZones): la seconda chiamata
	 * viene saltata invece di far partire due letture parallele che si rallentano a vicenda.
	 */
	var itemsRequestsInFlight = {};
	var setItemsLoading = function (loading) {
		itemsLoadingCount = Math.max(0, itemsLoadingCount + (loading ? 1 : -1));
		var active = itemsLoadingCount > 0;
		$("#quotation-items-loader").toggle(active);
		$("#nav-plate-tab, #nav-signage-tab, #nav-accessory-tab, #nav-article-tab").prop("disabled", active);
		$("#nav-tabContent .tab-pane").css({ opacity: active ? 0.4 : "", pointerEvents: active ? "none" : "" });
		// cursore "vietato" e tab attenuati (regole in quotation.css) + spinner piccolo sul tab che sta caricando
		$("#nav-tab").toggleClass("items-loading", active);
		$("#nav-tab .tab-loading-spinner").remove();
		if (active) {
			$("#nav-" + viewModel.get("typeId") + "-tab").append('<span class="spinner-border spinner-border-sm ms-2 tab-loading-spinner" role="status" aria-hidden="true"></span>');
		}
	};

	/*
		Avviso "articoli senza prezzo" (banner sopra i tab + icona sui tab): le righe si
		caricano un tab alla volta, quindi il conteggio su tutto il preventivo arriva dal
		server. Richiamata a ogni loadItems() (apertura pagina, salvataggi, eliminazioni,
		"Aggiorna tutti i prezzi").
	*/
	var missingPriceTypeLabels = { plate: "Placche", signage: "Segnaletiche", accessory: "Accessori" };

	var refreshMissingPrices = function () {
		NM.util.ajax({
			method: "GET",
			url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/missing-prices",
			callback: {
				done: function (xhr) {
					var data = xhr.data || {};
					var byType = data.byType || {};

					$("#nav-tab .qt-tab-missing-price-icon").remove();
					var parts = [];
					Object.keys(missingPriceTypeLabels).forEach(function (type) {
						var count = byType[type];
						if (!count) return;
						$("#nav-" + type + "-tab").append('<i class="fas fa-exclamation-triangle qt-tab-missing-price-icon" title="Articoli senza prezzo"></i>');
						parts.push('<a data-missing-price-type="' + type + '">' + missingPriceTypeLabels[type] + ": " + count + "</a>");
					});

					$("#qt-missing-prices-detail").html(parts.join(", "));
					$("#qt-missing-prices-alert").toggleClass("d-none", !data.total);
				}
			}
		});
	};

	// Click su una voce dell'avviso: apre il tab corrispondente.
	// Non si può simulare il click sul tab con .click(): jQuery esegue prima l'handler
	// Kendo (changeType -> loadItems), che disabilita subito i tab (setItemsLoading), e
	// solo dopo il click nativo, che Bootstrap ignora sul bottone ormai disabilitato:
	// cambiava la querystring ma il tab restava quello di prima. Quindi: prima si mostra
	// il tab con l'API Bootstrap, poi si carica con changeType.
	$(document).on("click", "#qt-missing-prices-alert [data-missing-price-type]", function () {
		var tabButton = document.getElementById("nav-" + $(this).data("missing-price-type") + "-tab");
		if (!tabButton || tabButton.disabled) return;
		bootstrap.Tab.getOrCreateInstance(tabButton).show();
		viewModel.changeType({ currentTarget: tabButton });
	});

	/*
		?highlight=<quotationItemId>,<quotationItemId> (es. link "elementi in uso" dal prodotto):
		dopo il caricamento delle righe scorre alla prima indicata e le evidenzia. Si applica
		una volta sola, al primo caricamento in cui almeno una delle righe è nel DOM.
	*/
	var pendingHighlightIds = [];

	var applyPendingHighlight = function () {
		if (!pendingHighlightIds.length) return;

		var cards = $(".quotation-item").filter(function () {
			return pendingHighlightIds.includes(String($(this).data("id")));
		});
		if (!cards.length) return;

		pendingHighlightIds = [];
		cards.addClass("qt-item-highlight");
		cards.get(0).scrollIntoView({ behavior: "smooth", block: "center" });
	};

	var setQuotationItems = function (items, typeId) {
		if (!typeId) typeId = viewModel.get("typeId");

		if (typeId == "plate") {
			viewModel.set("quotationItemsPlate", items);
		}

		if (typeId == "signage") {
			viewModel.set("quotationItemsSignage", items);
		}

		if (typeId == "accessory") {
			viewModel.set("quotationItemsAccessory", items);
		}

		if (typeId == "article") {
			viewModel.set("quotationItemsArticle", items);
		}

	};

	var getQuotationItems = function (items) {

		var typeId = viewModel.get("typeId");

		if (typeId == "plate") {
			return viewModel.get("quotationItemsPlate");
		}

		if (typeId == "signage") {
			return viewModel.get("quotationItemsSignage");
		}

		if (typeId == "accessory") {
			return viewModel.get("quotationItemsAccessory");
		}

		if (typeId == "article") {
			return viewModel.get("quotationItemsArticle");
		}

	};


	var viewModel = kendo.observable({
		typeId: "plate",
		showCosts: AP.getUserPref("showCosts"),
		detailForm: {
			data: {
				zone: {
					id: ""
				},
			},
		},
		canEdit: AP.page.canEdit,
		canSee: AP.page.canSee,
		canRevise: AP.page.canRevise || false,
		canExport: AP.page.canExport || false,

		target: null,
		zones: new kendo.data.DataSource(),

		quotationItemsArticle: new kendo.data.DataSource({}),
		quotationItemsPlate: new kendo.data.DataSource({}),
		quotationItemsSignage: new kendo.data.DataSource({}),
		quotationItemsAccessory: new kendo.data.DataSource({}),

		showItems: function () {
			return getQuotationItems().total() > 0;
		},

		hideItems: function () {
			return getQuotationItems().total() == 0;
		},

		crmCustomers: new kendo.data.DataSource({
			serverFiltering: true,
			transport: {
				read: {
					url: "/manager/ajax/quotations/crmcustomers/",
					data: {
						str: function () {
							return $("#customer").val();
						},
					}
				}
			},
			schema: {
				data: function (xhr) {
					return xhr.data;
				}
			}
		}),

		crmOpportunities: new kendo.data.DataSource({
			serverFiltering: true,
			transport: {
				read: {
					url: "/manager/ajax/quotations/crmopportunities/",
					data: {
						str: function () {
							return $("#opportunity").val();
						},
					}
				}
			},
			schema: {
				data: function (xhr) {
					return xhr.data;
				}
			}
		}),

		crmLeads: new kendo.data.DataSource({
			serverFiltering: true,
			transport: {
				read: {
					url: "/manager/ajax/quotations/crmleads/",
					data: {
						str: function () {
							return $("#lead").val();
						},
					}
				}
			},
			schema: {
				data: function (xhr) {
					return xhr.data.map(item => ({
						...item,
						fullName: `${item.firstName} ${item.lastName}`
					}));
				}
			}
		}),
		list: function () {
			window.location.href = "/manager/quotations";
		},

		showHeader: function () {
			headerApp().edit(AP.page.quotation.id);
		},

		export: function () {
			viewModel.runExport({
				url: "/manager/ajax/quotations-export/" + AP.page.quotation.id,
				title: "Risultato esportazione preventivo",
				errorMessage: "Errore durante l'esportazione del preventivo.",
				onSuccess: function () {
					$(".export-button").hide();
					AP.widget.notify("success", "Preventivo esportato e convertito in ordine.");
					// lo stato è passato a "Convertito in ordine": alla chiusura del
					// riepilogo si ricarica la pagina ( stato e blocco aggiornati )
					$(AP.quotation.fields.exportResultModalRoot).one("hidden.bs.modal", function () {
						window.location.reload();
					});
				}
			});
		},

		// Esportazione verso Verticale: il server esporta prima gli articoli e poi
		// il preventivo, e restituisce entrambi i risultati per la modale di riepilogo.
		runExport: function (options) {
			AP.loading.show();
			NM.util.ajax({
				method: "GET",
				url: options.url,
				callback: {
					done: function (xhr) {
						AP.loading.hide();
						if (xhr.status == "INVALID") {
							NM.form.showMessages(xhr.data);
							return;
						}
						var failed = !!(xhr.data.error || xhr.data.success == false);
						if (failed) {
							AP.widget.notify("error", xhr.data.error ? xhr.data.error : options.errorMessage);
							// senza il risultato degli articoli non c'è niente da riepilogare
							if (!xhr.data.products) {
								return;
							}
						} else {
							options.onSuccess();
						}
						viewModel.renderExportResult(xhr.data, options.title);
						NM.util.openModal(AP.quotation.fields.exportResultModalRoot);
					},
					fail: function () {
						AP.loading.hide();
					}
				}
			});
		},

		renderExportResult: function (data, title) {
			var esc = function (value) {
				return $("<div>").text(value == null ? "" : String(value)).html();
			};
			var num = function (value) {
				return kendo.toString(Number(value) || 0, "n2");
			};

			$("#qt-export-result-title").text(title);

			// Preventivo: testata e righe scritte su ORDINI_APIR
			var $quotation = $("#qt-export-quotation");
			if (data.success == false) {
				$quotation.html("<div class='alert alert-danger mb-0'>Preventivo non scritto su Verticale: " + esc(data.error || "errore sconosciuto") + "</div>");
			} else {
				var header = data.header || {};
				var rows   = data.rows || [];
				var fields = [
					["Numero documento", header.number],
					["Seriale", header.serial],
					["Cliente", header.company],
					["Codice cliente", header.customerId],
					["Partita IVA", header.vatNumber],
					["Indirizzo fatturazione", header.billingAddress],
					["Destinazione", header.shippingCompany],
					["Indirizzo spedizione", header.shippingAddress],
					["Referente spedizione", header.shippingContact],
					["Riferimento", header.reference],
					["PO", header.po],
					["Fattura reclamo", header.claim],
					["Data evasione", header.deliveryDate],
					["Agente", header.agent],
					["Pagamento", header.paymentMethod],
					["Aliquota IVA", header.vatCode],
					["Sconti testata", num(header.discount1) + " + " + num(header.discount2) + " %"],
					["Spese trasporto", num(header.shippingCost)]
				];
				var html = "<table class='table table-sm mb-3'><tbody>" + fields.map(function (f) {
					return "<tr><th style='width: 30%;'>" + f[0] + "</th><td>" + esc(f[1]) + "</td></tr>";
				}).join("") + "</tbody></table>";

				html += "<p class='mb-1'><strong>Righe scritte (" + rows.length + "):</strong></p>";
				if (rows.length) {
					html += "<table class='table table-sm table-striped mb-0'><thead><tr>" +
						"<th>Riga</th><th>Articolo</th><th>Variante</th><th>Colore</th>" +
						"<th class='text-end'>Qtà</th><th class='text-end'>Prezzo</th><th class='text-end'>Sc. 1</th><th class='text-end'>Sc. 2</th><th>Note</th>" +
						"</tr></thead><tbody>" + rows.map(function (r) {
							return "<tr><td>" + esc(r.row) + "</td><td>" + esc(r.code) + "</td><td>" + esc(r.variant) + "</td><td>" + esc(r.color) + "</td>" +
								"<td class='text-end'>" + num(r.quantity) + "</td><td class='text-end'>" + num(r.price) + "</td>" +
								"<td class='text-end'>" + num(r.discount1) + "</td><td class='text-end'>" + num(r.discount2) + "</td>" +
								"<td>" + esc(r.note) + "</td></tr>";
						}).join("") + "</tbody></table>";
				} else {
					html += "<p class='text-muted mb-0'>Nessuna riga.</p>";
				}
				$quotation.html(html);
			}

			// Articoli: esportati in questo giro o già presenti su Verticale
			var products = data.products || {};
			var exported = products.exportedItems || [];
			var skipped  = products.skippedItems  || [];

			if (exported.length) {
				$("#qt-export-products-exported").html(
					"<p class='mb-1'><strong>Esportati (" + exported.length + "):</strong></p>" +
					"<ul class='mb-0'>" + exported.map(function (c) { return "<li>" + esc(c) + "</li>"; }).join("") + "</ul>"
				);
			} else {
				$("#qt-export-products-exported").html("<p class='text-muted mb-0'>Nessun nuovo articolo esportato.</p>");
			}

			if (skipped.length) {
				$("#qt-export-products-skipped").html(
					"<hr class='my-3'>" +
					"<p class='mb-1'><strong>Già presenti (" + skipped.length + "):</strong></p>" +
					"<ul class='mb-0'>" + skipped.map(function (c) { return "<li>" + esc(c) + "</li>"; }).join("") + "</ul>"
				);
			} else {
				$("#qt-export-products-skipped").html("");
			}
		},

		export3dPlates: function () {
			AP.loading.show();
			NM.util.ajax({
				method: "GET",
				url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/plates-export3d",
				callback: {
					done: function (xhr) {
						AP.loading.hide();
						if (xhr.status == "INVALID") {
							NM.form.showMessages(xhr.data);
							return;
						}
						var $modal = $("#qt-export3d-modal");
						$("#qt-export3d-text", $modal).val(JSON.stringify(xhr.data, null, 2));
						var modal = bootstrap.Modal.getOrCreateInstance($modal[0]);
						modal.show();
					},
					fail: function () {
						AP.loading.hide();
					}
				}
			});
		},

		// stesso JSON di export3dPlates ( array di tutte le placche ), scaricato come file
		downloadPlatesJson: function (event) {
			var fileName = $(event.currentTarget).data("file-name") || "placche.json";
			AP.loading.show();
			NM.util.ajax({
				method: "GET",
				url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/plates-export3d",
				callback: {
					done: function (xhr) {
						AP.loading.hide();
						if (xhr.status == "INVALID") {
							NM.form.showMessages(xhr.data);
							return;
						}
						var blob = new Blob([JSON.stringify(xhr.data, null, 2)], { type: "application/json" });
						var url = URL.createObjectURL(blob);
						var a = document.createElement("a");
						a.href = url;
						a.download = fileName;
						document.body.appendChild(a);
						a.click();
						document.body.removeChild(a);
						setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
					},
					fail: function () {
						AP.loading.hide();
					}
				}
			});
		},

		changeType: function (event) {

			var target = $(event.currentTarget);
			var type = target.data("type");

			viewModel.set("typeId", type);
			viewModel.loadItems();

			// Aggiorna l'URL con il tab attivo
			var url = new URL(window.location);
			url.searchParams.set("tab", type);
			window.history.pushState({}, "", url);
		},

		getImageSrc: function (event) {

			const uri = event.image?.uri || "";

			if (uri.toLowerCase().endsWith(".svg")) {
				return uri;
			}

			if (uri != "") {
				var replaced = uri.replace("_ori", "500");
				return replaced;
			}

			return "/assets/main/img/img-not-found.png";
		},

		callback: {
			onCreate: undefined,
			onUpdate: undefined,
			onLoad: undefined,
		},

		loadInvoiceStates: function () {
			var country = this.detailForm.data.invoiceData.country;
			if (country && country.id) {
				this.filteredInvoiceStates.data([]);
				var that = this;
				viewModel.states.fetch(function () {
					var data = that.states.data().filter(function (item) {
						return item.countryId == country.id;
					});
					that.filteredInvoiceStates.data(data);
					if (data.length == 1) {
						that.detailForm.data.invoiceData.state = {id: data[0].id};
					} else {
						that.detailForm.data.invoiceData.state = {id: ""};
					}
				});
			} else {
				this.filteredInvoiceStates.data([]);
				this.detailForm.data.invoiceData.state = {id: ""};
			}
		},

		loadShipmentStates: function () {
			var country = this.detailForm.data.shipmentData.country;
			if (country && country.id) {
				this.filteredShipmentStates.data([]);
				var that = this;
				viewModel.states.fetch(function () {
					var data = that.states.data().filter(function (item) {
						return item.countryId == country.id;
					});
					that.filteredShipmentStates.data(data);
					if (data.length == 1) {
						that.detailForm.data.shipmentData.state = {id: data[0].id};
					} else {
						that.detailForm.data.shipmentData.state = {id: ""};
					}
				});
			} else {
				this.filteredShipmentStates.data([]);
				this.detailForm.data.shipmentData.state = {id: ""};
			}
		},

		delete: function (event) {
			event.stopPropagation();
			var itemId = event.currentTarget.dataset.id;

			bootbox.confirm({
				title: "Conferma eliminazione",
				message: "Sei sicuro di voler cancellare questa riga del preventivo?",
				buttons: {
					confirm: {
						label: "Si, confermo",
						className: "btn-primary",
					},
					cancel: {
						label: "No, chiudi",
						className: "btn-danger",
					},
				},
				callback: function (result) {
					if (result) {
						AP.loading.show()
						NM.util.ajax({
							method: "DELETE",
							url: "/manager/ajax/quotation-items",
							data: itemId,
							callback: {
								done: function (xhr) {
									AP.loading.hide()
									if (xhr.status == "INVALID") {
										NM.form.showMessages(xhr.data);
										return;
									}

									AP.widget.notify("success", "Riga cancellata correttamente.");
									var urlParams = new URLSearchParams(window.location.search);
									var tabParam = urlParams.get("tab");
									if (tabParam && tabParam != '') {
										window.location.href = "/manager/quotations/" + AP.page.quotation.id + "?tab=" + tabParam;
									} else {
										window.location.href = "/manager/quotations/" + AP.page.quotation.id;
									}
								}
							}
						});
					}
				},
			});

			return false;
		},

		approveQuotation: function (event) {
			event.stopPropagation();

			var maxAmount = AP.page.userRole ? parseFloat(AP.page.userRole.quotationMaxAmount) : 0;
			var pricingData = {};
			try { pricingData = AP.quotation.totalPricing.getTotals() || {}; } catch(e) {}
			var currentTotal = parseFloat(pricingData.total) || 0;
			var needsEscalation = maxAmount > 0 && currentTotal > maxAmount;

			var fmt = function(n) { return Number(n).toLocaleString('it-IT', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €"; };

			bootbox.confirm({
				size: 'large',
				title: needsEscalation ? "Richiesta approvazione superiore" : "Conferma approvazione",
				message: needsEscalation
					? "Il totale del preventivo (" + fmt(currentTotal) + ") supera il tuo massimale (" + fmt(maxAmount) + "). Vuoi inviare la richiesta di approvazione a un superiore?"
					: "Sei sicuro di voler approvare questo preventivo?",
				buttons: {
					confirm: {
						label: needsEscalation ? "Sì, invia richiesta" : "Sì, confermo",
						className: "btn-primary",
					},
					cancel: {
						label: "No, chiudi",
						className: "btn-danger",
					},
				},
				callback: function (result) {
					if (result) {
						AP.loading.show()
						NM.util.ajax({
							method: "GET",
							url: "/manager/ajax/quotations_approve/" + AP.page.quotation.id,
							callback: {
								done: function (xhr) {
									AP.loading.hide()
									const status = xhr.status ? xhr.status.toLowerCase() : 'error'
									AP.widget.notify(status, xhr.data.message)
									if (status == 'success') {
										setTimeout(() => {
											window.location.reload()
										}, 2000)
									}
								}
							}
						});
					}
				},
			});

			return false;
		},

		markAsSent: function (event) {
			event.stopPropagation();
			bootbox.confirm({
				size: 'large',
				title: "Invia a cliente",
				message: "Sei sicuro di voler contrassegnare questo preventivo come inviato al cliente? Il preventivo diventerà non modificabile.",
				buttons: {
					confirm: { label: "Sì, invia", className: "btn-success" },
					cancel: { label: "Annulla", className: "btn-secondary" },
				},
				callback: function (result) {
					if (!result) return;
					AP.loading.show();
					NM.util.ajax({
						method: "POST",
						url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/markasSent",
						callback: {
							done: function (xhr) {
								AP.loading.hide();
								const status = xhr.status ? xhr.status.toLowerCase() : 'error';
								AP.widget.notify(status, xhr.data.message);
								if (status === 'success') {
									setTimeout(() => { window.location.reload(); }, 1500);
								}
							}
						}
					});
				},
			});
			return false;
		},

		createRevision: function (event) {
			event.stopPropagation();
			// righe con elementi non più a catalogo: non vengono copiate, si avvisa prima
			AP.loadNotInCatalog(AP.page.quotation.id, function (labels) {
				bootbox.confirm({
					size: 'large',
					title: "Crea revisione",
					message: ( AP.page.lockReason
						? "Questo preventivo " + AP.page.lockReason + ". Per modificarlo verrà creata una revisione con numero di versione incrementato. Il preventivo originale resterà bloccato. Procedere?"
						: "Verrà creata una revisione di questo preventivo con numero di versione incrementato. Procedere?" )
						+ ( labels.length ? AP.notInCatalogMessage( labels, "Le righe che li usano non verranno copiate nella revisione." ) : "" ),
					buttons: {
						confirm: { label: "Sì, crea revisione", className: "btn-warning" },
						cancel: { label: "Annulla", className: "btn-secondary" },
					},
					callback: function (result) {
						if (!result) return;
						AP.loading.show();
						NM.util.ajax({
							method: "POST",
							url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/createrevision",
							callback: {
								done: function (xhr) {
									AP.loading.hide();
									const status = xhr.status ? xhr.status.toLowerCase() : 'error';
									if (status === 'success' && xhr.data.payload && xhr.data.payload.id) {
										AP.widget.notify('success', xhr.data.message);
										setTimeout(() => {
											window.location.href = "/manager/quotations/" + xhr.data.payload.id;
										}, 1500);
									} else {
										AP.widget.notify('error', xhr.data.message || 'Errore durante la creazione della revisione.');
									}
								}
							}
						});
					},
				});
			});
			return false;
		},

		save: function (event) {
			var detailFormDom = AP.quotation.fields.detailForm;

			detailFormDom.validate({
				onfocusout: function (element) {
					$(element).valid();
				},
				rules: {
					name: {
						required: true
					},
					number: {
						required: true
					},
					langId: {
						required: true
					},
					validityDate: {
						required: true
					},
					requireAnyOfCustomerLeadOrOpportunity: {
						required: function () {

							// almeno uno dei

							var leadId = viewModel.get("detailForm.data.lead.id");
							var customerId = viewModel.get("detailForm.data.customer.id");
							var opportunityId = viewModel.get("detailForm.data.opportunity.id");

							if (customerId || leadId || opportunityId) {
								return false;
							}

							return true;
						}
					},
				},
				messages: {
					name: {
						required: "Nome richiesto.",
					},
					number: {
						required: "Numero richiesto."
					},
					langId: {
						required: "Lingua richiesta."
					},
					validityDate: {
						required: "Data validità richiesta."
					},

					requireAnyOfCustomerLeadOrOpportunity: {
						required: "Compilare almeno un campo fra cliente, lead o opportunità"
					}

				}
			});

			if (detailFormDom.valid()) {
				const parsedData = viewModel.get("detailForm.data");

				NM.util.ajax({
					method: "POST",
					url: "/manager/ajax/quotations",
					data: JSON.stringify(parsedData),
					callback: {
						done: function (xhr) {

							AP.widget.notify("success", "Preventivo salvato correttamente.");
							viewModel.set("detailForm", defaultDetailForm);
							// window.location.href = "/manager/quotations/" + xhr.data.payload.ID;

						}
					}
				});
			}

			return false;
		},

		getZones: async function (e) {

			if (AP.page.quotation?.id) {

				await NM.util.ajax({
					method: "GET",
					url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/zones",
					callback: {
						done: function (xhr) {
							if (xhr.data.length) {
								var zones = xhr.data;
							} else {
								var zones = [];
							}

							zones.unshift(
								{
									"id": "",
									"name": "-- Tutte le zone",
									"quantity": 1
								}
							)

							zones.forEach(function (zone) {
								if (zone.origin) {
									zone.name = "\u00A0\u00A0- " + zone.name;
								}
							});

							viewModel.get("zones").data(zones);

							viewModel.set("detailForm.data.zones", zones);
							viewModel.loadItems();
						}
					}
				});

			}

			return false;
		},

		loadItems: function (e) {
			if (e && e.currentTarget && e.currentTarget.id == 'zones-selector') {
				AP.setUserPref("quotation." + AP.page.quotation.id + ".zone.id", viewModel.detailForm.data.zone.id);
				AP.setUserPref("quotation." + AP.page.quotation.id + ".zone.name", viewModel.detailForm.data.zone.name);
			}
			var typeId = viewModel.get("typeId");

			var url = "/manager/ajax/quotations/" + AP.page.quotation.id + "/items/" + typeId;

			if (AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.id") && AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.id") != '' && AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.name") != "-- Tutte le zone") {
				url = url + "?quotationZoneId=" + AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.id");
			}

			if (itemsRequestsInFlight[url]) {
				return false;
			}
			itemsRequestsInFlight[url] = true;

			var requestTypeId = typeId;
			setItemsLoading(true);
			// Svuota subito la lista del tab richiesto: durante il caricamento non si devono
			// vedere le righe del caricamento precedente (es. le 22 placche di prima).
			setQuotationItems([], requestTypeId);
			NM.util.ajax({
				method: "GET",
				url: url,
				callback: {
					done: function (xhr) {
						for (row in xhr.data) {
							if (xhr.data[row].note) {
								xhr.data[row].note_short = xhr.data[row].note.substr(0, 23)
							}
						}
						xhr.data.forEach(function (item) {
							item.special = item.special == 'true'
							item.bozza = item.bozza == 'true'
						})

						setQuotationItems(xhr.data, requestTypeId);
						setTimeout(initSortable, 150);
						setTimeout(applyPendingHighlight, 200);
						refreshMissingPrices();
					}
				}
			}).always(function () {
				// anche in caso di errore: mai lasciare i tab bloccati
				delete itemsRequestsInFlight[url];
				setItemsLoading(false);
			});

			return false;
		},

		setQuotation: function (quotation) {
			viewModel.set("detailForm.data", quotation);
		},

		// add

		addPlate: function () {
			plateApp().new();
			return false;
		},

		addSignage: function () {
			signageApp().new();
			return false;
		},

		addAccessory: function () {
			accessoryApp().new();
			return false;
		},

		addArticle: function () {
			articleApp().new();
			return false;
		},

		// edit

		edit: function (event) {
			viewModel.openItemEditor(event.data.id);
			event.preventDefault();
		},

		// Apre la modale di modifica della riga con l'id dato, in base al tab corrente
		// (placca, accessorio, segnaletica, servizio). Usata dal pulsante "Modifica"
		// e dopo la duplicazione come copia, per aprire subito la riga appena creata.
		openItemEditor: function (id) {
			AP.loading.show();
			var typeId = viewModel.get("typeId");

			if (typeId == "plate") {
				plateApp().edit({id: id});
			}

			if (typeId == "accessory") {
				accessoryApp().edit({id: id});
			}

			if (typeId == "signage") {
				signageApp().edit({id: id});
			}

			if (typeId == "article") {
				articleApp().edit(id);
			}
		},

		clone: function (event) {
			event.preventDefault();
			var itemId = event.data.id;
			$("#item-duplicate-modal").data("itemId", itemId).modal("show");
		},

		_duplicateItem: function (itemId, asInstance) {
			NM.util.ajax({
				method: "POST",
				url: "/manager/ajax/quotation-items/" + itemId + "/duplicate",
				data: JSON.stringify({ asInstance: asInstance }),
				callback: {
					done: function (xhr) {
						if (xhr.status === "ERROR") {
							AP.widget.notify("error", (xhr.data && xhr.data.message) || "Errore durante la duplicazione.");
							return;
						}
						$("#item-duplicate-modal").modal("hide");
						AP.widget.notify("success", "Articolo duplicato correttamente.");
						// la lista si aggiorna comunque in background; per la copia si apre
						// subito la modale della riga appena creata, così si può modificarla
						// senza doverla cercare nell'elenco (l'istanza invece resta com'era)
						viewModel.loadItems();
						if (!asInstance && xhr.data && xhr.data.id) {
							viewModel.openItemEditor(xhr.data.id);
						}
					}
				}
			});
		},

		/*
		editSignage: function( event ) {
			event.preventDefault();
			signageApp().edit( { id: event.data.id } );
			// AP.quotation.pricing.init( viewModel.get( "detailForm.data.id" ), "item" );
		},

		editAccessory: function( event ) {
			event.preventDefault();
			accessoryApp().edit( { id: event.data.id } );
			// AP.quotation.pricing.init( viewModel.get( "detailForm.data.id" ), "item" );
		},

		editPlate: function( event ) {
			event.preventDefault();
			// console.logx("editPlate")
			plateApp().edit( { id: event.data.id } );
			fields.totalItemBox.show();
			// AP.quotation.pricing.init( viewModel.get( "detailForm.data.id" ), "item", viewModel.get( "save" ) );
		},

		editArticle: function( event ) {
			event.preventDefault();
			articleApp().edit( { id: event.data.id } );
			fields.totalItemBox.show();
		},
		*/

		clonePlate: function (event) {
			event.preventDefault();
			event.stopPropagation();
			plateApp().edit({id: event.data.id, clone: true});
			fields.totalItemBox.show();
			// AP.quotation.pricing.init( viewModel.get( "detailForm.data.id" ), "item" );
		},

		openPrintModal: function () {
			if (AP.quotation.fields.printModalRoot.length) {
				AP.quotation.printModal.methods().resetForm();
				AP.quotation.printModal.init();
			}

			NM.util.openModal(AP.quotation.fields.printModalRoot);
		},

		openZonesDialog: function () {
			if (AP.quotation.fields.zonesModalRoot.length) {
				AP.quotation.zonesModal.init();
			}
			NM.util.openModal(AP.quotation.fields.zonesModalRoot);
		},

		openStatusModal: function () {

			statusApp().edit();

		},

		openDocumentsModal: function () {
			AP.quotation.documents.open();
		},

		updateAllPrices: function () {
			AP.loading.show()
			NM.util.ajax({
				method: "GET",
				url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/updateallprices",
				callback: {
					done: function (xhr) {
						AP.widget.notify('success', 'Prezzi articoli aggiornati con i costi fissi.')
						setTimeout(() => {
							window.location.reload()
						}, 500)
					}
				}
			});
		},

		// Sconto unico su tutti gli articoli della famiglia del tab corrente, in tutte le zone.
		// Sovrascrive gli sconti di riga (vedi QuotationItemAjaxController.applyDiscountByType)
		openBulkDiscount: function () {
			var labels = { plate: "Placche", signage: "Segnaletiche", accessory: "Accessori", article: "Servizi" };
			var typeId = viewModel.get("typeId");
			var $modal = $("#bulk-discount-modal");

			$modal.data("typeId", typeId);
			$modal.find(".bulk-discount-family").text(labels[typeId] || typeId);
			$("#bulk-discount-value").val("");
			$modal.modal("show");
		},

		_applyBulkDiscount: function () {
			var $modal = $("#bulk-discount-modal");
			var typeId = $modal.data("typeId");
			var raw = $("#bulk-discount-value").val();
			var discount = parseFloat(String(raw).replace(",", "."));

			if (raw === "" || isNaN(discount) || discount < 0 || discount > 100) {
				AP.widget.notify("error", "Indicare uno sconto compreso tra 0 e 100.");
				return;
			}

			AP.loading.show();
			NM.util.ajax({
				method: "POST",
				url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/items/" + typeId + "/discount",
				data: JSON.stringify({ discount: discount }),
				callback: {
					done: function (xhr) {
						if (xhr.status == "INVALID") {
							AP.loading.hide();
							AP.widget.notify("error", (xhr.data && xhr.data.message) || "Sconto non applicato.");
							return;
						}
						$modal.modal("hide");
						var msg = "Sconto del " + discount + "% applicato a " + xhr.data.updated + " articoli.";
						if (xhr.data.skippedFixed > 0) {
							msg += " " + xhr.data.skippedFixed + " articoli a prezzo fisso non modificati.";
						}
						AP.widget.notify("success", msg);
						// come "Aggiorna tutti i prezzi": ricarica per aggiornare righe e totali
						setTimeout(function () {
							window.location.reload();
						}, 1500);
					},
					fail: function () {
						AP.loading.hide();
					}
				}
			});
		},

		openPlantPosition: function (e) {
			e.preventDefault();
			var zoneId = viewModel.get("detailForm.data.zone.id") || "";
			var url = "/manager/quotation-plant-positions/" + AP.page.quotation.id;
			if (zoneId && zoneId !== "" && zoneId !== "0") {
				url += "?selectedZoneId=" + zoneId;
			}
			window.location.href = url;
		},
	});

	pub.showTotals = function (options) {
		AP.quotation.totalPricing.init();
	};

	pub.checkUrlHash = function () {
		// Pattern: /manager/quotations/{quotationId}#$TYPE/{itemId}
		// Esempio: /manager/quotations/c7b80d01-6169-4050-b25a-8883d17c3126#plate/c7b80d01-6169-4050-b25a-8883d17c3126
		var hash = window.location.hash;

		if (hash && hash.length > 1) {
			// Rimuove il # iniziale
			hash = hash.substring(1);

			// Divide per ottenere tipo e ID
			var parts = hash.split("/");

			if (parts.length === 2) {
				var type = parts[0];
				var itemId = parts[1];

				// Chiama la funzione edit corrispondente
				switch (type.toLowerCase()) {
					case "plate":
						if (AP.plate && AP.plate.modal && AP.plate.modal.edit) {
							AP.plate.modal.edit({id: itemId});
						}
						break;
					case "signage":
						if (AP.signage && AP.signage.modal && AP.signage.modal.edit) {
							AP.signage.modal.edit({id: itemId});
						}
						break;
					case "accessory":
						if (AP.accessory && AP.accessory.modal && AP.accessory.modal.edit) {
							AP.accessory.modal.edit({id: itemId});
						}
						break;
					case "article":
						if (AP.article && AP.article.modal && AP.article.modal.edit) {
							AP.article.modal.edit({id: itemId});
						}
						break;
					default:
						console.warn("Unknown type in URL hash:", type);
				}
			}
		}
	};

	pub.checkUrlTab = function () {
		// Controlla il parametro ?tab= nell'URL e attiva il tab corrispondente
		var urlParams = new URLSearchParams(window.location.search);
		var tabParam = urlParams.get("tab");

		if (tabParam) {
			var validTabs = ["plate", "signage", "accessory", "article"];

			if (validTabs.includes(tabParam.toLowerCase())) {
				var tabType = tabParam.toLowerCase();
				var tabButton = document.querySelector("button#nav-" + tabType + "-tab");

				if (tabButton) {
					// Rimuove la classe active da tutti i tab
					document.querySelectorAll(".nav-link").forEach(function (btn) {
						btn.classList.remove("active");
					});

					// Nasconde tutti i tab-pane
					document.querySelectorAll(".tab-pane").forEach(function (pane) {
						pane.classList.remove("show", "active");
					});

					// Attiva il tab corretto
					tabButton.classList.add("active");
					var targetPane = document.querySelector(tabButton.getAttribute("data-bs-target"));
					if (targetPane) {
						targetPane.classList.add("show", "active");
					}

					// Aggiorna il viewModel
					viewModel.set("typeId", tabType);
					viewModel.loadItems();

					// Aggiorna la visibilità dei pulsanti
					fields.addPlateBtn.toggle(tabType === "plate");
					fields.addSignageBtn.toggle(tabType === "signage");
					fields.addAccessoryBtn.toggle(tabType === "accessory");
					fields.addArticleBtn.toggle(tabType === "article");
				}
			}
		}
	};

	pub.config = function (options) {
		return viewModel.get("detailForm.data");
	};

	pub.getZones = function () {
		return viewModel.getZones();
	};

	pub.methods = function (options) {
		return viewModel;
	};

	pub.init = async function () {
		kendo.bind(AP.quotation.fields.detailRoot, viewModel);
		kendo.culture("it-IT");

		$('#quotation-totals-flat-discount-row').prop('hidden', !['ADM', 'CMA', 'TCD'].includes(AP.page.userRole.id));

		// ?zone=<quotationZoneId> (es. link "elementi in uso" dal prodotto): preseleziona la zona
		// salvandola nelle preferenze, come se l'utente l'avesse scelta dal selettore.
		// Va fatto prima di checkUrlTab/getZones, che caricano subito le righe filtrate per zona.
		var zonePrefKey = "quotation." + (AP.page.quotation?.id || "") + ".zone";
		var zoneParam = AP.page.quotation?.id ? new URLSearchParams(window.location.search).get("zone") : null;
		if (zoneParam) {
			AP.setUserPref(zonePrefKey + ".id", zoneParam);
			AP.setUserPref(zonePrefKey + ".name", "");
		}

		var highlightParam = new URLSearchParams(window.location.search).get("highlight");
		if (highlightParam) {
			pendingHighlightIds = highlightParam.split(",").filter(Boolean);
		}

		// Controlla se c'è un parametro tab nell'URL
		pub.checkUrlTab();

		// Se non c'è nessun tab nell'URL, carica il tab delle placche di default
		var urlParams = new URLSearchParams(window.location.search);

		if (!urlParams.get("tab")) {
			$("body").find("button#nav-plate-tab").click();
			$('#qt-update-prices').show();
		} else {
			if (!['signage', 'plate', 'accessory'].includes(urlParams.get('tab'))) {
				$('#qt-update-prices').hide();
			}
		}

		try {
			await viewModel.getZones();

			const zones = viewModel.get("detailForm.data.zones");

			// Completa la preferenza impostata da ?zone= con il nome della zona e pulisce l'URL
			if (zoneParam) {
				const urlZone = (zones || []).find(zone => zone.id == zoneParam);
				if (urlZone) {
					AP.setUserPref(zonePrefKey + ".name", urlZone.name);
				} else {
					AP.deleteUserPref(zonePrefKey + ".id");
					AP.deleteUserPref(zonePrefKey + ".name");
					viewModel.loadItems();
				}
			}

			// zone/highlight servono solo all'apertura: un reload non deve riapplicarli
			if (zoneParam || highlightParam) {
				var cleanParams = new URLSearchParams(window.location.search);
				cleanParams.delete("zone");
				cleanParams.delete("highlight");
				window.history.replaceState(null, null, window.location.pathname + (cleanParams.toString() ? "?" + cleanParams.toString() : "") + window.location.hash);
			}

			if (zones && zones.length > 0) {
				const defaultZone = zones.find(zone => zone.name == '-- Tutte le zone');
				if (defaultZone) {
					viewModel.set("detailForm.data.zone", defaultZone || zones[0]);
				}

				let zoneObject = {
					"id": "",
					"name": ""
				}
				if (AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.id") && AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.name")) {
					zoneObject = {
						"id": AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.id"),
						"name": AP.getUserPref("quotation." + AP.page.quotation.id + ".zone.name")
					}
				} else {
					if (defaultZone) {
						zoneObject = {
							"id": defaultZone.id,
							"name": defaultZone.name
						}
					}
				}
				viewModel.set('detailForm.data.zone', zoneObject)
			}

		} catch (error) {
			console.error("Errore durante il recupero delle zone:", error);
		}

		AP.quotation.detail.showTotals();

		// Badge + warning segnaposto non configurati sulla mappa
		$.get("/manager/ajax/quotations/" + AP.page.quotation.id + "/draft-count")
			.done(function(res) {
				var count = res && res.data ? res.data.count : 0;
				if (count > 0) {
					$("#plant-draft-badge").text(count).show();
					var label = count === 1
						? "C'è 1 articolo posizionato in pianta non ancora configurato."
						: "Ci sono " + count + " articoli posizionati in pianta non ancora configurati.";
					$("#plant-draft-warning-text").text(label);
					$("#plant-draft-warning-link").attr("href", "#").off("click.plant").on("click.plant", function(e) {
						e.preventDefault();
						var zoneId = viewModel.get("detailForm.data.zone.id") || "";
						var url = "/manager/quotation-plant-positions/" + AP.page.quotation.id;
						if (zoneId && zoneId !== "" && zoneId !== "0") {
							url += "?selectedZoneId=" + zoneId;
						}
						window.location.href = url;
					});
					$("#plant-draft-warning").show();
					$(".qt-draft-block").prop("disabled", true);
				}
			});

		// Controlla URL hash per auto-aprire edit modal
		// console.log( "init:checkUrlHash" );
		pub.checkUrlHash();


		if (AP.page.quotation) {

			document.querySelector("#nav-plate-tab").addEventListener("click", function (event) {
				event.preventDefault();
				fields.addPlateBtn.show();
				fields.addSignageBtn.hide();
				fields.addAccessoryBtn.hide();
				fields.addArticleBtn.hide();
				$('#qt-update-prices').show();
			});

			document.querySelector("#nav-signage-tab").addEventListener("click", function (event) {
				event.preventDefault();
				fields.addPlateBtn.hide();
				fields.addSignageBtn.show();
				fields.addAccessoryBtn.hide();
				fields.addArticleBtn.hide();
				$('#qt-update-prices').show();
			});

			document.querySelector("#nav-accessory-tab").addEventListener("click", function (event) {
				event.preventDefault();
				fields.addPlateBtn.hide();
				fields.addSignageBtn.hide();
				fields.addAccessoryBtn.show();
				fields.addArticleBtn.hide();
				$('#qt-update-prices').show();
			});

			document.querySelector("#nav-article-tab").addEventListener("click", function (event) {
				event.preventDefault();
				fields.addPlateBtn.hide();
				fields.addSignageBtn.hide();
				fields.addAccessoryBtn.hide();
				fields.addArticleBtn.show();
				$('#qt-update-prices').hide();
			});

			pricingApp().getTotals();

		}

		$(document).on("click", "#toggle-costs-link", function () {
			viewModel.set("showCosts", AP.getUserPref("showCosts"));
		});

		$("#item-duplicate-copy-btn").on("click", function () {
			var itemId = $("#item-duplicate-modal").data("itemId");
			viewModel._duplicateItem(itemId, false);
		});

		$("#item-duplicate-instance-btn").on("click", function () {
			var itemId = $("#item-duplicate-modal").data("itemId");
			viewModel._duplicateItem(itemId, true);
		});

		$("#bulk-discount-apply-btn").on("click", function () {
			viewModel._applyBulkDiscount();
		});
	};

	return pub;
}());

AP.quotation.zonesModal = (function () {
	var pub = {};
	var fields = AP.quotation.fields;

	function fileApp() {
		return AP.file.modal;
	}

	var viewModel = kendo.observable({
			zones: [],
			detailForm: {
				zones: [],
				data: {
					id: null,
					name: "",
					quantity: 1,
					parentZone: null,
					quotation: {id: AP.page.quotation.id}
				}
			},

			defaultDetailFormData: {
				id: null,
				name: "",
				quantity: 1,
				parentZone: null,
				quotation: {id: AP.page.quotation.id}
			},

			editZone: function (e) {
				var item = e.data;
				this.setupZoneModal(item);
			},

			deleteZone: function (e) {
				var item = e.data;
				var self = this;

				// force = false: se la zona contiene righe il server non cancella e
				// risponde "confirm"; dopo l'avviso si ripete con force = true, che
				// elimina zona e righe insieme
				var sendDelete = function (force) {
					AP.loading.show();
					NM.util.ajax({
						method: "DELETE",
						url: "/manager/ajax/quotations/zones/",
						data: JSON.stringify({zone: {id: item.id}, force: force}),
						callback: {
							done: function (xhr) {
								AP.loading.hide();
								if (xhr.status == "INVALID") {
									NM.form.showMessages(xhr.data);
									return;
								}
								if (xhr.data.status == "confirm") {
									bootbox.confirm({
										title: "Attenzione",
										message: xhr.data.message + "<br><br>Procedere con l'eliminazione?",
										buttons: {
											confirm: { label: "Sì, elimina tutto", className: "btn-danger" },
											cancel: { label: "Annulla", className: "btn-secondary" }
										},
										callback: function (confirmed) {
											if (confirmed) sendDelete(true);
										}
									});
									return;
								}
								AP.widget.notify(xhr.data.status.toLowerCase(), xhr.data.message);
								AP.quotation.detail.getZones().then(() => self.refreshGrids());
								if (xhr.data.status == "success") {
									// le righe eliminate cambiano i totali e le liste per tipo
									// filtro della lista sulla zona appena eliminata: si torna a tutte
									var prefKey = "quotation." + AP.page.quotation.id + ".zone";
									if (AP.getUserPref(prefKey + ".id") == item.id) {
										AP.setUserPref(prefKey + ".id", "");
										AP.setUserPref(prefKey + ".name", "");
									}
									AP.quotation.detail.methods().loadItems();
									AP.quotation.detail.showTotals();
								}
							}
						}
					});
				};

				bootbox.confirm("Eliminare la zona " + item.name + "?", function (result) {
					if (result) sendDelete(false);
				});
			},

			openDuplicateDialog: function (e) {
				var item = e.data;
				this.set("detailForm.data", {
					id: item.id,
					name: item.name + " Copia",
					quantity: item.quantity,
					parentZone: (item.origin && item.origin.id) ? item.origin.id : null,
					quotation: {id: AP.page.quotation.id}
				});
				$("#duplicateDialogTitle").text("Duplica zona " + item.name);
				$("#duplicateNameInput").val(this.get('detailForm.data.name'));
				$("#duplicateDialog").modal("show");
			},

			openImagesList: function (event) {
				var value = {
					type: "quotationZone",
					id: event.data.id,
					origin: event.data.origin ? event.data.origin.name : null,
					name: event.data.name,
				};

				fileApp().open(value);

				return false;
			},

			setupZoneModal: function (item) {
				var hasParentZones = this.get("zones").filter(function(z) { return z.id !== ""; }).length > 0;
				if (hasParentZones) {
					$("#zone-parent-container").show();
				} else {
					$("#zone-parent-container").hide();
				}

				if (item) {
					this.set("detailForm.data", {
						id: item.id,
						name: item.name,
						quantity: item.quantity,
						parentZone: (item.origin && item.origin.id) ? item.origin.id : null,
						quotation: {id: AP.page.quotation.id}
					});
					$("#zoneTitle").text("Modifica Zona: " + item.name);
					$("#duplicate-zone-button, #duplicate-zone-with-children-button, #delete-zone-button").hide();
					$('#save-zone-button').show()
				} else {
					this.set("detailForm.data", {
						id: null,
						name: "",
						quantity: 1,
						parentZone: null,
						quotation: {id: AP.page.quotation.id}
					});
					$("#zoneTitle").text("Nuova Zona");
					$("#duplicate-zone-button, #duplicate-zone-with-children-button, #delete-zone-button").hide();
					$('#save-zone-button').show()
				}

				NM.util.openModal($("#zone-modal-root"));
			},

			addZone: function (e) {
				if (e) e.preventDefault();
				this.setupZoneModal(null);
			},

			saveZone: function () {
				var data = this.get("detailForm.data");
				var pz = data.parentZone;
				if (pz && pz.id) {
					data.parentZone = { id: pz.id };
				} else if (pz && typeof pz === "string" && pz !== "") {
					data.parentZone = { id: pz };
				} else {
					data.parentZone = null;
				}
				AP.loading.show();
				NM.util.ajax({
					method: "POST",
					url: "/manager/ajax/quotations/zones",
					data: JSON.stringify(data),
					callback: {
						done: (xhr) => {
							AP.loading.hide();
							fields.zoneModalRoot.modal('hide');
							let message = xhr.data.message
							if (message.toLowerCase() == 'not found') {
								message = data.id ? "Zona Aggiornata" : "Zona Creata"
							}
							AP.widget.notify(xhr.data.status, message);
							this.set('detailForm.data', this.get('defaultDetailFormData'))
							AP.quotation.detail.getZones().then(() => this.refreshGrids());
						}
					}
				});
			},

        duplicateZone: function(withChildren, newName) {

		var zoneId = this.get("detailForm.data.id");

		if (!zoneId) {
			AP.widget.notify("error", "Errore: nessuna zona selezionata.");
			return;
		}

		let data = this.get('detailForm.data')
		data.duplicaConSottozone = withChildren
		data.name = newName

		AP.loading.show();

		NM.util.ajax({
			method: "POST",
			url: "/manager/ajax/quotations/duplicatezone",
			data: JSON.stringify(data),
			callback: {
				done: (xhr) => {
					AP.loading.hide();
					$("#duplicateDialog").modal("hide");
					AP.widget.notify("success", "Zona duplicata con successo");
					var reload = function () {
						var url = new URL(window.location.href);
						if (!url.searchParams.has("reset")) {
							url.searchParams.set("reset", "1");
							window.location.href = url.toString();
						} else {
							window.location.reload();
						}
					};
					// righe non copiate perché usano elementi non più a catalogo
					var notInCatalog = (xhr && xhr.data && xhr.data.notInCatalog) || [];
					if (notInCatalog.length) {
						bootbox.alert({
							title: "Righe non copiate",
							message: AP.notInCatalogMessage(notInCatalog, "Le righe che li usano non sono state copiate nella nuova zona."),
							callback: reload
						});
					} else {
						reload();
					}
				},
				fail: () => AP.loading.hide()
			}
		});
	}

,

	refreshGrids: function () {
		let zones = AP.quotation.detail.config().zones.filter(z => z.name != '-- Tutte le zone' && z.name != 'Non assegnato')
			.map(z => {
				let newZ = {...z};

				if (newZ.name.startsWith("\u00A0\u00A0- ")) {
					newZ.name = newZ.name.replace("\u00A0\u00A0- ", "");
				}

				return newZ;
			});
		let parentZones = zones.filter(z => !z.origin);
		parentZones.unshift({
			'id': '',
			'name': '\u00A0\u00A0- '
		})

		viewModel.set('zones', parentZones);
		$("#zones-grid").data("kendoGrid").dataSource.data(zones);

	}
});

pub.init = function () {
	let allZones = AP.quotation.detail.config().zones || [];
	let gridZones = allZones
		.filter(z => z.name != '-- Tutte le zone' && z.name != 'Non assegnato')
		.map(z => {
			let newZ = {...z};

			if (newZ.name.startsWith("\u00A0\u00A0- ")) {
				newZ.name = newZ.name.replace("\u00A0\u00A0- ", "");
			}

			return newZ;
		});
	let parentZones = allZones.filter(z => !z.origin && z.name != '-- Tutte le zone' && z.name != 'Non assegnato');

	parentZones.unshift({
		'id': '',
		'name': '\u00A0\u00A0- '
	})
	viewModel.set('zones', parentZones);
	viewModel.set('detailForm.zones', gridZones);

	kendo.bind(fields.zonesModalRoot, viewModel);
	kendo.bind(fields.zoneModalRoot, viewModel);

	$("#duplicateSimpleBtn").on("click", function () {
		viewModel.duplicateZone(false, $("#duplicateNameInput").val());
	});

	$("#duplicateWithChildrenBtn").on("click", function () {
		viewModel.duplicateZone(true, $("#duplicateNameInput").val());
	});

};

return pub;
})
();

AP.quotation.printModal = (function () {
	var pub = {};
	// REF: il nome è errato
	var fields = AP.quotation.fields;

	const DEFAULT_REPORT = "classic";

	// Terzo livello: mappa opzione -> elementi nel DOM.
	const OPTION_FIELDS = {
		images: {checkbox: "#qt-print-image-checkbox", container: "#qt-print-images-cont"},
		note: {checkbox: "#qt-print-note-checkbox", container: "#qt-print-note-cont"},
		discounts: {checkbox: "#qt-print-discounts-checkbox", container: "#qt-print-discounts-cont"},
		plants: {checkbox: "#qt-print-plants-checkbox", container: "#qt-print-plants-cont"},
		hideTotal: {checkbox: "#qt-print-hide-total-checkbox", container: "#qt-print-hide-total-cont"}
	};

	// Per ogni tipologia di stampa (primo livello):
	//   grouping -> valore di default del secondo livello ("categories" | "none")
	//   options  -> opzioni di terzo livello supportate dal template, con il loro default.
	//               Le opzioni non elencate vengono nascoste e inviate a false.
	//   locked   -> opzioni elencate in "options" che restano visibili ma non
	//               modificabili: mantengono il valore di default. Serve a dire
	//               "questa stampa non lo prevede" lasciandolo comunque a video,
	//               invece di far sparire la voce.
	const REPORT_CONFIG = {
		classic: {
			grouping: "categories",
			options: {images: true, note: true, discounts: false, plants: false, hideTotal: false}
		},
		// Le voci sono organizzate per ambiente: il raggruppamento per categorie
		// non si applica, quindi il secondo livello resta nascosto. Con "Piante"
		// ogni zona stampa la sua pianta prima dei propri articoli.
		zone: {
			grouping: "none",
			hideGrouping: true,
			options: {images: true, note: true, discounts: false, plants: false, hideTotal: false}
		},
		photo: {
			grouping: "categories",
			options: {note: false, plants: false}
		},
		technical: {
			grouping: "categories",
			// la tecnica riporta sempre immagini e note: sono parte del documento,
			// non un'opzione
			options: {images: true, note: true, plants: false},
			locked: ["images", "note"]
		},
		// La proforma riusa la stampa del preventivo ma non riporta mai le foto,
		// e in più chiede progressivo e percentuale di anticipo.
		proforma: {
			grouping: "categories",
			options: {note: true, discounts: false, plants: false, hideTotal: false},
			// la proforma non riporta mai le piante e mostra sempre il totale
			locked: ["plants", "hideTotal"],
			needsProformaData: true
		}
	};

	const PROFORMA_FIELDS = {
		container: "#qt-print-proforma-cont",
		progressivo: "#qt-print-proforma-progressivo",
		percentuale: "#qt-print-proforma-percentuale",
		importo: "#qt-print-proforma-importo",
		error: "#qt-print-proforma-error",
		historyCont: "#qt-print-proforma-history-cont",
		historyBody: "#qt-print-proforma-history tbody"
	};

	// Progressivi già usati per questo preventivo, dallo storico caricato.
	// Servono a bloccare il riuso prima di lanciare la stampa: il server lo
	// rifiuta comunque, ma lì l'utente si troverebbe una pagina di errore.
	var progressiviUsati = [];

	// Storico delle proforma già stampate: elencate dalla più recente, con il
	// link al PDF archiviato al momento della stampa.
	function loadProformaHistory() {
		const $body = $(PROFORMA_FIELDS.historyBody);

		NM.util.ajax({
			method: "GET",
			url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/proformas",
			callback: {
				done: function (xhr) {
					const righe = (xhr.data || []);

					progressiviUsati = $.map(righe, function (r) {
						return $.trim(r.progressivo || "").toUpperCase();
					});

					// niente storico, niente riquadro: alla prima stampa non c'è
					// nulla da mostrare e una tabella vuota sarebbe solo rumore
					$(PROFORMA_FIELDS.historyCont).toggleClass("d-none", !righe.length);
					$body.empty();

					$.each(righe, function (i, r) {
						$("<tr>").append(
							$("<td>").addClass("small").text(r.progressivo || ""),
							$("<td>").addClass("small").text(r.anticipo || ""),
							$("<td>").addClass("small").text(NM.kendo.formatISODate(r.createdAt) || ""),
							$("<td>").addClass("text-end").append(
								// si passa dall'endpoint dell'app e non dal link statico:
								// il PDF resta dietro autenticazione e arriva con un nome
								// leggibile. Si apre in una nuova scheda, lasciando il
								// preventivo dov'è.
								$("<a>")
									.attr({
										href: "/manager/ajax/quotations/" + AP.page.quotation.id +
											"/proformas/" + r.id + "/download",
										target: "_blank",
										title: "Apri il PDF"
									})
									.addClass("btn btn-default btn-sm")
									.html('<i class="fas fa-file-pdf"></i>')
							)
						).appendTo($body);
					});
				}
			}
		});
	}

	// Tipologie generabili anche prima del calcolo del preventivo: il loro
	// template non riporta prezzi. Tenere allineato REPORTS_WITHOUT_PRICE in
	// TechnicalReportController.cfc, che rifiuta comunque le altre.
	const REPORTS_WITHOUT_PRICE = ["photo"];

	// Finché il preventivo non è calcolato non esiste un QuotationPrice, quindi le
	// stampe con prezzi e totali non possono essere generate: qui vengono
	// disabilitate invece di lasciarle scegliere e far comparire un errore dopo.
	function applyPriceRestriction() {
		const priceReady = !!(AP.page.quotation && AP.page.quotation.priceCalculated);

		$("input[name='report']").each(function () {
			const consentita = priceReady || REPORTS_WITHOUT_PRICE.indexOf(this.value) !== -1;

			// disabled sempre assegnato, anche a false: dopo un calcolo il modale
			// viene riaperto e le voci devono tornare disponibili
			$(this).prop("disabled", !consentita);
			$("label[for='" + this.id + "']").toggleClass("disabled", !consentita);
		});

		$("#qt-print-price-warning").toggleClass("d-none", priceReady);

		return priceReady;
	}

	function selectedReport() {
		return $("input[name='report']:checked").val() || DEFAULT_REPORT;
	}

	function reportConfig() {
		return REPORT_CONFIG[selectedReport()] || REPORT_CONFIG[DEFAULT_REPORT];
	}

	function showProformaError(message) {
		$(PROFORMA_FIELDS.error).text(message || "").toggleClass("d-none", !message);
	}

	// Percentuale e importo dell'anticipo sono alternativi: si compila l'uno o
	// l'altro. Compilandone uno l'altro viene svuotato, così non resta a video un
	// valore che poi non viene usato.
	function bindProformaExclusivity() {
		const coppie = [
			{scrive: PROFORMA_FIELDS.percentuale, pulisce: PROFORMA_FIELDS.importo},
			{scrive: PROFORMA_FIELDS.importo, pulisce: PROFORMA_FIELDS.percentuale}
		];

		$.each(coppie, function (i, coppia) {
			// off prima di on: init() viene rieseguito a ogni apertura della dialog,
			// e ora che si chiude dopo ogni proforma le riaperture sono la norma —
			// senza questo gli handler si accumulerebbero a ogni giro.
			$(coppia.scrive).off("input.apProforma").on("input.apProforma", function () {
				if ($.trim($(this).val() || "") !== "") {
					$(coppia.pulisce).val("");
				}
				showProformaError("");
			});
		});
	}

	// Restituisce { progressivo, percentuale, importo } se validi, altrimenti null
	// (con errore a video). Uno solo fra percentuale e importo è valorizzato.
	function readProformaData() {
		const progressivo = $.trim($(PROFORMA_FIELDS.progressivo).val() || "");
		const rawPercent = $.trim($(PROFORMA_FIELDS.percentuale).val() || "");
		const rawImporto = $.trim($(PROFORMA_FIELDS.importo).val() || "");
		const percentuale = parseFloat(rawPercent);
		const importo = parseFloat(rawImporto);

		if (!progressivo) {
			showProformaError("Indica il progressivo proforma.");
			$(PROFORMA_FIELDS.progressivo).trigger("focus");
			return null;
		}

		if (progressiviUsati.indexOf(progressivo.toUpperCase()) !== -1) {
			showProformaError(
				"Progressivo " + progressivo + " già utilizzato per questo preventivo. " +
				"Indicane uno diverso: quella già emessa resta scaricabile qui sotto."
			);
			$(PROFORMA_FIELDS.progressivo).trigger("focus");
			return null;
		}

		if (!rawPercent && !rawImporto) {
			showProformaError("Indica la percentuale oppure l'importo dell'anticipo.");
			$(PROFORMA_FIELDS.percentuale).trigger("focus");
			return null;
		}

		// 0 è ammesso: proforma senza anticipo ( "0% anticipato", totale a pagare 0 )
		if (rawPercent && (isNaN(percentuale) || percentuale < 0 || percentuale > 100)) {
			showProformaError("Indica una percentuale di anticipo fra 0 e 100.");
			$(PROFORMA_FIELDS.percentuale).trigger("focus");
			return null;
		}

		if (rawImporto && (isNaN(importo) || importo <= 0)) {
			showProformaError("Indica un importo di anticipo maggiore di zero.");
			$(PROFORMA_FIELDS.importo).trigger("focus");
			return null;
		}

		showProformaError("");

		// il campo non compilato viaggia a 0: la stampa usa l'importo se presente,
		// altrimenti ricade sulla percentuale
		return {
			progressivo: progressivo,
			percentuale: rawPercent ? percentuale : 0,
			importo: rawImporto ? importo : 0
		};
	}

	var viewModel = kendo.observable({

		print: function () {
			const config = reportConfig();

			const params = {
				id: AP.page.quotation.id,
				report: selectedReport(),
				groupByCategory: $("input[name='grouping']:checked").val() === "categories"
			};

			if (config.needsProformaData) {
				const proforma = readProformaData();
				if (!proforma) return;

				params.progressivo = proforma.progressivo;
				params.percentuale = proforma.percentuale;
				params.importo = proforma.importo;
			}

			$.each(OPTION_FIELDS, function (name, field) {
				params[name] = $(field.checkbox).is(":checked");
			});

			window.open("/manager/technical-reports/print?" + $.param(params), "_blank");

			// La proforma consuma il progressivo, ma lo storico in questa dialog
			// è quello caricato all'apertura e non lo sa ancora: restando aperta,
			// l'utente potrebbe rilanciare lo stesso progressivo e prendersi
			// l'errore del server. Chiudendola, la riapertura ricarica l'elenco
			// aggiornato e il controllo in readProformaData() lo intercetta.
			if (config.needsProformaData) {
				fields.printModalRoot.modal("hide");
			}
		},

		// Riallinea secondo e terzo livello ai default della tipologia selezionata.
		toggleOptions: function () {
			const config = reportConfig();

			$("input[name='grouping'][value='" + config.grouping + "']").prop("checked", true);
			$("#qt-print-grouping-cont").toggle(!config.hideGrouping);

			$.each(OPTION_FIELDS, function (name, field) {
				const available = Object.prototype.hasOwnProperty.call(config.options, name);
				const locked = available && (config.locked || []).indexOf(name) !== -1;

				$(field.container).toggle(available).toggleClass("print-option-locked", locked);

				// disabled va sempre assegnato, anche a false: altrimenti tornando
				// a una tipologia che l'opzione la prevede resterebbe bloccata.
				$(field.checkbox)
					.prop("checked", available && config.options[name])
					.prop("disabled", locked);
			});

			$(PROFORMA_FIELDS.container).toggle(!!config.needsProformaData);
			showProformaError("");
		},

		resetForm: function () {
			const priceReady = applyPriceRestriction();

			$("input[name='report'][value='" + (priceReady ? DEFAULT_REPORT : REPORTS_WITHOUT_PRICE[0]) + "']")
				.prop("checked", true);

			$(PROFORMA_FIELDS.progressivo).val("");
			$(PROFORMA_FIELDS.percentuale).val("");
			$(PROFORMA_FIELDS.importo).val("");
			viewModel.toggleOptions();

			// ricaricato a ogni apertura: dopo una stampa lo storico ha una riga in più
			loadProformaHistory();
		}
	});

	pub.init = function () {
		kendo.bind(fields.printModalRoot, viewModel);

		fields.printModalRoot
			.off("change.apPrintModal")
			.on("change.apPrintModal", "input[name='report']", viewModel.toggleOptions);

		bindProformaExclusivity();

		viewModel.toggleOptions();
	};

	pub.methods = function (options) {
		return viewModel;
	};

	return pub;
}());

// AP.quotation.exportCode è ora in app-quotation-export-code.js (condiviso con
// app-quotation-plant-positions.js, che non carica questo file).
