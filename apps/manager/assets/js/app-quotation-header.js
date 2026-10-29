AP.namespace( "quotation" );

Object.assign( AP.quotation.fields, {
    headerRoot: $( "#quotation-header-root" ),
    haderForm: $( "#quotation-header-form" ),
} );

$( document ).ready( function() {
    if ( AP.quotation.fields.headerRoot.length ) {
        AP.quotation.header.init();
    }

} );

var quotationDate = new Date();
var validityDate = new Date( quotationDate );

validityDate.setMonth( validityDate.getMonth() + 1 );

AP.quotation.header = ( function() {
    var pub = {};
    var fields = AP.quotation.fields;

    function buildCustomerDisplay(c) {
        var company = c.company || "";
        var rs      = c.ragioneSociale || "";
        var name    = c.name || "";
        var label   = (company && rs && company !== rs) ? company + " (" + rs + ")" : (rs || company);
        return label ? label + (name ? " / " + name : "") : name;
    }

    // Sigla nazione da mostrare: ISO, o la sigla Verticale/CRM se l'ISO manca (es. UK)
    function countryDisplay(country) {
        return country ? ( country.isoCode || country.code || "" ) : "";
    }

    var defaultDetailForm = {
        data: {
            id: "",
            name: "",
            customer: {
                id: "",
                name: "",
                ragioneSociale: "",
                industry: ""
            },
            shippingProfile: {
                id: "",
                name: "",
                shortId: "",
                street: "",
                city: "",
                postalCode: "",
                state: "",
                country: { id: "", isoCode: "" }
            },
            quotationNumber: "",
            versionNumber: 1,
            lang: {
                id: "IT",
                name: ""
            },
            zone: {
                id: "",
                name: ""
            },
            quotationDate: quotationDate,
            validityDate: validityDate,
            note: "",
            statusFile: {
                id: null,
                file: null
            },
            opportunity: {
                id: "",
                name: ""
            },
            lead: {
                id: "",
                name: ""
            },
            pricelist: {
                id: ""
            },
            paymentMethod: {
                id: 18 // BB 60 GG FM
            },
            customPaymentMethod: "",
            currency: {
                id: 1
            },
            vatCode: {
                id: 22
            },
            graphicTechnician: {
                id: "",
                name: ""
            },
            salesAgent: {
                id: "",
                name: ""
            },
            invoiceData: {
                name: "",
                company: "",
                vatNumber: "",
                email: "",
                phone: "",
                street: "",
                city: "",
                postalCode: "",
                country: { id: "" },
                state: { id: "" }
            },
            shipmentData: {
                name: "",
                company: "",
                vatNumber: "",
                email: "",
                phone: "",
                street: "",
                city: "",
                postalCode: "",
                country: { id: "", name: "" },
                state: { id: "", name: "" }
            },
			nessunAgente: true,
			agente1: null,
			agente2: null,
			agente3: null,
			agente4: null,
			agente5: null,
			commission1: null,
			commission2: null,
			commission3: null,
			commission4: null,
			commission5: null,
			referenteAmministrativo: "",
			referenteSpedizione: "",
			customerType: "",
			industry: "",
			industryLabel: "",
			rifLibero: "",
			po: "",
			reclamoAnno: "",
			reclamoNumero: "",
			reclamoAlfa: "",
			dataEvasione: null,
			codiceSdi: "",
        },
        title: "Modifica preventivo",
        totals: {
            "id": null
        },
		agentiList: []
    };

    var viewModel = kendo.observable( {
        detailForm: defaultDetailForm,
        languages: new kendo.data.DataSource(),
        // varCodes: new kendo.data.DataSource(),
        statuses: new kendo.data.DataSource(),
        vatCodes: new kendo.data.DataSource(),
        pricelists: new kendo.data.DataSource(),
        paymentMethods: new kendo.data.DataSource(),
        currencies: new kendo.data.DataSource(),
        countries: new kendo.data.DataSource(),
        states: new kendo.data.DataSource(),
        quotationItems: new kendo.data.DataSource(),
        saleUsers: new kendo.data.DataSource(),
        techUsers: new kendo.data.DataSource(),
        // Tendine a cascata del tab Reclamo ( vedi refreshClaimLists )
        showCustomPaymentMethod: false,
        claimAnni: [],
        claimNumeri: [],
        claimAlfa: [],
        canEdit: AP.page.canEdit,
        canSee: AP.page.canSee,
        agente2Enabled: false,
        agente3Enabled: false,
        agente4Enabled: false,
        agente5Enabled: false,

        crmCustomers: new kendo.data.DataSource( {
            serverFiltering: true,
            transport: {
                read: {
                    url: "/manager/ajax/quotations/crmcustomers",
                    data: {
                        str: function() {
                            return $( "#qt-customer" ).val();
                        },
                    }
                },
                parameterMap: function( data, type ) {
                    if ( type === "read" ) {
                        return { "str": data.str() };
                    }
                }
            },
            schema: {
                data: function( xhr ) { return xhr.data; },
                parse: function( xhr ) {
                    ( xhr.data || [] ).forEach( function( item ) {
                        item.displayLabel = buildCustomerDisplay( item );
                        ( item.shippingProfiles || [] ).forEach( function( p ) {
                            p.displayName = p.name + ( p.shortId ? " - " + p.shortId : "" );
                        } );
                    } );
                    return xhr;
                }
            }
        } ),

        crmOpportunities: new kendo.data.DataSource( {
            serverFiltering: true,
            transport: {
                read: {
                    url: "/manager/ajax/quotations/crmopportunities",
                    data: {
                        str: function() {
                            return $( "#qt-opportunity" ).val();
                        },
                    }
                },
                parameterMap: function( data, type ) {
                    if ( type === "read" ) {
                        return { "str": data.str() };
                    }
                }
            },
            schema: {
                data: function( xhr ) {
                    return xhr.data;
                }
            }
        } ),

        crmLeads: new kendo.data.DataSource( {
            serverFiltering: true,
            transport: {
                read: {
                    url: "/manager/ajax/quotations/crmleads",
                    data: {
                        str: function() {
                            return $( "#qt-lead" ).val();
                        },
                    }
                },
                parameterMap: function( data, type ) {
                    if ( type === "read" ) {
                        return { "str": data.str() };
                    }
                }
            },
            schema: {
                data: function( xhr ) {
                    return xhr.data.map( item => ( {
                        ...item,
                        fullName: `${item.firstName} ${item.lastName}`
                    } ) );
                }
            }
        } ),
        list: function() {
            window.location.href = "/manager/quotations";
        },
        exportQuotation: function() {
            AP.loading.show();
            NM.util.ajax( {
                method: "GET",
                url: "/manager/ajax/quotations-export/" + AP.page.quotation.id,
                callback: {
                    done: function( xhr ) {
                        if( xhr.status == "INVALID" ) {
                            AP.loading.hide();
                            NM.form.showMessages( xhr.data );
                            return;
                        }
                        AP.loading.hide();
                        AP.widget.notify( "success", "Preventivo esportato correttamente." );
                    }
                }
            } );
        },
		showAgenti: function() {
			return !viewModel.get("detailForm.data.nessunAgente");
		},
        changeMode: function( e ) {
            viewModel.set( "mode", e.currentTarget.textContent.toLowerCase() );
            viewModel.getItems();
        },
        getMode: function() {
            return viewModel.get( "mode" );
        },
        getImageSrc: function( event ) {

            const uri = event.image?.uri || "";

            if ( uri.toLowerCase().endsWith( ".svg" ) ) {
                return uri;
            }

            if ( uri != "" )  {
                var replaced = uri.replace( "_ori", "500" );
                return replaced;
            }

            return "/assets/main/img/img-not-found.png";
        },

        callback: {
            onCreate: undefined,
            onUpdate: undefined,
            onLoad: undefined,
        },

        loadInvoiceStates: function() {
            var country = this.detailForm.data.invoiceData.country;
            if ( country && country.id ) {
                this.filteredInvoiceStates.data( [] );

                var that = this;

                viewModel.states.fetch( function() {
                    var data = that.states.data().filter( function( item ) {
                        return item.countryId == country.id;
                    } );
                    that.filteredInvoiceStates.data( data );
                    if ( data.length == 1 ) {
                        that.detailForm.data.invoiceData.state = { id: data[0].id };
                    } else {
                        that.detailForm.data.invoiceData.state = { id: "" };
                    }
                } );

            } else {

                this.filteredInvoiceStates.data( [] );
                this.detailForm.data.invoiceData.state = { id: "" };
            }
        },

        loadShipmentStates: function() {
            var country = this.detailForm.data.shipmentData.country;
            if ( country && country.id ) {
                this.filteredShipmentStates.data( [] );
                var that = this;
                viewModel.states.fetch( function() {
                    var data = that.states.data().filter( function( item ) {
                        return item.countryId == country.id;
                    } );
                    that.filteredShipmentStates.data( data );
                    if ( data.length == 1 ) {
                        that.detailForm.data.shipmentData.state = { id: data[0].id };
                    } else {
                        that.detailForm.data.shipmentData.state = { id: "" };
                    }
                } );
            } else {
                this.filteredShipmentStates.data( [] );
                this.detailForm.data.shipmentData.state = { id: "" };
            }
        },

        save: function() {

            var thisForm = fields.haderForm;
            var status = thisForm.find( ".save-status" );

            thisForm.validate( {
                onfocusout: function( element ) {
                    $( element ).valid();
                },
                rules: {
                    name: {
                        required: true
                    },
                    quotationNumber: {
                        required: true
                    },
                    lang: {
                        required: true
                    },
                    validityDate: {
                        required: true
                    },
                    requireAnyOfCustomerLeadOrOpportunity: {
                        required: function() {

                            var leadId = viewModel.get( "detailForm.data.lead.id" );
                            var customerId =  viewModel.get( "detailForm.data.customer.id" );
                            var opportunityId = viewModel.get( "detailForm.data.opportunity.id" );

                            if ( customerId || leadId || opportunityId ) {
                                return false;
                            }

                            return true;
                        }
                    },
                    status: {
                        required: function() {

                            var statusId = viewModel.get( "detailForm.data.status.id" );
                            var statusFile = viewModel.get( "detailForm.data.statusFile" );
                            if ( statusId == "CCN" && !statusFile ) {
                                return true;
                            }

                            return false;
                        }
                    }
                },
                messages: {
                    name: {
                        required: "Nome richiesto.",
                    },
                    quotationNumber: {
                        required: "Numero richiesto."
                    },
                    lang: {
                        required: "Lingua richiesta."
                    },
                    validityDate: {
                        required: "Data validità richiesta."
                    },

                    requireAnyOfCustomerLeadOrOpportunity: {
                        required: "Compilare almeno un campo fra cliente, lead o opportunità"
                    },

                    status: {
                        required: "Caricare il documento."
                    }

                }
            } );

            if ( thisForm.valid() ) {

                status.html( "<img src='/assets/main/img/ajax-loading.svg' width='20' height='20'>" );
                const parsedData = viewModel.get( "detailForm.data" );

                // Date-only fields must be sent as "YYYY-MM-DD" strings, not Date objects.
                // JSON.stringify on a Date uses UTC, causing an off-by-one for UTC+ timezones
                // (e.g. local Dec 21 00:00 UTC+1 → "2026-12-20T23:00:00Z" → server stores Dec 20).
                [ "quotationDate", "validityDate", "dataEvasione" ].forEach( function( f ) {
                    var v = parsedData.get( f );
                    if ( v instanceof Date ) { parsedData.set( f, kendo.toString( v, "yyyy-MM-dd" ) ); }
                } );

	                NM.util.ajax( {
                    method: "POST",
                    url: "/manager/ajax/quotations",
                    data: JSON.stringify( parsedData ),
                    callback: {
                        done: function( xhr ) {

                            status.html( "" );
                            AP.widget.notify( "success", "Preventivo salvato correttamente." );

                            if ( viewModel.get( "detailForm.data.id" ) != "" ) {
                                window.location.reload();
                            } else {
                                window.location.href = "/manager/quotations/" + xhr.data.payload.id;
                            }
                        }
                    }
                } );
            }

            return false;
        },

    } );

    function applyShippingProfile(p) {
        p = p || {};
        viewModel.set("detailForm.data.shippingProfile.id", p.id || "");
        viewModel.set("detailForm.data.shippingProfile.name", p.name || "");
        viewModel.set("detailForm.data.shippingProfile.shortId", p.shortId || "");
        viewModel.set("detailForm.data.shippingProfile.street", p.street || "");
        viewModel.set("detailForm.data.shippingProfile.city", p.city || "");
        viewModel.set("detailForm.data.shippingProfile.postalCode", p.postalCode || "");
        viewModel.set("detailForm.data.shippingProfile.state", p.state || "");
        viewModel.set("detailForm.data.shippingProfile.country", p.country || { id: "", isoCode: "" });
        // Direct jQuery for guaranteed display update (MVVM nested binding doesn't fire after bulk set)
        $("#sp-street").val(p.street || "");
        $("#sp-city").val(p.city || "");
        $("#sp-postal-code").val(p.postalCode || "");
        $("#sp-country-iso").val(countryDisplay(p.country));
        $("#sp-state").val(p.state || "");
    }

    function clearAgentiFrom(n) {
        for (var i = n; i <= 5; i++) {
            viewModel.set("detailForm.data.agente" + i, null);
            viewModel.set("detailForm.data.commission" + i, null);
        }
    }

    function syncAgentiEnabled() {
        for (var i = 2; i <= 5; i++) {
            var prev = viewModel.get("detailForm.data.agente" + (i - 1));
            var prevId = prev ? (typeof prev === "object" ? prev.id : prev) : "";
            var enabled = !!(prevId && prevId !== "");
            viewModel.set("agente" + i + "Enabled", enabled);
            $("#agente-commission-" + i).prop("disabled", !enabled);
        }
    }

    // Pagamento 26 SCADENZE DA IMPUTARE: solo con questo si mostra ( e si salva ) la modalità di pagamento.
    var PAYMENT_SCADENZE_DA_IMPUTARE = "26";

    // Flag semplice e non binding calcolato: il bulk set di detailForm.data al caricamento
    // non scatena il change di detailForm.data.paymentMethod.
    function syncCustomPaymentMethod() {
        var pm = viewModel.get( "detailForm.data.paymentMethod" );
        var pmId = pm ? ( typeof pm === "object" ? pm.id : pm ) : "";
        viewModel.set( "showCustomPaymentMethod", String( pmId ) === PAYMENT_SCADENZE_DA_IMPUTARE );
    }

    // Fatture soggette a reclamo ( copia locale di Verticale ): [ { anno, numero, alfa } ]
    var claimInvoices = [];
    var claimRefreshing = false;

    function claimValue( field ) {
        var v = viewModel.get( "detailForm.data." + field );
        return v === null || v === undefined ? "" : String( v );
    }

    function uniqueValues( list ) {
        return list.filter( function( v, i ) { return list.indexOf( v ) === i; } );
    }

    // Ricostruisce le tendine anno -> numero -> alfa e riallinea i valori scelti.
    // Imperativo e non con binding calcolati: il bulk set di detailForm.data al caricamento
    // non scatena i change annidati. La fattura già salvata resta selezionabile anche se
    // nel frattempo è stata saldata ( non è più fra quelle con partita aperta ).
    function refreshClaimLists() {
        if ( claimRefreshing ) return;
        claimRefreshing = true;

        var anno = claimValue( "reclamoAnno" );
        var numero = claimValue( "reclamoNumero" );
        var alfa = claimValue( "reclamoAlfa" );

        var rows = claimInvoices.map( function( r ) {
            return { anno: String( r.anno ), numero: String( r.numero ), alfa: r.alfa || "" };
        } );
        if ( anno && numero && !rows.some( function( r ) { return r.anno === anno && r.numero === numero && r.alfa === alfa; } ) ) {
            rows.push( { anno: anno, numero: numero, alfa: alfa } );
        }

        var anni = uniqueValues( rows.map( function( r ) { return r.anno; } ) ).sort().reverse();
        if ( anno && anni.indexOf( anno ) < 0 ) anno = "";

        var numeri = uniqueValues( rows.filter( function( r ) { return anno && r.anno === anno; } )
            .map( function( r ) { return r.numero; } ) )
            .sort( function( a, b ) { return Number( b ) - Number( a ); } );
        if ( numero && numeri.indexOf( numero ) < 0 ) numero = "";

        var alfas = uniqueValues( rows.filter( function( r ) { return numero && r.anno === anno && r.numero === numero; } )
            .map( function( r ) { return r.alfa; } ) ).sort();
        if ( alfas.indexOf( alfa ) < 0 ) alfa = "";

        viewModel.set( "claimAnni", [ { id: "", name: "-- seleziona" } ].concat( anni.map( function( a ) { return { id: a, name: a }; } ) ) );
        viewModel.set( "claimNumeri", [ { id: "", name: "-- seleziona" } ].concat( numeri.map( function( n ) { return { id: n, name: n }; } ) ) );
        // Alfa vuoto è un valore valido ( "(nessuno)" ) e prende il posto del placeholder,
        // che ha lo stesso id "".
        viewModel.set( "claimAlfa", ( alfas.indexOf( "" ) < 0 ? [ { id: "", name: "-- seleziona" } ] : [] )
            .concat( alfas.map( function( a ) { return { id: a, name: a || "(nessuno)" }; } ) ) );

        viewModel.set( "detailForm.data.reclamoAnno", anno );
        viewModel.set( "detailForm.data.reclamoNumero", numero );
        viewModel.set( "detailForm.data.reclamoAlfa", alfa );

        // Il cambio di source può far scegliere al widget il primo elemento: riallinea.
        [ [ "#qt-claim-anno", anno ], [ "#qt-claim-numero", numero ], [ "#qt-claim-alfa", alfa ] ].forEach( function( pair ) {
            var ddl = $( pair[ 0 ] ).data( "kendoDropDownList" );
            if ( ddl ) ddl.value( pair[ 1 ] );
        } );

        claimRefreshing = false;
    }

    pub.config = function() {
        return viewModel.get( "detailForm.data" );
    };

    pub.edit = function( id, onsSave ) {
        NM.util.openModal( $( "#quotation-header-modal" ) );

        // var status = $( "#quotation-header-modal .save-status" );

        AP.loading.show();

        NM.util.ajax( {
            method: "GET",
            url: "/manager/ajax/quotations/" + id,
            callback: {
                done: function( xhr ) {
                    if ( !xhr.data.customer ) {
                        xhr.data.customer = {};
                    }
                    if ( !xhr.data.customer.shippingProfiles ) {
                        xhr.data.customer.shippingProfiles = [];
                    }
                    // Il cliente caricato dal DB non ha displayLabel (lo aggiunge solo lo
                    // schema.parse della ricerca CRM): senza, l'autocomplete Cliente appare vuoto
                    if ( xhr.data.customer.id ) {
                        xhr.data.customer.displayLabel = buildCustomerDisplay( xhr.data.customer );
                        xhr.data.customer.countryLabel = countryDisplay( xhr.data.customer.country );
                    }
                    if ( !xhr.data.shippingProfile ) {
                        xhr.data.shippingProfile = {};
                    }
                    viewModel.set( "detailForm.data", xhr.data );
                    applyShippingProfile( xhr.data.shippingProfile || {} );

                    // Native <input type="date"> requires exactly "YYYY-MM-DD".
                    // Mementify serializes Date beans as "YYYY-MM-DD HH:mm:ss" — reformat here.
                    ["quotationDate", "validityDate", "dataEvasione"].forEach( function( f ) {
                        if ( xhr.data[ f ] ) {
                            var d = kendo.parseDate( xhr.data[ f ] );
                            if ( d ) viewModel.set( "detailForm.data." + f, kendo.toString( d, "yyyy-MM-dd" ) );
                        }
                    } );

                    var loadedIndustry = xhr.data.industry || "";
                    if (loadedIndustry) {
                        var industryMapLoad = {
                            "CAT": "Catena Alberghiera", "HOT": "Hotel", "HO1": "Hotel 1 stella",
                            "HO2": "Hotel 2 stelle", "HO3": "Hotel 3 stelle", "HO4": "Hotel 4 stelle",
                            "HO5": "Hotel 5 stelle", "BEB": "Bed & Breakfast", "RIS": "Ristorante/Bar",
                            "AGR": "Agriturismo", "CAM": "Camping", "AGE": "Agente/Segnalatore",
                            "CLI": "Clinica/Casa di Riposo", "RES": "Residence",
                            "UFF": "Uffici/Centro direzionale", "ARC": "Architetto/Ing.",
                            "CEN": "Centro Congressi/Fiere/Casinò", "CON": "Contract",
                            "RIV": "Rivenditore", "IMC": "Impresa di costruzioni",
                            "COl": "Collegio Professionale", "AZI": "Azienda", "PRO": "Procurement",
                            "COS": "Consultant", "ELE": "Elettricista", "ENT": "Ente Pubblico",
                            "NEG": "Negozio", "AGA": "Agente Apir", "CCR": "Concorrente",
                            "PRI": "Residenziale", "Installatore Elettrico": "Installatore Elettrico",
                            "Tour Operator": "Tour Operator", "Other": "Altro"
                        };
                        viewModel.set("detailForm.data.industryLabel", industryMapLoad[loadedIndustry] || loadedIndustry);
                    }

                    setTimeout( function() {
                        syncAgentiEnabled();
                        refreshClaimLists();
                        syncCustomPaymentMethod();

                        if ( xhr.data.customer.id ) {
                            var customerAc = $( "#qt-customer" ).data( "kendoAutoComplete" );
                            if ( customerAc ) customerAc.value( xhr.data.customer.displayLabel );
                        }

                        // Fix DropDownList display in edit mode.
                        // Items loaded from DB don't have displayName (only CRM schema.parse adds it).
                        var savedSp = xhr.data.shippingProfile;
                        var spDdl = $( "#qt-shipping-profile" ).data( "kendoDropDownList" );
                        if ( spDdl && savedSp && savedSp.name ) {
                            var spItems = spDdl.dataSource.data();
                            if ( spItems.length > 0 ) {
                                spItems.forEach( function( item ) {
                                    if ( !item.displayName ) {
                                        item.set( "displayName", item.name + ( item.shortId ? " - " + item.shortId : "" ) );
                                    }
                                } );
                                if ( savedSp.shortId ) spDdl.value( savedSp.shortId );
                                spDdl.refresh();
                            } else {
                                var spKey = savedSp.shortId || savedSp.id || "saved";
                                var spDisplay = savedSp.name + ( savedSp.shortId ? " - " + savedSp.shortId : "" );
                                spDdl.dataSource.add( { shortId: spKey, name: savedSp.name, displayName: spDisplay } );
                                spDdl.value( spKey );
                            }
                        }

                        if ( !AP.page.canEdit ) {
                            var $form = $( '#quotation-header-form' );
                            $form.find( 'input:not([type=hidden]), textarea' ).prop( 'readonly', true );
                            $form.find( 'select' ).each( function() {
                                var ddl = $( this ).data( 'kendoDropDownList' );
                                if ( ddl ) { ddl.enable( false ); } else { $( this ).prop( 'disabled', true ); }
                            } );
                        }
                        AP.loading.hide();
                    }, 1000 );

                }
            }
        } );

        // $( "#quotationNameInput" ).prop( "readonly", true );
        $( "#quotationNumberInput" ).prop( "readonly", true );
        $( "#nav-general-tab" ).trigger( "click" );
    };

    pub.init = function() {

        kendo.bind( fields.headerRoot, viewModel );

        setTimeout(function() {
            var ddl = $("#qt-shipping-profile").data("kendoDropDownList");
            if (ddl) {
                ddl.bind("change", function() {
                    var item = this.dataItem();
                    if (item) applyShippingProfile(item.toJSON ? item.toJSON() : item);
                });
            }
        }, 0);

        viewModel.get( "languages" ).data( AP.page.languages );
        viewModel.get( "statuses" ).data( AP.page.statuses );
        viewModel.get( "paymentMethods" ).data( AP.page.paymentMethods );
        viewModel.get( "currencies" ).data( AP.page.currencies );
        viewModel.get( "countries" ).data( AP.page.countries );
        viewModel.get( "states" ).data( AP.page.states );
        viewModel.get( "vatCodes" ).data( AP.page.vatCodes );

        AP.page.saleUsers.unshift( { "id": "", "name": "-- seleziona" } );

        viewModel.get( "saleUsers" ).data( AP.page.saleUsers );

        AP.page.techUsers.unshift( { "id": "", "name": "-- seleziona" } );

        viewModel.get( "techUsers" ).data( AP.page.techUsers );

        $( "#nav-status-tab" ).on( "click", function( event ) {
            $( "#nav-actual-tab" ).trigger( "click" );
        } );

		NM.util.ajax( {
			method: "GET",
			url: "/manager/ajax/accounts?hasAgenteVerticale=true",
			callback: {
				done: function( xhr ) {
					xhr.data.unshift( { id: "", name: "-- seleziona" } );
					viewModel.set( "agentiList", xhr.data );
					setTimeout( syncAgentiEnabled, 0 );
				},
			},
		} );

		NM.util.ajax( {
			method: "GET",
			url: "/manager/ajax/verticale/claim-invoices",
			callback: {
				done: function( xhr ) {
					claimInvoices = xhr.data || [];
					refreshClaimLists();
				},
			},
		} );

		viewModel.bind("change", function(e) {

			if ( e.field === "detailForm.data.paymentMethod" ) {
				syncCustomPaymentMethod();
			}

			// Cambiando un campo del reclamo si puliscono quelli sotto ( anno -> numero -> alfa ).
			if ( !claimRefreshing && ( e.field === "detailForm.data.reclamoAnno" || e.field === "detailForm.data.reclamoNumero" ) ) {
				claimRefreshing = true;
				if ( e.field === "detailForm.data.reclamoAnno" ) viewModel.set( "detailForm.data.reclamoNumero", "" );
				viewModel.set( "detailForm.data.reclamoAlfa", "" );
				claimRefreshing = false;
				refreshClaimLists();
			}

			if (e.field === "detailForm.data.customer") {
				var customer = viewModel.get("detailForm.data.customer");
				if (customer && typeof customer === "object") {
					viewModel.set("detailForm.data.customer.countryLabel", countryDisplay(customer.country));
				}
				var lingua = customer && typeof customer === "object" ? customer.lingua : null;
				if (lingua) {
					var lang = AP.page.languages.find(function(l) { return l.id === lingua; });
					if (lang) {
						viewModel.set("detailForm.data.lang", lang);
					}
					var vatCodeId = lingua === "IT" ? 201 : 15;
					var vatCode = AP.page.vatCodes.find(function(v) { return v.id == vatCodeId; });
					if (vatCode) {
						viewModel.set("detailForm.data.vatCode", vatCode);
					}
				}
				var accountType = customer && typeof customer === "object" ? customer.accountType : null;
				viewModel.set("detailForm.data.customerType", accountType || "");
				var industry = customer && typeof customer === "object" ? customer.industry : null;
				viewModel.set("detailForm.data.industry", industry || "");
				var industryMap = {
					"CAT": "Catena Alberghiera", "HOT": "Hotel", "HO1": "Hotel 1 stella",
					"HO2": "Hotel 2 stelle", "HO3": "Hotel 3 stelle", "HO4": "Hotel 4 stelle",
					"HO5": "Hotel 5 stelle", "BEB": "Bed & Breakfast", "RIS": "Ristorante/Bar",
					"AGR": "Agriturismo", "CAM": "Camping", "AGE": "Agente/Segnalatore",
					"CLI": "Clinica/Casa di Riposo", "RES": "Residence",
					"UFF": "Uffici/Centro direzionale", "ARC": "Architetto/Ing.",
					"CEN": "Centro Congressi/Fiere/Casinò", "CON": "Contract",
					"RIV": "Rivenditore", "IMC": "Impresa di costruzioni",
					"COl": "Collegio Professionale", "AZI": "Azienda", "PRO": "Procurement",
					"COS": "Consultant", "ELE": "Elettricista", "ENT": "Ente Pubblico",
					"NEG": "Negozio", "AGA": "Agente Apir", "CCR": "Concorrente",
					"PRI": "Residenziale", "Installatore Elettrico": "Installatore Elettrico",
					"Tour Operator": "Tour Operator", "Other": "Altro"
				};
				viewModel.set("detailForm.data.industryLabel", industry ? (industryMap[industry] || industry) : "");
				var sdi = customer && typeof customer === "object" ? (customer.SDI || "") : "";
				viewModel.set("detailForm.data.codiceSdi", sdi);
				var profiles = customer && typeof customer === "object" ? (customer.shippingProfiles || []) : [];
				applyShippingProfile(profiles.length > 0 ? profiles[0] : {});
				setTimeout(function() {
					var ddl = $("#qt-shipping-profile").data("kendoDropDownList");
					if (ddl) ddl.value(profiles.length > 0 ? profiles[0].shortId : "");
				}, 0);
				if (customer && typeof customer === "object" && customer.id) {
					var ac = $( "#qt-customer" ).data( "kendoAutoComplete" );
					if (ac) ac.value( buildCustomerDisplay( customer ) );
				}
			}

			if (e.field === "detailForm.data.nessunAgente") {
				if (viewModel.get("detailForm.data.nessunAgente") == true) {
					clearAgentiFrom(1);
				}
				syncAgentiEnabled();
			}

			if (e.field === "detailForm.data.agente1") {
				var a = viewModel.get("detailForm.data.agente1");
				if (!a || !a.id) clearAgentiFrom(2);
				syncAgentiEnabled();
			}

			if (e.field === "detailForm.data.agente2") {
				var a = viewModel.get("detailForm.data.agente2");
				if (!a || !a.id) clearAgentiFrom(3);
				syncAgentiEnabled();
			}

			if (e.field === "detailForm.data.agente3") {
				var a = viewModel.get("detailForm.data.agente3");
				if (!a || !a.id) clearAgentiFrom(4);
				syncAgentiEnabled();
			}

			if (e.field === "detailForm.data.agente4") {
				var a = viewModel.get("detailForm.data.agente4");
				if (!a || !a.id) clearAgentiFrom(5);
				syncAgentiEnabled();
			}
		});
    };

    return pub;
} () );

