AP.namespace( "planningStats" );

/**
 * Statistiche dei progetti: costo ( ore pianificate × costo orario in vigore
 * quel giorno, PlanningService.projectStats ) rispetto al budget delle attività.
 * Una riga per progetto, espandibile per attività; riepilogo dei progetti
 * filtrati in alto.
 */
AP.planningStats = ( function() {

    // oltre questa quota del budget la barra diventa arancione
    const WARN_RATIO = .85;

    const pub = {};

    pub.init = function() {
        pub.vm = new Vue( {
            el: "#planning-stats-app",

            data: {
                workTypes: AP.page.workTypes || [],
                projects: [],
                loading: false,
                expanded: {},
                filters: { str: "", state: "all" },
            },

            computed: {
                filteredProjects: function() {
                    const str = this.filters.str.trim().toLowerCase();
                    const state = this.filters.state;

                    return this.projects.filter( ( project ) => {
                        if ( state === "open" && project.completed ) return false;
                        if ( state === "completed" && !project.completed ) return false;
                        if ( state === "over" && !this.isOver( project.totals ) ) return false;
                        if ( !str ) return true;
                        return [ project.label, project.name, project.rifLibero, project.customer ].join( " " ).toLowerCase().indexOf( str ) !== -1;
                    } );
                },

                summary: function() {
                    const summary = { cost: 0, doneCost: 0, budget: null, withBudget: 0, hours: 0, estimatedHours: 0, overBudget: 0 };
                    this.filteredProjects.forEach( ( project ) => {
                        const totals = project.totals;
                        summary.cost += totals.cost;
                        summary.doneCost += totals.doneCost;
                        summary.hours += totals.hours;
                        summary.estimatedHours += totals.estimatedHours;
                        if ( totals.budget !== "" ) {
                            summary.budget = ( summary.budget || 0 ) + totals.budget;
                            summary.withBudget++;
                        }
                        if ( this.isOver( totals ) ) summary.overBudget++;
                    } );
                    return summary;
                },
            },

            mounted: function() {
                this.load();
            },

            methods: {
                load: function() {
                    this.loading = true;
                    NM.util.ajax( {
                        method: "GET",
                        url: "/manager/ajax/planning/stats",
                        callback: {
                            done: ( xhr ) => {
                                this.loading = false;
                                // prima i progetti ( come arrivano ), poi i preventivi per numero e versione decrescenti
                                const items = xhr.data || [];
                                const quotations = items.filter( function( item ) { return item.kind !== "project"; } ).sort( function( a, b ) {
                                    return ( Number( b.number ) - Number( a.number ) ) || ( Number( b.version ) - Number( a.version ) );
                                } );
                                this.projects = items.filter( function( item ) { return item.kind === "project"; } ).concat( quotations );
                            },
                        },
                    } ).always( () => { this.loading = false; } );
                },

                toggle: function( id ) {
                    this.$set( this.expanded, id, !this.expanded[ id ] );
                },

                /* ---------- budget ---------- */

                // item: totali di un progetto o un'attività ( cost, doneCost, budget )
                ratio: function( item ) {
                    return item.budget > 0 ? item.cost / item.budget : ( item.cost > 0 ? Infinity : 0 );
                },

                isOver: function( item ) {
                    return item.budget !== "" && item.cost > item.budget;
                },

                usageClass: function( item ) {
                    const ratio = this.ratio( item );
                    return { over: ratio > 1, warn: ratio > WARN_RATIO && ratio <= 1 };
                },

                usageWidth: function( value, budget ) {
                    if ( !( budget > 0 ) ) return value > 0 ? "100%" : "0%";
                    return Math.min( 100, value / budget * 100 ) + "%";
                },

                usagePct: function( item ) {
                    const ratio = this.ratio( item );
                    return ratio === Infinity ? "–" : Math.round( ratio * 100 ) + "%";
                },

                usageTitle: function( item ) {
                    return "Svolto " + this.money( item.doneCost ) + ", pianificato " + this.money( item.cost ) + " su un budget di " + this.money( item.budget );
                },

                // budget meno costo pianificato: positivo = margine, negativo = sforamento
                delta: function( item ) {
                    if ( item.budget === "" ) return "–";
                    const delta = item.budget - item.cost;
                    return ( delta > 0 ? "+" : "" ) + this.money( delta );
                },

                deltaClass: function( item ) {
                    if ( item.budget === "" ) return "text-muted";
                    return item.cost > item.budget ? "text-danger" : "text-success";
                },

                /* ---------- utilità ---------- */

                workType: function( id ) {
                    return this.workTypes.find( function( type ) { return type.id === id; } ) || { activity: id, color: "#868e96" };
                },

                money: function( value ) {
                    return ( Number( value ) || 0 ).toLocaleString( "it-IT", { style: "currency", currency: "EUR" } );
                },

                hours: function( value ) {
                    return ( Math.round( ( Number( value ) || 0 ) * 100 ) / 100 ).toLocaleString( "it-IT" ) + " h";
                },
            },
        } );
    };

    return pub;
}() );

$( document ).ready( function() {
    if ( document.getElementById( "planning-stats-app" ) ) {
        AP.planningStats.init();
    }
} );
