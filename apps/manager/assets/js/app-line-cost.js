AP.namespace( "lineCost" );

Object.assign( AP.lineCost.fields, {
    listRoot: $( "#line-cost-list-root" ),
    detailRoot: $( "#line-cost-modal-root" ),
    detailRoot: $( "#line-cost-grid-form" ),
} );

$( document ).ready( function() {
    if ( AP.lineCost.fields.listRoot.length ) {
        AP.lineCost.list.init();
    }
} );

AP.lineCost.list = ( function() {
    var pub = {};

    var dataSources = {
        items: NM.kendo.dataSource( { url: "/manager/ajax/lines_costs" } ),
    };

    var emptyItem = function() {
        return { "id": "", "name": "" };
    };

    // Linee della categoria ( AP.page.lines ha le categorie di ogni linea )
    var linesOfCategory = function( categoryId ) {
        if ( !categoryId ) return [];
        return AP.page.lines.filter( function( line ) {
            return line.categories.some( cat => cat.id == categoryId );
        } );
    };

    // Solo le finiture che hanno prodotti della categoria e linea scelte
    // ( stesso endpoint dei configuratori, che legge da catalog_bundles )
    var loadFinishesInto = function( dataSource, categoryId, lineId ) {
        dataSource.data( [] );
        if ( !categoryId || !lineId ) return;

        NM.util.ajax( {
            method: "GET",
            url: "/manager/ajax/quotations/finishes/" + encodeURIComponent( categoryId ) + "/" + encodeURIComponent( lineId ),
            callback: {
                done: function( xhr ) {
                    dataSource.data( xhr.data || [] );
                }
            },
        } );
    };

    var viewModel = kendo.observable( {
        rows: dataSources.items,
        categories: AP.page.categories,

        // dialog "Aggiungi costo"
        category: emptyItem(),
        lines: new kendo.data.DataSource(),
        line: emptyItem(),
        finishes: new kendo.data.DataSource(),
        finish: emptyItem(),

        // filtri di ricerca
        selectedCategory: emptyItem(),
        searchLines: new kendo.data.DataSource(),
        selectedLine: emptyItem(),
        searchFinishes: new kendo.data.DataSource(),
        selectedFinish: emptyItem(),

        loadLines: function() {
            this.get( "lines" ).data( linesOfCategory( this.get( "category.id" ) ) );
            this.set( "line", emptyItem() );
            this.loadFinishes();
        },

        loadFinishes: function() {
            this.set( "finish", emptyItem() );
            loadFinishesInto( this.get( "finishes" ), this.get( "category.id" ), this.get( "line.id" ) );
        },

        loadSearchLines: function() {
            this.get( "searchLines" ).data( linesOfCategory( this.get( "selectedCategory.id" ) ) );
            this.set( "selectedLine", emptyItem() );
            this.loadSearchFinishes();
        },

        loadSearchFinishes: function() {
            this.set( "selectedFinish", emptyItem() );
            loadFinishesInto( this.get( "searchFinishes" ), this.get( "selectedCategory.id" ), this.get( "selectedLine.id" ) );
        },

        search: function( event ) {
            const data = $('#line-cost-search-form').serializeArray();
            let parsedData = {};
            data.forEach(function (row) {
                parsedData[row.name] = row.value
            })

            viewModel.rows.read( parsedData );

            return false;
        },

        create: function( event ) {
            const data = $('#line-cost-add-form').serializeArray();
            let parsedData = {};
            data.forEach(function (row) {
                parsedData[row.name] = row.value
            })
            parsedData.id = null
            if (!parsedData.categoryId || !parsedData.lineId || !parsedData.finishId || !parsedData.cost) {
                AP.widget.notify( "error", "Compilare tutti i campi." )
                return false
            }

            AP.loading.show()
            NM.util.ajax( {
                method: "POST",
                url: "/manager/ajax/lines_costs",
                data: JSON.stringify(parsedData),
                callback: {
                    always: function(xhr) {
                        if (xhr.status && xhr.status == 'ERROR') {
                            AP.widget.notify( "error", "Non è possibile assegnare questo costo fisso. " + xhr.message );
                            AP.loading.hide()
                        } else {
                            $('#line-cost-add-form')[0].reset();
                            if (xhr.status && xhr.status == 'SUCCESS') {
                                var modal = bootstrap.Modal.getInstance(
                                    document.getElementById('lineCostAddModal')
                                );
                                modal.hide();
                            }
                            if (xhr.status || xhr.status != 'ERROR') {
                                AP.widget.notify( "success", "Costo Linea/Finitura creato correttamente." );
                                setTimeout( () => {
                                    window.location.reload()
                                }, 500 );
                            }
                        }
                    }
                },
            } );

            return false;
        },

        update: function( event ) {
            AP.loading.show()
            const id = event.data.id
            const categoryId = event.data.category.id
            const lineId = event.data.line.id
            const finishId = event.data.finish.id
            const cost = event.data.cost
            
            if (!cost || cost == 0) {
                AP.widget.notify( "error", "Compilare tutti i campi." )
                return false
            }

            parsedData = {
                "id": id,
                "categoryId": categoryId,
                "lineId": lineId,
                "finishId": finishId,
                "cost": cost
            }

            AP.loading.show()
            NM.util.ajax( {
                method: "POST",
                url: "/manager/ajax/lines_costs",
                data: JSON.stringify(parsedData),
                callback: {
                    always: function(xhr) {
                        if (xhr.status && xhr.status == 'ERROR') {
                            AP.widget.notify( "error", "Non è possibile aggiornare questo costo fisso. " + xhr.message );
                        }
                        if (xhr.status || xhr.status != 'ERROR') {
                            AP.widget.notify( "success", "Costo Linea/Finitura aggiornato correttamente." );
                        }
                        AP.loading.hide()
                    }
                },
            } );

            return false;
        },

        delete: function( event ) {
            AP.loading.show()
            const id = event.data.id

            parsedData = {
                "id": id
            }

            AP.loading.show()
            NM.util.ajax( {
                method: "DELETE",
                url: "/manager/ajax/lines_costs",
                data: JSON.stringify(parsedData),
                callback: {
                    always: function(xhr) {
                        if (xhr.status && xhr.status == 'ERROR') {
                            AP.widget.notify( "error", "Non è possibile cancellare questo costo fisso. " + xhr.message );
                        }
                        if (xhr.status || xhr.status != 'ERROR') {
                            AP.widget.notify( "success", "Costo Linea/Finitura cancellato correttamente." );
                            setTimeout( () => {
                                window.location.reload()
                            }, 500 );
                        }
                        AP.loading.hide()
                    }
                },
            } );

            return false;
        },

    } );

    pub.init = function() {
        kendo.bind( AP.lineCost.fields.listRoot, viewModel );
    };

    return pub;
} () );
