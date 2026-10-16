AP.namespace( "planningGantt" );

/**
 * Calendario ( Gantt ) della pianificazione: persone sui preventivi attivi
 * ( qualunque stato tranne Perso ed Estinto ) e sui progetti. Si assegnano
 * persone alle voci "In corso" e "Da programmare" ( assignable ); ogni persona
 * riceve le attività delle sue tipologie. Entrambe le viste mostrano le voci in
 * corso e da programmare, non le concluse né le sospese.
 *
 * Un blocco è una persona su un'attività di un preventivo, con le ore giorno
 * per giorno ( planning_blocks / planning_block_days ): la distribuzione delle
 * ore la decide il server ( PlanningService ); qui si disegna, si raccolgono i
 * gesti e dopo ogni operazione si ricaricano i dati.
 *
 * Interazioni:
 * - un riquadro di "Da pianificare" trascinato su una persona del tipo giusto
 *   crea un blocco con tutte le ore mancanti, dal giorno del rilascio; un
 *   riquadro senza ore residue ( 0 h ) apre la nuova attività ( ore extra );
 * - il nome di una persona trascinato su un giorno, o il suo "+", apre la
 *   nuova attività ( es. ore extra );
 * - una barra trascinata cambia data ( e persona, nella vista Persone );
 * - il bordo destro di una barra la allunga o accorcia;
 * - un click sulla barra la seleziona e mostra i pulsanti ( ore per giorno,
 *   dividi dal giorno cliccato, sabati, festivi, lucchetto, elimina ); doppio
 *   click apre le ore del giorno cliccato;
 * - un blocco con il lucchetto non si sposta né si modifica: lo toglie solo
 *   un ADM ( AP.page.isAdmin ).
 *
 * Scale: giornaliera ( 2 settimane, colonne larghe con le ore di ogni giorno ),
 * settimanale ( 6 settimane ), mensile ( mese di calendario, default ).
 * Le date si trattano come stringhe "yyyy-mm-dd" in ora locale.
 */
