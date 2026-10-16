AP.namespace( "planningProjects" );

/**
 * Ore progetti per la pianificazione ( Gantt ): per ogni voce del Gantt le ore
 * stimate per tipo di attività e lo stato. Le voci sono i preventivi attivi in
 * qualunque stato tranne Perso ed Estinto e i progetti ( kind
 * "project": nome + rif. libero, con zero o più preventivi collegati; un
 * preventivo collegato non compare da solo, è nel Gantt tramite il progetto ).
 * Per ogni voce anche la pianificazione: stato ( In corso / Concluso / In
 * sospeso / Da programmare: si assegnano persone solo In corso ), priorità,
 * data con tipo ( richiesta / tassativa ) e note, visibili nel Gantt. Ogni
 * modifica di una riga si salva subito; una voce conclusa esce dall'elenco
 * ( salvo filtro di stato ) e dal Gantt.
 */
AP.planningProjects = ( function() {

    const BASE = "/manager/ajax/planning";

    const pub = {};

    pub.init = function() {
        pub.vm = new Vue( {
            el: "#planning-projects-app",

            data: {
                workTypes: AP.page.workTypes || [],
                options: AP.page.planningOptions || { statuses: [], dateTypes: [], priorities: [] },
                projects: [],
                loading: false,
                // statusId: vuoto = tutti tranne i conclusi, "_all" = tutti
                filters: { str: "", statusId: "" },
                newProject: { open: false, name: "", rifLibero: "", saving: false },
            },

            computed: {
                filteredProjects: function() {
                    const str = this.filters.str.trim().toLowerCase();
                    const statusId = this.filters.statusId;

                    return this.projects.filter( function( project ) {
                        const projectStatus = project.planning.statusId;
                        if ( statusId === "" && projectStatus === "CLS" ) return false;
                        if ( statusId && statusId !== "_all" && projectStatus !== statusId ) return false;
                        if ( !str ) return true;
                        const linked = ( project.quotations || [] ).map( function( quotation ) {
                            return [ quotation.label, quotation.name, quotation.customer ].join( " " );
                        } );
                        const text = [ project.label, project.name, project.rifLibero, project.customer ].concat( linked ).join( " " ).toLowerCase();
                        return text.indexOf( str ) !== -1;
                    } );
                },
            },

            mounted: function() {
                this.load();
            },

            methods: {
                // promessa della richiesta: dopo un'operazione che ricarica l'elenco
                load: function() {
                    this.loading = true;
                    return NM.util.ajax( {
                        method: "GET",
                        url: BASE + "/projects",
                        callback: {
                            done: ( xhr ) => {
                                this.loading = false;
                                // prima i progetti ( dal più recente, come arrivano ), poi i preventivi
                                // per numero decrescente ( i più recenti in alto ) e versione decrescente
                                const items = xhr.data || [];
                                const quotations = items.filter( function( item ) { return item.kind !== "project"; } ).sort( function( a, b ) {
                                    return ( Number( b.number ) - Number( a.number ) ) || ( Number( b.version ) - Number( a.version ) );
                                } );
                                const projects = items.filter( function( item ) { return item.kind === "project"; } ).concat( quotations );
                                this.projects = projects.map( ( project ) => {
                                    // form: ore stimate modificabili, una per tipo; budgets: euro, vuoto = nessun budget
                                    const form = {};
                                    const budgets = {};
                                    this.workTypes.forEach( function( type ) {
                                        const hours = project.hours[ type.id ];
                                        form[ type.id ] = hours ? hours.estimated : 0;
                                        budgets[ type.id ] = hours && hours.budget !== "" ? hours.budget : "";
                                    } );
                                    return Object.assign( project, {
                                        form: form,
                                        budgets: budgets,
                                        saving: false,
                                        // solo progetti: modifica di nome / rif. libero e ricerca dei preventivi da collegare
                                        quotations: project.quotations || [],
                                        planning: {
                                            statusId: project.planningStatusId || "DAP",
                                            dueDate: project.dueDate || "",
                                            dateType: project.dateType || "",
                                            priority: project.priority || "",
                                            note: project.note || "",
                                        },
                                        editing: false,
                                        edit: { name: project.name, rifLibero: project.rifLibero },
                                        search: { str: "", results: [], empty: false, timer: null },
                                    } );
                                } );
                            },
                        },
                    } ).always( () => { this.loading = false; } );
                },

                save: function( project ) {
                    const vm = this;
                    const hours = {};
                    const budgets = {};
                    this.workTypes.forEach( function( type ) {
                        hours[ type.id ] = Math.max( Number( project.form[ type.id ] ) || 0, 0 );
                        const budget = String( project.budgets[ type.id ] ).trim();
                        budgets[ type.id ] = budget === "" || isNaN( Number( budget ) ) ? "" : Math.max( Number( budget ), 0 );
                    } );

                    project.saving = true;

                    return new Promise( ( resolve ) => {
                        NM.util.ajax( {
                            method: "POST",
                            url: BASE + "/projects/" + project.id,
                            loading: false, // salvataggio di una riga: niente spinner a tutta pagina
                            data: JSON.stringify( { hours: hours, budgets: budgets, planning: project.planning } ),
                            callback: {
                                done: function( xhr ) {
                                    project.saving = false;
                                    if ( xhr.status === "ERROR" ) {
                                        AP.widget.notify( "error", ( xhr.data && xhr.data.message ) || "Salvataggio non riuscito." );
                                        resolve( false );
                                        return;
                                    }
                                    vm.flashSaved( project );
                                    resolve( true );
                                },
                            },
                        } ).always( function() { project.saving = false; } );
                    } );
                },

                /*
                    Conferma del salvataggio ben visibile anche su righe lunghe: overlay
                    verde su tutta la riga con la spunta al centro della parte visibile
                    ( tabella e finestra ), che sparisce con una dissolvenza ( CSS ).
                */
                flashSaved: function( project ) {
                    const wrap = this.$refs.tableWrap;
                    const row = wrap && wrap.querySelector( 'tr[data-project-id="' + project.id + '"]' );
                    if ( !row ) return;

                    const previous = wrap.querySelector( '.pp-saved-overlay[data-project-id="' + project.id + '"]' );
                    if ( previous ) previous.remove();

                    const wrapRect = wrap.getBoundingClientRect();
                    const rowRect = row.getBoundingClientRect();
                    const visibleLeft = Math.max( rowRect.left, wrapRect.left, 0 );
                    const visibleRight = Math.min( rowRect.right, wrapRect.right, window.innerWidth );

                    const overlay = document.createElement( "div" );
                    overlay.className = "pp-saved-overlay";
                    overlay.dataset.projectId = project.id;
                    overlay.style.left = ( rowRect.left - wrapRect.left + wrap.scrollLeft ) + "px";
                    overlay.style.top = ( rowRect.top - wrapRect.top + wrap.scrollTop ) + "px";
                    overlay.style.width = rowRect.width + "px";
                    overlay.style.height = rowRect.height + "px";

                    const check = document.createElement( "div" );
                    check.className = "pp-saved-check";
                    check.innerHTML = '<i class="fas fa-check"></i>';
                    check.style.left = ( ( visibleLeft + visibleRight ) / 2 - rowRect.left ) + "px";
                    overlay.appendChild( check );

                    overlay.addEventListener( "animationend", function() { overlay.remove(); } );
                    wrap.appendChild( overlay );
                },

                // cambio di stato: si salva e si spiega cosa cambia nel Gantt
                // data tassativa: la priorità si toglie ( anche il server la ignora )
                changeDateType: function( project ) {
                    if ( project.planning.dateType === "TAS" ) project.planning.priority = "";
                    this.save( project );
                },

                changeStatus: async function( project ) {
                    const saved = await this.save( project );
                    if ( !saved ) return;
                    const label = project.kind === "project" ? project.name : project.label;
                    const messages = {
                        COR: "è in corso: nel Calendario si possono assegnare le persone.",
                        CLS: "è concluso: non compare più nel Calendario.",
                        SOS: "è in sospeso: nel Calendario non si possono assegnare persone.",
                        DAP: "è da programmare: nel Calendario si possono assegnare le persone.",
                    };
                    AP.widget.notify( "success", label + " " + ( messages[ project.planning.statusId ] || "salvato." ) );
                },

                /* ---------- progetti ---------- */

                openNewProject: function() {
                    this.newProject = { open: true, name: "", rifLibero: "", saving: false };
                    this.$nextTick( () => { if ( this.$refs.newProjectName ) this.$refs.newProjectName.focus(); } );
                },

                createProject: function() {
                    if ( !this.newProject.name.trim() ) return;
                    this.newProject.saving = true;
                    this.call( "POST", BASE + "/projects", { name: this.newProject.name, rifLibero: this.newProject.rifLibero }, () => {
                        AP.widget.notify( "success", "Progetto creato: inserisci le ore e collega i preventivi." );
                        this.newProject.open = false;
                        this.load();
                    }, () => { this.newProject.saving = false; } );
                },

                startEdit: function( project ) {
                    project.edit = { name: project.name, rifLibero: project.rifLibero };
                    project.editing = true;
                },

                saveDetails: function( project ) {
                    if ( !project.edit.name.trim() ) return;
                    this.call( "POST", BASE + "/projects/" + project.id + "/details", project.edit, () => {
                        project.name = project.edit.name.trim();
                        project.label = project.name;
                        project.rifLibero = project.edit.rifLibero.trim();
                        project.editing = false;
                        // la riga cambia altezza chiudendo il modulo: overlay dopo il ridisegno
                        this.$nextTick( () => this.flashSaved( project ) );
                    } );
                },

                deleteProject: function( project ) {
                    bootbox.confirm( {
                        title: "Elimina progetto",
                        message: "Eliminare il progetto \"" + project.name + "\"? Le sue ore stimate si perdono e i preventivi collegati"
                            + " tornano nel Calendario da soli. Un progetto con blocchi pianificati non si può eliminare.",
                        buttons: {
                            confirm: { label: "Elimina", className: "btn-danger" },
                            cancel: { label: "Annulla", className: "btn-default" },
                        },
                        callback: ( confirmed ) => {
                            if ( !confirmed ) return;
                            this.call( "DELETE", BASE + "/projects/" + project.id, null, () => {
                                AP.widget.notify( "success", "Progetto eliminato." );
                                this.load();
                            } );
                        },
                    } );
                },

                // ricerca con un attimo di attesa: non una richiesta per ogni tasto
                searchQuotations: function( project ) {
                    clearTimeout( project.search.timer );
                    const str = project.search.str.trim();
                    if ( str.length < 2 ) {
                        project.search.results = [];
                        project.search.empty = false;
                        return;
                    }
                    project.search.timer = setTimeout( () => {
                        NM.util.ajax( {
                            method: "GET",
                            url: BASE + "/quotations?str=" + encodeURIComponent( str ),
                            callback: {
                                done: function( xhr ) {
                                    // risposta di una ricerca superata da una più recente: si ignora
                                    if ( project.search.str.trim() !== str ) return;
                                    project.search.results = xhr.data || [];
                                    project.search.empty = !project.search.results.length;
                                },
                            },
                        } );
                    }, 300 );
                },

                clearSearch: function( project ) {
                    clearTimeout( project.search.timer );
                    project.search = { str: "", results: [], empty: false, timer: null };
                },

                linkQuotation: function( project, quotation ) {
                    this.call( "POST", BASE + "/projects/" + project.id + "/quotations", { quotationId: quotation.id }, () => {
                        AP.widget.notify( "success", "Preventivo " + quotation.label + " collegato: nel Calendario è ora sotto il progetto." );
                        this.reloadAndFlash( project );
                    } );
                },

                unlinkQuotation: function( project, quotation ) {
                    bootbox.confirm( {
                        title: "Scollega preventivo",
                        message: "Scollegare il preventivo " + quotation.label + " dal progetto \"" + project.name + "\"?"
                            + " Torna nel Calendario da solo; i blocchi già pianificati restano al progetto.",
                        buttons: {
                            confirm: { label: "Scollega", className: "btn-warning" },
                            cancel: { label: "Annulla", className: "btn-default" },
                        },
                        callback: ( confirmed ) => {
                            if ( !confirmed ) return;
                            this.call( "DELETE", BASE + "/projects/" + project.id + "/quotations/" + quotation.id, null, () => {
                                this.reloadAndFlash( project );
                            } );
                        },
                    } );
                },

                // dopo il ricaricamento la riga è un oggetto nuovo: l'overlay la cerca per id
                reloadAndFlash: function( project ) {
                    this.load().always( () => this.$nextTick( () => this.flashSaved( project ) ) );
                },

                // chiamata con messaggio d'errore del server ( status ERROR ) e callback di riuscita
                call: function( method, url, payload, onSuccess, onAlways ) {
                    NM.util.ajax( {
                        method: method,
                        url: url,
                        data: payload ? JSON.stringify( payload ) : null,
                        callback: {
                            done: function( xhr ) {
                                if ( xhr.status === "ERROR" ) {
                                    AP.widget.notify( "error", ( xhr.data && xhr.data.message ) || "Operazione non riuscita." );
                                    return;
                                }
                                onSuccess( xhr );
                            },
                        },
                    } ).always( function() { if ( onAlways ) onAlways(); } );
                },

                planned: function( project, typeId ) {
                    return project.hours[ typeId ] ? project.hours[ typeId ].planned : 0;
                },

                // ore extra: pianificate oltre la stima, non la consumano
                extra: function( project, typeId ) {
                    return project.hours[ typeId ] ? ( project.hours[ typeId ].extra || 0 ) : 0;
                },

                // pianificate oltre la stima: in rosso; pari alla stima: in verde
                plannedClass: function( project, typeId ) {
                    const planned = this.planned( project, typeId );
                    const estimated = Number( project.form[ typeId ] ) || 0;
                    return { over: planned > estimated, done: planned > 0 && planned === estimated };
                },

                total: function( project ) {
                    return this.workTypes.reduce( function( sum, type ) { return sum + ( Number( project.form[ type.id ] ) || 0 ); }, 0 );
                },

                // somma dei budget inseriti ( null se nessuna attività ha un budget )
                totalBudget: function( project ) {
                    let total = null;
                    this.workTypes.forEach( function( type ) {
                        const budget = String( project.budgets[ type.id ] ).trim();
                        if ( budget !== "" && !isNaN( Number( budget ) ) ) total = ( total || 0 ) + Number( budget );
                    } );
                    return total;
                },

                formatMoney: function( value ) {
                    return ( Number( value ) || 0 ).toLocaleString( "it-IT", { style: "currency", currency: "EUR" } );
                },

                totalPlanned: function( project ) {
                    return this.workTypes.reduce( ( sum, type ) => sum + this.planned( project, type.id ), 0 );
                },

                // colore del badge di stato del preventivo
                statusClass: function( statusId ) {
                    return {
                        LAV: "bg-light text-dark border",
                        PEN: "bg-warning text-dark",
                        APR: "bg-primary",
                        CCN: "bg-info",
                        CON: "bg-success",
                    }[ statusId ] || "bg-light text-dark";
                },

                // "yyyy-mm-dd" -> "gg/mm/aaaa" ( vuoto se non c'è )
                formatDate: function( value ) {
                    if ( !value ) return "";
                    const parts = String( value ).split( "-" );
                    return parts.length === 3 ? parts[ 2 ] + "/" + parts[ 1 ] + "/" + parts[ 0 ] : value;
                },

                format: function( value ) {
                    return ( Math.round( ( Number( value ) || 0 ) * 100 ) / 100 ).toLocaleString( "it-IT" );
                },
            },
        } );
    };

    return pub;
}() );

$( document ).ready( function() {
    if ( document.getElementById( "planning-projects-app" ) ) {
        AP.planningProjects.init();
    }
} );
