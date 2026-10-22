AP.namespace( "plate" );

Object.assign( AP.plate.fields, {
    modalRoot: $( "#plate-modal-root" ),
} );

AP.plate.modal = ( function() {
    /**
     * Riferimento globale all'istanza Vue della placca.
     * @type {Vue|null}
     */
    window.vm = null;

    /** Oggetto pubblico esportato dal modulo. */
    const pub = {};

    /** Risposta del server restituita dal caricamento della placca in modifica. */
    let plateResponse = null;

    /**
     * Restituisce il modulo griglia per la gestione delle celle della placca.
     * @returns {Object|null} Il modulo AP.plate.grid o null se non definito.
     */
    function getGridModule() {
        return AP.plate.grid;
    }

    /**
     * Restituisce l'app modale per la gestione dei file allegati.
     * @returns {Object} Il modulo AP.file.modal.
     */
    function fileApp() {
        return AP.file.modal;
    }

    /**
     * Rasterizza un'immagine SVG (background-image) in un PNG delle dimensioni date,
     * replicando "background-size:contain" + "background-position:center". Serve perché
     * html2canvas non rasterizza in modo affidabile gli SVG senza width/height espliciti
     * (solo viewBox, come i pittogrammi delle incisioni): li disegna microscopici invece
     * che riempire il box. Il rendering nativo del browser (drawImage), invece, rispetta
     * sempre il viewBox correttamente: da qui il giro per un canvas intermedio.
     * @param {string} url - URL dell'immagine SVG.
     * @param {number} w - Larghezza target in px.
     * @param {number} h - Altezza target in px.
     * @returns {Promise<string>} Data URL PNG risultante.
     */
    function svgUrlToPngDataUrl( url, w, h ) {
        return new Promise( ( resolve, reject ) => {
            const img = new Image();
            img.crossOrigin = "anonymous";
            img.onload = () => {
                const canvas   = document.createElement( "canvas" );
                canvas.width   = w;
                canvas.height  = h;
                const ctx      = canvas.getContext( "2d" );
                const naturalW = img.naturalWidth || w;
                const naturalH = img.naturalHeight || h;
                const scale    = Math.min( w / naturalW, h / naturalH );
                const drawW    = naturalW * scale;
                const drawH    = naturalH * scale;
                ctx.drawImage( img, ( w - drawW ) / 2, ( h - drawH ) / 2, drawW, drawH );
                resolve( canvas.toDataURL( "image/png" ) );
            };
            img.onerror = reject;
            img.src = url;
        } );
    }

    /**
     * Sostituisce temporaneamente il background-image SVG dei simboli di incisione dentro
     * $root con un PNG pre-rasterizzato (vedi svgUrlToPngDataUrl), per l'anteprima
     * html2canvas. Restituisce la lista delle sostituzioni fatte, da ripristinare subito
     * dopo la cattura con restoreSvgSymbols().
     * @param {Object} $root - Elemento jQuery radice su cui cercare .fruit-engraving-symbol.
     * @returns {Promise<Array<{el: Object, original: string}>>} Sostituzioni da ripristinare.
     */
    async function rasterizeSvgSymbolsForPreview( $root ) {
        const restores = [];
        const symbols  = $root.find( ".fruit-engraving-symbol" ).filter( function() {
            return /\.svg(["')]|\?)/i.test( $( this ).css( "background-image" ) );
        } );
        for ( const el of symbols.toArray() ) {
            const $el   = $( el );
            const bg    = $el.css( "background-image" );
            const match = bg.match( /url\(["']?([^"')]+)["']?\)/ );
            if ( !match ) {
                continue;
            }
            const w = Math.max( 1, Math.round( $el.width() ) );
            const h = Math.max( 1, Math.round( $el.height() ) );
            try {
                const dataUrl = await svgUrlToPngDataUrl( match[1], w, h );
                restores.push( { el: $el, original: bg } );
                $el.css( "background-image", `url('${dataUrl}')` );
            } catch ( e ) {
                // se il rasterize fallisce (es. CORS) meglio lasciare l'svg originale:
                // peggio nella preview, ma non deve bloccare il salvataggio
            }
        }
        return restores;
    }

    /**
     * Ripristina i background-image SVG sostituiti da rasterizeSvgSymbolsForPreview().
     * @param {Array<{el: Object, original: string}>} restores - Sostituzioni da annullare.
     */
    function restoreSvgSymbols( restores ) {
        restores.forEach( ( r ) => { r.el.css( "background-image", r.original ); } );
    }

    /**
     * Crea e restituisce la struttura dati predefinita per il form di dettaglio della placca.
     * Contiene dati iniziali vuoti, elenchi di stato, titolo e configurazioni di prezzo.
     * @returns {Object} Oggetto form con proprietà data, statuses, itemStatuses, title, canSave, isClone, priceTypes.
     */
    function createDefaultDetailForm() {
        return {
            data: {
                id: "",
                quantity: 1,
                special: false,
                customImage: false,
                bozza: false,
                note: "",
                status: { id: "ACT" },
                position: { id: "", code: "" },
                quotationZone: { id: "", name: "" },
                quotationZoneId: "",
                quotationSubzone: null,
                quotationSubzoneId: "",
                product: {
                    id: "",
                    orientation: { id: "" },
                    frame: { id: "" },
                    finish: { id: "" },
                    line: { id: "" },
                    model: { id: "", code: "" },
                    image: { id: "", uri: "" },
                    items: [],
                },
                plateQuotationItemProductItems: [],
                fruits: [],
                fruitQuotationItemProductItems: [],
                productItemsImages: [],
            },
            statuses: AP.page.statuses || [],
            itemStatuses: AP.page.itemStatuses || [],
            title: "Carica placca",
            canSave: false,
            isClone: false,
            priceTypes: [
                { id: "C", name: "Calcolato" },
                { id: "F", name: "Fisso" },
            ],
        };
    }

    /** Valori predefiniti per una nuova placca: dimensioni, orientamento e griglia di base. */
    const defaultPlate = {
        id: "100",
        code: "508",
        image: { uri: "" },
        width: 1200,
        height: 500,
        displayScale: 1,
        // Ingombro dell'armatura in px (già scalato): serve a centrarla nel canvas.
        frameWidth: 1200,
        frameHeight: 500,
        orientation: { id: "" },
        cellOrientation: { id: "" },
        blocks: [],
        // override orientamento per singolo blocco: { "<order>": "HOR"|"VER" }
        blockOrientations: {},
        grid: [
            [
                { type: "_", id: "default-cell-1" },
                { type: "_", id: "default-cell-2" },
            ],
        ],
    };

    /**
     * Mappa i dati di un frutto nel formato richiesto dal FruitsController della griglia.
     * Calcola larghezza e altezza in base alle dimensioni delle celle libere e al positionCount.
     * @param {Object} data - Dati del frutto da mappare.
     * @param {string} data.id - Identificativo del frutto.
     * @param {string} data.fruitId - Identificativo del prodotto frutto.
     * @param {Object} data.fruit - Oggetto frutto con proprietà code, name, horizontalImage.
     * @param {number} [data.fruit.positionCount] - Numero di posizioni occupate dal frutto sulla griglia.
     * @returns {Object|null} Oggetto frutto formattato per la griglia, o null se il modulo griglia non è disponibile.
     */
    function mapFruitForPlate( data ) {
        const gm = getGridModule();
        if ( !gm ) {
            return null;
        }
        const displayScale = pub.fruitsController?.plate?.displayScale ?? 1;
        const fruitWidth  = gm.constants.GRID_CELL_DIMENSIONS[gm.CELL_TYPE.FREE].width  * displayScale * ( data.fruit.positionCount || 1 );
        const fruitHeight = gm.constants.GRID_CELL_DIMENSIONS[gm.CELL_TYPE.FREE].height * displayScale;
        return {
            id: data.id,
            fruitId: data.fruitId,
            width: fruitWidth,
            height: fruitHeight,
            columnSpan: data.fruit.positionCount || 1,
            rowSpan: 1,
            code: data.fruit.code,
            name: data.fruit.name,
            image: data.fruit?.horizontalImage?.uri || "/assets/main/img/fruit-generic.png",
        };
    }

    /**
     * Crea un nuovo oggetto frutto arricchito con dati aggiuntivi.
     * Aggiunge fruitId, genera un UUID se mancante e inizializza posizioni e items.
     * @param {Object} data - Dati base del frutto.
     * @param {Object} data.fruit - Oggetto frutto con proprietà id.
     * @param {string} [data.id] - Identificativo opzionale del frutto.
     * @param {Array} [data.positionIds] - Elenco opzionale degli ID posizione.
     * @returns {Object} Nuovo oggetto frutto con proprietà id, fruitId, positionIds, items, expanded.
     */
    function createFruit( data ) {
        const fruit = { ...data };
        fruit.fruitId = data.fruit.id;
        fruit.id = data.id || NM.util.uuid();
        fruit._key = NM.util.uuid();
        fruit.positionIds = data.positionIds || [];
        fruit.items = [];
        fruit.expanded = true;
        return fruit;
    }

    /**
     * Configura la placca all'interno del modulo griglia.
     * Imposta le dimensioni delle celle, costruisce la griglia a partire dai dati della placca,
     * crea il Plate e il FruitsController, disegna la placca nel DOM e aggiunge i frutti esistenti.
     * Aggiorna il flag isPlateDefined al termine.
     */
    function configPlate() {
        const gm = getGridModule();
        if ( !gm ) {
            return;
        }

        const plate = window.vm.plate;

        let freeCellWidth = gm.constants.GRID_CELL_DIMENSIONS[gm.CELL_TYPE.FREE].width;
        let freeCellHeight = gm.constants.GRID_CELL_DIMENSIONS[gm.CELL_TYPE.FREE].height;

        if ( plate.cellOrientation.id == gm.orientation.VERTICAL ) {
            const tmp = freeCellWidth;
            freeCellWidth = freeCellHeight;
            freeCellHeight = tmp;
        }

        gm.setCellDimensions( freeCellWidth, freeCellHeight );

        const isBlockPlate = !!( plate.blocks && plate.blocks.length );

        const grid = [];
        if ( !isBlockPlate ) {
            for ( const columns of plate.grid ) {
                const row = [];
                for ( const cellData of columns ) {
                    const cellType = cellData.type;
                    const cell = new gm.Cell(
                        gm.constants.GRID_CELL_DIMENSIONS[cellType].width,
                        gm.constants.GRID_CELL_DIMENSIONS[cellType].height,
                        plate.cellOrientation.id,
                        cellType,
                        cellData.id,
                        cellData.order
                    );
                    row.push( cell );
                }
                grid.push( row );
            }
        }

        // Per le placche a blocchi, scala le coordinate dal sistema mm (1mm=1px)
        // al canvas del designer (TARGET_WIDTH=1000px). displayScale=1 per le legacy.
        const displayScale = plate.displayScale || 1;
        const scaledBlocks = isBlockPlate
            ? ( plate.blocks || [] ).map( b => ( {
                ...b,
                top:    b.top    * displayScale,
                left:   b.left   * displayScale,
                width:  b.width  * displayScale,
                height: b.height * displayScale,
            } ) )
            : null;

        const plateObj = new gm.Plate( {
            width: plate.width,
            height: plate.height,
            frameWidth: plate.frameWidth,
            frameHeight: plate.frameHeight,
            orientation: plate.orientation.id,
            cellOrientation: plate.cellOrientation.id,
            id: plate.id,
            code: plate.code,
            image: plate.image?.uri || "",
            // placche a blocchi: la griglia viene costruita da drawBlocksWithin()
            blocks: scaledBlocks,
            displayScale: displayScale,
            onRotateBlock: isBlockPlate ? function( blockOrder ) {
                window.vm.rotateBlock( blockOrder );
            } : null,
            grid: grid,
            isSpecial: false,
        } );

        pub.fruitsController = new gm.FruitsController( {
            plate: plateObj,
            fruits: [],
        } );

        pub.fruitsController.plate.drawGridWithin( $( ".plate-designer" ) );

        window.vm.isPlateDefined = true;
    }

    /**
     * Wrapper per le chiamate AJAX tramite NM.util.ajax.
     * @param {Object} opts - Opzioni della richiesta AJAX.
     * @returns {Object} Promise restituita da NM.util.ajax.
     */
    const ajax = function( opts ) {
        return NM.util.ajax( opts );
    };

    /** URL base per le richieste AJAX del manager. */
    const BASE = "/manager/ajax";

    /**
     * Memoria degli attributi frutto per cui i figli sono già stati richiesti al server.
     * Chiave: fruitId + "-" + itemId (fi.id); valore: originId (productItemId selezionato).
     * processFruitCascade la usa per riconoscere gli attributi foglia (il server non restituisce
     * figli): senza questa memoria childrenLoaded resta false per sempre e ogni giro del watcher
     * li ricaricherebbe, riassegnando fruit.items e innescando un loop cascata → render → watcher.
     */
    const fruitChildrenLoaded = new Map();

    /**
     * Recupera i dati completi di una placca.
     * @param {string} id - Identificativo della placca.
     * @returns {Object} Promise della richiesta AJAX.
     */
    function getPlate( id ) {
        return ajax( { method: "GET", url: BASE + "/quotation-items/plate/" + id } );
    }

    /**
     * Template originale dell'element #plate-vue-app, cacheato al primo montaggio
     * per poter ripristinare le direttive Vue prima di un re-mount.
     */
    let plateVueTemplate = "";

    /**
     * Monta l'applicazione Vue per il modale della placca.
     * Crea una nuova istanza Vue direttamente, senza attendere eventi Bootstrap.
     * Se un'istanza esiste già (da un'apertura precedente), la distrugge
     * e ripristina il template originale prima di crearne una nuova.
     */
    function mountVue() {
        fruitChildrenLoaded.clear();
        if ( window.vm ) {
            window.vm.$destroy();
            window.vm = null;
        }

        // Cache del template originale al primo montaggio e ripristino prima del re-mount
        if ( plateVueTemplate ) {
            $( "#plate-vue-app" ).html( plateVueTemplate );
        } else {
            plateVueTemplate = $( "#plate-vue-app" ).html() || "";
        }

        // Lega la pulizia alla chiusura del modal (un solo handler attivo per volta)
        $( "#plate-modal-root" ).off( "hidden.bs.modal" ).on( "hidden.bs.modal", function() {
            if ( window.vm ) {
                window.vm.$destroy();
                window.vm = null;
            }
        } );

        window.vm = new Vue( {
            data: {
                backgroundCustomImage: { id: "", url: "" }, /** Immagine personalizzata di sfondo per la placca. */
                detailForm: createDefaultDetailForm(), /** Dati del form di dettaglio: item, prodotto, frutti, zone e stato. */
                lines: [], /** Elenco delle linee prodotto disponibili. */
                models: [], /** Elenco dei modelli disponibili per la linea selezionata. */
                finishes: [], /** Elenco delle finiture disponibili per il modello selezionato. */
                plate: { ...defaultPlate }, /** Dati della placca corrente: dimensioni, orientamento, griglia e immagine. */
                availableOrientations: [], /** Orientamenti disponibili per il telaio selezionato. */
                currentFruit: {}, /** Frutto correntemente selezionato o in interazione. */
                toggleFruitsLabel: "Comprimi tutti", /** Etichetta del pulsante comprimi/espandi tutti i frutti. */
                zones: [], /** Zone di quotazione principali (senza origine). */
                subzones: [], /** Sottozone di quotazione (con origine). */
                allZones: [], /** Elenco completo di tutte le zone, incluse le sottozone. */
                isEditMode: false, /** Flag che indica se la modalità corrente è di modifica. */
                isPlateDefined: false, /** Flag che indica se la placca è stata disegnata nella griglia. */
                fruitSearchTerm: "", /** Termine di ricerca per il suggeritore frutti. */
                fruitSuggestions: [], /** Suggerimenti frutti corrispondenti alla ricerca. */
                positionSearchTerm: "", /** Termine di ricerca per il suggeritore posizioni. */
                positionSuggestions: [], /** Suggerimenti posizioni corrispondenti alla ricerca. */
                fruitSuggestLoading: false, /** Flag di caricamento per la ricerca frutti. */
                positionSuggestLoading: false, /** Flag di caricamento per la ricerca posizioni. */
                productItemsImages: {}, /** Mappa degli URI delle immagini dei product items, indicizzata per ID. */
                activeTab: "plate", /** Tab attivo nel pannello degli attributi (plate | fruits). */
                smallLoading: false, /** Flag di caricamento. */
                exportCodePreview: null, /** Anteprima codice export (articolo + variante) dal server, vedi refreshExportCode. */
                savedExportCode: "", /** Codice realmente salvato in export_codes per l'ultima esportazione di questa riga (vedi savedExportCode in editPlate), "" se mai esportata. */
                importantAttributes: [], /** Attributi "da esportare" del prodotto ({ id, code }), per il badge accanto al nome. */
                canEdit: AP.page.canEdit, /** Flag che indica se il preventivo è modificabile. */
                showJsonPanel: false, /** Flag per mostrare il pannello JSON export (provvisorio). */
                jsonExportText: "", /** Contenuto JSON dell'export placca. */
                jsonExportLoading: false, /** Flag di caricamento per il JSON export. */
                show3dPanel: false, /** Flag per mostrare il pannello JSON 3D. */
                json3dText: "", /** Contenuto JSON 3D della placca. */
                json3dLoading: false, /** Flag di caricamento per il JSON 3D. */

                /**
                 * Griglie incisioni dei frutti sulla placca, per id prodotto frutto:
                 * { attributes: [ { id, code, name, markers[] } ], rootCodes, symbolCodes, symbolSizeMm }.
                 * Caricata una volta per prodotto da /ajax/products/:id/engraving-markers.
                 */
                engravingGrids: {},
                /**
                 * Posizione scelta per ogni simbolo inciso, chiave "fruitId-itemId":
                 * { markerId, order, code }. Tenuta fuori da detailForm.data.fruits per non
                 * far scattare il watcher profondo a ogni trascinamento; il dato che viene
                 * salvato è value.engravingMarkerId sul valore selezionato.
                 */
                engravingSelection: {},

                /** Dati di prezzatura: sconti, metodo di calcolo, righe e totale. */
                pricing: {
                    data: {
                        id: "",
                        quantity: 1,
                        discount1: "",
                        discount2: "",
                        method: { id: "C", name: "Calcolato" },
                        lines: [],
                        total: 0,
                    },
                    priceTypes: [
                        { id: "C", name: "Calcolato" },
                        { id: "F", name: "Fisso" },
                    ],
                    isTotalEnabled: false,
                },
            },

            computed: {
                /**
                 * Codice dello slot orientamento nel codice variante export (es. "HO"), letto
                 * dall'anteprima del server: è l'unica parte senza attributeId. Vuoto se
                 * l'anteprima non c'è ancora (nessun prodotto scelto).
                 */
                orientationExportCode: function() {
                    const parts = ( this.exportCodePreview && this.exportCodePreview.variantParts ) || [];
                    const part = parts.find( ( p ) => { return !p.attributeId; } );
                    return part ? part.attributeCode : "";
                },

                /**
                 * Restituisce il numero totale di frutti presenti nel form.
                 * @returns {number} Conteggio dei frutti.
                 */
                getFruitCount: function() {
                    return this.detailForm.data.fruits.length;
                },

                /**
                 * Indica se il pulsante di cancellazione superiore deve essere visibile.
                 * È visibile solo in modalità nuovo inserimento (ID assente).
                 * @returns {boolean} True se il form è in modalità nuovo inserimento.
                 */
                visibleUpperClearButton: function() {
                    return this.detailForm.data.id === "";
                },

                /**
                 * Indica se il pulsante di cancellazione inferiore deve essere visibile.
                 * È visibile solo in modalità nuovo inserimento (ID assente).
                 * @returns {boolean} True se il form è in modalità nuovo inserimento.
                 */
                visibleLowerClearButton: function() {
                    return this.detailForm.data.id === "";
                },

                /**
                 * HTML della riga "Codice export" (helper condiviso AP.quotation.exportCode).
                 */
                exportCodeHtml: function() {
                    return AP.quotation.exportCode.html( this.exportCodePreview, this.savedExportCode );
                },

                /**
                 * Pulsanti di debug "JSON"/"JSON 3D": visibili solo a chi sta sviluppando
                 * quella funzionalità, non fanno parte del flusso utente normale.
                 */
                canSeeJsonDebugButtons: function() {
                    return AP.hasEmail( "guido.sangiovanni@gslabs.it" );
                },
            },

            watch: {
                /**
                 * Osserva il cambiamento della zona di quotazione selezionata.
                 * Alla selezione di una nuova zona, carica le relative sottozone.
                 * @param {string} newZoneId - Identificativo della nuova zona selezionata.
                 */
                "detailForm.data.quotationZoneId": function( newZoneId ) {
                    this.loadSubZones( newZoneId );
                },

                /**
                 * Osserva in profondità l'array dei frutti per rilevare cambiamenti
                 * nelle selezioni degli attributi (sia manuali che automatici).
                 * Quando una value diventa selected=true, carica i figli tramite
                 * processFruitCascade e aggiorna gli overlay delle immagini.
                 * L'uso di deep: true garantisce la reattività anche per modifiche
                 * annidate (es. values[0].selected = true).
                 */
                "detailForm.data.fruits": {
                    deep: true,
                    handler: function() {
                        this.$nextTick( function() {
                            if ( !this._cascadingFruit ) {
                                this._cascadingFruit = true;
                                this.processFruitCascade().finally( function() {
                                    this._cascadingFruit = false;
                                }.bind( this ) );
                            }
                        }.bind( this ) );
                    },
                },
            },

            methods: {
                // MARK: Lifecycle
                /**
                 * Reimposta il form di dettaglio ai valori predefiniti.
                 * Sostituisce tutti i dati del form con una nuova istanza pulita,
                 * resettando frutti e product items.
                 */
                resetDetailForm: function() {
                    const fresh = createDefaultDetailForm();
                    Object.assign( this.detailForm, fresh );
                    this.detailForm.data.fruits = [];
                    this.detailForm.data.product.items = [];
                    this.showJsonPanel = false;
                    this.jsonExportText = "";
                    this.show3dPanel = false;
                    this.json3dText = "";
                    this.savedExportCode = "";
                },

                // MARK: Custom Image
                /**
                 * Attiva o disattiva la modalità immagine personalizzata per la placca.
                 * Quando attivata, carica l'immagine di sfondo esistente e scambia
                 * la vista tra designer standard e personalizzato.
                 * Modifica il DOM mostrando/nascondendo #plate-designer e #plate-custom-designer.
                 */
                toggleCustomImage: function() {
                    const id = this.detailForm.data.id;
                    if ( id ) {
                        this.loadBackgroundCustomImage( id );
                    }
                    // La visibilità è gestita da v-show nel template
                },

                /**
                 * Carica l'immagine personalizzata di sfondo per un quotation item.
                 * Effettua una richiesta AJAX per ottenere le immagini associate all'item.
                 * @param {string} quotationItemId - Identificativo del quotation item.
                 */
                loadBackgroundCustomImage: async function( quotationItemId ) {
                    if ( !quotationItemId ) {
                        return;
                    }
                    await ajax( {
                        method: "GET",
                        url: BASE + "/quotation-items/" + quotationItemId + "/images",
                        callback: {
                            done: ( xhr ) => {
                                if ( xhr.data && xhr.data.length > 0 && xhr.data[0].uri ) {
                                    // Il template lega backgroundCustomImage.url, ma l'API restituisce uri.
                                    this.backgroundCustomImage = Object.assign( {}, xhr.data[0], { url: xhr.data[0].uri } );
                                }
                            },
                        },
                    } );
                },

                /**
                 * Apre il modale di selezione immagini per il quotation item corrente.
                 * Utilizza l'app file modale passando tipo e identificativo dell'item.
                 */
                openImagesList: function() {
                    const type = "quotationItem";
                    const value = {
                        type: type,
                        id: this.detailForm.data.id,
                        name: this.detailForm.data.id,
                    };
                    fileApp().open( value );
                },

                // MARK: Lines / Models / Finishes
                /**
                 * Carica l'elenco delle linee prodotto per la categoria 22.
                 * Effettua una richiesta AJAX e aggiorna la lista lines.
                 */
                loadLines: async function() {
                    await ajax( {
                        method: "GET",
                        url: BASE + "/quotations/lines/22",
                        callback: {
                            done: ( xhr ) => {
                                this.lines = xhr.data;
                            },
                        },
                    } );
                },

                /**
                 * Carica l'elenco dei modelli per la linea attualmente selezionata.
                 * Effettua una richiesta AJAX e aggiorna la lista models.
                 * Salva la preferenza utente per la linea.
                 */
                loadModels: async function() {
                    const lineId = this.detailForm.data.product.line.id;
                    if ( !lineId ) {
                        return;
                    }
                    await ajax( {
                        method: "GET",
                        // riga in modifica: il suo prodotto conta anche se eliminato dal catalogo
                        url: BASE + "/quotations/models/" + lineId + "?quotationItemId=" + ( this.detailForm.data.id || "" ),
                        callback: {
                            done: ( xhr ) => {
                                this.models = xhr.data;
                            },
                        },
                    } );
                    AP.setUserPref( "plate.lineId", lineId );
                },

                /**
                 * Carica l'elenco delle finiture per la linea selezionata.
                 * Effettua una richiesta AJAX e aggiorna la lista finishes.
                 * Verifica la possibilità di salvare e salva la preferenza utente per il modello.
                 */
                loadFinishes: async function() {
                    const modelId = this.detailForm.data.product.model.id;
                    const lineId = this.detailForm.data.product.line.id;
                    if ( !modelId || modelId === "" ) {
                        return;
                    }
                    await ajax( {
                        method: "GET",
                        url: BASE + "/quotations/finishes/22/" + lineId + "?modelId=" + encodeURIComponent( modelId ) + "&quotationItemId=" + ( this.detailForm.data.id || "" ),
                        callback: {
                            done: ( xhr ) => {
                                this.finishes = xhr.data;
                            },
                        },
                    } );
                    this.checkCanSave();
                    AP.setUserPref( "plate.modelId", modelId );
                },

                // MARK: Zones
                /**
                 * Carica l'elenco completo delle zone di quotazione.
                 * Filtra le zone separando quelle principali (senza origine) dalle sottozone.
                 * Aggiorna le proprietà allZones, zones e subzones.
                 */
                loadZones: async function() {
                    await ajax( {
                        method: "GET",
                        url: BASE + "/quotations/" + AP.page.quotation.id + "/zones",
                        callback: {
                            done: ( xhr ) => {
                                const allZones = xhr.data || [];
                                this.allZones = allZones;
                                this.zones = allZones.filter( ( zone ) => {
                                    return !zone.origin;
                                } );
                            },
                        },
                    } );
                },

                /**
                 * Carica le sottozone corrispondenti a una zona padre.
                 * Resetta la selezione della sottozona corrente.
                 * @param {string} zoneId - Identificativo della zona padre.
                 */
                loadSubZones: function( zoneId ) {
                    this.detailForm.data.quotationSubzoneId = "";
                    this.detailForm.data.quotationSubzone = null;
                    if ( !zoneId ) {
                        this.subzones = [];
                        return;
                    }
                    this.subzones = this.allZones.filter( ( z ) => {
                        return z.origin?.id === zoneId;
                    } );
                },

                /**
                 * Gestisce il cambiamento della zona di quotazione selezionata.
                 * Aggiorna l'oggetto quotationZone nel form con i dati completi della zona scelta.
                 */
                onZoneChange: function() {
                    const zoneId = this.detailForm.data.quotationZoneId;
                    if ( zoneId ) {
                        const match = this.allZones.find( ( z ) => { return z.id === zoneId; } );
                        if ( match ) {
                            this.detailForm.data.quotationZone = match;
                        }
                    } else {
                        this.detailForm.data.quotationZone = { id: "", name: "" };
                    }
                },

                openInPlant: function() {
                    var zoneId = this.detailForm.data.quotationSubzoneId || this.detailForm.data.quotationZoneId || "";
                    window.open( "/manager/quotation-plant-positions/" + AP.page.quotation.id + "?selectedZoneId=" + zoneId, "_blank" );
                },

                // MARK: Product loading
                /**
                 * Popola i campi del prodotto nel form di dettaglio a partire dai dati ricevuti.
                 * Imposta ID, finitura, modello, linea e immagine del prodotto.
                 * @param {Object} product - Dati del prodotto da mappare.
                 * @param {string} product.id - Identificativo del prodotto.
                 * @param {Object} product.finish - Oggetto finitura con proprietà id.
                 * @param {Object} product.model - Oggetto modello con proprietà id e code.
                 * @param {Object} product.line - Oggetto linea con proprietà id.
                 * @param {Object|null} product.horizontalImage - Immagine orizzontale con id e uri.
                 * @param {Object|null} product.verticalImage - Immagine verticale con id e uri.
                 */
                /**
                 * Imposta le dimensioni del canvas della placca (sfondo + immagine).
                 * Placche legacy: width/height dal server o default 1200x500 (con swap
                 * gestito da Rectangle in base all'orientamento).
                 * Placche a blocchi: il canvas è fisso 1200x500 (500x1200 se la placca
                 * è verticale) e l'armatura ci viene centrata dentro da drawBlocksWithin.
                 * plate.frameWidth/frameHeight sono l'ingombro dell'armatura già scalato,
                 * cioè il bounding box dei blocchi più i margini finali destro e
                 * inferiore: è il rettangolo da centrare, e arriva da data.width/height
                 * che il server calcola già comprensivi di quei margini.
                 * @param {Object} data - Risposta del server (frame).
                 */
                applyPlateCanvasSize: function( data ) {
                    const isBlockPlate = ( data.blocks || [] ).length > 0;

                    if ( !isBlockPlate ) {
                        this.plate.displayScale = 1;
                        this.plate.width  = data?.width  ?? 1200;
                        this.plate.height = data?.height ?? 500;
                        this.plate.frameWidth  = this.plate.width;
                        this.plate.frameHeight = this.plate.height;
                        return;
                    }

                    // displayScale converte mm → px per blocchi e celle.
                    // MAX_SCALE ≈ scala fisica CSS a 96dpi (allineata al builder con unità mm).
                    const MAX_SCALE     = 4;
                    const rawWidth  = data?.width  || 1;
                    const rawHeight = data?.height || 1;
                    const isVertical = data.orientation && data.orientation.id === "VER";
                    const canvasW = isVertical ? 500  : 1200;
                    const canvasH = isVertical ? 1200 : 500;
                    const displayScale = Math.min( canvasW / rawWidth, canvasH / rawHeight, MAX_SCALE );
                    this.plate.displayScale = displayScale;

                    this.plate.width  = Math.max( canvasW, rawWidth  * displayScale );
                    this.plate.height = Math.max( canvasH, rawHeight * displayScale );

                    this.plate.frameWidth  = rawWidth  * displayScale;
                    this.plate.frameHeight = rawHeight * displayScale;
                },

                populateProduct: function( product ) {
                    const image = product.horizontalImage || product.verticalImage;
                    this.detailForm.data.product.id = product.id || "";
                    this.detailForm.data.product.finish.id = product.finish.id;
                    this.detailForm.data.product.finish.name = product.finish.name || "";
                    this.detailForm.data.product.model.id = product.model.id;
                    this.detailForm.data.product.model.code = product.model.code;
                    this.detailForm.data.product.model.name = product.model.name || "";
                    this.detailForm.data.product.line.id = product.line.id;
                    this.detailForm.data.product.line.name = product.line.name || "";
                    this.detailForm.data.product.image.id = ( image?.id ) || "";
                    this.detailForm.data.product.image.uri = ( image?.uri ) || "";
                },

                /**
                 * Carica il prodotto in base a linea, modello e finitura selezionati.
                 * Effettua una richiesta AJAX per ottenere il prodotto, poi carica i product items
                 * e configura la placca. Salva la preferenza utente per la finitura.
                 */
                loadProduct: async function() {
                    const lineId = this.detailForm.data.product.line.id;
                    const modelId = this.detailForm.data.product.model.id;
                    const finishId = this.detailForm.data.product.finish.id;
                    AP.setUserPref( "plate.finishId", finishId );

                    if ( !finishId || finishId === "" ) {
                        this.detailForm.data.product.items = [];
                        return;
                    }

                    let productFound = false;

                    await ajax( {
                        method: "GET",
                        // riga in modifica: il suo prodotto resta anche se eliminato dal catalogo
                        url: BASE + "/quotation-items/product/by-params?categoryId=22&lineId=" + lineId + "&modelId=" + modelId + "&finishId=" + finishId + "&quotationItemId=" + ( this.detailForm.data.id || "" ),
                        callback: {
                            done: ( xhr ) => {
                                if ( !xhr.data || !xhr.data.id ) {
                                    AP.widget.notify( "error", "Nessun prodotto placca configurato per questa combinazione di linea, modello e finitura. Verifica l'anagrafica prodotti." );
                                    return;
                                }
                                productFound = true;
                                this.populateProduct( xhr.data );
                            },
                        },
                    } );

                    if ( !productFound ) {
                        this.detailForm.data.product.id = "";
                        this.detailForm.data.product.items = [];
                        return;
                    }

                    await this.firstLoadProductItems();
                    await this.loadPlate();
                },

                // MARK: Plate / Frame
                /**
                 * Carica i dati del telaio e configura la placca.
                 * Cerca il telaio corrispondente al codice modello, effettua una richiesta AJAX
                 * e aggiorna le proprietà della placca (dimensioni, orientamento, griglia, immagine).
                 * Se viene fornito un orientamento, attiva il cambio orientamento.
                 * @param {Object} [orientationValue] - Orientamento opzionale da applicare dopo il caricamento.
                 */
                loadPlate: async function( orientationValue ) {
                    const modelCode = this.detailForm.data.product.model.code;
                    const image = this.detailForm.data.product.image;

                    const frame = AP.page.frames.find( ( f ) => {
                        return f.code === modelCode;
                    } );

                    if ( !frame ) {
                        AP.widget.notify( "error", `Modello [${modelCode}] non trovato. Impossibile continuare.` );
                        return;
                    }

                    const frameId = frame.id;
                    this.detailForm.data.product.frame.id = frameId;

                    await ajax( {
                        method: "GET",
                        url: BASE + "/frames/" + frameId + "?_=1" + this.blockOrientationsParam(),
                        callback: {
                            done: ( xhr ) => {
                                this.plate.id = xhr.data.id;
                                this.plate.code = xhr.data.code;
                                this.plate.orientation = xhr.data.orientation;
                                this.detailForm.data.product.orientation = orientationValue || xhr.data.orientation;
                                this.plate.cellOrientation = xhr.data.cellOrientation;
                                this.availableOrientations = xhr.data.availableOrientations;
                                this.plate.blocks = xhr.data.blocks || [];
                                this.plate.grid = xhr.data.grid || [];
                                this.applyPlateCanvasSize( xhr.data );
                                this.plate.image = image;
                                this.$nextTick( () => {
                                    if ( orientationValue ) {
                                        this.changeOrientation();
                                    } else {
                                        this.renderPlateWithFruits();
                                    }
                                } );
                            },
                        },
                    } );
                    // l'orientamento è noto solo ora: l'anteprima chiesta da
                    // firstLoadProductItems() partiva senza e non aveva lo slot HO
                    this.refreshExportCode();
                },

                /**
                 * Cambia l'orientamento della placca e ricarica la configurazione.
                 * Effettua una richiesta AJAX per ottenere i dati del telaio con il nuovo orientamento,
                 * aggiorna la griglia e riconfigura la placca.
                 * Riapplica le immagini dei product items dopo il cambio.
                 */
                changeOrientation: async function() {
                    const orientationId = this.detailForm.data.product.orientation.id;
                    const frameId = this.detailForm.data.product.frame.id;
                    const productId = this.detailForm.data.product.id;

                    if ( !orientationId || !frameId ) {
                        return;
                    }

                    this.smallLoading = true;

                    // Placche legacy (griglia da file): la griglia cambia
                    // completamente con l'orientamento e le vecchie posizioni
                    // dei frutti non sono più valide. Si azzerano in modo che
                    // renderPlateWithFruits li collochi automaticamente.
                    // Nelle placche a blocchi gli id slot sono interi stabili
                    // fra HOR e VER: le posizioni restano valide e i frutti
                    // ruotano coerentemente con la placca.
                    if ( !( this.plate.blocks && this.plate.blocks.length ) ) {
                        for ( const fruit of this.detailForm.data.fruits ) {
                            fruit.positionIds = [];
                        }
                    } else {
                        // allinea le posizioni con lo stato corrente del designer
                        // (eventuali drag fatti dopo il caricamento)
                        for ( const fruit of this.detailForm.data.fruits ) {
                            const designerFruit = pub.fruitsController?.fruits.find( ( f ) => f.id === fruit.id );
                            if ( designerFruit && designerFruit.cellIds.length ) {
                                fruit.positionIds = designerFruit.cellIds.map( ( c ) => c.id );
                            }
                        }
                    }

                    await ajax( {
                        method: "GET",
                        url: BASE + "/frames/" + frameId + "?orientationId=" + orientationId + "&productId=" + productId + this.blockOrientationsParam(),
                        callback: {
                            done: ( xhr ) => {
                                this.plate.orientation = xhr.data.orientation;
                                this.plate.cellOrientation = xhr.data.cellOrientation;

                                // Block plates: swap marginLeft↔marginTop when going to VER.
                                // The server uses marginTop as VER flow gap, but blocks are
                                // configured in the builder with HOR semantics (marginLeft = flow
                                // gap between blocks). Rotating to VER must map marginLeft → VER
                                // flow gap, matching the builder's setPreviewOrientation swap.
                                const blocks = xhr.data.blocks || [];
                                if ( blocks.length && orientationId === "VER" ) {
                                    let flowCursor = 0;
                                    let bboxWidth  = 0;
                                    let bboxHeight = 0;
                                    for ( const block of blocks ) {
                                        block.top  = flowCursor + block.marginLeftMm;
                                        block.left = block.marginTopMm;
                                        flowCursor = block.top + block.height;
                                        bboxWidth  = Math.max( bboxWidth,  block.left + block.width );
                                        bboxHeight = Math.max( bboxHeight, block.top  + block.height );
                                    }
                                    // Swap plate-level trailing margins (right↔bottom) to match builder.
                                    xhr.data.width  = bboxWidth  + ( xhr.data.marginBottomMm || 0 );
                                    xhr.data.height = bboxHeight + ( xhr.data.marginRightMm  || 0 );
                                }

                                this.plate.blocks = blocks;
                                this.plate.grid = xhr.data.grid || [];
                                this.applyPlateCanvasSize( xhr.data );
                                this.plate.image = xhr.data.image;
                                this.detailForm.data.product.orientation = xhr.data.orientation;
                                this.$nextTick( () => {
                                    this.renderPlateWithFruits();
                                } );
                            },
                        },
                    } );
                    // l'orientamento entra nel codice variante export
                    this.refreshExportCode();
                },

                /**
                 * Querystring con gli override di orientamento dei blocchi
                 * (vuota se non ci sono override).
                 */
                blockOrientationsParam: function() {
                    const overrides = this.plate.blockOrientations || {};
                    if ( !Object.keys( overrides ).length ) {
                        return "";
                    }
                    return "&blockOrientations=" + encodeURIComponent( JSON.stringify( overrides ) );
                },

                /**
                 * Ruota il singolo blocco della placca (solo per questa riga di
                 * preventivo): inverte l'orientamento corrente del blocco e
                 * ricarica il layout. Gli id degli slot sono stabili, quindi i
                 * frutti restano nelle stesse posizioni e ruotano col blocco.
                 * @param {number} blockOrder - ordine del blocco nella placca.
                 */
                rotateBlock: async function( blockOrder ) {
                    const block = ( this.plate.blocks || [] ).find( ( b ) => {
                        return b.order == blockOrder;
                    } );

                    if ( !block ) {
                        return;
                    }

                    const next = block.cellOrientation === "HOR" ? "VER" : "HOR";

                    // orientamento "naturale" del blocco (senza override):
                    // se l'override coincide, si rimuove invece di salvarlo
                    const plateOrientation = this.detailForm.data.product.orientation.id || this.plate.orientation.id;
                    const natural = block.orientationMode === "HAV" ? plateOrientation : block.orientationMode;

                    const overrides = { ...( this.plate.blockOrientations || {} ) };
                    if ( next === natural ) {
                        delete overrides[ blockOrder ];
                    } else {
                        overrides[ blockOrder ] = next;
                    }
                    this.plate.blockOrientations = overrides;

                    // changeOrientation ricarica il layout con gli override e
                    // riposiziona i frutti per id slot
                    await this.changeOrientation();
                },

                /**
                 * Riapplica le immagini dei product items dopo un cambio di orientamento.
                 * Scorre tutti gli attributi del prodotto e per ogni valore selezionato
                 * richiama il metodo changeImage.
                 */
                reapplyProductItemImages: function() {
                    const items = this.detailForm.data.product.items;
                    for ( const attr of items ) {
                        if ( attr?.values?.length ) {
                            const selected = attr.values.find( ( v ) => { return v.selected; } );
                            if ( selected?.productItemId ) {
                                this.changeImage( selected );
                            }
                        }
                    }
                },

                // MARK: Product Items
                /**
                 * Carica per la prima volta i product items del prodotto selezionato.
                 * Organizza gli items per attributo raggruppandone i valori.
                 * Se esiste già un quotation item, ripristina le selezioni salvate.
                 */
                /**
                 * Chiede al server l'anteprima del codice export (articolo + variante a 10
                 * caratteri) per il prodotto e gli attributi placca selezionati, con la stessa
                 * logica dell'esportazione. Aggiorna anche l'elenco degli attributi "da esportare".
                 */
                refreshExportCode: function() {
                    const productId = this.detailForm.data.product.id;
                    if ( !productId ) {
                        this.exportCodePreview = null;
                        this.importantAttributes = [];
                        return;
                    }
                    const productItemIds = [];
                    for ( const item of ( this.detailForm.data.product.items || [] ) ) {
                        for ( const v of ( item.values || [] ) ) {
                            if ( v.selected && v.productItemId ) {
                                productItemIds.push( v.productItemId );
                            }
                        }
                    }
                    const orientationId = ( this.detailForm.data.product.orientation && this.detailForm.data.product.orientation.id ) || "";
                    if ( !orientationId ) {
                        // placca non ancora caricata: la richiede loadPlate() appena
                        // l'orientamento è noto (senza, il server risponderebbe con errore)
                        return;
                    }
                    AP.quotation.exportCode.preview( "plate", { productId: productId, productItemIds: productItemIds, orientationId: orientationId }, ( outcome ) => {
                        this.exportCodePreview = outcome;
                        this.importantAttributes = ( outcome && outcome.importantAttributes ) || [];
                    } );
                },

                /**
                 * Codice dell'attributo se è tra quelli "da esportare", altrimenti stringa vuota.
                 * @param {string} attributeId - Identificativo dell'attributo.
                 */
                importantAttributeCode: function( attributeId ) {
                    const found = ( this.importantAttributes || [] ).find( ( a ) => { return a.id === attributeId; } );
                    return found ? found.code : "";
                },

                firstLoadProductItems: async function() {
                    const quotationItemId = this.detailForm.data.id;
                    const productId = this.detailForm.data.product.id;

                    await ajax( {
                        method: "GET",
                        url: AP.productItemsUrl( productId, null, this.detailForm.data.id ),
                        callback: {
                            done: ( xhr ) => {
                                if ( xhr.count > 0 ) {
                                    const items = [];
                                    for ( const item of xhr.data ) {
                                        const existing = items.find( ( d ) => {
                                            return d.attributeId === item.attribute.id;
                                        } );
                                        if ( existing ) {
                                            const already = existing.values.find( ( v ) => {
                                                return v.productItemId === item.id;
                                            } );
                                            if ( !already ) {
                                                existing.values.push( {
                                                    attributeId: item.attribute.id,
                                                    attributeValue: item.attributeValue,
                                                    productItemId: item.id,
                                                    images: item.images,
                                                    selected: false,
                                                    orderby: item.orderby || 0,
                                                    horizontalImage: item.horizontalImage,
                                                    verticalImage: item.verticalImage,
                                                } );
                                            }
                                        } else {
                                            items.push( {
                                                attributeId: item.attribute.id,
                                                attributeName: item.attribute.name,
                                                level: 0,
                                                values: [ {
                                                    attributeValue: item.attributeValue,
                                                    attributeId: item.attribute.id,
                                                    productItemId: item.id,
                                                    images: item.images,
                                                    selected: false,
                                                    orderby: item.orderby || 0,
                                                    horizontalImage: item.horizontalImage,
                                                    verticalImage: item.verticalImage,
                                                } ],
                                            } );
                                        }
                                    }
                                    this.detailForm.data.product.items = items;
                                }
                            },
                        },
                    } );

                    if ( quotationItemId ) {
                        let savedData = null;
                        await ajax( {
                            method: "GET",
                            url: BASE + "/quotation-items/" + quotationItemId + "/product-items",
                            callback: {
                                done: ( xhr ) => {
                                    savedData = xhr.data;
                                },
                            },
                        } );
                        if ( savedData?.length ) {
                            await this.restoreProductItemSelections( savedData );
                        }
                    }
                    if ( !quotationItemId || !this.detailForm.data.product.items.some( ( pi ) => {
                        return pi.values?.some( ( v ) => { return v.selected; } );
                    } ) ) {
                        // Auto-seleziona il primo valore degli attributi radice e carica i figli
                        // (solo per nuove placche o quando restore non ha trovato selezioni)
                        for ( const pi of this.detailForm.data.product.items ) {
                            if ( pi.level === 0 && !pi.parentItemId && pi.values?.length ) {
                                const hasSelection = pi.values.some( ( v ) => { return v.selected; } );
                                if ( !hasSelection ) {
                                    pi.values[0].selected = true;
                                    await this.$nextTick();
                                    await this.loadProductItems( pi.values[0].productItemId, pi.attributeId );
                                }
                            }
                        }
                    }

                    this.refreshExportCode();
                },

                /**
                 * Ripristina le selezioni dei product items a partire dai dati salvati.
                 * Ordina gli items per orderby e carica ricorsivamente i figli.
                 * Al termine, applica l'immagine del product item selezionato.
                 * @param {Array} data - Elenco dei quotation item product items salvati.
                 */
                restoreProductItemSelections: async function( data ) {
                    if ( !data?.length ) {
                        return;
                    }

                    // In precedenza le selezioni salvate venivano processate
                    // in ordine crescente di orderby. Questo causava un problema quando un
                    // attributo figlio (es. INCISIONE COLORE, orderby 90) veniva processato
                    // PRIMA del suo genitore (es. INCISIONE LOGO, orderby 100).
                    // Il metodo loadProductItems() per il genitore rimuove TUTTI i figli
                    // (elementi con level > parent.level) e li ricarica dal server.
                    // Così facendo, la selezione già applicata al figlio veniva azzerata
                    // perché il figlio veniva rimosso e reinserito con tutti i valori
                    // impostati a selected:false.
                    //
                    // Soluzione: raggruppare le selezioni per livello (qipi.level) e
                    // processarle in ordine crescente di livello: prima tutti i genitori
                    // (livello 0), che caricano la loro intera sottostruttura, poi i figli
                    // (livello 1+). Così quando un figlio viene processato, il genitore
                    // non verrà più rieseguito e la selezione non viene azzerata.
                    const byLevel = {};
                    let maxLevel = 0;
                    for ( const qipi of data ) {
                        const level = qipi.level || 0;
                        if ( !byLevel[ level ] ) {
                            byLevel[ level ] = [];
                        }
                        byLevel[ level ].push( qipi );
                        if ( level > maxLevel ) {
                            maxLevel = level;
                        }
                    }
                    for ( let lv = 0; lv <= maxLevel; lv++ ) {
                        const qipis = byLevel[ lv ];
                        if ( !qipis ) {
                            continue;
                        }
                        qipis.sort( ( a, b ) => {
                            return a.productItem.orderby - b.productItem.orderby;
                        } );
                        for ( const qipi of qipis ) {
                            await this.loadProductItems( qipi.productItem.id, qipi.productItem.attribute.id, true );
                        }
                    }
                    this.$nextTick( () => {
                        this.renderPlateWithFruits();
                    } );
                },


                /**
                 * Carica i product items figli per un dato attributo e origine.
                 * Se originId è vuoto, deseleziona i valori dell'attributo e rimuove gli items figli.
                 * Altrimenti, carica i figli tramite AJAX e li organizza per attributo.
                 * Gestisce la sostituzione degli items esistenti con quelli nuovi.
                 * @param {string} [originId=""] - Identificativo dell'item origine per il caricamento dei figli.
                 * @param {string} attributeId - Identificativo dell'attributo da aggiornare.
                 * @param {boolean} [skipAutoSelect=false] - Se true, non auto-seleziona il primo
                 *   valore dei figli dopo il caricamento.
                 */
                loadProductItems: async function( originId, attributeId, skipAutoSelect ) {
                    const productId = this.detailForm.data.product.id;
                    const items = this.detailForm.data.product.items;

                    originId = originId || "";

                    if ( originId === "" ) {
                        let actualIndex = null;
                        for ( let i = items.length - 1; i >= 0; i-- ) {
                            if ( items[i].attributeId == attributeId ) {
                                actualIndex = i;
                                items[i].values.forEach( ( v ) => {
                                    v.selected = false;
                                    v.note = null;
                                } );
                            }
                        }
                        if ( actualIndex !== null ) {
                            const idx = actualIndex + 1;
                            while ( idx < items.length ) {
                                if ( items[idx].level > items[actualIndex].level ) {
                                    items.splice( idx, 1 );
                                } else {
                                    break;
                                }
                            }
                        }
                        this.detailForm.data.product.items = items.slice();
                        return;
                    }

                    await ajax( {
                        method: "GET",
                        url: AP.productItemsUrl( productId, originId, this.detailForm.data.id ),
                        callback: {
                            done: ( xhr ) => {
                                let parentIndex = -1;
                                items.forEach( ( d, idx ) => {
                                    if ( d.attributeId == attributeId ) {
                                        parentIndex = idx;
                                    }
                                } );

                                // Se l'attributo non è più presente in items (es. race condition
                                // tra chiamate AJAX asincrone annidate dovute al processFruitCascade
                                // o a rapide interazioni utente), si esce senza modificare lo stato.
                                if ( parentIndex === -1 ) {
                                    this.detailForm.data.product.items = items.slice();
                                    return;
                                }

                                const parent = items[parentIndex];
                                parent.values.forEach( ( v ) => {
                                    v.selected = v.productItemId == originId;
                                } );

                                // Rimuove tutti gli elementi figli (level > parent.level)
                                // che seguono immediatamente il genitore
                                const i = parentIndex + 1;
                                while ( i < items.length ) {
                                    if ( items[i].level > parent.level ) {
                                        items.splice( i, 1 );
                                    } else {
                                        break;
                                    }
                                }

                                if ( xhr.data.length > 0 ) {
                                    const newAttrs = [];
                                    let lastAttrId = null;
                                    let attr = null;

                                    xhr.data.forEach( ( item ) => {
                                        if ( lastAttrId == null || lastAttrId != item.attribute.id ) {
                                            attr = {
                                                attributeId: item.attribute.id,
                                                attributeName: item.attribute.name,
                                                parentAttributeId: attributeId,
                                                parentItemId: originId,
                                                level: parent.level + 1,
                                                values: [],
                                                horizontalImage: item.horizontalImage,
                                                verticalImage: item.verticalImage,
                                                orderby: item.orderby,
                                            };
                                            newAttrs.push( attr );
                                        }
                                        attr.values.push( {
                                            attributeValue: item.attributeValue,
                                            productItemId: item.id,
                                            images: item.images,
                                            selected: false,
                                            horizontalImage: item.horizontalImage,
                                            verticalImage: item.verticalImage,
                                            orderby: item.orderby,
                                        } );
                                        lastAttrId = item.attribute.id;
                                    } );

                                    for ( let ni = 0; ni < newAttrs.length; ni++ ) {
                                        items.splice( parentIndex + 1 + ni, 0, newAttrs[ni] );
                                    }
                                }
                                this.detailForm.data.product.items = items.slice();
                            },
                        },
                    } );

                    // Auto-seleziona il primo valore di ogni nuovo figlio e carica ricorsivamente
                    if ( !skipAutoSelect ) {
                        const allItems = this.detailForm.data.product.items;
                        let parentIdx = -1;
                        for ( let i = 0; i < allItems.length; i++ ) {
                            if ( allItems[i].attributeId == attributeId ) {
                                parentIdx = i;
                                break;
                            }
                        }
                        if ( parentIdx !== -1 ) {
                            const parentLevel = allItems[parentIdx].level;
                            const children = [];
                            for ( let i = parentIdx + 1; i < allItems.length; i++ ) {
                                if ( allItems[i].level > parentLevel ) {
                                    children.push( allItems[i] );
                                } else {
                                    break;
                                }
                            }
                            for ( const child of children ) {
                                if ( child.values && child.values.length ) {
                                    const hasSelection = child.values.some( ( v ) => { return v.selected; } );
                                    if ( !hasSelection ) {
                                        child.values[0].selected = true;
                                        await this.$nextTick();
                                        await this.loadProductItems( child.values[0].productItemId, child.attributeId );
                                    }
                                }
                            }
                        }
                    }
                },

                /**
                 * Cambia l'immagine visualizzata per un product item selezionato.
                 * Cerca l'immagine corrispondente all'orientamento corrente tra quelle disponibili.
                 * Se trovata, crea o aggiorna un elemento DOM sovrapposto al designer della placca.
                 * @param {Object} item - Oggetto valore del product item con productItemId, images/horizontalImage/verticalImage.
                 */
                changeImage: function( item ) {
                    if ( !item || !item.productItemId ) {
                        return;
                    }
                    let uri = "";
                    const orientationId = this.detailForm.data.product.orientation.id;
                    if ( item.images?.length ) {
                        const targetOrientation = orientationId === "HOR" ? "horizontal" : "vertical";
                        for ( const image of item.images ) {
                            if ( image.type?.id == targetOrientation ) {
                                uri = image.uri;
                                break;
                            }
                        }
                    }
                    if ( !uri ) {
                        uri = orientationId === "VER" ? item.verticalImage?.uri : item.horizontalImage?.uri;
                    }
                    if ( uri ) {
                        const existing = $( `#productItem-image-${item.productItemId}` );
                        if ( existing.length ) {
                            existing.css( "background-image", `url('${uri}')` );
                        } else {
                            const zIndex = ( item.orderby || 0 ) + 10;
                            $( "<div>" )
                                .attr( "id", `productItem-image-${item.productItemId}` )
                                .css( {
                                    "background-image": `url('${uri}')`,
                                    "background-size": "cover",
                                    "background-position": "center",
                                    position: "absolute",
                                    top: 0,
                                    left: 0,
                                    width: "100%",
                                    height: "100%",
                                    "z-index": zIndex,
                                } )
                                .insertBefore( "#plate-layers" );
                        }
                    } else {
                        $( `#productItem-image-${item.productItemId}` ).remove();
                    }
                },

                /**
                 * Gestisce la selezione di un product item da parte dell'utente.
                 * Resetta la nota associata al valore precedente, carica i figli
                 * e aggiorna l'immagine corrispondente.
                 * @param {string} selectedId - Identificativo del product item selezionato.
                 * @param {string} attributeId - Identificativo dell'attributo.
                 * @param {Object} value - Oggetto valore selezionato per l'aggiornamento dell'immagine.
                 */
                handleProductItemSelect: async function( selectedId, attributeId, value ) {
                    await this.loadProductItems( selectedId, attributeId );
                    this.renderPlateWithFruits();
                    this.refreshExportCode();
                },

                // MARK: Fruits
                /**
                 * Gestisce la selezione di un frutto dall'elenco dei suggerimenti.
                 * Crea un nuovo frutto, lo aggiunge al form, lo disegna nella placca
                 * e inizializza i suoi product items e l'effetto hover.
                 * @param {Object} selectedFruit - Dati del frutto selezionato.
                 */
                onSelectFruit: async function( selectedFruit ) {
                    const newFruit = createFruit( { position: 1, fruit: selectedFruit } );

                    // se il frutto non è posizionabile non va nemmeno in lista
                    const mapped = mapFruitForPlate( newFruit );
                    if ( mapped && pub.fruitsController && !pub.fruitsController.canPlaceFruit( mapped ) ) {
                        AP.widget.notify( "error", "Non c'è spazio sufficiente sulla placca per questo frutto. Sposta i frutti esistenti per liberare posizioni adiacenti." );
                        return;
                    }

                    this.detailForm.data.fruits.push( newFruit );
                    await this.addProductItemsToFruit( newFruit.id );
                    this.renderPlateWithFruits();
                },

                /**
                 * Aggiunge gli effetti hover al DOM per un frutto nella lista e nella griglia.
                 * All'entrata del mouse colora lo sfondo; all'uscita ripristina il colore originale.
                 * Usa .off() prima di .on() per evitare accumulo di handler in caso di
                 * chiamate multiple (es. da renderPlateWithFruits).
                 * @param {string} fruitId - Identificativo del frutto.
                 */
                addFruitHover: function( fruitId ) {
                    $( `.quotation-fruit-row[data-fruit-id="${fruitId}"]` )
                        .off( "mouseenter mouseleave" )
                        .on( "mouseenter", () => {
                            $( `#quotation-plate-fruits #${fruitId}` ).css( "background-color", "rgba(162, 253, 161, 0.44)" );
                            $( `div[data-fruit-id="${fruitId}"]` ).css( "background-color", "#a3fda170" );
                        } )
                        .on( "mouseleave", () => {
                            $( `#quotation-plate-fruits #${fruitId}` ).css( "background-color", "" );
                            $( `div[data-fruit-id="${fruitId}"]` ).css( "background-color", "" );
                        } );
                },

                /**
                 * Ricostruisce da zero l'intero designer della placca:
                 * svuota il contenitore grafico, richiama configPlate() per ridisegnare
                 * griglia e frutti, poi riapplica tutte le sovrapposizioni
                 * (immagini attributi placca, immagini frutti, overlay attributi frutto).
                 * Va chiamato dopo ogni modifica ai dati dei frutti
                 * (aggiunta, rimozione, cambio attributo) o della placca.
                 */
                renderPlateWithFruits: function() {
                    this.smallLoading = true;

                    // Placche a blocchi: gli id slot sono stabili, quindi prima di
                    // ridisegnare allinea le posizioni del form allo stato corrente
                    // del designer (drag compresi); senza questo, il re-render
                    // riporterebbe i frutti alle posizioni dell'ultimo load.
                    // NB: positionIds va riassegnato SOLO se cambiato davvero, il
                    // watcher deep sui frutti rilancerebbe cascata+render in loop.
                    if ( ( this.plate.blocks || [] ).length && pub.fruitsController?.plate?.isBlockPlate?.() ) {
                        for ( const fruit of this.detailForm.data.fruits ) {
                            const designerFruit = pub.fruitsController.fruits.find( ( f ) => { return f.id === fruit.id; } );
                            if ( !designerFruit || !designerFruit.cellIds.length ) {
                                continue;
                            }

                            const next = designerFruit.cellIds.map( ( c ) => { return c.id; } );
                            const current = fruit.positionIds || [];
                            const changed = next.length !== current.length
                                || next.some( ( id, i ) => { return String( id ) !== String( current[ i ] ); } );

                            if ( changed ) {
                                fruit.positionIds = next;
                            }
                        }
                    }

                    this.$nextTick( async function() {
                        try {
                            const gm = getGridModule();
                            if ( !gm ) {
                                return;
                            }

                            $( ".plate-designer" ).empty();
                            configPlate();
                            for ( const fruit of this.detailForm.data.fruits ) {
                                const obj = mapFruitForPlate( fruit );
                                if ( fruit.positionIds && fruit.positionIds.length ) {
                                    pub.fruitsController.addFruitToPositions( obj, fruit.positionIds );
                                } else {
                                    pub.fruitsController.addFruitToPlate( obj );
                                }
                            }
                            this.reapplyProductItemImages();
                            for ( const fruit of this.detailForm.data.fruits ) {
                                this.addFruitHover( fruit.id );
                                this.changeFruitImage( fruit.id );
                                if ( fruit.items ) {
                                    for ( let fiIdx = 0; fiIdx < fruit.items.length; fiIdx++ ) {
                                        const fi = fruit.items[ fiIdx ];
                                        const selected = fi.values && fi.values.find( function( v ) { return v.selected; } );
                                        if ( selected && selected.productItemId ) {
                                            this.updateFruitAttributeOverlay( fruit.id, fi.attributeId, selected, fi.parentAttributeId, 1040 + fiIdx, fi );
                                        }
                                    }
                                }
                                await this.updateFruitCombinationOverlay( fruit.id );
                            }
                        } finally {
                            this.smallLoading = false;
                        }
                    }.bind( this ) );
                },

                /**
                 * Rimuove un frutto dalla lista del form e dalla placca.
                 * Aggiorna sia i dati del form che il controller dei frutti nella griglia.
                 * @param {Object} fruit - Oggetto frutto da rimuovere.
                 */
                removeFruit: function( fruit ) {
                    const idx = this.detailForm.data.fruits.indexOf( fruit );
                    if ( idx > -1 ) {
                        this.detailForm.data.fruits.splice( idx, 1 );
                    }
                    this.renderPlateWithFruits();
                },

                /**
                 * Espande o comprime la visualizzazione dei dettagli di un singolo frutto.
                 * @param {Object} fruit - Oggetto frutto di cui invertire lo stato expanded.
                 */
                toggleFruit: function( fruit ) {
                    fruit.expanded = !fruit.expanded;
                },

                /**
                 * Espande o comprime tutti i frutti contemporaneamente.
                 * Aggiorna l'etichetta del pulsante in base allo stato corrente.
                 */
                toggleFruits: function() {
                    const currentLabel = this.toggleFruitsLabel;
                    const newExpandedState = currentLabel === "Espandi tutti";
                    this.detailForm.data.fruits.forEach( ( f ) => {
                        f.expanded = newExpandedState;
                    } );
                    this.toggleFruitsLabel = newExpandedState ? "Comprimi tutti" : "Espandi tutti";
                },

                /**
                 * Carica i frutti associati a una placca esistente.
                 * Effettua una richiesta AJAX, crea i frutti e li posiziona nella griglia.
                 * Carica i product items per ciascun frutto e inizializza gli effetti hover.
                 */
                loadFruits: async function() {
                    const id = this.detailForm.data.id;
                    if ( !id ) {
                        return;
                    }
                    const fruitQIPIs = [];
                    const fruits = [];
                    const PLUG_IDS = [
                        "5f4ec169-c445-40a0-8c94-1dc22c21be79",
                        "452e03e4-ddf4-4042-ac87-b0f17489c4e1",
                    ];

                    await ajax( {
                        method: "GET",
                        url: BASE + "/quotation-items/plate/" + id + "/fruits",
                        callback: {
                            done: ( xhr ) => {
                                xhr.data.forEach( ( thisFruit ) => {
                                    if ( PLUG_IDS.includes( thisFruit.fruit.id.toLowerCase() ) ) return;
                                    const newFruit = createFruit( { position: 1, fruit: thisFruit.fruit, id: thisFruit.id } );
                                    if ( thisFruit.positions && thisFruit.positions.length ) {
                                        newFruit.positionIds = thisFruit.positions.map( ( p ) => { return p.position; } );
                                    }
                                    fruits.push( newFruit );
                                    this.detailForm.data.fruits.push( newFruit );

                                    thisFruit?.items?.forEach( ( item ) => {
                                        if ( item.productItem && item.productItem.attributeValue && item.productItem.attributeValue.allowNote ) {
                                            fruitQIPIs.push( {
                                                quotation_item_fruit_id: thisFruit.id,
                                                product_item_id: item.productItem.id,
                                                attribute_value_id: item.productItem.attributeValue.id,
                                                note: item.note,
                                            } );
                                        }
                                    } );
                                } );
                                this.detailForm.data.fruitQuotationItemProductItems = fruitQIPIs;
                            },
                        },
                    } );

                    for ( const fruit of fruits ) {
                        await this.addProductItemsToFruit( fruit.id );
                    }
                    this.renderPlateWithFruits();
                },

                /**
                 * Carica i product items per un frutto specifico.
                 * Effettua una richiesta AJAX per gli items del prodotto frutto e per i product items salvati.
                 * Aggiorna la mappa delle immagini e ripristina le selezioni esistenti.
                 * @param {string} fruitId - Identificativo del frutto.
                 */
                addProductItemsToFruit: async function( fruitId ) {
                    const fruits = this.detailForm.data.fruits;
                    let thisFruit = null;
                    for ( const fruit of fruits ) {
                        if ( fruit.id === fruitId ) {
                            thisFruit = fruit;
                            break;
                        }
                    }

                    if ( !thisFruit ) {
                        return;
                    }

                    const productId = thisFruit.fruit.id;

                    // griglia incisioni del frutto (posizioni ammesse per il simbolo):
                    // parte in parallelo, serve prima di disegnare gli overlay
                    const engravingGrid = this.loadEngravingGrid( productId );

                    await ajax( {
                        method: "GET",
                        url: AP.productItemsUrl( productId, null, this.detailForm.data.id ),
                        callback: {
                            done: ( xhr ) => {
                                if ( xhr.count > 0 ) {
                                    const fruitItems = thisFruit.items || [];
                                    xhr.data.forEach( ( item ) => {
                                        this.productItemsImages[ item.id ] = item.horizontalImage ? item.horizontalImage.uri : "";
                                        const existing = fruitItems.find( ( d ) => { return d.attributeId === item.attribute.id; } );
                                        if ( existing ) {
                                            existing.values.push( {
                                                attributeValue: item.attributeValue,
                                                productItemId: item.id,
                                                images: item.images,
                                                selected: false,
                                                orderby: item.orderby || 0,
                                                horizontalImage: item.horizontalImage,
                                                verticalImage: item.verticalImage,
                                            } );
                                        } else {
                                            fruitItems.push( {
                                                id: NM.util.uuid(),
                                                attributeId: item.attribute.id,
                                                attributeName: item.attribute.name,
                                                attributeCode: item.attribute.code,
                                                level: 0,
                                                values: [ {
                                                    attributeValue: item.attributeValue,
                                                    productItemId: item.id,
                                                    images: item.images,
                                                    selected: false,
                                                    orderby: item.orderby || 0,
                                                    horizontalImage: item.horizontalImage,
                                                    verticalImage: item.verticalImage,
                                                } ],
                                            } );
                                        }
                                    } );
                                    thisFruit.items = fruitItems;
                                }
                            },
                        },
                    } );

                    // Carica prima le selezioni salvate degli attributi (se presenti)
                    const savedSelections = [];
                    const qifId = thisFruit.id;
                    if ( typeof qifId === "number" ) {
                        await ajax( {
                            method: "GET",
                            url: BASE + "/quotation-items/fruits/" + qifId + "/product-items",
                            callback: {
                                done: ( xhr ) => {
                                    if ( xhr.data && xhr.data.length ) {
                                        savedSelections.push( ...xhr.data );
                                    }
                                },
                            },
                        } );
                    }

                    await engravingGrid;

                    // Se i valori degli attributi sono salvati nel db, applica quelli
                    if ( savedSelections.length > 0 ) {
                        this._cascadingFruit = true;
                        savedSelections.sort( ( a, b ) => { return a.productItem.orderby - b.productItem.orderby; } );
                        for ( const qipi of savedSelections ) {
                            for ( const fi of thisFruit.items ) {
                                if ( fi.attributeId == qipi.productItem.attribute.id ) {
                                    const match = fi.values.find( ( v ) => { return v.productItemId == qipi.productItem.id; } );
                                    if ( match ) {
                                        // posizione dell'incisione salvata col preventivo
                                        // (assegnazione non reattiva: vedi drawFruitEngravingSymbol)
                                        if ( qipi.engravingMarkerId != null ) {
                                            match.engravingMarkerId = qipi.engravingMarkerId;
                                        }
                                        // coordinate salvate: servono a ritrovare la posizione
                                        // se la griglia del frutto è stata rifatta
                                        if ( qipi.engravingXMm != null ) {
                                            match.engravingXMm = qipi.engravingXMm;
                                            match.engravingYMm = qipi.engravingYMm;
                                        }
                                        match.selected = true;
                                        await this.$nextTick();
                                        await this.loadFruitProductItems( fruitId, qipi.productItem.id, fi.id, true );
                                        break;
                                    }
                                }
                            }
                        }
                        this._cascadingFruit = false;
                    } else {
                        // Altrimenti procede con l'auto-selezione normale:
                        // auto-seleziona il primo valore degli attributi radice e carica i figli
                        for ( const fi of thisFruit.items ) {
                            if ( fi.level === 0 && !fi.parentItemId && fi.values && fi.values.length ) {
                                const hasSelection = fi.values.some( ( v ) => { return v.selected; } );
                                if ( !hasSelection ) {
                                    fi.values[0].selected = true;
                                    await this.$nextTick();
                                    await this.loadFruitProductItems( fruitId, fi.values[0].productItemId, fi.id );
                                }
                            }
                        }
                    }
                },

                /**
                 * Imposta l'immagine radice del frutto
                 * sul tag <img> del frutto nella griglia. Se il frutto non ha un'immagine
                 * radice (es. nessuna immagine definita sul prodotto frutto), nasconde
                 * completamente il tag <img>.
                 * NON carica immagini di combinazione dagli attributi selezionati
                 * @param {string} fruitId - Identificativo del frutto.
                 */
                /**
                 * Orientamento effettivo di un frutto: nelle placche a blocchi è
                 * quello del blocco che lo ospita (può differire da quello della
                 * placca, es. blocco ruotato singolarmente); altrimenti quello
                 * della placca.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @returns {string} "HOR" | "VER"
                 */
                fruitOrientationId: function( fruitId ) {
                    const designerFruit = pub.fruitsController?.fruits.find( ( f ) => { return f.id === fruitId; } );
                    if ( designerFruit && designerFruit.orientation ) {
                        return designerFruit.orientation;
                    }
                    return this.detailForm.data.product.orientation.id;
                },

                /**
                 * Stile (posizionamento + eventuale rotazione) per gli overlay
                 * immagine di un frutto. Le immagini di frutti e attributi sono
                 * censite in orizzontale: quando il frutto è verticale (blocco
                 * ruotato o placca verticale) l'overlay viene ruotato via CSS,
                 * come già avviene per l'immagine base del frutto.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {number} zIndex - z-index dell'overlay.
                 * @returns {string} Frammento di stile inline.
                 */
                fruitOverlayStyle: function( fruitId, zIndex ) {
                    if ( this.fruitOrientationId( fruitId ) !== "VER" ) {
                        return `z-index: ${zIndex}; width: 100%; height: 100%; position: absolute; top: 0; left: 0;`;
                    }
                    const fruitEl = $( "#quotation-plate-fruits #" + fruitId );
                    const width = fruitEl.height();
                    const height = fruitEl.width();
                    return `z-index: ${zIndex}; width: ${width}px; height: ${height}px; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(90deg);`;
                },

                changeFruitImage: function( fruitId ) {
                    const fruit = this.detailForm.data.fruits.find( ( f ) => { return f.id === fruitId; } );
                    if ( !fruit ) {
                        return;
                    }
                    const img = $( "#quotation-plate-fruits #" + fruitId + " img" );
                    if ( !img.length ) {
                        return;
                    }
                    // le immagini dei frutti sono censite in orizzontale: per i
                    // frutti verticali la rotazione la fa il CSS (drawWithin)
                    const rootImage = fruit.fruit?.horizontalImage?.uri;
                    if ( rootImage ) {
                        img.attr( "src", rootImage ).show();
                        return;
                    }
                    // Se il frutto non ha l'immagine e almeno un attributo selezionato
                    // ha un'immagine, nasconde il placeholder.
                    const hasOverlayImage = fruit.items?.some( ( fi ) => {
                        const sel = fi.values?.find( ( v ) => { return v.selected; } );
                        if ( !sel ) {
                            return false;
                        }
                        return sel.horizontalImage?.uri;
                    } );
                    if ( hasOverlayImage ) {
                        img.hide();
                    } else {
                        img.show();
                    }
                },

                /**
                 * Carica i product items figli per un attributo di un frutto specifico.
                 * Se originId è vuoto, deseleziona i valori dell'attributo e rimuove gli items figli.
                 * Altrimenti, carica i figli tramite AJAX e li organizza per attributo.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {string} [originId=""] - Identificativo dell'item origine per il caricamento dei figli.
                 * @param {string} itemId - Identificativo univoco dell'item attributo (fi.id).
                 * @param {boolean} [skipAutoSelect=false] - Se true, non auto-seleziona il primo
                 *   valore dei figli dopo il caricamento. Utile quando si ripristinano selezioni
                 *   salvate (il loop chiamante si occupa di selezionare i valori corretti).
                 */
                loadFruitProductItems: async function( fruitId, originId, itemId, skipAutoSelect ) {
                    let fruit = null;
                    for ( const fr of this.detailForm.data.fruits ) {
                        if ( fr.id === fruitId ) {
                            fruit = fr;
                            break;
                        }
                    }
                    if ( !fruit ) {
                        return;
                    }
                    const fruitItems = fruit.items;
                    const productId = fruit.fruit.id;
                    originId = originId || "";

                    const itemIdx = fruitItems.findIndex( ( d ) => { return d.id === itemId; } );
                    if ( itemIdx === -1 ) {
                        fruit.items = fruitItems.slice();
                        return;
                    }
                    const itemAttr = fruitItems[itemIdx];
                    const attributeId = itemAttr.attributeId;

                    if ( originId === "" ) {
                        fruitChildrenLoaded.delete( fruitId + "-" + itemId );
                        itemAttr.values.forEach( ( v ) => {
                            v.selected = false;
                            v.note = null;
                        } );
                        const idx = itemIdx + 1;
                        while ( idx < fruitItems.length ) {
                            if ( fruitItems[idx].level > itemAttr.level ) {
                                fruitItems.splice( idx, 1 );
                            } else {
                                break;
                            }
                        }
                        fruit.items = fruitItems.slice();
                        return;
                    }

                    await ajax( {
                        method: "GET",
                        url: AP.productItemsUrl( productId, originId, this.detailForm.data.id ),
                        callback: {
                            done: ( xhr ) => {
                                let parentIndex = -1;
                                fruitItems.forEach( ( d, idx ) => {
                                    if ( d.id === itemId ) {
                                        parentIndex = idx;
                                    }
                                } );

                                if ( parentIndex === -1 ) {
                                    fruit.items = fruitItems.slice();
                                    return;
                                }

                                // figli richiesti per questa selezione: anche se il server non ne
                                // restituisce (attributo foglia) la cascata non deve ripeterla
                                fruitChildrenLoaded.set( fruitId + "-" + itemId, String( originId ) );

                                const parent = fruitItems[parentIndex];
                                parent.values.forEach( ( v ) => {
                                    v.selected = v.productItemId == originId;
                                } );

                                // Rimuove i vecchi figli prima di caricare i nuovi
                                const i = parentIndex + 1;
                                while ( i < fruitItems.length ) {
                                    if ( fruitItems[i].level > parent.level ) {
                                        fruitItems.splice( i, 1 );
                                    } else {
                                        break;
                                    }
                                }

                                if ( xhr.data.length > 0 ) {
                                    const newAttrs = [];
                                    let lastAttrId = null;
                                    let attr = null;

                                    xhr.data.forEach( ( item ) => {
                                        if ( lastAttrId == null || lastAttrId != item.attribute.id ) {
                                            attr = {
                                                id: NM.util.uuid(),
                                                attributeId: item.attribute.id,
                                                attributeName: item.attribute.name,
                                                attributeCode: item.attribute.code,
                                                parentAttributeId: attributeId,
                                                parentItemId: originId,
                                                level: fruitItems[parentIndex].level + 1,
                                                values: [],
                                                horizontalImage: item.horizontalImage,
                                                verticalImage: item.verticalImage,
                                                orderby: item.orderby,
                                            };
                                            newAttrs.push( attr );
                                        }
                                        attr.values.push( {
                                            attributeValue: item.attributeValue,
                                            productItemId: item.id,
                                            selected: false,
                                            orderby: item.orderby || 0,
                                            horizontalImage: item.horizontalImage,
                                            verticalImage: item.verticalImage,
                                        } );
                                        lastAttrId = item.attribute.id;
                                    } );

                                    for ( let ni = 0; ni < newAttrs.length; ni++ ) {
                                        fruitItems.splice( parentIndex + 1 + ni, 0, newAttrs[ni] );
                                    }
                                }
                                fruit.items = fruitItems.slice();
                            },
                        },
                    } );

                    // Auto-seleziona il primo valore di ogni nuovo figlio
                    // Il watcher processFruitCascade si occuperà di caricare ricorsivamente
                    // i figli successivi e di chiamare updateFruitAttributeOverlay.
                    // Se skipAutoSelect è true, salta (il chiamante gestisce le selezioni).
                    if ( !skipAutoSelect ) {
                        const updatedFruitItems = fruit.items;
                        const fruitParentIdx = updatedFruitItems.findIndex( ( d ) => { return d.id === itemId; } );
                        if ( fruitParentIdx !== -1 ) {
                            const fruitParentLevel = updatedFruitItems[fruitParentIdx].level;
                            for ( let i = fruitParentIdx + 1; i < updatedFruitItems.length; i++ ) {
                                if ( updatedFruitItems[i].level > fruitParentLevel ) {
                                    if ( updatedFruitItems[i].values && updatedFruitItems[i].values.length ) {
                                        const hasSelection = updatedFruitItems[i].values.some( ( v ) => { return v.selected; } );
                                        if ( !hasSelection ) {
                                            updatedFruitItems[i].values[0].selected = true;
                                        }
                                    }
                                } else {
                                    break;
                                }
                            }
                        }
                    }
                },

                /**
                 * Gestisce la selezione di un product item per un frutto.
                 * Resetta la nota associata al valore precedente, carica i figli
                 * e aggiorna l'immagine del frutto.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {string} selectedId - Identificativo del product item selezionato.
                 * @param {string} itemId - Identificativo univoco dell'item attributo (fi.id).
                 * @param {Object} value - Oggetto valore selezionato.
                 */
                handleFruitProductItemSelect: async function( fruitId, selectedId, itemId, value ) {
                    await this.loadFruitProductItems( fruitId, selectedId, itemId );

                    // Se la selezione ha dei figli, il watcher (processFruitCascade) li carica
                    // e ridisegna la placca. Per gli attributi foglia o per la deselezione la
                    // cascata non ha nulla da caricare e quindi non ridisegna: overlay attributo
                    // e combinazioni vanno aggiornati esplicitamente qui.
                    const fruit = this.detailForm.data.fruits.find( ( f ) => { return f.id === fruitId; } );
                    const item = fruit?.items?.find( ( fi ) => { return fi.id === itemId; } );
                    const hasChildren = !!( item && selectedId && fruit.items.some( ( ci ) => {
                        return ci.parentAttributeId === item.attributeId && String( ci.parentItemId ) === String( selectedId );
                    } ) );
                    if ( !hasChildren ) {
                        this.renderPlateWithFruits();
                    }
                },

                /**
                 * Processa a cascata tutte le selezioni di attributi frutto.
                 * Questo metodo viene chiamato dal watcher su detailForm.data.fruits
                 * ogni volta che una value diventa selected=true, sia per interazione manuale
                 * dell'utente che per selezione automatica via codice.
                 *
                 * Usa un do-while perché ogni caricamento di figli può generare nuove
                 * selezioni automatiche (primo valore pre-selezionato), che a loro volta
                 * potrebbero avere figli da caricare.
                 *
                 * processed (Set) traccia le coppie fruitId + attributeId già processate
                 * nel giro corrente. Per gli attributi foglia (senza figli) childrenLoaded
                 * non può essere dedotto dagli items: ci pensa fruitChildrenLoaded, che
                 * ricorda per quale selezione i figli sono già stati richiesti, così i
                 * giri successivi del watcher non li ricaricano (e non ridisegnano) all'infinito.
                 *
                 * childrenLoaded verifica se esistono già items con parentAttributeId
                 * e parentItemId corrispondenti alla selezione corrente. Se true, significa
                 * che i figli sono già stati caricati (da un giro precedente del do-while
                 * o dal flusso manuale handleFruitProductItemSelect -> loadFruitProductItems).
                 */
                processFruitCascade: async function() {
                    this.smallLoading = true;
                    try {
                        const processed = new Set();
                        let cascaded;
                        let didCascade = false;
                        do {
                            cascaded = false;
                            for ( const fruit of this.detailForm.data.fruits ) {
                                if ( !fruit.items ) {
                                    continue;
                                }
                                for ( const item of fruit.items ) {
                                    // chiave sull'id della riga, non sull'attributo: lo stesso
                                    // attributo può comparire in due rami del frutto (INCISIONE
                                    // LOGO sotto IS e sotto II) e vanno processati entrambi
                                    const key = fruit.id + "-" + item.id;
                                    if ( processed.has( key ) ) {
                                        continue;
                                    }
                                    const selected = item.values && item.values.find( ( v ) => { return v.selected; } );
                                    if ( !selected || !selected.productItemId ) {
                                        continue;
                                    }
                                    const alreadyRequested = fruitChildrenLoaded.get( fruit.id + "-" + item.id ) === String( selected.productItemId );
                                    const childrenLoaded = alreadyRequested || fruit.items.some( ( ci ) => {
                                        return ci.parentAttributeId === item.attributeId && ci.parentItemId === selected.productItemId;
                                    } );
                                    if ( childrenLoaded ) {
                                        processed.add( key );
                                    } else {
                                        processed.add( key );
                                        await this.loadFruitProductItems( fruit.id, selected.productItemId, item.id );
                                        await this.$nextTick();
                                        cascaded = true;
                                        didCascade = true;
                                    }
                                }
                            }
                        } while ( cascaded );

                        // ridisegna solo se la cascata ha caricato davvero qualcosa:
                        // il render tocca i frutti, il watcher deep riparte e senza
                        // questa guardia si innesca un loop cascata->render infinito
                        if ( didCascade ) {
                            this.renderPlateWithFruits();
                        } else {
                            this.smallLoading = false;
                        }
                    } catch ( e ) {
                        this.smallLoading = false;
                        throw e;
                    }
                },

                /**
                 * Aggiorna l'overlay dell'attributo di un frutto sulla griglia della placca.
                 * Rimuove l'overlay esistente e ne crea uno nuovo con l'immagine corretta
                 * in base all'orientamento (orizzontale/verticale).
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {string} attributeId - Identificativo dell'attributo.
                 * @param {Object} value - Oggetto valore del product item con immagini.
                 * @param {string} [parentAttributeId] - Identificativo opzionale dell'attributo padre.
                 * @param {number} zIndex - Z-index calcolato in base alla posizione nell'array fruit.items.
                 * @param {Object} [item] - Attributo di appartenenza del valore (serve per l'incisione).
                 */
                updateFruitAttributeOverlay: function( fruitId, attributeId, value, parentAttributeId, zIndex, item ) {
                    if ( !value || !attributeId ) {
                        return;
                    }
                    const fruitEl = $( "#quotation-plate-fruits #" + fruitId );
                    if ( !fruitEl.length ) {
                        return;
                    }
                    // la chiave usa l'id della riga quando c'è: due attributi uguali in rami
                    // diversi (SIMBOLO sotto IS e sotto II) devono avere overlay distinti
                    const overlayKey = item?.id
                        ? "i" + String( item.id ).replace( /[^A-Za-z0-9_-]/g, "" )
                        : ( parentAttributeId ? parentAttributeId + "-" + attributeId : attributeId );
                    fruitEl.find( "> .fruit-overlay-" + overlayKey ).remove();
                    // i layer di incisione non sono più figli del frutto (vedi
                    // drawFruitEngravingSymbol): vanno cercati e rimossi nell'ancora esterna
                    this.engravingAnchor().find(
                        '> .fruit-overlay-' + overlayKey + '[data-fruit-id="' + fruitId + '"]'
                    ).remove();

                    // incisioni: il simbolo non si disegna a tutto frutto ma in scala nella
                    // posizione scelta sulla griglia, ed è trascinabile da marker a marker
                    const engraving = item ? this.engravingContext( fruitId, item ) : null;
                    if ( engraving && engraving.markers.length ) {
                        this.drawFruitEngravingSymbol( fruitId, overlayKey, item, value, engraving, zIndex + 60 );
                        return;
                    }
                    // immagine orizzontale + rotazione CSS per i frutti verticali
                    const imageUri = value.horizontalImage?.uri;
                    if ( imageUri ) {
                        const style = this.fruitOverlayStyle( fruitId, zIndex );
                        fruitEl.append( `<div class="fruit-overlay-${overlayKey}" style="${style} background-image: url('${imageUri}'); background-size: contain; background-repeat: no-repeat; background-position: center"></div>` );
                    }
                },

                // MARK: Engraving grid
                /**
                 * Carica (una sola volta per prodotto frutto) la griglia incisioni:
                 * attributi radice con i loro marker, codici radice/simbolo e dimensione
                 * del simbolo. Le richieste in volo sono deduplicate.
                 * @param {string} productId - Identificativo del prodotto frutto.
                 * @returns {Promise<Object>} Griglia del frutto.
                 */
                loadEngravingGrid: function( productId ) {
                    const empty = { attributes: [], rootCodes: [], symbolCodes: [], symbolSizeMm: 10 };
                    if ( !productId ) {
                        return Promise.resolve( empty );
                    }
                    if ( this.engravingGrids[ productId ] ) {
                        return Promise.resolve( this.engravingGrids[ productId ] );
                    }
                    if ( !this._engravingRequests ) {
                        this._engravingRequests = {};
                    }
                    if ( this._engravingRequests[ productId ] ) {
                        return this._engravingRequests[ productId ];
                    }

                    this._engravingRequests[ productId ] = ( async () => {
                        const grid = { ...empty };
                        await ajax( {
                            method: "GET",
                            url: "/manager/ajax/products/" + productId + "/engraving-markers",
                            callback: {
                                done: ( xhr ) => {
                                    if ( !xhr.data ) {
                                        return;
                                    }
                                    grid.attributes   = xhr.data.attributes || [];
                                    grid.rootCodes    = xhr.data.rootCodes || [];
                                    grid.symbolCodes  = xhr.data.symbolCodes || [];
                                    grid.symbolSizeMm = Number( xhr.data.symbolSizeMm ) || 10;
                                },
                            },
                        } );
                        this.$set( this.engravingGrids, productId, grid );
                        return grid;
                    } )();

                    return this._engravingRequests[ productId ];
                },

                /**
                 * Attributo radice dell'incisione (IS/II/IL) a cui appartiene un attributo
                 * del frutto: risale la catena dei padri e tiene il più in alto fra quelli
                 * radice, come fa ProductEngravingMarkerService.resolveRootAttributeId.
                 * @param {Object} fruit - Frutto configurato.
                 * @param {Object} item - Attributo di partenza.
                 * @param {Object} grid - Griglia incisioni del frutto.
                 * @returns {Object|null} Attributo radice con i suoi marker.
                 */
                engravingRootAttribute: function( fruit, item, grid ) {
                    let current = item;
                    let found   = null;
                    let guard   = 0;

                    while ( current && guard < 10 ) {
                        guard++;
                        const attr = ( grid.attributes || [] ).find( ( a ) => { return a.id === current.attributeId; } );
                        if ( attr ) {
                            found = attr;
                        }
                        if ( !current.parentAttributeId ) {
                            break;
                        }
                        current = this.fruitParentItem( fruit, current );
                    }

                    return found;
                },

                /**
                 * Riga padre di un attributo del frutto. Si segue il product item selezionato
                 * dal padre (parentItemId), non l'attributo: lo stesso attributo può comparire
                 * in due rami (INCISIONE LOGO sotto incisione superiore e inferiore) e cercarlo
                 * per attributeId restituirebbe sempre il primo.
                 * @param {Object} fruit - Frutto configurato.
                 * @param {Object} item - Attributo di partenza.
                 * @returns {Object|undefined} Riga padre.
                 */
                fruitParentItem: function( fruit, item ) {
                    const items = fruit.items || [];

                    if ( item.parentItemId != null ) {
                        const byProductItem = items.find( ( i ) => {
                            return ( i.values || [] ).some( ( v ) => { return String( v.productItemId ) === String( item.parentItemId ); } );
                        } );
                        if ( byProductItem ) {
                            return byProductItem;
                        }
                    }

                    return items.find( ( i ) => { return i.attributeId === item.parentAttributeId; } );
                },

                /**
                 * Contesto incisione di un attributo frutto: valorizzato solo se l'attributo
                 * porta il simbolo inciso (codice in symbolCodes) e il suo ramo risale a un
                 * attributo radice con almeno un marker.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {Object} item - Attributo del frutto.
                 * @returns {Object|null} { markers, rootAttributeId, rootCode, rootName, symbolSizeMm }
                 */
                engravingContext: function( fruitId, item ) {
                    const fruit = this.detailForm.data.fruits.find( ( f ) => { return f.id === fruitId; } );
                    const grid  = fruit && fruit.fruit ? this.engravingGrids[ fruit.fruit.id ] : null;

                    if ( !grid || !item || !item.attributeCode ) {
                        return null;
                    }
                    if ( ( grid.symbolCodes || [] ).indexOf( item.attributeCode ) === -1 ) {
                        return null;
                    }

                    const root = this.engravingRootAttribute( fruit, item, grid );
                    if ( !root ) {
                        return null;
                    }

                    return {
                        markers: root.markers || [],
                        rootAttributeId: root.id,
                        rootCode: root.code,
                        rootName: root.name,
                        symbolSizeMm: grid.symbolSizeMm,
                    };
                },

                /**
                 * Scala di disegno della placca (mm → px), quella del designer.
                 * @returns {number}
                 */
                engravingDisplayScale: function() {
                    return pub.fruitsController?.plate?.displayScale ?? 1;
                },

                /**
                 * Ancora esterna su cui agganciare i layer di incisione: #quotation-plate-fruits
                 * è dimensionato esattamente sulla placca fisica e ha overflow:hidden, quindi
                 * taglia qualunque cosa esca dal proprio riquadro - non solo dal riquadro del
                 * frutto, anche dal riquadro della placca stessa se piccola. Va agganciato dentro
                 * #plate-layers (suo genitore diretto, area 1200x500 molto più ampia della placca,
                 * overflow:hidden ma con margine ampio) e NON più in alto (#plate-background):
                 * #plate-layers ha z-index:2147483647 per stare sempre sopra il resto della UI,
                 * quindi un layer agganciato fuori da lui - pur restando visibile, perché in
                 * quell'area #plate-layers è perlopiù trasparente - perde ogni evento di puntatore
                 * (click/drag), che #plate-layers cattura comunque per via dello stacking.
                 * @returns {Object} Elemento jQuery dell'ancora.
                 */
                engravingAnchor: function() {
                    return $( "#plate-layers" );
                },

                /**
                 * Posiziona un layer di incisione sul centro a schermo del frutto, rispetto
                 * all'ancora esterna. Basato su getBoundingClientRect (non su calcoli sui
                 * css dichiarati lungo la catena di antenati): funziona a prescindere da
                 * eventuali trasformazioni/zoom intermedi. Va richiamato di nuovo ogni volta
                 * che il frutto si sposta (il layer non è più figlio del frutto, quindi non
                 * segue automaticamente un semplice aggiornamento css left/top del frutto).
                 * @param {Object} $layer - Layer di incisione (jQuery).
                 * @param {Object} fruitEl - Elemento del frutto (jQuery).
                 */
                positionEngravingLayer: function( $layer, fruitEl ) {
                    const $anchor = this.engravingAnchor();
                    if ( !$anchor.length || !fruitEl.length ) {
                        return;
                    }
                    const fr = fruitEl[ 0 ].getBoundingClientRect();
                    const ar = $anchor[ 0 ].getBoundingClientRect();
                    $layer.css( {
                        left: ( fr.left + fr.width / 2 - ar.left ) + "px",
                        top: ( fr.top + fr.height / 2 - ar.top ) + "px",
                    } );
                },

                /**
                 * Risincronizza la posizione di tutti i layer di incisione di un frutto:
                 * va richiamato dopo un trascinamento (il frutto non è più il genitore del
                 * layer, quindi il riposizionamento del frutto non lo trascina più insieme).
                 * Chiamato da app-quotation-plate-designer.js dopo ogni drag.
                 * @param {string} fruitId - Identificativo del frutto spostato.
                 */
                repositionEngravingLayers: function( fruitId ) {
                    const fruitEl = $( "#quotation-plate-fruits #" + fruitId );
                    const self = this;
                    this.engravingAnchor()
                        .find( '> .fruit-engraving-layer[data-fruit-id="' + fruitId + '"]' )
                        .each( function() { self.positionEngravingLayer( $( this ), fruitEl ); } );
                },

                /**
                 * Disegna il simbolo inciso sul frutto nella posizione scelta sulla griglia,
                 * insieme ai punti di aggancio (visibili durante il trascinamento).
                 * Le coordinate dei marker sono in mm rispetto al CENTRO del frutto
                 * orizzontale (un marker può stare anche fuori dal frutto, incluso fuori dalla
                 * placca stessa se piccola): per questo il layer NON è annidato dentro il
                 * frutto (che erediterebbe il taglio di #quotation-plate-fruits) ma agganciato
                 * a engravingAnchor() e posizionato in base alla posizione reale a schermo del
                 * frutto (vedi positionEngravingLayer()). Per i frutti verticali la rotazione
                 * 90° resta CSS, applicata al layer.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {string} overlayKey - Chiave dell'overlay (per la rimozione al re-render).
                 * @param {Object} item - Attributo del simbolo.
                 * @param {Object} value - Valore selezionato (porta l'immagine e il marker scelto).
                 * @param {Object} engraving - Contesto incisione (vedi engravingContext).
                 * @param {number} zIndex - z-index dell'overlay.
                 */
                drawFruitEngravingSymbol: function( fruitId, overlayKey, item, value, engraving, zIndex ) {
                    const fruitEl = $( "#quotation-plate-fruits #" + fruitId );
                    const $anchor = this.engravingAnchor();
                    if ( !fruitEl.length || !$anchor.length ) {
                        return;
                    }

                    const markers = engraving.markers;
                    const scale   = this.engravingDisplayScale();
                    const size    = Math.max( 6, engraving.symbolSizeMm * scale );

                    const isVertical  = this.fruitOrientationId( fruitId ) === "VER";
                    const centerX     = ( isVertical ? fruitEl.height() : fruitEl.width() ) / 2;
                    const centerY     = ( isVertical ? fruitEl.width() : fruitEl.height() ) / 2;

                    // marker salvato se esiste ancora; se la griglia è stata rifatta il marker
                    // non c'è più ma restano le coordinate salvate col preventivo, quindi si
                    // riaggancia alla posizione più vicina; in ultima istanza la prima
                    let marker = markers.find( ( m ) => { return String( m.id ) === String( value.engravingMarkerId ); } );
                    if ( !marker && value.engravingXMm != null && value.engravingYMm != null ) {
                        let nearest = null;
                        for ( const m of markers ) {
                            const distance = Math.pow( m.xMm - value.engravingXMm, 2 ) + Math.pow( m.yMm - value.engravingYMm, 2 );
                            if ( !nearest || distance < nearest.distance ) {
                                nearest = { marker: m, distance: distance };
                            }
                        }
                        marker = nearest?.marker;
                    }
                    if ( !marker ) {
                        marker = markers[ 0 ];
                    }
                    // assegnazione semplice (non $set): la proprietà non è reattiva e il
                    // watcher profondo sui frutti non deve ripartire a ogni disegno
                    value.engravingMarkerId = marker.id;
                    this.$set( this.engravingSelection, fruitId + "-" + item.id, {
                        markerId: marker.id,
                        order: marker.order,
                        count: markers.length,
                        code: engraving.rootCode,
                    } );

                    const layerWidth  = centerX * 2;
                    const layerHeight = centerY * 2;
                    const $layer = $( "<div/>", {
                        "class": `fruit-overlay-${overlayKey} fruit-engraving-layer`,
                        "data-fruit-id": fruitId,
                        "data-overlay-key": overlayKey,
                        css: {
                            position: "absolute",
                            zIndex: zIndex + 9000,
                            width: layerWidth + "px",
                            height: layerHeight + "px",
                            transform: "translate(-50%, -50%)" + ( isVertical ? " rotate(90deg)" : "" ),
                        },
                    } );

                    for ( const m of markers ) {
                        $layer.append( $( "<div/>", {
                            "class": "fruit-engraving-snap",
                            "data-marker-id": m.id,
                            "data-order": m.order,
                            "data-x": m.xMm,
                            "data-y": m.yMm,
                            css: { left: ( centerX + m.xMm * scale ) + "px", top: ( centerY + m.yMm * scale ) + "px" },
                        } ) );
                    }

                    const $symbol = $( "<div/>", {
                        "class": "fruit-engraving-symbol",
                        css: {
                            left: ( centerX + marker.xMm * scale ) + "px",
                            top: ( centerY + marker.yMm * scale ) + "px",
                            width: size + "px",
                            height: size + "px",
                        },
                    } );
                    // immagine del simbolo: prima quella del product item (come per tutti gli altri
                    // overlay del frutto, ed è quella che si vede sulla scheda prodotto), poi quella
                    // generica del valore attributo (files.attribute_raw_value_id, di solito un SVG).
                    // Sempre la versione orizzontale: la rotazione dei frutti verticali la fa il CSS.
                    const symbolUri = value.horizontalImage?.uri || value.attributeValue?.horizontalImage?.uri;
                    if ( symbolUri ) {
                        $symbol.css( "background-image", `url('${symbolUri}')` );
                    } else {
                        // valori senza disegno (CUSTOM, TESTO CUSTOM...): resta il riquadro
                        // tratteggiato, così la posizione si vede e si può spostare
                        $symbol.addClass( "is-empty" );
                    }
                    $layer.append( $symbol );
                    $anchor.append( $layer );
                    this.positionEngravingLayer( $layer, fruitEl );

                    if ( this.canEdit && markers.length > 1 ) {
                        this.makeEngravingSymbolDraggable( $symbol, $layer, fruitId, item, value, engraving, scale, centerX, centerY );
                    } else {
                        $symbol.attr( "title", `Incisione ${engraving.rootCode} · posizione ${marker.order}` );
                    }
                },

                /**
                 * Rende trascinabile il simbolo inciso: durante il trascinamento il simbolo
                 * si aggancia in tempo reale al marker più vicino al puntatore (distanza
                 * calcolata sulle coordinate a schermo, così vale anche per i frutti ruotati)
                 * e al rilascio la posizione scelta viene scritta sul valore selezionato.
                 * @param {Object} $symbol - Elemento jQuery del simbolo.
                 * @param {Object} $layer - Contenitore degli agganci.
                 * @param {string} fruitId - Identificativo del frutto.
                 * @param {Object} item - Attributo del simbolo.
                 * @param {Object} value - Valore selezionato.
                 * @param {Object} engraving - Contesto incisione.
                 * @param {number} scale - Scala mm → px.
                 * @param {number} centerX - Offset in px del centro del frutto (origine dei marker) nel layer.
                 * @param {number} centerY - Offset in px del centro del frutto (origine dei marker) nel layer.
                 */
                makeEngravingSymbolDraggable: function( $symbol, $layer, fruitId, item, value, engraving, scale, centerX, centerY ) {
                    const self = this;
                    const key  = fruitId + "-" + item.id;

                    const applyMarker = function( marker ) {
                        $symbol.css( { left: ( centerX + marker.xMm * scale ) + "px", top: ( centerY + marker.yMm * scale ) + "px" } );
                        $symbol.attr( "title", `Incisione ${engraving.rootCode} · posizione ${marker.order} di ${engraving.markers.length} (trascina per spostare)` );
                    };

                    $symbol.addClass( "is-draggable" );
                    applyMarker( engraving.markers.find( ( m ) => { return String( m.id ) === String( value.engravingMarkerId ); } ) || engraving.markers[ 0 ] );

                    // il frutto è un draggable di jQuery UI: il mousedown sul simbolo non deve arrivarci
                    $symbol.on( "mousedown", function( event ) {
                        event.preventDefault();
                        event.stopPropagation();
                    } );

                    $symbol.on( "pointerdown", function( event ) {
                        event.preventDefault();
                        event.stopPropagation();

                        $symbol.addClass( "is-dragging" );
                        $layer.addClass( "is-dragging" );

                        const onMove = function( moveEvent ) {
                            const nearest = self.nearestEngravingMarker( $layer, moveEvent.clientX, moveEvent.clientY );
                            if ( !nearest ) {
                                return;
                            }
                            $layer.find( ".fruit-engraving-snap" ).removeClass( "is-target" );
                            $( nearest.element ).addClass( "is-target" );
                            applyMarker( nearest.marker );
                        };

                        const onUp = function( upEvent ) {
                            document.removeEventListener( "pointermove", onMove );
                            document.removeEventListener( "pointerup", onUp );
                            $symbol.removeClass( "is-dragging" );
                            $layer.removeClass( "is-dragging" );
                            $layer.find( ".fruit-engraving-snap" ).removeClass( "is-target" );

                            const nearest = self.nearestEngravingMarker( $layer, upEvent.clientX, upEvent.clientY );
                            if ( !nearest ) {
                                return;
                            }
                            applyMarker( nearest.marker );
                            value.engravingMarkerId = nearest.marker.id;
                            self.$set( self.engravingSelection, key, {
                                markerId: nearest.marker.id,
                                order: nearest.marker.order,
                                count: engraving.markers.length,
                                code: engraving.rootCode,
                            } );
                        };

                        document.addEventListener( "pointermove", onMove );
                        document.addEventListener( "pointerup", onUp );
                    } );
                },

                /**
                 * Marker più vicino a un punto dello schermo fra gli agganci disegnati.
                 * @param {Object} $layer - Contenitore degli agganci.
                 * @param {number} clientX - Coordinata X del puntatore.
                 * @param {number} clientY - Coordinata Y del puntatore.
                 * @returns {Object|null} { element, marker }
                 */
                nearestEngravingMarker: function( $layer, clientX, clientY ) {
                    let best     = null;
                    let bestDist = Number.POSITIVE_INFINITY;

                    $layer.find( ".fruit-engraving-snap" ).each( function() {
                        const rect = this.getBoundingClientRect();
                        const dx   = ( rect.left + rect.width / 2 ) - clientX;
                        const dy   = ( rect.top + rect.height / 2 ) - clientY;
                        const dist = ( dx * dx ) + ( dy * dy );
                        if ( dist < bestDist ) {
                            bestDist = dist;
                            best = this;
                        }
                    } );

                    if ( !best ) {
                        return null;
                    }

                    return {
                        element: best,
                        marker: {
                            id: best.dataset.markerId,
                            order: Number( best.dataset.order ),
                            xMm: Number( best.dataset.x ),
                            yMm: Number( best.dataset.y ),
                        },
                    };
                },

                /**
                 * Etichetta della posizione scelta per il simbolo inciso di un attributo,
                 * mostrata sotto la tendina nella lista attributi del frutto.
                 * @param {Object} fruit - Frutto configurato.
                 * @param {Object} item - Attributo del frutto.
                 * @returns {string} Testo o stringa vuota.
                 */
                engravingPositionLabel: function( fruit, item ) {
                    const selection = this.engravingSelection[ fruit.id + "-" + item.id ];
                    if ( !selection ) {
                        return "";
                    }
                    const selected = item.values?.find( function( v ) { return v.selected; } );
                    if ( !selected ) {
                        return "";
                    }
                    return `Incisione in posizione ${selection.order} di ${selection.count}: trascina il simbolo sull'anteprima per spostarlo.`;
                },

                /**
                 * Avviso non bloccante per i frutti con un simbolo inciso selezionato ma
                 * senza griglia definita: il simbolo resta centrato come prima.
                 * @param {Object} fruit - Frutto configurato.
                 * @returns {string} Testo dell'avviso o stringa vuota.
                 */
                engravingWarning: function( fruit ) {
                    const grid = fruit && fruit.fruit ? this.engravingGrids[ fruit.fruit.id ] : null;
                    if ( !grid || !( grid.attributes || [] ).length ) {
                        return "";
                    }

                    const missing = [];
                    for ( const fi of ( fruit.items || [] ) ) {
                        if ( !fi.attributeCode || ( grid.symbolCodes || [] ).indexOf( fi.attributeCode ) === -1 ) {
                            continue;
                        }
                        if ( !fi.values?.some( function( v ) { return v.selected; } ) ) {
                            continue;
                        }
                        const root = this.engravingRootAttribute( fruit, fi, grid );
                        if ( root && !( root.markers || [] ).length && missing.indexOf( root.name ) === -1 ) {
                            missing.push( root.name );
                        }
                    }

                    if ( !missing.length ) {
                        return "";
                    }

                    return `Griglia incisioni non definita (${missing.join( ", " )}): il simbolo resta centrato sul frutto.`;
                },

                /**
                 * Aggiorna l'overlay di combinazione per un frutto.
                 * Raccoglie tutti i productItemId selezionati tra gli attributi del frutto,
                 * li invia al server per ottenere le immagini delle combinazioni compatibili
                 * (ricerca parziale con controllo conflitti) e mostra ciascuna immagine
                 * come overlay allo stesso z-index del suo attributo con indice più alto.
                 * @param {string} fruitId - Identificativo del frutto.
                 */
                updateFruitCombinationOverlay: function( fruitId ) {
                    const fruit = this.detailForm.data.fruits.find( function( f ) { return f.id === fruitId; } );
                    if ( !fruit ) {
                        return;
                    }
                    const selectedIds = [];
                    const productItemIndex = {};
                    if ( fruit.items ) {
                        let itemIdx = 0;
                        for ( const item of fruit.items ) {
                            const selected = item.values?.find( function( v ) { return v.selected; } );
                            if ( selected?.productItemId ) {
                                selectedIds.push( selected.productItemId );
                                productItemIndex[ selected.productItemId ] = itemIdx;
                            }
                            itemIdx++;
                        }
                    }
                    const fruitEl = $( "#quotation-plate-fruits #" + fruitId );
                    if ( !fruitEl.length ) {
                        return;
                    }
                    fruitEl.find( "div[class^='fruit-overlay-combination']" ).remove();
                    if ( selectedIds.length === 0 ) {
                        return;
                    }
                    // le immagini di combinazione sono censite in orizzontale:
                    // per i frutti verticali la rotazione la fa il CSS
                    const overlayStyleFor = ( zIndex ) => { return this.fruitOverlayStyle( fruitId, zIndex ); };
                    return new Promise( function( resolve ) {
                        ajax( {
                            method: "POST",
                            url: BASE + "/combinations/findByListOfProductItemIds",
                            loading: false, // in sfondo: niente spinner globale
                            data: JSON.stringify( { productItemIds: selectedIds, orientation: "HOR" } ),
                            callback: {
                                done: function( xhr ) {
                                    if ( xhr.status === "SUCCESS" && xhr.data?.combinations?.length ) {
                                        // Se c'è almeno una combinazione, nasconde l'immagine del frutto (ma solo se è
                                        // l'immagine del frutto generico)
                                        const hasRootImage = fruit.fruit?.horizontalImage?.uri;
                                        if ( !hasRootImage ) {
                                            fruitEl.find( "img" ).hide();
                                        }
                                        for ( let idx = 0; idx < xhr.data.combinations.length; idx++ ) {
                                            const combo = xhr.data.combinations[ idx ];
                                            let maxIdx = 0;
                                            for ( const pid of combo.productItemIds ) {
                                                const fi = productItemIndex[ pid ];
                                                if ( fi !== undefined && fi > maxIdx ) {
                                                    maxIdx = fi;
                                                }
                                            }
                                            const zIndex = 1040 + maxIdx;
                                            fruitEl.append( `<div class="fruit-overlay-combination-${idx}" style="${overlayStyleFor( zIndex )} background-image: url('${combo.image}'); background-size: contain; background-repeat: no-repeat; background-position: center"></div>` );
                                        }
                                    }
                                    resolve();
                                },
                                fail: function() {
                                    resolve();
                                },
                            },
                        } );
                    } );
                },

                /**
                 * Verifica se il valore attualmente selezionato di un attributo
                 * consente l'inserimento di una nota testuale (allowNote = true).
                 * @param {Object} item - Attributo con array values.
                 * @returns {boolean} True se il valore selezionato ha allowNote attivo.
                 */
                checkIfSelectedAllowsNote: function( item ) {
                    const selected = item.values?.find( function( v ) { return v.selected; } );
                    return !!selected?.attributeValue?.allowNote;
                },

                /**
                 * Restituisce la nota associata al valore selezionato di un attributo.
                 * Cerca prima sulla value (impostata dall'input), poi nei dati salvati.
                 * @param {Object} item - Attributo con array values.
                 * @param {string|number} [fruitId] - ID del frutto (solo per attributi frutto).
                 * @returns {string} Nota o stringa vuota.
                 */
                getValueNote: function( item, fruitId ) {
                    const selected = item.values?.find( function( v ) { return v.selected; } );
                    if ( !selected ) { return ""; }
                    if ( selected.note != null ) { return selected.note; }
                    const productItemId = selected.productItemId;
                    const attrValueId = selected.attributeValue?.id;
                    if ( !productItemId || !attrValueId ) { return ""; }
                    if ( fruitId != null ) {
                        const saved = ( this.detailForm.data.fruitQuotationItemProductItems || [] ).find( function( qipi ) {
                            return qipi.product_item_id == productItemId
                                && qipi.attribute_value_id == attrValueId
                                && qipi.quotation_item_fruit_id == fruitId;
                        } );
                        if ( saved?.note != null ) {
                            // this.$set( selected, "note", saved.note );
                            return saved.note;
                        }
                    } else {
                        const saved = ( this.detailForm.data.plateQuotationItemProductItems || [] ).find( function( qipi ) {
                            return qipi.productItem?.id == productItemId
                                && qipi.productItem?.attributeValue?.id == attrValueId;
                        } );
                        if ( saved?.note != null ) {
                            // this.$set( selected, "note", saved.note );
                            return saved.note;
                        }
                    }
                    return "";
                },

                /**
                 * Aggiorna la nota del valore selezionato di un attributo.
                 * @param {Event} event - Evento input.
                 * @param {Object} item - Attributo con array values.
                 */
                onValueNoteInput: function( event, item ) {
                    const selected = item.values?.find( function( v ) { return v.selected; } );
                    if ( selected ) {
                        this._cascadingFruit = true;
                        this.$set( selected, "note", event.target.value );
                        this.$nextTick( () => {
                            this.$nextTick( () => {
                                this._cascadingFruit = false;
                            } );
                        } );
                    }
                },

                // MARK: Fruit Suggest
                /**
                 * Gestisce l'input di ricerca nel suggeritore frutti.
                 * Se il termine ha almeno 3 caratteri, effettua una richiesta AJAX
                 * per ottenere i suggerimenti filtrati per termine e linea.
                 * Aggiorna la lista fruitSuggestions e il flag di caricamento.
                 */
                onFruitSearchInput: function() {
                    const term = this.fruitSearchTerm;
                    clearTimeout( this._fruitSearchTimer );
                    if ( term.length < 3 ) {
                        this.fruitSuggestions = [];
                        return;
                    }
                    this._fruitSearchTimer = setTimeout( () => {
                        if ( this.fruitSearchTerm !== term ) return;
                        this.fruitSuggestLoading = true;
                        ajax( {
                            method: "GET",
                            url: BASE + "/fruits?str=" + encodeURIComponent( term ) + "&lineId=" + ( this.detailForm.data.product.line.id || "" ),
                            callback: {
                                done: ( xhr ) => {
                                    if ( this.fruitSearchTerm !== term ) return;
                                    this.fruitSuggestions = xhr.data || [];
                                    this.fruitSuggestLoading = false;
                                },
                                fail: () => {
                                    if ( this.fruitSearchTerm !== term ) return;
                                    this.fruitSuggestLoading = false;
                                },
                            },
                        } );
                    }, 300 );
                },

                /**
                 * Seleziona un frutto dai suggerimenti e lo aggiunge alla placca.
                 * Resetta il termine di ricerca e la lista dei suggerimenti.
                 * @param {Object} item - Frutto selezionato dai suggerimenti.
                 */
                selectFruitSuggestion: function( item ) {
                    this.onSelectFruit( item );
                    this.fruitSearchTerm = "";
                    this.fruitSuggestions = [];
                },

                // MARK: Position Suggest
                /**
                 * Gestisce l'input di ricerca nel suggeritore posizioni.
                 * Se il termine ha almeno 2 caratteri ed è selezionata una zona,
                 * effettua una richiesta AJAX per ottenere i suggerimenti.
                 * Aggiorna la lista positionSuggestions e il flag di caricamento.
                 */
                onPositionSearchInput: function() {
                    const term = this.positionSearchTerm;
                    const zoneId = this.detailForm.data.quotationZoneId;
                    clearTimeout( this._positionSearchTimer );
                    if ( term.length < 2 || !zoneId ) {
                        this.positionSuggestions = [];
                        this.detailForm.data.position = { id: "", code: term };
                        return;
                    }
                    this._positionSearchTimer = setTimeout( () => {
                        if ( this.positionSearchTerm !== term ) return;
                        this.positionSuggestLoading = true;
                        ajax( {
                            method: "GET",
                            url: BASE + "/quotations/zones/" + zoneId + "/positions?str=" + encodeURIComponent( term ),
                            callback: {
                                done: ( xhr ) => {
                                    if ( this.positionSearchTerm !== term ) return;
                                    this.positionSuggestions = xhr.data || [];
                                    this.positionSuggestLoading = false;
                                },
                                fail: () => {
                                    if ( this.positionSearchTerm !== term ) return;
                                    this.positionSuggestLoading = false;
                                },
                            },
                        } );
                    }, 300 );
                },

                /**
                 * Seleziona una posizione dai suggerimenti e aggiorna il form.
                 * Imposta il termine di ricerca con il codice della posizione selezionata.
                 * @param {Object} item - Posizione selezionata con proprietà id e code.
                 */
                selectPositionSuggestion: function( item ) {
                    this.detailForm.data.position = item;
                    this.positionSearchTerm = item.code || item.term;
                    this.positionSuggestions = [];
                },

                /**
                 * Sincronizza il campo position con il termine di ricerca digitato.
                 * Se l'utente ha digitato un codice che non corrisponde a nessun suggerimento,
                 * imposta una posizione libera con solo il codice.
                 */
                syncPositionFromSearchTerm: function() {
                    if ( this.positionSearchTerm && ( !this.detailForm.data.position || this.detailForm.data.position.code !== this.positionSearchTerm ) ) {
                        this.detailForm.data.position = { id: "", code: this.positionSearchTerm };
                    }
                },

                // MARK: Pricing
                /**
                 * Calcola e aggiorna il prezzo della placca tramite richiesta al server.
                 * Se il metodo di prezzo è "Fisso", mostra un avviso e non procede.
                 * Invia i dati dell'item, il prezzo corrente e l'ID quotazione.
                 * Applica gli sconti e calcola il totale.
                 * @returns {Promise<boolean>} Promise che restituisce false se il metodo è fisso.
                 */
                updatePricing: async function() {
                    if ( this.pricing.data.method.id === "F" ) {
                        AP.widget.notify( "warning", "Hai selezionato Prezzo Fisso." );
                        return false;
                    }
                    const item = this.getItemData();

                    // posizioni correnti dei frutti: servono al server per la
                    // logica dei tappi (VITI A VISTA = NO), come nel salvataggio
                    const positions = {};
                    pub.fruitsController?.fruits.forEach( ( fruit ) => {
                        positions[ fruit.id ] = fruit.cellIds;
                    } );

                    const payload = {
                        item: item,
                        price: this.pricing.data,
                        quotationId: AP.page.quotation.id,
                        positions: positions,
                    };
                    AP.loading.show();

                    ajax( {
                        method: "POST",
                        url: BASE + "/quotation-items/type/plate/pricing",
                        data: JSON.stringify( payload ),
                        callback: {
                            done: ( xhr ) => {
                                AP.loading.hide();
                                if ( xhr.data ) {
                                    this.pricing.data = xhr.data;
                                    const actualTotal = xhr.data.totalGoods;
                                    const disc1 = Number.parseFloat( this.pricing.data.discount1 ) || 0;
                                    const disc2 = Number.parseFloat( this.pricing.data.discount2 ) || 0;
                                    const td1 = actualTotal - ( actualTotal * disc1 / 100 );
                                    const td2 = td1 - ( td1 * disc2 / 100 );
                                    this.pricing.data.total = Number( td2 ).toFixed( 2 );
                                }
                            },
                            fail: () => {
                                AP.loading.hide();
                            },
                        },
                    } );
                },

                /**
                 * Gestisce il cambiamento del metodo di prezzo tra "Calcolato" e "Fisso".
                 * In modalità calcolato, azzera il totale e disabilita l'inserimento manuale.
                 * In modalità fisso, azzera le righe (gli sconti restano) e abilita l'inserimento manuale del totale.
                 */
                changePricingMethod: function() {
                    if ( this.pricing.data.method.id === "C" ) {
                        this.pricing.data.total = 0;
                        this.pricing.isTotalEnabled = false;
                    } else {
                        // a prezzo fisso gli sconti restano: si applicano all'importo inserito
                        this.pricing.data.lines = [];
                        this.pricing.data.total = 0;
                        this.pricing.isTotalEnabled = true;
                    }
                },

                /**
                 * Formatta un importo numerico nel formato valuta italiano:
                 * punto come separatore delle migliaia, virgola per i decimali,
                 * sempre due cifre decimali.
                 * @param {*} amount - Valore da formattare (numero o stringa numerica).
                 * @returns {string} Importo formattato, o stringa vuota se non valido.
                 */
                formatMoney: function( amount ) {
                    if ( amount === null || amount === undefined || amount === "" ) { return ""; }
                    const num = Number( amount );
                    if ( Number.isNaN( num ) ) { return String( amount ); }
                    return num.toLocaleString( "it-IT", { minimumFractionDigits: 2, maximumFractionDigits: 2 } );
                },

                // MARK: Save
                /**
                 * Salva la placca sul server.
                 * Verifica che la placca sia configurata (anche senza frutti) e, in caso di
                 * custom image, che sia stata selezionata un'immagine.
                 * Prepara i dati includendo posizioni, zone e fruit positions.
                 * Genera un'anteprima tramite html2canvas da inviare come base64.
                 * Al successo, mostra il modale post-salvataggio.
                 * @returns {Promise<boolean>} Promise che restituisce false se le validazioni falliscono.
                 */
                save: async function() {
                    AP.loading.show();

                    // La placca si può salvare anche senza frutti (placca cieca / retro struttura):
                    // basta che sia stata configurata e disegnata (linea, modello, finitura).
                    if ( !pub.fruitsController || !this.isPlateDefined ) {
                        AP.widget.notify( "error", "Devi configurare la placca (linea, modello e finitura) prima di salvare." );
                        AP.loading.hide();
                        return false;
                    }

                    if ( this.detailForm.data.id && this.detailForm.data.customImage && !this.backgroundCustomImage.url ) {
                        AP.widget.notify( "error", "Hai scelto custom image, devi selezionare un'immagine prima di salvare." );
                        AP.loading.hide();
                        return false;
                    }

                    const positions = {};
                    pub.fruitsController.fruits.forEach( ( fruit ) => {
                        positions[fruit.id] = fruit.cellIds;
                    } );

                    this.smallLoading = true;

                    let preview = $( "#plate-background" )[0];
                    if ( this.detailForm.data.id && this.detailForm.data.customImage ) {
                        preview = $( "#plate-custom-image" )[0];
                    }

                    const parsedData = {};
                    parsedData.quotationId = AP.page.quotation.id;
                    parsedData.item = this.getItemData();
                    parsedData.isClone = this.detailForm.isClone || false;
                    parsedData.typeId = "plate";
                    parsedData.price = this.pricing.data;

                    if ( this.detailForm.data.quotationSubzoneId ) {
                        let subzoneObj = this.detailForm.data.quotationSubzone;
                        if ( !subzoneObj ) {
                            for ( const subzone of this.subzones ) {
                                if ( subzone.id === this.detailForm.data.quotationSubzoneId ) {
                                    subzoneObj = subzone;
                                    break;
                                }
                            }
                        }
                        parsedData.item.quotationZone = subzoneObj || this.detailForm.data.quotationZone;
                    } else if ( this.detailForm.data.quotationZoneId ) {
                        parsedData.item.quotationZone = this.detailForm.data.quotationZone;
                    }

                    const fruitPositions = {};
                    for ( const f of this.detailForm.data.fruits ) {
                        fruitPositions[f.id] = positions[f.id] || [];
                    }
                    parsedData.positions = fruitPositions;

                    // html2canvas non rasterizza in modo affidabile i pittogrammi delle
                    // incisioni (SVG con solo viewBox, senza width/height): li disegna
                    // microscopici. Si sostituiscono con un PNG pre-rasterizzato solo per lo
                    // scatto, poi si ripristina subito l'SVG originale (serve per il drag).
                    const svgRestores = await rasterizeSvgSymbolsForPreview( $( preview ) );
                    const canvas = await html2canvas( preview, { useCORS: true } );
                    restoreSvgSymbols( svgRestores );
                    const imgData = scaleCanvasToBase64( canvas, 800 );
                    parsedData.imageBase64 = imgData;

                    await ajax( {
                        method: "POST",
                        url: BASE + "/quotation-items/plate",
                        data: JSON.stringify( parsedData ),
                        callback: {
                            done: ( xhr ) => {
                                this.smallLoading = false;
                                AP.loading.hide();
                                // validazione lato server (es. attributi non compilati): non è un salvataggio riuscito
                                if ( xhr.status === "INVALID" ) {
                                    NM.form.showMessages( xhr.data );
                                    return;
                                }
                                AP.widget.notify( "success", "Placca salvata correttamente." );
                                // .modal("hide"): fa scattare il listener globale hide.bs.modal
                                // (app-quotation-detail.js) che pulisce l'hash #plate/{id} dell'URL.
                                // Senza, un reload successivo (es. click su "No" nel modale "vuoi
                                // posizionarlo in pianta") riapre la stessa riga in modifica invece
                                // di tornare alla vista normale del preventivo.
                                AP.plate.fields.modalRoot.modal( "hide" );
                                this.showPostSaveModal( parsedData.quotationId, xhr.data && xhr.data.id );
                            },
                            fail: () => {
                                this.smallLoading = false;
                                AP.loading.hide();
                            },
                        },
                    } );
                },

                /**
                 * Mostra il modale post-salvataggio per decidere se posizionare
                 * la placca in pianta o rimanere nella pagina corrente.
                 * Se la placca è nuova o sono cambiati zona/quantità, mostra il modale.
                 * Altrimenti reindirizza alla scheda quotazione dopo un breve timeout.
                 * @param {string} parsedQuotationId - Identificativo della quotazione.
                 */
                showPostSaveModal: function( parsedQuotationId, newItemId ) {
                    if ( AP.page.pendingDraftId && newItemId ) {
                        AP.plate.fields.modalRoot.modal( "hide" );
                        var draftId = AP.page.pendingDraftId;
                        AP.page.pendingDraftId = null;
                        $.ajax({
                            method: "POST",
                            url: "/manager/ajax/quotation-item-drafts/" + draftId + "/apply",
                            data: JSON.stringify({ quotationItemId: newItemId, sizeMultiplier: window.plantPositionsVm ? window.plantPositionsVm.lastSizeMultiplier : null }),
                            contentType: "application/json"
                        }).always(function() {
                            if ( window.plantPositionsVm ) {
                                window.plantPositionsVm.getItems();
                            }
                        });
                        return;
                    }

                    // Già nella vista pianta: niente prompt "vuoi posizionarlo in pianta"
                    // né redirect, si è già lì. Basta aggiornare l'elenco articoli (la
                    // modale è già stata chiusa correttamente prima di chiamare questo metodo).
                    if ( window.plantPositionsVm ) {
                        window.plantPositionsVm.getItems();
                        return;
                    }

                    const pd = this.detailForm.data;
                    const modal = $( "#posizione-in-pianta-modal" );

                    function handlerSi() {
                        var zoneId = ( pd.quotationZone ? pd.quotationZone.id : "" ) || viewModel.get( "detailForm.data.zone.id" ) || "";
                        var url = "/manager/quotation-plant-positions/" + AP.page.quotation.id;
                        if ( zoneId ) { url += "?selectedZoneId=" + zoneId; }
                        window.location.href = url;
                    }

                    function handlerNo() {
                        window.location.reload();
                    }

                    modal.find( "#btn-si" ).off( "click" ).on( "click", handlerSi );
                    modal.find( "#btn-no" ).off( "click" ).on( "click", handlerNo );

                    const isNew = plateResponse === undefined || plateResponse === null;
                    let hoCambiatoZona = false;
                    let hoCambiatoQuantita = false;

                    if ( !isNew && plateResponse?.data ) {
                        hoCambiatoZona = pd.quotationZone && plateResponse.data.quotationItem && pd.quotationZone.name !== plateResponse.data.quotationItem.quotationZone.name;
                        hoCambiatoQuantita = pd.quantity !== plateResponse.data.quotationItem.quantity;
                    }

                    const hasZone = pd.quotationZone && pd.quotationZone.name && pd.quotationZone.name !== "Non assegnato";

                    if ( hasZone && ( isNew || !pd.id || hoCambiatoZona || hoCambiatoQuantita ) ) {
                        modal.modal( "show" );
                        return;
                    }

                    setTimeout( function() {
                        window.location.href = "/manager/quotations/" + parsedQuotationId + "?tab=plate";
                    }, 1000 );
                },

                // MARK: Helpers
                /**
                 * Prepara e restituisce i dati dell'item per l'invio al server.
                 * Copia i dati del form e mappa i frutti con le proprietà essenziali.
                 * @returns {Object} Dati dell'item pronti per la serializzazione.
                 */
                getItemData: function() {
                    const data = { ...this.detailForm.data };
                    data.product = { ...data.product };
                    data.product.items = { _data: data.product.items || [] };
                    data.blockOrientations = { ...( this.plate.blockOrientations || {} ) };
                    data.fruits = {
                        _data: this.detailForm.data.fruits.map( ( f ) => {
                            return {
                                id: f.id,
                                fruitId: f.fruitId,
                                fruit: f.fruit,
                                position: f.position,
                                items: { _data: f.items || [] },
                                positionIds: f.positionIds,
                            };
                        } ),
                    };
                    return data;
                },

                /**
                 * Verifica se le condizioni per il salvataggio sono soddisfatte.
                 * Il salvataggio è abilitato se la quantità è maggiore di zero
                 * e la finitura del prodotto è stata selezionata.
                 */
                checkCanSave: function() {
                    this.detailForm.canSave = this.detailForm.data.quantity > 0 && this.detailForm.data.product.finish.id !== "";
                },

                /**
                 * Resetta i campi di linea, modello e finitura del prodotto nel form.
                 */
                clearForm: function() {
                    this.detailForm.data.product.line.id = "";
                    this.detailForm.data.product.model.id = "";
                    this.detailForm.data.product.finish.id = "";
                    this.exportCodePreview = null;
                    this.importantAttributes = [];
                },

                /**
                 * Resetta i filtri di linea, modello e finitura.
                 * Cancella le preferenze utente corrispondenti e verifica la possibilità di salvare.
                 */
                clearFilters: function() {
                    this.clearForm();
                    AP.deleteUserPref( "plate.lineId" );
                    AP.deleteUserPref( "plate.modelId" );
                    AP.deleteUserPref( "plate.finishId" );
                    this.checkCanSave();
                },

                toggleJsonExport: function() {
                    if ( this.showJsonPanel ) {
                        this.showJsonPanel = false;
                        return;
                    }
                    const id = this.detailForm.data.id;
                    if ( !id ) return;
                    this.jsonExportLoading = true;
                    ajax( {
                        method: "GET",
                        url: BASE + "/quotation-items/plate/" + id + "/export",
                        callback: {
                            done: ( xhr ) => {
                                this.jsonExportText = JSON.stringify( xhr.data, null, 2 );
                                this.showJsonPanel = true;
                                this.jsonExportLoading = false;
                            },
                            fail: () => {
                                this.jsonExportLoading = false;
                            },
                        },
                    } );
                },

                toggle3dExport: function() {
                    if ( this.show3dPanel ) {
                        this.show3dPanel = false;
                        return;
                    }
                    const id = this.detailForm.data.id;
                    if ( !id ) return;
                    this.json3dLoading = true;
                    ajax( {
                        method: "GET",
                        url: BASE + "/quotation-items/plate/" + id + "/export3d",
                        callback: {
                            done: ( xhr ) => {
                                this.json3dText = JSON.stringify( xhr.data, null, 2 );
                                this.show3dPanel = true;
                                this.json3dLoading = false;
                            },
                        },
                    } ).always( () => {
                        this.json3dLoading = false;
                    } );
                },

                /**
                 * Cerca in una lista (modelli o finiture) la voce che corrisponde a quella
                 * selezionata prima del cambio: stesso id, altrimenti stesso codice,
                 * altrimenti stessa descrizione.
                 * @param {Array} list - Lista caricata dall'ajax.
                 * @param {Object|null} prev - { id, code, name } della voce precedente.
                 * @returns {Object|null}
                 */
                findEquivalent: function( list, prev ) {
                    if ( !prev || !list || !list.length ) {
                        return null;
                    }
                    const norm = ( v ) => { return String( v || "" ).trim().toUpperCase(); };
                    return list.find( ( i ) => { return prev.id && i.id == prev.id; } )
                        || list.find( ( i ) => { return prev.code && norm( i.code ) === norm( prev.code ); } )
                        || list.find( ( i ) => { return prev.name && norm( i.name ) === norm( prev.name ); } )
                        || null;
                },

                /**
                 * Restituisce { id, code, name } della voce con l'id dato, letta dalla lista
                 * grezza dell'ajax (il v-model contiene solo l'id).
                 */
                pickFromList: function( list, id ) {
                    if ( !id || !list ) {
                        return null;
                    }
                    const found = list.find( ( i ) => { return i.id == id; } );
                    return found ? { id: found.id, code: found.code, name: found.name } : null;
                },

                /**
                 * Reset dei campi che dipendono dal prodotto (attributi, frutti, placca disegnata).
                 */
                resetProductDependents: function() {
                    this.detailForm.data.product.items = [];
                    this.detailForm.data.fruits = [];
                    this.plate.blockOrientations = {};
                    this.isPlateDefined = false;
                    this.renderPlateWithFruits();
                },

                /**
                 * Dopo il caricamento delle finiture, riseleziona quella equivalente alla
                 * precedente (es. OTTONE ANTICATO SCURO passando da 503 a 2x3) e ricarica
                 * il prodotto; se non esiste nel nuovo modello la finitura resta vuota.
                 */
                preserveFinish: async function( prevFinish ) {
                    const matched = this.findEquivalent( this.finishes, prevFinish );
                    if ( matched ) {
                        this.detailForm.data.product.finish = { id: matched.id, name: matched.name || "" };
                        await this.loadProduct();
                    } else {
                        AP.deleteUserPref( "plate.finishId" );
                    }
                },

                /**
                 * Gestisce il cambio di linea selezionata.
                 * Carica i modelli della nuova linea e prova a mantenere modello e finitura
                 * equivalenti (per codice/descrizione); resetta attributi, frutti e placca.
                 */
                handleLineChange: async function() {
                    const prevModel = this.pickFromList( this.models, this.detailForm.data.product.model.id );
                    const prevFinish = this.pickFromList( this.finishes, this.detailForm.data.product.finish.id );

                    this.detailForm.data.product.model = { id: "", code: "" };
                    this.detailForm.data.product.finish = { id: "" };
                    this.models = [];
                    this.finishes = [];
                    this.resetProductDependents();

                    await this.loadModels();

                    const matchedModel = this.findEquivalent( this.models, prevModel );
                    if ( !matchedModel ) {
                        AP.deleteUserPref( "plate.modelId" );
                        AP.deleteUserPref( "plate.finishId" );
                        return;
                    }
                    this.detailForm.data.product.model = { id: matchedModel.id, code: matchedModel.code };
                    await this.loadFinishes();
                    await this.preserveFinish( prevFinish );
                },

                /**
                 * Gestisce il cambio di modello selezionato.
                 * Carica le finiture e mantiene quella già scelta se esiste anche per il nuovo
                 * modello (per id/codice/descrizione); resetta attributi, frutti e placca.
                 */
                handleModelChange: async function() {
                    const prevFinish = this.pickFromList( this.finishes, this.detailForm.data.product.finish.id );

                    this.detailForm.data.product.finish = { id: "" };
                    this.finishes = [];
                    this.resetProductDependents();

                    await this.loadFinishes();
                    await this.preserveFinish( prevFinish );
                },

                /**
                 * Apre la scheda di dettaglio del prodotto corrente in una nuova finestra.
                 */
                goToProduct: function() {
                    const id = this.detailForm.data.product.id;
                    if ( id ) {
                        window.open( "/manager/products/" + id + "/detail", "_blank" );
                    }
                },
            },
        } );

        window.vm.$mount( "#plate-vue-app" );
        window.vm.loadZones();
    }

    /**
     * Apre il modale per la creazione di una nuova placca.
     * Monta l'app Vue, carica linee e zone, applica le preferenze utente
     * e inizializza i campi del form per un nuovo inserimento.
     * @param {Function} [onSave] - Callback opzionale da eseguire dopo il salvataggio.
     */
    pub.new = async function( onSave ) {
        AP.loading.show();
        NM.util.openModal( AP.plate.fields.modalRoot );

        await mountVue();

        if ( onSave ) {
            window.vm.detailForm.callback = window.vm.detailForm.callback || {};
            window.vm.detailForm.callback.onSave = onSave;
        }
        await window.vm.loadLines();
        window.vm.resetDetailForm();
        window.vm.plate.blockOrientations = {};

        let zoneData = AP.quotation.detail.config().zone;
        if ( !zoneData || zoneData.id === "" ) {
            const nonAss = window.vm.zones.find( ( z ) => { return z.name === "Non assegnato"; } );
            if ( nonAss ) {
                zoneData = nonAss;
            }
        }
        if ( zoneData ) {
            window.vm.detailForm.data.quotationZone = zoneData;
            window.vm.detailForm.data.quotationZoneId = zoneData.id;
        }

        window.vm.isEditMode = false;
        window.vm.detailForm.title = "Carica placca";
        window.vm.detailForm.isClone = false;

        const plateLineId = AP.getUserPref( "plate.lineId" );
        const plateModelId = AP.getUserPref( "plate.modelId" );
        const plateFinishId = AP.getUserPref( "plate.finishId" );

        if ( plateLineId ) {
            const line = window.vm.lines.find( ( l ) => { return l.id == plateLineId; } );
            if ( line ) {
                window.vm.detailForm.data.product.line.id = line.id;
                await window.vm.loadModels();
                if ( plateModelId ) {
                    const model = window.vm.models.find( ( m ) => { return m.id == plateModelId; } );
                    if ( model ) {
                        window.vm.detailForm.data.product.model.id = model.id;
                        await window.vm.loadFinishes();
                        if ( plateFinishId ) {
                            const finish = window.vm.finishes.find( ( f ) => { return f.id == plateFinishId; } );
                            if ( finish ) {
                                window.vm.detailForm.data.product.finish.id = finish.id;
                                await window.vm.loadProduct();
                            }
                        }
                    }
                }
            }
        }

        window.vm.pricing = {
            data: {
                id: "",
                quantity: 1,
                discount1: "",
                discount2: "",
                method: { id: "C", name: "Calcolato" },
                lines: [],
                total: 0,
            },
            priceTypes: [
                { id: "C", name: "Calcolato" },
                { id: "F", name: "Fisso" },
            ],
            isTotalEnabled: false,
        };

        window.vm.positionSearchTerm = "";
        window.vm.fruitSearchTerm = "";

        plateResponse = null;
        AP.loading.hide();
    };

    /**
     * Apre il modale per la modifica o la clonazione di una placca esistente.
     * Carica i dati della placca dal server, popola il form con i valori esistenti,
     * carica linee, modelli, finiture, product items e frutti.
     * @param {Object} opts - Opzioni per la modifica.
     * @param {string} opts.id - Identificativo della placca da modificare.
     * @param {boolean} [opts.clone=false] - Se true, apre in modalità clonazione.
     * @param {Function} [opts.onSave] - Callback opzionale da eseguire dopo il salvataggio.
     */
    pub.edit = async function( opts ) {
        const id = opts.id;

        NM.util.openModal( AP.plate.fields.modalRoot );

        await new Promise( function( resolve ) { setTimeout( resolve, 100 ); } );
        await mountVue();

        const clone = opts.clone || false;
        const onSave = opts.onSave;

        window.location.hash = "plate/" + id;
        AP.warnNotInCatalog( id );
        window.vm.resetDetailForm();
        window.vm.isEditMode = true;
        window.vm.detailForm.isClone = clone;
        window.vm.detailForm.title = clone ? "Clona placca" : "Modifica placca";

        plateResponse = await getPlate( id );

        if ( plateResponse.status === "SUCCESS" ) {
            const data = plateResponse.data;
            window.vm.savedExportCode = data.savedExportCode || "";
            window.vm.populateProduct( data.quotationItem.product );

            // override orientamento blocchi salvati con la riga di preventivo
            window.vm.plate.blockOrientations = {};
            if ( data.quotationItem.blockOrientations ) {
                try {
                    window.vm.plate.blockOrientations = JSON.parse( data.quotationItem.blockOrientations );
                } catch ( e ) {
                    console.error( "blockOrientations non valido", data.quotationItem.blockOrientations );
                }
            }
            window.vm.detailForm.data.id = data.quotationItem.id;
            window.vm.detailForm.data.position = data.quotationItem.position;
            window.vm.detailForm.data.note = data.quotationItem.note;
            window.vm.detailForm.data.quantity = data.quotationItem.quantity;
            window.vm.detailForm.data.special = data.quotationItem.special === "true";
            window.vm.detailForm.data.customImage = data.quotationItem.customImage === "true";
            window.vm.detailForm.data.bozza = data.quotationItem.bozza === "true";
            window.vm.detailForm.data.plateQuotationItemProductItems = data.quotationItem.items || [];

            const qz = data.quotationItem.quotationZone;
            if ( qz ) {
                if ( qz.origin ) {
                    window.vm.detailForm.data.quotationZone = qz.origin;
                    window.vm.detailForm.data.quotationZoneId = qz.origin.id;
                    window.vm.detailForm.data.quotationSubzone = qz;
                    window.vm.detailForm.data.quotationSubzoneId = qz.id;
                } else {
                    window.vm.detailForm.data.quotationZone = qz;
                    window.vm.detailForm.data.quotationZoneId = qz.id;
                }
            }

            await window.vm.loadBackgroundCustomImage( data.quotationItem.id );

            await window.vm.loadLines();
            await window.vm.loadModels();
            await window.vm.loadFinishes();
            await window.vm.firstLoadProductItems();
            await window.vm.loadPlate( data.quotationItem.frame ? data.quotationItem.frame.orientation : null );
            await window.vm.loadFruits();

            window.vm.positionSearchTerm = data.quotationItem.position ? data.quotationItem.position.code : "";
            window.vm.fruitSearchTerm = "";

            if ( data.quotationItem.price ) {
                window.vm.pricing.data = {  ...window.vm.pricing.data, ...data.quotationItem.price };
                if ( data.quotationItem.price.method ) {
                    window.vm.pricing.data.method = data.quotationItem.price.method;
                }
                // a prezzo fisso il campo Totale è l'importo pieno (amount), non il totale scontato
                if ( data.quotationItem.price.method?.id === "F" && data.quotationItem.price.amount != null ) {
                    window.vm.pricing.data.total = data.quotationItem.price.amount;
                }
                if ( window.vm.pricing.data.total != null ) {
                    window.vm.pricing.data.total = Number( window.vm.pricing.data.total ).toFixed( 2 );
                }
                window.vm.pricing.isTotalEnabled = data.quotationItem.price.method?.id === "F";
            }
        }

        if ( onSave ) {
            window.vm.detailForm.callback = window.vm.detailForm.callback || {};
            window.vm.detailForm.callback.onSave = onSave;
        }

        AP.loading.hide();
    };

    /**
     * Restituisce i dati correnti del form di dettaglio della placca.
     * @returns {Object|null} Dati del form o null se l'istanza Vue non è montata.
     */
    pub.getItem = function() {
        return window.vm ? window.vm.detailForm.data : null;
    };

    /**
     * Apre il modale in modalità clonazione per una placca esistente.
     * @param {Object} opts - Opzioni per la clonazione.
     * @param {string} opts.id - Identificativo della placca da clonare.
     */
    pub.clone = function( opts ) {
        pub.edit( { id: opts.id, clone: true } );
    };

    return pub;
} () );
