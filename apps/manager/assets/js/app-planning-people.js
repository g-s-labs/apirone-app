AP.namespace( "planningPeople" );

/**
 * Disponibilità persone per la pianificazione ( Gantt ): tipo di lavoro e ore
 * da lunedì a domenica per ogni utente, festivi di San Marino e chiusure
 * aziendali. Ogni modifica di una riga si salva subito.
 */
AP.planningPeople = ( function() {

    const BASE = "/manager/ajax/planning";

    const pub = {};

    function ajax( options ) {
        return new Promise( function( resolve ) {
            NM.util.ajax( Object.assign( {}, options, {
                callback: {
                    done: function( xhr ) {
                        if ( xhr.status === "ERROR" ) {
                            AP.widget.notify( "error", ( xhr.data && xhr.data.message ) || "Operazione non riuscita." );
                            resolve( null );
                            return;
                        }
                        resolve( xhr );
                    }
                }
            } ) );
        } );
    }

    pub.init = function() {
        new Vue( {
            el: "#planning-people-app",

            data: {
                tab: "people",
                workTypes: AP.page.workTypes || [],
                defaultHours: AP.page.defaultHours || [ 8, 8, 8, 8, 8, 0, 0 ],
                dayNames: [ "Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom" ],
                // inizio giornata: passi di 30 minuti
                timeOptions: ( function() {
                    const options = [];
                    for ( let minutes = 0; minutes < 24 * 60; minutes += 30 ) {
                        options.push( String( Math.floor( minutes / 60 ) ).padStart( 2, "0" ) + ":" + String( minutes % 60 ).padStart( 2, "0" ) );
                    }
                    return options;
                }() ),
                people: [],
                filters: { str: "", workTypeId: "" },
                newPerson: { open: false, name: "", workTypeIds: [ "MON" ] },

                year: new Date().getFullYear(),
                holidays: [],
                closures: [],
                newClosure: { day: "", description: "" },

                // storico dei costi orari della persona aperta nella modale
                today: ( function() { const d = new Date(); return d.getFullYear() + "-" + String( d.getMonth() + 1 ).padStart( 2, "0" ) + "-" + String( d.getDate() ).padStart( 2, "0" ); }() ),
                costEditor: { person: null, costs: [], form: { validFrom: "", hourlyCost: "" } },
            },

            computed: {
                filteredPeople: function() {
                    const str = this.filters.str.trim().toLowerCase();
                    const typeId = this.filters.workTypeId;

                    return this.people.filter( function( person ) {
                        if ( str && person.name.toLowerCase().indexOf( str ) === -1 ) return false;
                        if ( typeId === "_none" ) return !person.workTypeIds.length;
                        if ( typeId ) return person.workTypeIds.indexOf( typeId ) !== -1;
                        return true;
                    } );
                },
            },

            mounted: function() {
                this.loadPeople();
                this.loadCalendar();
            },

            methods: {
                loadPeople: async function() {
                    const xhr = await ajax( { method: "GET", url: BASE + "/people" } );
                    if ( !xhr ) return;
                    this.people = xhr.data.map( function( person ) {
                        return Object.assign( person, { saving: false, saved: false } );
                    } );
                },

                weekTotal: function( person ) {
                    const total = person.hours.reduce( function( sum, value ) { return sum + ( Number( value ) || 0 ); }, 0 );
                    return Math.round( total * 100 ) / 100;
                },

                // si pianifica chi ha almeno una tipologia
                planned: function( person ) {
                    return person.workTypeIds.length > 0;
                },

                // attiva / toglie una tipologia dall'elenco ( persona o nuova persona )
                toggleType: function( ids, typeId ) {
                    const index = ids.indexOf( typeId );
                    if ( index === -1 ) ids.push( typeId ); else ids.splice( index, 1 );
                },

                chipStyle: function( type, ids ) {
                    return ids.indexOf( type.id ) !== -1 ? { backgroundColor: type.color, borderColor: type.color } : {};
                },

                // Tipologie assegnate a chi non ha ancora ore: si parte da 8h lun-ven
                changeType: function( person ) {
                    if ( this.planned( person ) && this.weekTotal( person ) === 0 ) {
                        person.hours = this.defaultHours.slice();
                    }
                    this.save( person );
                },

                save: async function( person ) {
                    person.saving = true;
                    person.saved = false;

                    const xhr = await ajax( {
                        method: "POST",
                        url: BASE + "/people/" + person.id,
                        loading: false, // salvataggio di una riga: niente spinner a tutta pagina
                        data: JSON.stringify( {
                            workTypeIds: person.workTypeIds,
                            hours: person.hours.map( function( value ) { return Number( value ) || 0; } ),
                            dayStart: person.dayStart,
                        } ),
                    } );

                    person.saving = false;
                    if ( xhr ) {
                        person.saved = true;
                        setTimeout( function() { person.saved = false; }, 1500 );
                    }
                },

                openNewPerson: function() {
                    this.tab = "people";
                    this.newPerson = { open: true, name: "", workTypeIds: [ "MON" ] };
                    this.$nextTick( () => { this.$refs.newPersonName && this.$refs.newPersonName.focus(); } );
                },

                createPerson: async function() {
                    if ( !this.newPerson.name.trim() ) return;

                    const xhr = await ajax( {
                        method: "POST",
                        url: BASE + "/people",
                        data: JSON.stringify( { name: this.newPerson.name.trim(), workTypeIds: this.newPerson.workTypeIds } ),
                    } );
                    if ( !xhr ) return;

                    AP.widget.notify( "success", xhr.data.message );
                    this.newPerson.open = false;
                    await this.loadPeople();
                },

                /* ---------- costi orari ---------- */

                openCosts: function( person ) {
                    this.costEditor = { person: person, costs: [], form: { validFrom: this.today, hourlyCost: "" } };
                    this.loadCosts();
                    NM.util.openModal( $( "#planning-costs-modal" ) );
                },

                loadCosts: async function() {
                    const xhr = await ajax( { method: "GET", url: BASE + "/people/" + this.costEditor.person.id + "/costs" } );
                    if ( xhr ) this.applyCosts( xhr.data || [] );
                },

                // storico aggiornato: anche la colonna "Costo orario" mostra quello in vigore
                applyCosts: function( costs ) {
                    this.costEditor.costs = costs;
                    const current = costs.find( function( cost ) { return cost.current; } );
                    this.costEditor.person.hourlyCost = current ? current.hourlyCost : "";
                    this.costEditor.person.costValidFrom = current ? current.validFrom : "";
                },

                addCost: async function() {
                    const form = this.costEditor.form;
                    if ( !form.validFrom || form.hourlyCost === "" ) return;

                    const xhr = await ajax( {
                        method: "POST",
                        url: BASE + "/people/" + this.costEditor.person.id + "/costs",
                        data: JSON.stringify( { validFrom: form.validFrom, hourlyCost: form.hourlyCost } ),
                    } );
                    if ( !xhr ) return;

                    this.applyCosts( xhr.data.costs || [] );
                    this.costEditor.form = { validFrom: this.today, hourlyCost: "" };
                },

                deleteCost: async function( cost ) {
                    const xhr = await ajax( { method: "DELETE", url: BASE + "/costs/" + cost.id } );
                    if ( xhr ) this.loadCosts();
                },

                formatMoney: function( value ) {
                    return ( Number( value ) || 0 ).toLocaleString( "it-IT", { style: "currency", currency: "EUR" } );
                },

                formatDate: function( isoDay ) {
                    if ( !isoDay ) return "";
                    const parts = isoDay.split( "-" );
                    return parts[ 2 ] + "/" + parts[ 1 ] + "/" + parts[ 0 ];
                },

                /* ---------- festivi e chiusure ---------- */

                loadCalendar: async function() {
                    const xhr = await ajax( { method: "GET", url: BASE + "/closures?year=" + this.year } );
                    if ( !xhr ) return;

                    const holidays = xhr.data.holidays || {};
                    this.holidays = Object.keys( holidays ).sort().map( function( day ) {
                        return { day: day, name: holidays[ day ] };
                    } );
                    this.closures = xhr.data.closures || [];
                },

                changeYear: function( delta ) {
                    this.year += delta;
                    this.loadCalendar();
                },

                addClosure: async function() {
                    if ( !this.newClosure.day ) return;

                    const xhr = await ajax( {
                        method: "POST",
                        url: BASE + "/closures",
                        data: JSON.stringify( this.newClosure ),
                    } );
                    if ( !xhr ) return;

                    this.newClosure = { day: "", description: "" };
                    this.loadCalendar();
                },

                deleteClosure: async function( closure ) {
                    const xhr = await ajax( { method: "DELETE", url: BASE + "/closures/" + closure.id } );
                    if ( xhr ) this.loadCalendar();
                },

                formatDay: function( isoDay ) {
                    const parts = isoDay.split( "-" );
                    const date = new Date( Number( parts[ 0 ] ), Number( parts[ 1 ] ) - 1, Number( parts[ 2 ] ) );
                    return date.toLocaleDateString( "it-IT", { weekday: "short", day: "2-digit", month: "2-digit" } );
                },
            },
        } );
    };

    return pub;
}() );

$( document ).ready( function() {
    if ( document.getElementById( "planning-people-app" ) ) {
        AP.planningPeople.init();
    }
} );
