AP.namespace( "quotation" );

Object.assign( AP.quotation.fields, {
    /* boxItemPricing: $( "#quotation-item-pricing-box" ), */
    boxTotalPricing: $( "#quotation-total-pricing-box" ),
} );

AP.quotation.itemPricing = ( function() {

    var pub = {};
    var fields = AP.quotation.fields;

    var defaultForm = {
        data: {
            id: "",
            quantity: 1,
            discount1: "",
            discount2: "",
            method: {
                id: "C", // calculated,
                name: "Calcolato"
            },
            lines: [], // es. { name: "Frutto 1", amount: 10.5 },
            total: 0,
        },
        priceTypes: [
            { id: "C", name: "Calcolato" },
            { id: "F", name: "Fisso" },
        ],
    };

    var getItem = function() {

        var result = {};

        var type = viewModel.get( "typeId" );

        if ( type == "plate" ) {
            result = AP.plate.modal.getItem();
            // result = data.data; // plate
        }

        if ( type == "signage" ) {
            result = AP.signage.modal.getItem();
        }

        if ( type == "accessory" ) {
            result = AP.accessory.modal.getItem();
        }

        return result;

    };

    var viewModel = kendo.observable( {

        pricing: defaultForm,
        typeId: undefined, // plate, signage, accessory

        changeMethod: function( event ) {
            var value = event.sender.value();
            if ( value == "C" ) {
                viewModel.set( "pricing.data.total", 0 );
                $( "[name=\"discount1\"]" ).prop( "disabled", false );
                $( "[name=\"discount2\"]" ).prop( "disabled", false );
                viewModel.set("pricing.isTotalEnabled", false);
                this.update();
            } else {
                // a prezzo fisso gli sconti restano: si applicano all'importo inserito
                viewModel.set( "pricing.data.lines", [] );
                viewModel.set( "pricing.data.total", 0 );
                viewModel.set("pricing.isTotalEnabled", true);
            }

        },

        update: function( event ) {
            if ( viewModel.get( "pricing.data.method.id" ) == "F" ) {
                AP.widget.notify( "warning", "Hai selezionato Prezzo Fisso." );
                return false;
            }
            AP.loading.show();
            var payload = {};

            var typeId = viewModel.get( "typeId" );

            if ( typeId == "plate" ) {
                payload.item = getItem();
                payload.price = viewModel.get( "pricing.data" );
            } else {
                payload = getItem();
                payload.quotationItem.price.discount1 = viewModel.get( "pricing.data.discount1" );
                payload.quotationItem.price.discount2 = viewModel.get( "pricing.data.discount2" );
                payload.quotationItem.price.total     = viewModel.get( "pricing.data.total" );
                payload.quotationItem.price.method    = viewModel.get( "pricing.data.method" );
            }
            payload.quotationId = AP.page.quotation.id;

            const url = "/manager/ajax/quotation-items/type/" + typeId + "/pricing";

            NM.util.ajax( {
                method: "POST",
                url: url,
                data: JSON.stringify( payload ),
                callback: {
                    done: function( xhr ) {
                        // validazione lato server (es. nessun prodotto per la combinazione scelta)
                        if ( xhr.status === "INVALID" ) {
                            AP.loading.hide();
                            NM.form.showMessages( xhr.data );
                            return;
                        }
                        if ( xhr.data ) {
                            AP.loading.hide();
                            viewModel.set( "pricing.data", xhr.data );
                            const actualTotal = xhr.data.totalGoods;
                            const totalDiscounted1 = actualTotal - (actualTotal * viewModel.get( "pricing.data.discount1" ) / 100);
                            const totalDiscounted2 = totalDiscounted1 - (totalDiscounted1 * viewModel.get( "pricing.data.discount2" ) / 100);
                            viewModel.set( "pricing.data.total", Number( totalDiscounted2 ).toFixed( 2 ) );
                        }
                    }
                }
            } );

            return false;

        },

    } );


    pub.update = function() {

    	viewModel.update();
    };

    pub.init = function( typeId, data ) { // type: plate, signage, accessory

        var elementId = $( "#" + typeId + "-quotation-item-pricing-box" );

        kendo.bind( elementId, viewModel );

        viewModel.set( "typeId", typeId );

        $( "[name=\"discount1\"]" ).prop( "disabled", false );
        $( "[name=\"discount2\"]" ).prop( "disabled", false );

        if ( data ) {
            // a prezzo fisso il campo Totale è l'importo pieno (amount), non il totale scontato
            if ( data.data.method.id == "F" && data.data.amount != null ) {
                data.data.total = data.data.amount;
            }
            if (data.data.method.id == "C") {
                viewModel.set("pricing.isTotalEnabled", false);
            } else {
                viewModel.set("pricing.isTotalEnabled", true);
            }
            viewModel.set( "pricing", data );
        } else {
            viewModel.set( "pricing", defaultForm );
            viewModel.set("pricing.isTotalEnabled", false);
        }

    };

    pub.getData = function( itemId ) {

        return viewModel.get( "pricing" );

    };

    return pub;
} () );