AP.planningGantt = ( function() {

    const BASE = "/manager/ajax/planning";

    const DOW_LABELS   = [ "D", "L", "M", "M", "G", "V", "S" ];
    const MONTH_LABELS = [ "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre" ];

    // altezza di una corsia: la barra ha due righe ( preventivo e cliente /
    // persona ), nella scala giornaliera una terza con le ore di ogni giorno
    const LANE_HEIGHT = { day: 58, week: 40, month: 40 };
    const ROW_PADDING = 8;
    const MIN_ROW_HEIGHT = 44;

    // scala giornaliera: ogni giorno mostra questa fascia oraria ( minuti ) e i
    // pezzi dei blocchi stanno nella loro posizione reale
    const DAY_VIEW_FROM = 6 * 60;
    const DAY_VIEW_TO = 20 * 60;

    // orari selezionabili per inizio / fine di un blocco: passi di 30 minuti
    const TIME_OPTIONS = [];
    for ( let minutes = 0; minutes < 24 * 60; minutes += 30 ) {
        TIME_OPTIONS.push( formatTime( minutes ) );
    }

    const pub = {};

    // trascinamento / ridimensionamento in corso di una barra ( fuori dai dati
    // reattivi di Vue: cambia a ogni movimento del puntatore )
    let pointer = null;

    /* ---------- date e orari ---------- */

    // minuti dalla mezzanotte -> "HH:MM"
    function formatTime( minutes ) {
        return String( Math.floor( minutes / 60 ) ).padStart( 2, "0" ) + ":" + String( minutes % 60 ).padStart( 2, "0" );
    }

    // giorno "yyyy-mm-dd" -> numero di giorno, per confrontare istanti di giorni diversi
    function dayNumber( key ) {
        const parts = key.split( "-" );
        return Math.round( Date.UTC( Number( parts[ 0 ] ), Number( parts[ 1 ] ) - 1, Number( parts[ 2 ] ) ) / 86400000 );
    }

    // inizio e fine di un blocco in minuti assoluti ( per le corsie della scala giornaliera )
    function blockInterval( block ) {
        const first = block.days[ 0 ];
        const last = block.days[ block.days.length - 1 ];
        return {
            start: dayNumber( first.day ) * 1440 + first.start,
            end: dayNumber( last.day ) * 1440 + last.start + Math.round( last.hours * 60 ),
        };
    }

    function parseDay( key ) {
        const parts = key.split( "-" );
        return new Date( Number( parts[ 0 ] ), Number( parts[ 1 ] ) - 1, Number( parts[ 2 ] ) );
    }

    function dayKey( date ) {
        const month = String( date.getMonth() + 1 ).padStart( 2, "0" );
        const day = String( date.getDate() ).padStart( 2, "0" );
        return date.getFullYear() + "-" + month + "-" + day;
    }

    function addDays( date, count ) {
        const result = new Date( date.getFullYear(), date.getMonth(), date.getDate() );
        result.setDate( result.getDate() + count );
        return result;
    }

    function mondayOf( date ) {
        const dow = ( date.getDay() + 6 ) % 7; // lunedì = 0
        return addDays( date, -dow );
    }

    /**
     * Intervallo visibile per scala e data di riferimento.
     */
    function rangeFor( scale, anchor ) {
        if ( scale === "month" ) {
            const from = new Date( anchor.getFullYear(), anchor.getMonth(), 1 );
            const to = new Date( anchor.getFullYear(), anchor.getMonth() + 1, 0 );
            return { from: from, to: to };
        }
        const from = mondayOf( anchor );
        return { from: from, to: addDays( from, scale === "day" ? 13 : 41 ) };
    }

    /**
     * Blocchi di una riga distribuiti in corsie, così quelli che si
     * sovrappongono nei giorni stanno uno sotto l'altro.
     */
    // timed: scala giornaliera, si confrontano gli orari ( un blocco che inizia
    // quando finisce l'altro sta sulla stessa corsia ); altrimenti i giorni
    function assignLanes( blocks, timed ) {
        const items = blocks.map( function( block ) {
            const interval = timed ? blockInterval( block ) : { start: block.start, end: block.end };
            return { block: block, start: interval.start, end: interval.end };
        } ).sort( function( a, b ) {
            return a.start < b.start ? -1 : a.start > b.start ? 1 : a.block.id - b.block.id;
        } );
        const laneEnds = [];
        const lanes = {};

        items.forEach( function( item ) {
            let lane = laneEnds.findIndex( function( end ) { return timed ? end <= item.start : end < item.start; } );
            if ( lane === -1 ) {
                lane = laneEnds.length;
                laneEnds.push( item.end );
            } else {
                laneEnds[ lane ] = item.end;
            }
            lanes[ item.block.id ] = lane;
        } );

        return { lanes: lanes, count: Math.max( laneEnds.length, 1 ) };
    }

    pub.init = function() {
        const today = dayKey( new Date() );
        const prefs = {
            scale: AP.getUserPref( "planning.gantt.scale", "month" ),
            groupBy: AP.getUserPref( "planning.gantt.groupBy", "people" ),
            backlogCollapsed: AP.getUserPref( "planning.gantt.backlogCollapsed", false ),
        };

        pub.vm = new Vue( {
            el: "#planning-gantt-app",

            data: {
                workTypes: AP.page.workTypes || [],
                options: AP.page.planningOptions || { statuses: [], dateTypes: [], priorities: [] },
                isAdmin: !!AP.page.isAdmin,
                scale: prefs.scale,
                groupBy: prefs.groupBy,
                anchor: new Date(),
                today: today,
                loading: false,
                backlogCollapsed: prefs.backlogCollapsed,
                collapsedGroups: {},
                gridWidth: 1000,
                labelWidth: 210,

                people: [],
                quotations: [],
                blocks: [],
                nonWorkingDays: {},

                // riquadro di "Da pianificare" trascinato e cella su cui verrebbe rilasciato
                dragging: null,
                dropTarget: null,

                // blocco selezionato ( day: giorno cliccato ) e ore per giorno aperte
                selected: null,
                dayEditor: { open: false },

                // nuova attività ( extra ): persona trascinata su un giorno, "+" della
                // persona o riquadro senza ore residue
                extraForm: { person: null, day: "", quotationId: "", workTypeId: "", hours: 8, startTime: "", note: "", extra: true },

                // preventivo / progetto aperto nella modale dei dettagli ( stato, priorità, data, note )
                itemInfo: null,

                // pianificazione automatica: anteprima del server ( PlanningService.autoPlan )
                autoPlan: { loading: false, result: null },
            },

            computed: {
                range: function() {
                    return rangeFor( this.scale, this.anchor );
                },

                days: function() {
                    const result = [];
                    for ( let date = this.range.from; date <= this.range.to; date = addDays( date, 1 ) ) {
                        const key = dayKey( date );
                        result.push( {
                            key: key,
                            date: date,
                            dow: date.getDay(),
                            dowLabel: DOW_LABELS[ date.getDay() ],
                            dom: date.getDate(),
                            nonWorking: this.nonWorkingDays[ key ] || null,
                        } );
                    }
                    return result;
                },

                dayIndex: function() {
                    const index = {};
                    this.days.forEach( function( day, i ) { index[ day.key ] = i; } );
                    return index;
                },

                // il mese riempie la larghezza disponibile, le altre scale hanno colonne fisse
                colWidth: function() {
                    if ( this.scale === "day" ) return 160;
                    if ( this.scale === "week" ) return 34;
                    const available = this.gridWidth - this.labelWidth - 2;
                    return Math.max( 22, Math.floor( available / this.days.length ) );
                },

                periodLabel: function() {
                    const from = this.range.from;
                    const to = this.range.to;
                    if ( this.scale === "month" ) {
                        return MONTH_LABELS[ from.getMonth() ] + " " + from.getFullYear();
                    }
                    const format = function( date ) { return date.toLocaleDateString( "it-IT", { day: "2-digit", month: "short" } ); };
                    return format( from ) + " – " + format( to ) + " " + to.getFullYear();
                },

                // intestazione superiore: mesi ( settimana / mese ) o settimane ( giorno )
                headerSpans: function() {
                    const spans = [];
                    this.days.forEach( ( day ) => {
                        const key = this.scale === "day"
                            ? "w" + dayKey( mondayOf( day.date ) )
                            : "m" + day.date.getFullYear() + "-" + day.date.getMonth();
                        const last = spans[ spans.length - 1 ];
                        if ( last && last.key === key ) {
                            last.count++;
                            return;
                        }
                        const label = this.scale === "day"
                            ? "Settimana dal " + day.date.toLocaleDateString( "it-IT", { day: "2-digit", month: "long" } )
                            : MONTH_LABELS[ day.date.getMonth() ] + " " + day.date.getFullYear();
                        spans.push( { key: key, label: label, count: 1 } );
                    } );
                    return spans;
                },

                quotationsById: function() {
                    const map = {};
                    this.quotations.forEach( function( quotation ) { map[ quotation.id ] = quotation; } );
                    return map;
                },

                peopleById: function() {
                    const map = {};
                    this.people.forEach( function( person ) { map[ person.id ] = person; } );
                    return map;
                },

                // ore pianificate per persona e giorno ( tutti i blocchi caricati )
                plannedByPersonDay: function() {
                    const map = {};
                    this.blocks.forEach( function( block ) {
                        block.days.forEach( function( day ) {
                            const key = block.userId + "|" + day.day;
                            map[ key ] = ( map[ key ] || 0 ) + day.hours;
                        } );
                    } );
                    return map;
                },

                // giorni non lavorativi resi lavorabili da un blocco ( usa sabati /
                // forza festivi ) per persona: "userId|yyyy-mm-dd" -> true
                openedByPersonDay: function() {
                    const map = {};
                    this.blocks.forEach( ( block ) => {
                        block.days.forEach( ( day ) => {
                            const nonWorking = this.nonWorkingDays[ day.day ];
                            if ( !nonWorking || !day.hours ) return;
                            if ( block.forceHolidays || ( nonWorking.type === "SAT" && block.useSaturday ) ) {
                                map[ block.userId + "|" + day.day ] = true;
                            }
                        } );
                    } );
                    return map;
                },

                /*
                    Ore stimate per preventivo e tipo, da trascinare sulle persone.
                    Anche le attività già tutte pianificate ( 0 h residue, mai sotto
                    zero ): trascinate aprono la nuova attività ( ore extra ). Prima
                    le voci con ore residue, e in ogni voce i loro riquadri.
                */
                backlog: function() {
                    const open = [];
                    const done = [];
                    this.quotations.forEach( ( quotation ) => {
                        // voci in corso e da programmare: a sospese e concluse non si assegnano persone
                        if ( !quotation.plannable || !quotation.assignable ) return;
                        const chips = [];
                        this.workTypes.forEach( function( type ) {
                            const hours = quotation.hours[ type.id ];
                            if ( !hours || !( hours.estimated > 0 || hours.planned > 0 ) ) return;
                            const remaining = Math.max( 0, Math.round( ( hours.estimated - hours.planned ) * 100 ) / 100 );
                            chips.push( { workTypeId: type.id, estimated: hours.estimated, planned: hours.planned, remaining: remaining } );
                        } );
                        if ( !chips.length ) return;
                        chips.sort( function( a, b ) { return ( b.remaining > 0 ) - ( a.remaining > 0 ); } );
                        const remaining = chips.some( function( chip ) { return chip.remaining > 0; } );
                        ( remaining ? open : done ).push( { quotation: quotation, chips: chips, remaining: remaining } );
                    } );
                    const compare = this.compareItems;
                    open.sort( function( a, b ) { return compare( a.quotation, b.quotation ); } );
                    done.sort( function( a, b ) { return compare( a.quotation, b.quotation ); } );
                    return open.concat( done );
                },

                rowGroups: function() {
                    return this.groupBy === "people" ? this.peopleGroups() : this.quotationGroups();
                },
            },

            watch: {
                range: function() { this.load(); },
            },

            mounted: function() {
                this.measure();
                window.addEventListener( "resize", this.measure );
                window.addEventListener( "pointermove", this.onPointerMove );
                window.addEventListener( "pointerup", this.onPointerUp );

                // click fuori dal blocco selezionato e dai suoi pulsanti: deseleziona
                document.addEventListener( "click", ( event ) => {
                    if ( !this.selected ) return;
                    if ( event.target.closest( ".pg-bar, .pg-block-toolbar, .modal, .bootbox" ) ) return;
                    this.clearSelection();
                } );
                document.addEventListener( "keydown", ( event ) => {
                    if ( event.key === "Escape" ) this.clearSelection();
                } );

                this.load();
            },

            methods: {
                load: async function() {
                    this.loading = true;
                    const from = dayKey( this.range.from );
                    const to = dayKey( this.range.to );

                    NM.util.ajax( {
                        method: "GET",
                        url: BASE + "/gantt?from=" + from + "&to=" + to,
                        callback: {
                            done: ( xhr ) => {
                                this.loading = false;
                                if ( xhr.status === "ERROR" ) {
                                    AP.widget.notify( "error", ( xhr.data && xhr.data.message ) || "Caricamento non riuscito." );
                                    return;
                                }
                                // risposta di un intervallo vecchio ( navigazione veloce ): si ignora
                                if ( from !== dayKey( this.range.from ) || to !== dayKey( this.range.to ) ) return;

                                this.people = xhr.data.people || [];
                                this.quotations = xhr.data.quotations || [];
                                this.blocks = xhr.data.blocks || [];
                                this.nonWorkingDays = xhr.data.nonWorkingDays || {};

                                // il blocco selezionato può non esserci più ( eliminato, fuori periodo )
                                if ( this.selected && !this.blocks.some( ( block ) => block.id === this.selected.blockId ) ) {
                                    this.clearSelection();
                                }
                            },
                        },
                    } ).always( () => { this.loading = false; } );
                },

                measure: function() {
                    if ( this.$refs.grid ) {
                        this.gridWidth = this.$refs.grid.clientWidth;
                    }
                },

                /* ---------- navigazione ---------- */

                setScale: function( scale ) {
                    this.scale = scale;
                    AP.setUserPref( "planning.gantt.scale", scale );
                },

                setGroupBy: function( groupBy ) {
                    this.groupBy = groupBy;
                    AP.setUserPref( "planning.gantt.groupBy", groupBy );
                },

                move: function( direction ) {
                    const anchor = this.anchor;
                    if ( this.scale === "month" ) {
                        this.anchor = new Date( anchor.getFullYear(), anchor.getMonth() + direction, 1 );
                    } else {
                        this.anchor = addDays( anchor, direction * ( this.scale === "day" ? 7 : 28 ) );
                    }
                },

                goToday: function() {
                    this.anchor = new Date();
                },

                toggleBacklog: function() {
                    this.backlogCollapsed = !this.backlogCollapsed;
                    AP.setUserPref( "planning.gantt.backlogCollapsed", this.backlogCollapsed );
                    this.$nextTick( this.measure );
                },

                toggleGroup: function( key ) {
                    this.$set( this.collapsedGroups, key, !this.collapsedGroups[ key ] );
                },

                /* ---------- righe ---------- */

                // per Persone: un solo gruppo, una riga per persona con le sue tipologie
                // ( una persona può averne più d'una: un gruppo per tipologia la ripeterebbe )
                peopleGroups: function() {
                    const rows = this.people.map( ( person ) => {
                        const blocks = this.blocks.filter( function( block ) { return block.userId === person.id; } );
                        const types = person.workTypeIds.map( ( id ) => this.workType( id ).name ).join( ", " );
                        return this.buildRow( "p-" + person.id, person.name, types, blocks, person, null );
                    } );
                    return rows.length ? [ {
                        key: "people",
                        title: "Persone",
                        subtitle: rows.length + ( rows.length === 1 ? " persona" : " persone" ),
                        color: "#868e96",
                        rows: rows,
                        emptyText: "Nessuna persona da pianificare",
                    } ] : [];
                },

                // per Preventivi: un gruppo per preventivo, una riga per tipo di
                // attività; i progetti conclusi non si vedono più
                quotationGroups: function() {
                    // le voci in corso e da programmare: non le concluse né le sospese
                    return this.quotations.filter( function( quotation ) {
                        return quotation.planningStatusId === "COR" || quotation.planningStatusId === "DAP";
                    } ).sort( this.compareItems ).map( ( quotation ) => {
                        const rows = [];
                        this.workTypes.forEach( ( type ) => {
                            const hours = quotation.hours[ type.id ];
                            const blocks = this.blocks.filter( function( block ) {
                                return block.quotationId === quotation.id && block.workTypeId === type.id;
                            } );
                            // solo le attività con ore stimate o pianificate
                            if ( !( hours && ( hours.estimated > 0 || hours.planned > 0 ) ) && !blocks.length ) return;

                            const subtitle = hours
                                ? this.format( hours.planned ) + " / " + this.format( hours.estimated ) + " h pianificate"
                                : "";
                            rows.push( this.buildRow( "q-" + quotation.id + "-" + type.id, type.activity, subtitle, blocks, null, type.color ) );
                        } );

                        return {
                            key: "quotation-" + quotation.id,
                            title: this.quotationLabel( quotation ),
                            subtitle: this.itemSubtitle( quotation ),
                            project: quotation.kind === "project",
                            // la voce: priorità, stato, data e note nell'intestazione del gruppo
                            item: quotation,
                            // i colori sono dei tipi di attività: il gruppo del preventivo resta neutro
                            color: "",
                            rows: rows,
                            emptyText: "Nessuna ora di attività inserita",
                        };
                    } );
                },

                /*
                    Ordine delle voci ( vista Preventivi e "Da pianificare" ): prima le
                    in corso, poi per data del preventivo / progetto crescente ( prima
                    quelle che scadono prima, senza data in fondo ), infine dalla più
                    recente ( preventivi e progetti insieme ).
                */
                compareItems: function( a, b ) {
                    const status = ( a.planningStatusId === "COR" ? 0 : 1 ) - ( b.planningStatusId === "COR" ? 0 : 1 );
                    if ( status ) return status;
                    if ( ( a.dueDate || "" ) !== ( b.dueDate || "" ) ) {
                        if ( !a.dueDate ) return 1;
                        if ( !b.dueDate ) return -1;
                        return a.dueDate < b.dueDate ? -1 : 1;
                    }
                    return ( b.createdAt || "" ).localeCompare( a.createdAt || "" );
                },

                // scadenza della voce rispetto a oggi: "overdue" ( data passata ),
                // "soon" ( entro 30 giorni ), "" ( più avanti o senza data )
                dueState: function( item ) {
                    if ( !item || !item.dueDate ) return "";
                    const days = dayNumber( item.dueDate ) - dayNumber( this.today );
                    if ( days < 0 ) return "overdue";
                    return days <= 30 ? "soon" : "";
                },

                dueStateTitle: function( item ) {
                    const state = this.dueState( item );
                    if ( state === "overdue" ) return "Scaduto: " + this.dueTitle( item );
                    if ( state === "soon" ) return "Scade entro 30 giorni: " + this.dueTitle( item );
                    return "";
                },

                buildRow: function( key, title, subtitle, blocks, person, dotColor ) {
                    const lanes = assignLanes( blocks, this.scale === "day" );
                    const bars = blocks
                        .map( ( block ) => this.buildBar( block, lanes.lanes[ block.id ] ) )
                        .filter( Boolean );

                    return {
                        key: key,
                        title: title,
                        subtitle: subtitle,
                        person: person,
                        dotColor: dotColor,
                        laneCount: lanes.count,
                        bars: bars,
                    };
                },

                // posizione del blocco nell'intervallo visibile ( tagliato ai bordi )
                buildBar: function( block, lane ) {
                    const first = this.days[ 0 ].key;
                    const last = this.days[ this.days.length - 1 ].key;
                    if ( block.end < first || block.start > last ) return null;

                    const start = block.start < first ? first : block.start;
                    const end = block.end > last ? last : block.end;
                    const startIndex = this.dayIndex[ start ];
                    const endIndex = this.dayIndex[ end ];

                    const cells = block.days
                        .filter( ( day ) => this.dayIndex[ day.day ] !== undefined )
                        .map( ( day ) => ( {
                            key: day.day,
                            hours: day.hours,
                            left: ( this.dayIndex[ day.day ] - startIndex ) * this.colWidth,
                        } ) );

                    // giorni attraversati dalla barra senza ore ( es. la domenica tra
                    // un sabato e un lunedì ): tratti non lavorati, raggruppati
                    const worked = {};
                    block.days.forEach( function( day ) { if ( day.hours > 0 ) worked[ day.day ] = true; } );
                    const gaps = [];
                    for ( let index = startIndex; index <= endIndex; index++ ) {
                        if ( worked[ this.days[ index ].key ] ) continue;
                        const left = ( index - startIndex ) * this.colWidth;
                        const previous = gaps[ gaps.length - 1 ];
                        if ( previous && previous.left + previous.width === left ) {
                            previous.width += this.colWidth;
                        } else {
                            gaps.push( { key: this.days[ index ].key, left: left, width: this.colWidth } );
                        }
                    }

                    const bar = {
                        block: block,
                        lane: lane,
                        startIndex: startIndex,
                        span: endIndex - startIndex + 1,
                        clippedStart: block.start < first,
                        clippedEnd: block.end > last,
                        cells: cells,
                        gaps: gaps,
                        timed: false,
                        left: startIndex * this.colWidth,
                        width: ( endIndex - startIndex + 1 ) * this.colWidth,
                    };

                    // scala giornaliera: un pezzo per giorno nella sua fascia oraria
                    if ( this.scale === "day" ) {
                        const pieces = block.days
                            .filter( ( day ) => this.dayIndex[ day.day ] !== undefined && day.hours > 0 )
                            .map( ( day ) => {
                                const base = this.dayIndex[ day.day ] * this.colWidth;
                                const end = day.start + Math.round( day.hours * 60 );
                                const left = base + this.timeX( day.start );
                                return {
                                    key: day.day,
                                    hours: day.hours,
                                    time: formatTime( day.start ) + "–" + formatTime( end ),
                                    left: left,
                                    width: Math.max( 8, base + this.timeX( end ) - left ),
                                };
                            } );

                        if ( pieces.length ) {
                            const barLeft = bar.clippedStart ? 0 : pieces[ 0 ].left;
                            const lastPiece = pieces[ pieces.length - 1 ];
                            const barRight = bar.clippedEnd ? this.days.length * this.colWidth : lastPiece.left + lastPiece.width;
                            pieces.forEach( function( piece ) { piece.left -= barLeft; } );
                            bar.timed = true;
                            bar.pieces = pieces;
                            bar.left = barLeft;
                            bar.width = Math.max( 8, barRight - barLeft );
                        }
                    }

                    return bar;
                },

                // posizione di un orario dentro la colonna di un giorno ( scala giornaliera )
                timeX: function( minutes ) {
                    const ratio = ( minutes - DAY_VIEW_FROM ) / ( DAY_VIEW_TO - DAY_VIEW_FROM );
                    return Math.min( Math.max( ratio, 0 ), 1 ) * this.colWidth;
                },

                laneHeight: function() {
                    return LANE_HEIGHT[ this.scale ] || 30;
                },

                rowHeight: function( row ) {
                    return Math.max( MIN_ROW_HEIGHT, row.laneCount * this.laneHeight() + ROW_PADDING );
                },

                // barra stretta: testo più piccolo, preventivo sopra e ore sotto
                barCompact: function( bar ) {
                    return bar.span * this.colWidth < 90;
                },

                showDayHours: function() {
                    return this.scale === "day";
                },

                // i colori identificano solo il tipo di attività ( come in Ore progetti
                // e Statistiche ); il preventivo si riconosce dal numero sulla barra
                barColor: function( bar ) {
                    return this.workType( bar.block.workTypeId ).color;
                },

                barStyle: function( bar ) {
                    const style = {
                        left: ( bar.left + 2 ) + "px",
                        width: ( bar.width - 4 ) + "px",
                        top: ( ROW_PADDING / 2 + bar.lane * this.laneHeight() ) + "px",
                        height: ( this.laneHeight() - 4 ) + "px",
                        backgroundColor: bar.timed ? "transparent" : this.barColor( bar ),
                    };
                    // pezzi a orario: il colore serve alla linea che li unisce
                    if ( bar.timed ) style.color = this.barColor( bar );
                    return style;
                },

                // prima riga della barra: il preventivo ( vista Persone ) o la persona
                // ( vista Preventivi, dove il preventivo è già la riga )
                barMain: function( block, compact ) {
                    if ( this.groupBy === "people" ) {
                        const quotation = this.quotationsById[ block.quotationId ];
                        if ( !quotation ) return "";
                        // progetto: il nome; preventivo: il numero ( "n. " solo se c'è spazio )
                        if ( quotation.kind === "project" ) return quotation.label;
                        const number = quotation.number + ( quotation.version ? "/" + quotation.version : "" );
                        return compact ? number : "n. " + number;
                    }
                    const person = this.peopleById[ block.userId ];
                    return person ? person.name : "";
                },

                // seconda riga: la nota ( se c'è ), altrimenti cliente ( o nome del
                // preventivo ) / numero del preventivo
                barSub: function( block ) {
                    if ( block.note ) return block.note;
                    const quotation = this.quotationsById[ block.quotationId ];
                    if ( !quotation ) return "";
                    if ( this.groupBy === "people" ) {
                        return this.itemSubtitle( quotation );
                    }
                    return this.quotationLabel( quotation ) + ( quotation.customer ? " · " + quotation.customer : "" );
                },

                barLabel: function( block ) {
                    if ( this.groupBy === "people" ) {
                        const quotation = this.quotationsById[ block.quotationId ];
                        return quotation ? this.quotationLabel( quotation ) + ( quotation.customer ? " · " + quotation.customer : "" ) : "";
                    }
                    const person = this.peopleById[ block.userId ];
                    return person ? person.name : "";
                },

                barTitle: function( block ) {
                    const quotation = this.quotationsById[ block.quotationId ];
                    const person = this.peopleById[ block.userId ];
                    const lines = [
                        ( quotation ? [ this.quotationLabel( quotation ), quotation.kind === "project" ? quotation.rifLibero : quotation.name ].filter( Boolean ).join( " " ) : "" ),
                        this.workType( block.workTypeId ).activity + ( person ? " – " + person.name : "" ),
                        this.format( block.total ) + " h, dal " + this.formatDay( block.start ) + " " + this.blockStart( block )
                            + " al " + this.formatDay( block.end ) + " " + this.blockEnd( block ),
                    ];
                    if ( block.locked ) lines.push( "Con lucchetto" + ( block.lockedBy ? " ( " + block.lockedBy + ", " + block.lockedAt + " )" : "" ) + ": non si sposta" );
                    if ( block.extra ) lines.push( "Ore extra ( oltre la stima del progetto )" );
                    if ( block.note ) lines.push( "Note: " + block.note );
                    if ( block.useSaturday ) lines.push( "Usa i sabati" );
                    if ( block.forceHolidays ) lines.push( "Usa domeniche e festivi" );
                    return lines.filter( Boolean ).join( "\n" );
                },

                /* ---------- carico giornaliero ---------- */

                // disponibilità della persona nel giorno: 0 nei giorni non lavorativi,
                // salvo che un suo blocco li usi ( stessa regola di PlanningService.dayCapacity )
                capacity: function( person, day ) {
                    const base = person.hours[ ( day.dow + 6 ) % 7 ] || 0;
                    if ( !day.nonWorking ) return base;
                    if ( !this.openedByPersonDay[ person.id + "|" + day.key ] ) return 0;
                    return base > 0 ? base : Math.max.apply( null, person.hours.slice( 0, 5 ) );
                },

                dayLoad: function( person, day ) {
                    const planned = this.plannedByPersonDay[ person.id + "|" + day.key ] || 0;
                    const capacity = this.capacity( person, day );
                    return { planned: planned, capacity: capacity, over: planned > capacity };
                },

                loadWidth: function( person, day ) {
                    const load = this.dayLoad( person, day );
                    if ( !load.capacity ) return "100%";
                    return Math.min( 100, Math.round( load.planned / load.capacity * 100 ) ) + "%";
                },

                dayClasses: function( day ) {
                    return {
                        "non-working": !!day.nonWorking,
                        holiday: day.nonWorking && ( day.nonWorking.type === "HOL" || day.nonWorking.type === "CLO" ),
                        today: day.key === this.today,
                        "week-start": day.dow === 1,
                    };
                },

                /* ---------- operazioni sui blocchi ---------- */

                // chiamata al server; dopo l'operazione si ricaricano i dati del Gantt
                api: function( path, body, method ) {
                    return new Promise( ( resolve ) => {
                        NM.util.ajax( {
                            method: method || "POST",
                            url: BASE + "/blocks" + path,
                            data: body ? JSON.stringify( body ) : undefined,
                            callback: {
                                done: ( xhr ) => {
                                    if ( xhr.status === "ERROR" ) {
                                        AP.widget.notify( "warning", ( xhr.data && xhr.data.message ) || "Operazione non riuscita." );
                                        this.load();
                                        resolve( null );
                                        return;
                                    }
                                    this.load();
                                    resolve( xhr );
                                },
                            },
                        } );
                    } );
                },

                isSelected: function( block ) {
                    return !!this.selected && this.selected.blockId === block.id;
                },

                selectedBlock: function() {
                    return this.selected ? this.blocks.find( ( block ) => block.id === this.selected.blockId ) : null;
                },

                clearSelection: function() {
                    this.selected = null;
                    this.dayEditor = { open: false };
                },

                // in due blocchi di pari durata ( mezz'ore ): serve almeno 1 h
                canSplit: function( block ) {
                    return block.total >= 1;
                },

                // prima metà arrotondata per eccesso alla mezz'ora, come sul server
                splitHours: function( block ) {
                    const first = Math.ceil( block.total / 2 * 2 ) / 2;
                    return [ first, Math.round( ( block.total - first ) * 100 ) / 100 ];
                },

                splitSelected: function() {
                    const block = this.selectedBlock();
                    if ( !block || !this.canSplit( block ) ) return;
                    const parts = this.splitHours( block );
                    this.api( "/" + block.id + "/split", {} ).then( ( xhr ) => {
                        if ( xhr ) AP.widget.notify( "success", "Blocco diviso in " + this.format( parts[ 0 ] ) + " h + " + this.format( parts[ 1 ] ) + " h." );
                    } );
                },

                toggleFlag: function( block, flag ) {
                    const flags = { useSaturday: block.useSaturday, forceHolidays: block.forceHolidays };
                    flags[ flag ] = !flags[ flag ];
                    this.api( "/" + block.id + "/flags", flags );
                },

                deleteSelected: function() {
                    const block = this.selectedBlock();
                    if ( !block ) return;
                    bootbox.confirm( {
                        title: "Elimina blocco",
                        message: "Eliminare il blocco di " + this.format( block.total ) + " h ( " + this.barLabel( block ) + " )? Le ore tornano da pianificare.",
                        buttons: {
                            confirm: { label: "Elimina", className: "btn-danger" },
                            cancel: { label: "Annulla", className: "btn-default" },
                        },
                        callback: ( confirmed ) => {
                            if ( !confirmed ) return;
                            this.clearSelection();
                            this.api( "/" + block.id, null, "DELETE" );
                        },
                    } );
                },

                toggleDayEditor: function() {
                    this.dayEditor = { open: !this.dayEditor.open };
                    if ( this.dayEditor.open ) this.focusDayInput();
                },

                openDayEditorAt: function( event, bar ) {
                    const index = this.dayIndexAt( event, event.currentTarget.parentElement );
                    this.selected = { blockId: bar.block.id, day: this.days[ index ].key };
                    this.dayEditor = { open: true };
                    this.focusDayInput();
                },

                focusDayInput: function() {
                    this.$nextTick( () => {
                        const day = this.selected && this.selected.day;
                        const refs = day && this.$refs[ "dayInput-" + day ];
                        const input = Array.isArray( refs ) ? refs[ 0 ] : refs;
                        if ( input ) {
                            input.focus();
                            input.select();
                        }
                    } );
                },

                setDayHours: function( block, day, value ) {
                    const hours = Math.max( 0, Number( String( value ).replace( ",", "." ) ) || 0 );
                    this.selected = { blockId: block.id, day: day };
                    this.api( "/" + block.id + "/day", { day: day, hours: hours } );
                },

                // pulsanti sotto la barra selezionata
                toolbarStyle: function( bar ) {
                    const left = Math.max( 0, bar.left );
                    return {
                        left: left + "px",
                        top: ( ROW_PADDING / 2 + ( bar.lane + 1 ) * this.laneHeight() ) + "px",
                    };
                },

                /* ---------- orari del blocco ---------- */

                timeOptions: function() {
                    return TIME_OPTIONS;
                },

                blockStart: function( block ) {
                    return formatTime( block.days[ 0 ].start );
                },

                blockEnd: function( block ) {
                    const last = block.days[ block.days.length - 1 ];
                    return formatTime( last.start + Math.round( last.hours * 60 ) );
                },

                // "start" o "end": la durata resta la stessa, l'altro orario si adegua
                setBlockTime: function( block, which, value ) {
                    const body = {};
                    body[ which ] = value;
                    this.api( "/" + block.id + "/times", body );
                },

                setBlockNote: function( block, note ) {
                    if ( ( note || "" ).trim() === ( block.note || "" ) ) return;
                    this.api( "/" + block.id + "/note", { note: note } );
                },

                quotationOf: function( block ) {
                    return this.quotationsById[ block.quotationId ] || null;
                },

                /* ---------- trascinamento da "Da pianificare" ---------- */

                startBacklogDrag: function( event, quotation, chip ) {
                    this.clearSelection();
                    this.dragging = {
                        kind: "backlog",
                        quotationId: quotation.id,
                        workTypeId: chip.workTypeId,
                        // 0: già tutto pianificato, al rilascio si apre la nuova attività ( extra )
                        hours: chip.remaining,
                        label: this.quotationLabel( quotation ),
                    };
                    event.dataTransfer.effectAllowed = "copy";
                    event.dataTransfer.setData( "text/plain", quotation.id );
                    if ( this.groupBy !== "people" ) {
                        AP.widget.notify( "info", "Per pianificare trascina sulla vista Persone." );
                    }
                },

                endBacklogDrag: function() {
                    this.dragging = null;
                    this.dropTarget = null;
                },

                // persone che hanno la tipologia dell'attività
                canAssign: function( person, workTypeId ) {
                    return person.workTypeIds.indexOf( workTypeId ) !== -1;
                },

                canDropOn: function( row ) {
                    if ( !this.dragging || !row.person ) return false;
                    // persona trascinata: solo sui giorni della sua riga
                    if ( this.dragging.kind === "person" ) return row.person.id === this.dragging.person.id;
                    return this.canAssign( row.person, this.dragging.workTypeId );
                },

                /* ---------- attività extra: persona trascinata su un giorno ---------- */

                personDragHint: function() {
                    return "Trascina su un giorno per aggiungere un'attività ( es. ore extra )";
                },

                startPersonDrag: function( event, person ) {
                    this.clearSelection();
                    this.dragging = { kind: "person", person: person };
                    event.dataTransfer.effectAllowed = "copy";
                    event.dataTransfer.setData( "text/plain", person.id );
                },

                // progetti aperti: pianificabili e non conclusi, dal più recente
                openProjects: function() {
                    return this.quotations
                        .filter( function( quotation ) { return quotation.plannable && quotation.assignable; } )
                        .slice()
                        .sort( function( a, b ) {
                            return ( Number( b.number ) - Number( a.number ) ) || ( Number( b.version ) - Number( a.version ) );
                        } );
                },

                projectOptionLabel: function( quotation ) {
                    return [ this.quotationLabel( quotation ), quotation.customer, quotation.rifLibero ].filter( Boolean ).join( " · " );
                },

                // attività possibili per la persona: le sue tipologie
                personActivities: function( person ) {
                    if ( !person ) return [];
                    return this.workTypes.filter( function( type ) { return person.workTypeIds.indexOf( type.id ) !== -1; } );
                },

                // preset: { quotationId, workTypeId } ( riquadro senza ore residue )
                openExtraModal: function( person, dayKey, preset ) {
                    preset = preset || {};
                    // ore di default: quelle che la persona lavora normalmente quel giorno
                    let hours = person.hours[ ( parseDay( dayKey ).getDay() + 6 ) % 7 ] || 0;
                    if ( !hours ) hours = Math.max.apply( null, person.hours.slice( 0, 5 ) ) || 8;

                    this.extraForm = {
                        person: person,
                        day: dayKey,
                        quotationId: preset.quotationId || "",
                        workTypeId: preset.workTypeId || person.workTypeIds[ 0 ] || "",
                        hours: hours,
                        startTime: "",
                        note: "",
                        extra: true,
                    };
                    NM.util.openModal( $( "#pg-extra-modal" ) );
                },

                // "+" della persona: oggi se è nel periodo visibile, altrimenti il primo giorno
                openExtraFor: function( person ) {
                    const day = this.dayIndex[ this.today ] !== undefined ? this.today : this.days[ 0 ].key;
                    this.openExtraModal( person, day );
                },

                // giorno della nuova attività, con il tipo se non lavorativo ( se è nel periodo visibile )
                extraDayNote: function() {
                    const key = this.extraForm.day;
                    const day = key && this.days.find( function( item ) { return item.key === key; } );
                    return day && day.nonWorking ? day.nonWorking.name : "";
                },

                saveExtra: function() {
                    const form = this.extraForm;
                    if ( !/^\d{4}-\d{2}-\d{2}$/.test( form.day || "" ) ) {
                        AP.widget.notify( "warning", "Scegli il giorno." );
                        return;
                    }
                    if ( !form.quotationId ) {
                        AP.widget.notify( "warning", "Scegli il progetto." );
                        return;
                    }
                    const hours = Number( form.hours );
                    if ( !( hours > 0 ) || ( hours * 2 ) % 1 !== 0 ) {
                        AP.widget.notify( "warning", "Indica le ore, a passi di mezz'ora." );
                        return;
                    }

                    $( "#pg-extra-modal" ).modal( "hide" );
                    this.api( "", {
                        quotationId: form.quotationId,
                        userId: form.person.id,
                        workTypeId: form.workTypeId,
                        start: form.day,
                        hours: hours,
                        extra: form.extra,
                        startTime: form.startTime,
                        note: form.note,
                    } ).then( ( xhr ) => {
                        if ( xhr ) {
                            AP.widget.notify( "success", this.format( hours ) + " h " + ( form.extra ? "extra " : "" ) + "pianificate a " + form.person.name + "." );
                        }
                    } );
                },

                toggleExtra: function( block ) {
                    this.api( "/" + block.id + "/extra", { extra: !block.extra } );
                },

                // lucchetto: lo mette chiunque, lo toglie solo un ADM
                canToggleLock: function( block ) {
                    return !block.locked || this.isAdmin;
                },

                toggleLock: function( block ) {
                    if ( !this.canToggleLock( block ) ) return;
                    this.api( "/" + block.id + "/lock", { locked: !block.locked } ).then( ( xhr ) => {
                        if ( xhr ) AP.widget.notify( "success", block.locked ? "Lucchetto tolto." : "Blocco con lucchetto: non si può più spostare." );
                    } );
                },

                lockTitle: function( block ) {
                    if ( !block.locked ) return "Lucchetto: il blocco non si potrà più spostare né modificare";
                    const by = block.lockedBy ? " da " + block.lockedBy + " il " + block.lockedAt : "";
                    return "Bloccato" + by + ( this.isAdmin ? ". Clic per togliere il lucchetto" : ". Solo un amministratore può toglierlo" );
                },

                backlogDragOver: function( event, row ) {
                    if ( !this.canDropOn( row ) ) return;
                    event.preventDefault();
                    event.dataTransfer.dropEffect = "copy";
                    const index = this.dayIndexAt( event, event.currentTarget );
                    if ( !this.dropTarget || this.dropTarget.rowKey !== row.key || this.dropTarget.index !== index ) {
                        this.dropTarget = { rowKey: row.key, index: index };
                    }
                },

                backlogDragLeave: function( row ) {
                    // il passaggio da una cella all'altra genera dragleave: si pulisce a fine trascinamento
                },

                backlogDrop: function( event, row ) {
                    if ( !this.canDropOn( row ) ) return;
                    event.preventDefault();

                    const payload = this.dragging;
                    const start = this.days[ this.dayIndexAt( event, event.currentTarget ) ].key;
                    this.endBacklogDrag();

                    // persona trascinata su un giorno: nuova attività ( extra ) da completare
                    if ( payload.kind === "person" ) {
                        this.openExtraModal( row.person, start );
                        return;
                    }
                    // attività senza ore residue: nuova attività ( extra ) già impostata
                    if ( !( payload.hours > 0 ) ) {
                        this.openExtraModal( row.person, start, { quotationId: payload.quotationId, workTypeId: payload.workTypeId } );
                        return;
                    }

                    this.api( "", {
                        quotationId: payload.quotationId,
                        userId: row.person.id,
                        workTypeId: payload.workTypeId,
                        start: start,
                        hours: payload.hours,
                    } ).then( ( xhr ) => {
                        if ( xhr ) {
                            AP.widget.notify( "success", this.format( payload.hours ) + " h di " + this.workType( payload.workTypeId ).activity.toLowerCase()
                                + " del " + payload.label + " pianificate a " + row.person.name + "." );
                        }
                    } );
                },

                rowDropClasses: function( row ) {
                    if ( !this.dragging ) return {};
                    return { "drop-ok": this.canDropOn( row ), "drop-no": !this.canDropOn( row ) };
                },

                cellClasses: function( day, row, index ) {
                    const classes = this.dayClasses( day );
                    classes[ "drop-day" ] = !!this.dropTarget && this.dropTarget.rowKey === row.key && this.dropTarget.index === index;
                    return classes;
                },

                // indice del giorno sotto il puntatore, rispetto all'area dei giorni della riga
                dayIndexAt: function( event, laneArea ) {
                    const rect = laneArea.getBoundingClientRect();
                    const index = Math.floor( ( event.clientX - rect.left ) / this.colWidth );
                    return Math.min( Math.max( index, 0 ), this.days.length - 1 );
                },

                /* ---------- trascinamento / ridimensionamento di una barra ---------- */

                startBarDrag: function( event, bar, row ) {
                    if ( event.button !== 0 ) return;
                    event.preventDefault();

                    const element = event.currentTarget;
                    pointer = {
                        mode: "move",
                        element: element,
                        bar: bar,
                        // con il lucchetto si può solo selezionare
                        locked: bar.block.locked,
                        startX: event.clientX,
                        startY: event.clientY,
                        moved: false,
                        dayDelta: 0,
                        clickDay: this.days[ this.dayIndexAt( event, element.parentElement ) ].key,
                        targetUserId: null,
                        targetRow: null,
                    };
                },

                startBarResize: function( event, bar ) {
                    if ( event.button !== 0 ) return;
                    event.preventDefault();

                    const element = event.currentTarget.parentElement;
                    pointer = {
                        mode: "resize",
                        element: element,
                        bar: bar,
                        startX: event.clientX,
                        startY: event.clientY,
                        moved: false,
                        dayDelta: 0,
                        originalWidth: element.style.width,
                        originalPixels: element.offsetWidth,
                    };
                },

                onPointerMove: function( event ) {
                    if ( !pointer ) return;

                    const dx = event.clientX - pointer.startX;
                    const dy = event.clientY - pointer.startY;
                    if ( !pointer.moved && Math.abs( dx ) < 4 && Math.abs( dy ) < 4 ) return;

                    if ( pointer.locked ) {
                        if ( !pointer.warned ) {
                            pointer.warned = true;
                            AP.widget.notify( "info", "Il blocco ha il lucchetto: non si può spostare." );
                        }
                        return;
                    }

                    if ( !pointer.moved ) {
                        pointer.moved = true;
                        this.clearSelection();
                        pointer.element.classList.add( "dragging" );
                        // il puntatore deve "vedere" le righe sotto la barra trascinata
                        pointer.element.style.pointerEvents = "none";
                    }

                    pointer.dayDelta = Math.round( dx / this.colWidth );

                    if ( pointer.mode === "resize" ) {
                        const span = Math.max( 1, pointer.bar.span + pointer.dayDelta );
                        pointer.dayDelta = span - pointer.bar.span;
                        pointer.element.style.width = Math.max( 8, pointer.originalPixels + pointer.dayDelta * this.colWidth ) + "px";
                        return;
                    }

                    // spostamento: in verticale solo nella vista Persone, su persone dello stesso tipo
                    const vertical = this.groupBy === "people" ? dy : 0;
                    pointer.element.style.transform = "translate(" + ( pointer.dayDelta * this.colWidth ) + "px, " + vertical + "px)";

                    if ( this.groupBy === "people" ) {
                        const under = document.elementFromPoint( event.clientX, event.clientY );
                        const rowElement = under && under.closest( ".pg-row" );
                        const person = rowElement && this.peopleById[ rowElement.dataset.personId ];

                        if ( pointer.targetRow && pointer.targetRow !== rowElement ) {
                            pointer.targetRow.classList.remove( "drop-ok", "drop-no" );
                        }
                        pointer.targetRow = rowElement || null;
                        pointer.targetUserId = null;

                        if ( rowElement && person ) {
                            const valid = this.canAssign( person, pointer.bar.block.workTypeId );
                            rowElement.classList.add( valid ? "drop-ok" : "drop-no" );
                            if ( valid ) pointer.targetUserId = person.id;
                        }
                    }
                },

                onPointerUp: function() {
                    if ( !pointer ) return;

                    const state = pointer;
                    pointer = null;

                    state.element.classList.remove( "dragging" );
                    state.element.style.pointerEvents = "";
                    state.element.style.transform = "";
                    if ( state.originalWidth !== undefined ) state.element.style.width = state.originalWidth;
                    if ( state.targetRow ) state.targetRow.classList.remove( "drop-ok", "drop-no" );

                    const block = state.bar.block;

                    // senza movimento è un click: selezione e giorno cliccato
                    if ( !state.moved ) {
                        if ( state.mode === "move" ) {
                            this.selected = { blockId: block.id, day: state.clickDay };
                            this.dayEditor = { open: false };
                        }
                        return;
                    }

                    if ( state.mode === "resize" ) {
                        if ( !state.dayDelta ) return;
                        const end = dayKey( addDays( parseDay( block.end ), state.dayDelta ) );
                        this.api( "/" + block.id + "/resize", { end: end } );
                        return;
                    }

                    const userId = state.targetUserId || block.userId;
                    if ( !state.dayDelta && userId === block.userId ) return;

                    const start = dayKey( addDays( parseDay( block.start ), state.dayDelta ) );
                    this.api( "/" + block.id + "/move", { start: start, userId: userId } );
                },

                /* ---------- pianificazione automatica ---------- */

                autoPlanCall: function( apply ) {
                    this.autoPlan.loading = true;
                    return new Promise( ( resolve ) => {
                        NM.util.ajax( {
                            method: "POST",
                            url: BASE + "/auto-plan",
                            data: JSON.stringify( { apply: apply } ),
                            callback: {
                                done: ( xhr ) => {
                                    if ( xhr.status === "ERROR" ) {
                                        AP.widget.notify( "error", ( xhr.data && xhr.data.message ) || "Pianificazione non riuscita." );
                                        resolve( null );
                                        return;
                                    }
                                    resolve( xhr.data );
                                },
                            },
                        } ).always( () => { this.autoPlan.loading = false; } );
                    } );
                },

                openAutoPlan: async function() {
                    this.clearSelection();
                    const result = await this.autoPlanCall( false );
                    if ( !result ) return;
                    this.autoPlan.result = result;
                    this.$nextTick( () => NM.util.openModal( $( "#pg-auto-modal" ) ) );
                },

                applyAutoPlan: async function() {
                    const result = await this.autoPlanCall( true );
                    if ( !result ) return;
                    $( "#pg-auto-modal" ).modal( "hide" );
                    this.load();
                    const late = result.items.filter( function( item ) { return item.late; } ).length;
                    AP.widget.notify( late ? "warning" : "success", "Pianificazione applicata: " + result.created + " blocchi"
                        + ( late ? ", " + late + " voci in ritardo." : "." ) );
                },

                /* ---------- utilità ---------- */

                workType: function( id ) {
                    return this.workTypes.find( function( type ) { return type.id === id; } ) || { name: id, activity: id, color: "#868e96" };
                },

                /* ---------- pianificazione della voce ( stato, priorità, data, note ) ---------- */

                openItemInfo: function( quotation ) {
                    this.itemInfo = quotation;
                    NM.util.openModal( $( "#pg-item-modal" ) );
                },

                // nome di un valore delle tendine di pianificazione ( vuoto se non impostato )
                optionName: function( list, id ) {
                    const option = ( list || [] ).find( function( item ) { return item.id === id; } );
                    return option ? option.name : "";
                },

                dueTitle: function( quotation ) {
                    const type = this.optionName( this.options.dateTypes, quotation.dateType );
                    return "Data" + ( type ? " ( " + type.toLowerCase() + " )" : "" ) + ": " + this.formatDayLong( quotation.dueDate );
                },

                // colonna della data di consegna nell'intervallo visibile ( -1 se fuori )
                dueIndex: function( quotation ) {
                    if ( !quotation.dueDate ) return -1;
                    const index = this.dayIndex[ quotation.dueDate ];
                    return index === undefined ? -1 : index;
                },

                // "n. 123/1" per i preventivi, il nome per i progetti ( dal server )
                quotationLabel: function( quotation ) {
                    return quotation.label || ( "n. " + quotation.number + ( quotation.version ? "/" + quotation.version : "" ) );
                },

                // sotto il titolo di una voce: cliente ( o nome ) del preventivo; per un
                // progetto il rif. libero e i preventivi collegati
                itemSubtitle: function( quotation ) {
                    if ( quotation.kind === "project" ) {
                        const linked = ( quotation.quotations || [] ).map( function( linkedQuotation ) { return linkedQuotation.label; } );
                        return [ quotation.rifLibero ].concat( linked ).filter( Boolean ).join( " · " );
                    }
                    return quotation.customer || quotation.name;
                },

                format: function( value ) {
                    return ( Math.round( ( Number( value ) || 0 ) * 100 ) / 100 ).toLocaleString( "it-IT" );
                },

                formatDay: function( key ) {
                    return parseDay( key ).toLocaleDateString( "it-IT", { day: "2-digit", month: "2-digit" } );
                },

                formatDayLong: function( key ) {
                    return parseDay( key ).toLocaleDateString( "it-IT", { weekday: "short", day: "2-digit", month: "2-digit" } );
                },
            },
        } );
    };

    return pub;
}() );

$( document ).ready( function() {
    if ( document.getElementById( "planning-gantt-app" ) ) {
        AP.planningGantt.init();
    }
} );
