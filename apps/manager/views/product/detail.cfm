<cfimport prefix="ap" taglib="/apps/utils/ctags">

<cfoutput>

    <div id="product-detail-root">
        <div class="row">
            <div class="col-10">
                #pageTitle()#
            </div>
        </div>

        <div class="row">
            <div class="col-md-12">

                <section class="card">

                    <div class="card-body">

                        <div class="mb-0 row" id="product-config-row">

                            <cfif prc.product.getCategory().getMode().getId() <> "BAS">

                                <form class="d-flex align-items-center justify-content-end" id="product-change-form">

                                    <label class="me-2">Finitura:</label>

                                    <select name="finishId" class="form-control width-250 me-4"
                                        data-bind="events: { change: changeUri }">
                                        <option value="">-- non trovato</option>
                                        <cfloop array="#prc.finishes#" item="item">
                                            <option value="#item.getId()#"
                                                <cfif item.getId() EQ prc.finish.getId()>SELECTED</cfif>
                                            >
                                                #item.getName()#
                                            </option>
                                        </cfloop>

                                    </select>

                                    <label class="me-2">Modello:</label>

                                    <select name="modelId" class="form-control w-auto"
                                        data-bind="events: { change: changeUri }">
                                        <option value="">-- non trovato</option>
                                        <cfloop array="#prc.models#" item="item">
                                            <option value="#item.getId()#"
                                                <cfif item.getId() EQ prc.model.getId()>SELECTED</cfif>
                                            >
                                                #item.getCode()#
                                            </option>
                                        </cfloop>
                                    </select>

                                </form>

                            </cfif>

                        </div>

                        <div class="row">

                            <div class="col-12">

                                <ul class="nav nav-tabs" role="tablist">
                                    <li class="nav-item active">
                                        <a class="nav-link active" role="tab" data-bs-toggle="tab" aria-selected="true"
                                            id="product-general-tab"
                                            href="##product-general"
                                            aria-controls="product-general">
                                                Generale
                                        </a>
                                    </li>
                                    <li class="nav-item" data-bind="role: this" data-role-list="ADM/TCD/CMA" >
                                        <a class="nav-link" role="tab"data-bs-toggle="tab"  aria-selected="true"
                                            id="product-detail-tab"
                                            href="##product-detail"
                                            aria-controls="product-detail">
                                                Altri dati
                                        </a>
                                    </li>
                                    <cfif ArrayLen( prc.page.engraving.attributes )>
                                    <!--- griglia incisioni: solo frutti con attributi IS/II/IL, modificabile da ADM/TCD --->
                                    <li class="nav-item" data-bind="role: this" data-role-list="ADM/TCD">
                                        <a class="nav-link" role="tab" data-bs-toggle="tab" aria-selected="false"
                                            id="product-engravings-tab"
                                            href="##product-engravings"
                                            aria-controls="product-engravings">
                                                Griglia incisioni
                                        </a>
                                    </li>
                                    </cfif>
                                </ul>

                            </div>

                        </div>

                        <div class="row mb-3">

                            <div class="col-12">

                                <form id="product-detail-form">

                                    <div class="tab-content">


                                        <!---
                                            Generale
                                        --->

                                        <div class="tab-pane p-2 fade show active" id="product-general" role="tabpanel" aria-labelledby="product-general-tab">

                                            <div class="col-md-4 mb-3" data-bind="role: this" data-role-list="ADM/TCD">
                                                <button class="btn btn-primary btn-sm" data-bind="click:openAttributesList">Gestisci attributi &raquo;</button>
                                            </div>

                                            <div class="col-md-12">

                                                <div>

                                                    <div class="row d-flex mb-2">

                                                        <div class="col-sm-6 border-end">

                                                            <cfif prc.product.getCategory().getType().getId() == "SEG">
                                                                - <a href="/manager/signages/rows-config?lineId=#prc.line.getId()#&modelId=#prc.model.getId()#&categoryId=#prc.product.getCategory().getId()#" target="_blank" class="underline">
                                                                    Configurazione font #prc.line.getName()# / #prc.model.getCode()# &raquo;
                                                                    </a>

                                                                <br>
                                                            </cfif>

                                                            <cfif prc.product.getCategory().getMode().getId() <> "BAS">
                                                                - <a href="" class="underline" data-type="catalogBundle"
                                                                    data-model-id="#prc.model.getId()#"
                                                                    data-model-name="#prc.model.getCode()#"
                                                                    data-line-id="#prc.line.getId()#"
                                                                    data-line-name="#prc.line.getName()#"
                                                                    data-bind="click:openComponentsList">
                                                                        Componenti per #prc.line.getName()# / #prc.model.getCode()# &raquo;
                                                                    </a>

                                                                <br>
                                                            </cfif>

                                                            - <a href="" class="underline"
                                                                data-type="product"
                                                                data-product-id="#rc.id#"
                                                                data-product-name="#prc.textLink#"
                                                                data-bind="click: openComponentsList">
                                                                    #prc.textLink# &raquo;
                                                                </a>

                                                            <br>

                                                            <span
                                                                data-bind="role: this"
                                                                data-role-list="ADM/TCD"
                                                            >
                                                                - <a href="" class="underline"
                                                                    data-type="product"
                                                                    data-bind="click: openReorderingModal"
                                                                    >
                                                                        Riordina attributi &raquo;
                                                                    </a>

                                                                <br>
                                                                - <a href="" class="underline"
                                                                    data-type="product"
                                                                    data-bind="click:openImagesList">
                                                                        Aggiungi immagini per questo articolo &raquo;
                                                                    </a>

                                                                <br>

                                                                - <a href="/manager/products/#rc.id#/combinations" class="underline">
                                                                        Tutte le combinazioni &raquo;
                                                                    </a>
                                                            </span>

                                                        </div>

                                                        <div class="col-sm-6">

                                                            <div class="row">
                                                                <div class="col-3">
                                                                    <label class="my-1">Quantità</label>
                                                                    <input class="form-control text-end"
                                                                        id="product-simulate-quantity" value="1" type="number" min="1" style="width: 100px">
                                                                    <cfif prc.product.getCategory().getType().getId() == "SEG">
                                                                        <label class="my-1">N° Lettere</label>
                                                                        <input class="form-control text-end"
                                                                            id="product-simulate-letters-quantity" value="0" type="number" min="0" style="width: 100px">
                                                                    </cfif>
                                                                </div>
                                                                <div class="col-9">
                                                                    <cfif prc.product.getCategory().getType().getId() == "SEG">
                                                                        <label class="my-1">Font Family / Altezza:</label>
                                                                        <select type="text" class="form-control" style="width: 400px;" name="simulationSignageConfigItem"
                                                                            data-bind="value: simulationSignageConfigItem, source: fontSizeOptions"
                                                                            data-value-field="id"
                                                                            data-text-field="name"
                                                                            data-value-primitive="true"
                                                                        >
                                                                        </select>
                                                                    </cfif>

                                                                    <div class="col-12">
                                                                        <label class="my-1">Interlinee</label>
                                                                        <div
                                                                            data-template="product-line-height-row-tmpl"
                                                                            data-bind="source: currentLineHeights"
                                                                        ></div>
                                                                    </div>

                                                                    <div id="product-simulate-loading"></div>
                                                                </div>

                                                                <cfif prc.product.getCategory().getType().getId() == "SEG">
                                                                    <div class="row mt-4">
                                                                        <div class="col-2">
                                                                            <label class="my-1">Larghezza targa</label>
                                                                            <div class="d-flex">
                                                                            <input class="form-control text-end" id="plate_width" data-bind="value: product.plateWidth" />
                                                                            <div class="ms-1 mt-2">px</div>
                                                                            </div>
                                                                        </div>
                                                                        <div class="col-2">
                                                                            <label class="my-1">Altezza targa</label>
                                                                            <div class="d-flex">
                                                                            <input class="form-control text-end" id="plate_height" data-bind="value: product.plateHeight" />
                                                                            <div class="ms-1 mt-2">px</div>
                                                                            </div>
                                                                        </div>
                                                                        <div class="col-2">
                                                                            <label class="my-1">Margine alto</label>
                                                                            <div class="d-flex">
                                                                            <input class="form-control text-end" id="margin_top" data-bind="value: product.marginTop" />
                                                                            <div class="ms-1 mt-2">px</div>
                                                                            </div>
                                                                        </div>
                                                                        <div class="col-2">
                                                                            <label class="my-1">Margine sinistra</label>
                                                                            <div class="d-flex">
                                                                            <input class="form-control text-end" id="margin_left" data-bind="value: product.marginLeft" />
                                                                            <div class="ms-1 mt-2">px</div>
                                                                            </div>
                                                                        </div>
                                                                    </div>

                                                                    <div class="col-12 my-4">
                                                                        <button class="btn btn-primary btn-sm mt-2" data-bind="click:saveMargins">
                                                                            Salva
                                                                        </button>
                                                                    </div>

                                                                    <hr style="width: 98%; margin: auto;">
                                                                </cfif>
                                                            </div>
                                                            <div>
                                                                <cfif prc.product.getPrices().len() GT 0>
                                                                    <h3>Prezzi</h3>
                                                                </cfif>
                                                                <!--- sempre: senza prezzi il simula mostra lo stesso il costo --->
                                                                #button(
                                                                    label="Simula prezzo",
                                                                    bind  = "click:simulatePrice",
                                                                    size  = "sm"
                                                                )#
                                                                <cfif prc.product.getPrices().len() GT 0>
                                                                    <div data-bind="source: product.prices" data-template="price-row-tmpl">
                                                                    </div>
                                                                </cfif>
                                                            </div>

                                                        </div>

                                                    </div>

                                                </div>

                                            </div>

                                        </div>


                                        <!---
                                            Altri dati
                                        --->

                                        <div class="tab-pane p-2 fade" id="product-detail" role="tabpanel" aria-labelledby="product-detail-tab">
                                            <div class="row" data-bind="role: this" data-role-list="ADM/TCD/CMA">

                                                <div class="col-md-12 mb-3 col-lg-6">

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="qta">ID</label>
                                                            <div class="d-flex col-9 align-items-center">
                                                                <span data-bind="text: product.id" id="product-id" class="me-2">
                                                                </span>
                                                                <a href="##" data-bind="click:copyId" class="underline">Copia</a>
                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="qta">Status</label>
                                                            <div class="col-9">
                                                                <select type="text" class="form-control" name="statusId"
                                                                    required
                                                                    data-bind="source: statuses, value: product.status.id"
                                                                    data-value-field="id"
                                                                    data-text-field="name">
                                                                </select>
                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="qta">Quantità minima</label>
                                                            <div class="col-9">
                                                                <input class="form-control col-9" name="minQuantity" id="minQuantity"
                                                                    data-bind="value: product.minQuantity"
                                                                    >
                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="qta">Quantità massima</label>
                                                            <div class="col-9">
                                                                <input class="form-control col-9" name="maxQuantity" id="maxQuantity"
                                                                    data-bind="value: product.maxQuantity"
                                                                    >
                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="special">Attributi da esportare</label>
                                                            <div class="col-9">

                                                                <select id="product-important-attributes"
                                                                    data-placeholder="-- Seleziona gli attributi"
                                                                    data-role="multiselect"
                                                                    data-bind="source: attributesForSuggest, value: product.importantAttributes"
                                                                    data-value-field="id"
                                                                    data-text-field="name">
                                                                </select>

                                                                <script type="text/template" id="product-attribute-suggest-list-row-xx">
                                                                    <div>
                                                                        <span data-bind="text: name"></span>
                                                                    </div>
                                                                </script>

                                                                <div data-bind="source:  product.importantAttributes" data-template="product-attribute-suggest-list-row-xx"></div>

                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3 text-end" for="special">Speciale</label>
                                                            <div class="col-9">
                                                                <input class="me-4 ms-2" type="checkbox" name="special" id="special"
                                                                    data-bind="checked: product.special">
                                                            </div>
                                                        </div>

                                                        <div class="form-group pb-3 row align-items-center">
                                                            <label class="col-3" for="special"></label>
                                                            <div class="col-9 d-flex align-items-center">
                                                                #saveButton( bind="click:save", size="sm" )#
                                                                <div class="status errors-counter ms-2"></div>
                                                            </div>
                                                        </div>



                                                </div>

                                            </div>


                                        </div>


                                        <cfif ArrayLen( prc.page.engraving.attributes )>#view( "product/engravings-tab" )#</cfif>
                                    </div>

                                </form>

                            </div>

                        </div>

                        <div class="row">

                            <!---- product grid ---->

                            <div class="col-8 mb-2">

                                <a href=""
                                    class="underline"
                                    id="toggle-unlinked-attributes"
                                    data-bind="click:toggleUnlinked, text: textToggleLink">
                                </a>

                                <span
                                    data-bind="role: this"
                                    data-role-list="ADM/TCD"
                                >
                                    |

                                    <a href="" class="underline" data-type="item" data-product-id="0"
                                        data-product-name="Attributo radice"
                                        data-bind="click:openAttributesList"
                                    >
                                        Aggiungi attributo di base
                                    </a>

                                    |

                                    <a href="" class="underline"
                                        data-product-name="Attributo radice"
                                        data-bind="click:showCloneModal"
                                    >
                                        Clona albero
                                    </a>
                                </span>

                            </div>

                            <div class="text-end col-4 mb-2"
                                data-bind="role: this"
                                data-role-list="ADM/TCD"
                            >
                                #deleteButton(
                                    bind  = "click:removeAttributes",
                                    size  = "sm",
                                    class = "ms-2"
                                )#
                            </div>

                            <form id="product-grid-form">

                                <!---
                                TODO: remove productAttributesList
                                #productAttributesList(
                                    id="product-items-grid",
                                    type="product",
                                    onDataBound="AP.product.items.onDataBound",
                                    pageSizes=false
                                )#
                                ---->

                                #grid(
                                    id      = "product-items-grid",
                                    class   = "no-pager",
                                    columns = "[
                                        { 'field':'Id', 'title':'ID', width: '70px' },
                                        { 'field':'name', 'title':'Attributo' },
                                        { 'field':'', 'title':'Prezzo', width: '180px'},
                                        { 'field':'', 'title':'Aggiungi immagini', width: '200px'},
                                        { 'field':'', 'title':'Aggiungi altri attributi', width: '200px'},
                                        { 'field':'', 'title':'Aggiungi componenti all\'attributo', width: '250px'},
                                        {
                                            'field'           :'',
                                            'title'           :'<input type=checkbox onclick=NM.util.checkAll(this) name=selectAll>',
                                            'width'           :'40px',
                                            'headerAttributes': { 'class': 'text-center' }
                                        }
                                    ]",
                                    source: "items",
                                    rowTemplate = "product/product-item-row-tmpl"
                                )#

                            </form>

                            <!---- // product grid ---->

                        </div>

                    </div>

                </section>

            </div>
        </div>

        #view( "product/attributes-list-modal" )#
        #view( "product/sorting-modal" )#
        #view( "product/clone-modal" )#

    </div>

    #template("jstemplate/attribute/attribute-suggest-list-row-tmpl")#
    #template("jstemplate/price/price-row-tmpl")#

    <script type="text/x-kendo-template" id="product-line-height-row-tmpl">
        <div class="d-flex align-items-center mb-1">
            <span class="me-2" style="width: 100px">Riga ##: index ##:</span>
            <input
                type="number"
                step="0.1"
                min="0"
                class="form-control text-end"
                style="width: 100px"
                data-bind="value: value"
                data-value-update="keyup"
            />
            <span class="ms-1">px</span>
        </div>
    </script>

    #view( "attribute/detail-modal" )#
    #view( "component/list-modal" )#
    #view( "file/list-modal" )#
    #view( "price/list-modal" )#
    #view( "price/simulate-modal" )#

</cfoutput>