AP.quotation.totalPricing = ( function() {

    var pub = {};
    var fields = AP.quotation.fields;

    var isCollapsed = AP.getUserPref( "quotation.totalPricing.isBoxCollapsed", false );

    var collapseBox = function() {

        var status = viewModel.get( "detail.isCollapsed" );
        var newStatus = !status;

        viewModel.set( "detail.isCollapsed", newStatus );

        var newSymbol = newStatus ? "▲" : "▼";
        viewModel.set( "detail.symbol", newSymbol );

        const totalsBox = $('#quotation-total-pricing-box')
        if (newStatus) {
            totalsBox.addClass('collapsed')
        } else {
            totalsBox.removeClass('collapsed')
        }

        AP.setUserPref( "quotation.totalPricing.isBoxCollapsed", newStatus );

        return false;

    };

    var priceDirty = false;

    var markDirty = function() {
        priceDirty = true;
        $( "#qt-concludi-btn" ).prop( "disabled", true );
    };

    var markClean = function() {
        priceDirty = false;
        $( "#qt-concludi-btn" ).prop( "disabled", false );
    };

    var fetchTotals = function( payload, method ) {

        var status = $( "#quotation-totals-general-loading" );
        status.html( "<img src='/assets/main/img/ajax-loading-blu.svg' width=20 height=20>" );

        NM.util.ajax( {
            method: method,
            url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/totals",
            data: JSON.stringify( payload ),
            callback: {
                done: function( xhr ) {

                    status.html( "" );

                    viewModel.set( "pricing.counters", xhr.data.counters );
                    viewModel.set( "pricing.data", xhr.data.pricing );

                    if ( method === "POST" ) {
                        markClean();
                    }
                }
            }
        } );

    };


    var viewModel = kendo.observable( {
        showCosts: AP.getUserPref( "showCosts" ),
        canEdit: AP.page.canEdit,
        canSee: AP.page.canSee,
        detail: {
            title: "",
            isCollapsed: isCollapsed,
            symbol: isCollapsed ? "▲" : "▼",
        },

        pricing: {
            counters: {
                plates: 0,
                signages: 0,
                accessories: 0
            },
            data: {
                discount1: "",
                discount2: "",

                method: {
                    id: "C" // calculated
                },

                shippingCost: 0,
                noteTrasporto: "",
                totalGoods: 0,
                total: 0
            },
        },

        getFormattedTotal: function() {

            var value = this.get( "pricing.data.total" );
            return value;

        },

        init: function( event ) {

            var status = $( "#quotation-totals-general-loading" );
            status.html( "<img src='/assets/main/img/ajax-loading-blu.svg' width=20 height=20>" );

            NM.util.ajax( {
                method: "GET",
                url: "/manager/ajax/quotations/" + AP.page.quotation.id + "/totals",
                callback: {
                    done: function( xhr ) {

                        status.html( "" );

                        viewModel.set( "pricing.counters", xhr.data.counters );
                        viewModel.set( "pricing.data", xhr.data.pricing );
                    }
                }
            } );

        },

        updateTotals: function( event ) {
            var pricing = viewModel.get( "pricing.data" );
            fetchTotals( pricing, "POST" );
        },

        getTotals: function( event ) {
            fetchTotals( undefined, "GET" );
            return ( viewModel.get( "pricing.data" ) );
        },

        collapseTotals: function() {
            collapseBox();
        }

    } );

    pub.updateTotals = function() {
    	viewModel.updateTotals();
    };

    pub.getTotals = function() {
    	return viewModel.getTotals();
    };

    pub.markDirty = markDirty;
    pub.markClean = markClean;

    pub.init = function() { // type: item, quotation

        kendo.bind( fields.boxTotalPricing, viewModel );
        kendo.culture( "it-IT" );

        viewModel.set( "detail.title", "Totali preventivo" );

        $(document).on("click", "#toggle-costs-link", function () {
            viewModel.set("showCosts", AP.getUserPref("showCosts"));
        });

        if (viewModel.get( "detail.isCollapsed" )) {
            fields.boxTotalPricing.addClass('collapsed')
        } else {
            fields.boxTotalPricing.removeClass('collapsed')
        }

        fields.boxTotalPricing.show();

        // Dirty quando l'utente cambia sconti, spedizione o sconto incondizionato
        // senza aver ancora cliccato "Salva". Pulito solo dopo il POST riuscito.
        fields.boxTotalPricing.on(
            "input change",
            "input[name='discount1'], input[name='discount2'], input[name='shippingCost'], input[name='noteTrasporto'], input[name='flatDiscount']",
            markDirty
        );

    };

    pub.getData = function( itemId ) {

        // var model = getCurrentViewModel();
        return viewModel.get( "pricing" );

    };

    return pub;
} () );