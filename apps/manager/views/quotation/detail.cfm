<cfoutput>
    <div id="quotation-detail-root">
        <div class="row mb-3">
            <div class="col-5">
                <h2>#prc.title#</h2>
                #button( href="/manager/quotations", size="sm", label="Torna ai preventivi", icon="arrow-left" )#
            </div>

            <div class="col-7 mt-1">
                <!---
                    pulsanti tutti della stessa larghezza ( qt-actions in style.css ),
                    affiancati senza colonne: niente buchi dove un pulsante è nascosto
                --->
                <div class="qt-actions d-flex flex-wrap justify-content-end gap-2 mb-2">
                    #button( bind="click:showHeader", size="sm", label="Dettaglio", icon="edit" )#
                    <button type="button"
                            class="btn btn-outline-secondary btn-sm"
                            data-file-name="placche_#prc.quotation.getQuotationNumber()#_#prc.quotation.getVersionNumber()#.json"
                            data-bind="click:downloadPlatesJson">
                        <i class="fas fa-download"></i> Scarica DWG Placche
                    </button>
                    #button( bind="click:openDocumentsModal", size="sm", label="Documenti", icon="folder-open" )#
                    #button( bind="click:openPrintModal", size="sm", label="Stampe", icon="print" )#
                    <div class="position-relative">
                        #button( bind="click:openPlantPosition", size="sm", label="Posizioni in pianta", icon="map" )#
                        <span id="plant-draft-badge" class="badge bg-danger position-absolute top-0 start-100 translate-middle" style="display:none;font-size:10px;"></span>
                    </div>
                    <!--- nascosto: la funzione resta ( export3dPlates ), basta togliere d-none --->
                    <button type="button"
                            class="btn btn-outline-secondary btn-sm d-none"
                            data-email-list="guido.sangiovanni@gslabs.it"
                            data-bind="click:export3dPlates, email: this">
                        <i class="fas fa-cube"></i> JSON 3D placche
                    </button>
                </div>
                <div class="qt-actions d-flex flex-wrap justify-content-end gap-2">
                    <cfif prc.quotation.getSentToClient() ?: false>
                        <button type="button" class="btn btn-primary btn-sm" disabled>
                            <i class="fas fa-check-circle"></i>
                            Status: #prc.quotation.getStatusHistory().getStatus().getName()#
                        </button>
                    <cfelse>
                        <button type="button"
                                id="qt-status-btn"
                                class="btn btn-sm qt-draft-block #(prc.quotation.getStatusHistory().getStatus().getId() == 'PEN' ? 'btn-outline-primary' : 'btn-primary')#"
                                data-role-list="ADM/CMA"
                                data-bind="click: openStatusModal, roleEnable: this">
                            <i class="fas fa-check-circle"></i>
                            Status: #prc.quotation.getStatusHistory().getStatus().getName()#
                        </button>
                    </cfif>
                    #button( bind="click:export, enabled: canExport", size="sm", label="Esporta preventivo", icon="file-export", class="export-button qt-draft-block" )#
                    <button type="button" class="btn btn-outline-primary btn-sm" data-bind="click:markAsSent, visible:canEdit">
                        <i class="fas fa-paper-plane"></i> Inviato a cliente
                    </button>
                    <button type="button" class="btn btn-warning btn-sm" data-bind="click:createRevision, visible:canRevise">
                        <i class="fas fa-code-branch"></i> Crea revisione
                    </button>
                </div>
            </div>

            <div class="export-button-tooltip col-6 text-end">
				<p class="export-button-tooltip" style="color: red; display: none">
                    Il preventivo è già stato esportato
                </p>
			</div>

        </div>

        <div id="plant-draft-warning" class="row" style="display:none;">
            <div class="col-lg-12">
                <div class="alert alert-warning d-flex align-items-center gap-2 py-2 mb-2" role="alert">
                    <i class="fas fa-map-marker-alt"></i>
                    <span id="plant-draft-warning-text"></span>
                    <a id="plant-draft-warning-link" href="##" class="ms-2 alert-link fw-semibold">Vai alla pianta</a>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-lg-12">

                <form action="/manager/quotations" class="form-horizontal" method="post" id="quotation-detail-header-form">

                    <section class="card">

                        <div class="card-body">

                            <div class="row">

                                <div class="col-4 d-flex">
                                    <label class="me-2">Zone: </label>
                                    <select
                                        style="max-width: 600px;"
                                        class="form-control me-3"
                                        data-bind="source: zones, value: detailForm.data.zone, events: { change: loadItems }"
                                        data-value-field="id"
                                        data-text-field="name"
                                        id="zones-selector">
                                    </select>
                                </div>
                                <div class="col-8">
                                    <div class="d-flex align-items-center">
                                        <span data-bind="visible: canEdit">
				                            #button( type="button", bind="click:openZonesDialog", size="sm", label="Gestisci Zone" )#
                                        </span>
                                        <!--- Avviso righe senza prezzo configurato (compatto, accanto a "Gestisci Zone"): riempito da refreshMissingPrices() in app-quotation-detail.js --->
                                        <div id="qt-missing-prices-alert" class="d-none ms-3">
                                            <div class="alert qt-missing-price-alert d-flex align-items-center py-1 px-2 mb-0" role="alert">
                                                <i class="fas fa-exclamation-triangle me-2"></i>
                                                <div>
                                                    <strong>Articoli senza prezzo</strong> (salvati a 0 &euro;):
                                                    <span id="qt-missing-prices-detail"></span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                            </div>

                            <div class="form-group row mb-3">
                                <section class="card">
                                    <div class="card-body">
                                    <nav>
                                        <div class="nav nav-tabs" id="nav-tab" role="tablist">
                                            <div class="col-4 d-flex">

                                                <button class="nav-link active" data-bs-toggle="tab" type="button" role="tab"
                                                    id="nav-plate-tab"
                                                    data-type="plate"
                                                    data-bs-target="##nav-plate"
                                                    data-bind="click:changeType">
                                                    Placche
                                                </button>

                                                <button class="nav-link" data-bs-toggle="tab" type="button" role="tab"
                                                    id="nav-signage-tab"
                                                    data-type="signage"
                                                    data-bs-target="##nav-signage"
                                                    data-bind="click:changeType">
                                                    Segnaletiche
                                                </button>

                                                <button class="nav-link" data-bs-toggle="tab" type="button" role="tab"
                                                    id="nav-accessory-tab"
                                                    data-type="accessory"
                                                    data-bs-target="##nav-accessory"
                                                    data-bind="click:changeType">
                                                    Accessori
                                                </button>

                                                <button class="nav-link" data-bs-toggle="tab" type="button" role="tab"
                                                    id="nav-article-tab"
                                                    data-type="article"
                                                    data-bs-target="##nav-article"
                                                    data-bind="click:changeType">
                                                    Servizi
                                                </button>

                                            </div>
                                            <div class="col-8 text-end mb-2" data-bind="visible: canEdit">
                                                <button class="btn btn-primary btn-md" id="qt-update-prices" type="button" data-bind="click:updateAllPrices">
                                                    <i class="fas fa-sync"></i> Aggiorna tutti i prezzi
                                                </button>
                                                <button class="btn btn-outline-primary btn-md" id="qt-bulk-discount" type="button" data-bind="click:openBulkDiscount">
                                                    <i class="fas fa-percent"></i> Sconto famiglia
                                                </button>
                                                #addButton( label="Aggiungi placca", id="qt-add-plate", bind="click:addPlate")#
                                                #addButton( label="Aggiungi segnaletica", id="qt-add-signage", bind="click:addSignage", style="display: none" )#
                                                #addButton( label="Aggiungi accessorio", id="qt-add-accessory", bind="click:addAccessory", style="display: none" )#
                                                #addButton( label="Aggiungi servizio", id="qt-add-article", bind="click:addArticle", style="display: none" )#
                                                <cfif #prc.quotation.getStatusHistory().getStatus().getId() == 'LAV'#>
                                                    <button class="btn btn-success btn-md qt-draft-block" id="qt-concludi-btn" type="button" data-bind="click:approveQuotation">
                                                        <i class="fas fa-check"></i> Concludi preventivo
                                                    </button>
                                                </cfif>
                                            </div>
                                        </div>
                                    </nav>

                                    <div class="tab-content" id="nav-tabContent">
                                        <!--- Spinner mostrato da loadItems() mentre carica le righe del tab attivo; nel frattempo i tab sono disabilitati --->
                                        <div id="quotation-items-loader" class="text-center py-5" style="display: none;">
                                            <div class="spinner-border text-primary" role="status"><span class="visually-hidden">Caricamento</span></div>
                                            <div class="text-muted mt-2">Caricamento articoli in corso...</div>
                                        </div>
                                        <div class="tab-pane fade show active" id="nav-plate" role="tabpanel">
                                            <div>
                                                <div id="qt-items-plate" data-template="quotation-item-preview-tmpl" data-bind="source: quotationItemsPlate" class="row">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="tab-pane fade" id="nav-signage" role="tabpanel">
                                            <div>
                                                <div id="qt-items-signage" data-template="quotation-item-preview-tmpl" data-bind="source: quotationItemsSignage" class="row">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="tab-pane fade" id="nav-accessory" role="tabpanel">
                                            <div>
                                                <div id="qt-items-accessory" data-template="quotation-item-preview-tmpl" data-bind="source: quotationItemsAccessory" class="row">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="tab-pane fade" id="nav-article" role="tabpanel">
                                            <div>
                                                <div class="col-12">
                                                    #grid(
                                                        id = "quotation-item-article-grid",
                                                        class="no-pager",
                                                        columns = "[
                                                            { 'field':'', 'title':'',  width: '5%' },
                                                            { 'field':'article.code', 'title':'Codice', width: '10%' },
                                                            { 'field':'article.name', 'title':'Nome', width: '30%' },
                                                            { 'field':'quantity', 'title':'Quantità', width: '10%', 'headerAttributes': { 'class': 'justify-content-end' } },
                                                            { 'field':'price.total', 'title':'Prezzo', format: '{0:n2}', width: '10%', 'headerAttributes': { 'class': 'justify-content-end' } }
                                                        ]",
                                                        source="quotationItemsArticle",
                                                        rowTemplate = "quotation/quotation-item-article-grid-row-tmpl"
                                                    )#
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </section>
                            </div>

                        </div>

                    </section>

                </form>

            </div>

        </div>

    </div>

    #view( "quotation/header-modal" )#

    <div class="modal fade" id="bulk-discount-modal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-percent me-1"></i> Sconto su tutti gli articoli: <span class="bulk-discount-family"></span></h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="alert alert-warning mb-3">
                        <p class="mb-2">
                            <i class="fas fa-exclamation-triangle me-1"></i>
                            Lo sconto sarà applicato a <strong>TUTTI</strong> gli articoli della famiglia
                            <strong class="bulk-discount-family"></strong> di <strong>TUTTE le zone</strong> di questo preventivo.
                        </p>
                        <p class="mb-0">
                            La percentuale indicata <strong>SOVRASCRIVE</strong> gli sconti già impostati sui singoli articoli
                            (sconto 1 = percentuale indicata, sconto 2 azzerato). Gli articoli a prezzo fisso non vengono modificati.
                        </p>
                    </div>
                    <label for="bulk-discount-value" class="form-label">Percentuale di sconto</label>
                    <div class="input-group">
                        <input type="number" class="form-control" id="bulk-discount-value" min="0" max="100" step="0.01">
                        <span class="input-group-text">%</span>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Annulla</button>
                    <button type="button" class="btn btn-primary" id="bulk-discount-apply-btn">Applica sconto</button>
                </div>
            </div>
        </div>
    </div>

    <div class="modal fade" id="item-duplicate-modal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Duplica articolo</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <p class="mb-3">Come vuoi duplicare questo articolo?</p>
                    <div class="d-grid gap-2">
                        <button id="item-duplicate-copy-btn" class="btn btn-outline-primary">
                            <i class="fas fa-copy me-2"></i>Copia
                            <small class="d-block text-muted">Crea un articolo indipendente</small>
                        </button>
                        <button id="item-duplicate-instance-btn" class="btn btn-outline-secondary">
                            <i class="fas fa-link me-2"></i>Istanza
                            <small class="d-block text-muted">Crea una copia collegata (sincronizzata)</small>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    #view( "quotation/signage-modal" )#
    #view( "quotation/accessory-modal" )#
    #view( "quotation/posizione-in-pianta-modal" )#
    #view( "quotation/plate-modal-vue" )#
    #view( "quotation/article-modal" )#

    #view( "quotation/zones-modal" )#
    #view( "quotation/print-modal" )#
    #view( "quotation/status-modal" )#
    #view( "quotation/documents-modal" )#
    #view( "quotation/export-result-modal" )#

    <div class="modal fade" id="qt-export3d-modal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-cube me-1"></i> JSON 3D – Placche preventivo</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <textarea id="qt-export3d-text" class="form-control" style="font-size:10px; font-family:monospace; height:400px;" readonly onclick="this.select()"></textarea>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Chiudi</button>
                </div>
            </div>
        </div>
    </div>

    #view( "quotation/totals" )#

    #template( view="jstemplate/quotation/quotation-item-preview-tmpl" )#
    #template( view="jstemplate/quotation/quotation-item-article-grid-row-tmpl" )#
    #template( view="jstemplate/quotation/quotation-position-suggest-row-tmpl")#

    #template( view="jstemplate/quotation/quotation-pricing-totals-item-tmpl" )#

</cfoutput>
