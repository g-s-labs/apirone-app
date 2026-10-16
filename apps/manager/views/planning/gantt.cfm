<cfoutput>
<!---
    PLANNING/GANTT.CFM
    ==================
    Calendario ( Gantt ) della pianificazione: persone sui preventivi attivi ( qualunque stato
    tranne Perso ed Estinto ) e sui progetti. App Vue 2 montata su ##planning-gantt-app ( logica in
    app-planning-gantt.js, stile in css/planning.css ).

    - Viste giornaliera ( 2 settimane ), settimanale ( 6 settimane ), mensile
      ( mese di calendario, default sul mese corrente ).
    - Raggruppamento per Persone ( righe per tipo di lavoro, barre con il numero
      del preventivo ) o per Preventivi ( righe per tipo di attività, barre con il
      nome della persona ). I colori sono solo dei tipi di attività.
    - Colonna "Da pianificare": ore stimate, prima quelle non ancora pianificate.
--->
<script src="/assets/#prc.staticVersion#/main/js/vue2.js"></script>

<div id="planning-gantt-app" class="planning-gantt" v-cloak>

    <!--- ======================= BARRA ======================= --->
    <div class="pg-toolbar">
        <div class="pg-toolbar-title">
            #pageTitle()#
        </div>

        <div class="btn-group btn-group-sm" role="group">
            <button type="button" class="btn" :class="scale === 'day' ? 'btn-primary' : 'btn-default'" @click="setScale( 'day' )">Giorno</button>
            <button type="button" class="btn" :class="scale === 'week' ? 'btn-primary' : 'btn-default'" @click="setScale( 'week' )">Settimana</button>
            <button type="button" class="btn" :class="scale === 'month' ? 'btn-primary' : 'btn-default'" @click="setScale( 'month' )">Mese</button>
        </div>

        <div class="pg-period">
            <button type="button" class="btn btn-default btn-sm" @click="move( -1 )" title="Precedente"><i class="fas fa-chevron-left"></i></button>
            <button type="button" class="btn btn-default btn-sm" @click="goToday">Oggi</button>
            <button type="button" class="btn btn-default btn-sm" @click="move( 1 )" title="Successivo"><i class="fas fa-chevron-right"></i></button>
            <strong class="pg-period-label">{{ periodLabel }}</strong>
            <i v-if="loading" class="fas fa-spinner fa-spin text-muted"></i>
        </div>

        <!--- pianificazione automatica: anteprima, poi conferma --->
        <button type="button" class="btn btn-default btn-sm ms-auto" @click="openAutoPlan" :disabled="autoPlan.loading"
                title="Ripianifica le attività dei preventivi e progetti in corso e da programmare ( anteprima prima di salvare )">
            <i class="fas" :class="autoPlan.loading ? 'fa-spinner fa-spin' : 'fa-magic'"></i> Pianifica
        </button>

        <div class="btn-group btn-group-sm" role="group">
            <button type="button" class="btn" :class="groupBy === 'people' ? 'btn-primary' : 'btn-default'" @click="setGroupBy( 'people' )">
                <i class="fas fa-users"></i> Persone
            </button>
            <button type="button" class="btn" :class="groupBy === 'quotations' ? 'btn-primary' : 'btn-default'" @click="setGroupBy( 'quotations' )">
                <i class="fas fa-file-invoice"></i> Preventivi
            </button>
        </div>
    </div>

    <div class="pg-body">

        <!--- ======================= DA PIANIFICARE ======================= --->
        <aside class="pg-backlog" :class="{ collapsed: backlogCollapsed }">
            <div class="pg-backlog-header" @click="toggleBacklog">
                <span v-if="!backlogCollapsed"><i class="fas fa-inbox"></i> Da pianificare</span>
                <i class="fas" :class="backlogCollapsed ? 'fa-chevron-right' : 'fa-chevron-left'"></i>
            </div>

            <div class="pg-backlog-list" v-if="!backlogCollapsed">
                <div v-if="!backlog.length" class="text-muted small p-2">
                    Nessuna ora da pianificare. Le ore dei progetti si inseriscono in
                    <a href="/manager/planning/projects">Ore progetti</a>.
                </div>

                <div v-for="item in backlog" :key="item.quotation.id" class="pg-backlog-quotation"
                     :class="[ { 'pg-backlog-done': !item.remaining }, dueState( item.quotation ) ? 'pg-due-' + dueState( item.quotation ) : '' ]">
                    <div class="pg-backlog-quotation-title">
                        <!--- preventivo: link alla pagina; progetto: il nome ( si gestisce in Ore progetti ) --->
                        <i class="fas text-muted" :class="item.quotation.kind === 'project' ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                        <!--- scaduto / in scadenza entro 30 giorni --->
                        <i v-if="dueState( item.quotation )" class="fas pg-due-alert"
                           :class="dueState( item.quotation ) === 'overdue' ? 'fa-exclamation-circle' : 'fa-exclamation-triangle'"
                           :title="dueStateTitle( item.quotation )"></i>
                        <a v-if="item.quotation.url" :href="item.quotation.url" target="_blank">{{ quotationLabel( item.quotation ) }}</a>
                        <a v-else href="/manager/planning/projects" target="_blank" title="Progetto: si gestisce in Ore progetti">{{ quotationLabel( item.quotation ) }}</a>
                    </div>
                    <div class="pg-backlog-customer" v-if="itemSubtitle( item.quotation )">{{ itemSubtitle( item.quotation ) }}</div>
                    <!--- priorità, data con tipo, note ( dettagli al clic ) --->
                    <div class="pg-item-meta" v-if="item.quotation.planningStatusId !== 'COR' || item.quotation.priority || item.quotation.dueDate || item.quotation.note">
                        <span v-if="item.quotation.planningStatusId !== 'COR'" class="pg-planning-status">{{ optionName( options.statuses, item.quotation.planningStatusId ) }}</span>
                        <span v-if="item.quotation.priority" class="pg-priority" :class="'pg-priority-' + item.quotation.priority"
                              :title="optionName( options.priorities, item.quotation.priority )">{{ item.quotation.priority }}</span>
                        <span v-if="item.quotation.dueDate" class="pg-due" :class="{ tassativa: item.quotation.dateType === 'TAS' }"
                              :title="dueTitle( item.quotation )"><i class="far fa-calendar"></i> {{ formatDay( item.quotation.dueDate ) }}</span>
                        <a v-if="item.quotation.note" href="##" class="pg-note-link" @click.prevent="openItemInfo( item.quotation )" title="Note e dettagli">
                            <i class="fas fa-sticky-note"></i> note
                        </a>
                    </div>
                    <!--- riquadri da trascinare su una persona del tipo giusto, nel giorno di inizio;
                          a 0 h ( tutto pianificato ) si trascinano per aggiungere ore extra --->
                    <div class="pg-backlog-chips">
                        <span v-for="chip in item.chips" :key="chip.workTypeId" class="pg-chip pg-chip-draggable"
                              :class="{ 'pg-chip-done': !chip.remaining }"
                              draggable="true"
                              @dragstart="startBacklogDrag( $event, item.quotation, chip )"
                              @dragend="endBacklogDrag"
                              :style="{ borderColor: workType( chip.workTypeId ).color }"
                              :title="workType( chip.workTypeId ).activity + ': ' + format( chip.planned ) + ' h pianificate su ' + format( chip.estimated ) + ' h. '
                                  + ( chip.remaining ? 'Trascina su una persona per pianificare.' : 'Tutto pianificato: trascina su una persona per aggiungere ore extra.' )">
                            <span class="pg-chip-dot" :style="{ backgroundColor: workType( chip.workTypeId ).color }"></span>
                            {{ workType( chip.workTypeId ).activity }}
                            <strong>{{ format( chip.remaining ) }} h</strong>
                        </span>
                    </div>
                </div>
            </div>
        </aside>

        <!--- ======================= GRIGLIA ======================= --->
        <div class="pg-grid" ref="grid">

            <div class="pg-scroll" ref="scroll">
                <div class="pg-canvas" :style="{ width: ( labelWidth + days.length * colWidth ) + 'px' }">

                    <!--- intestazione: mesi / settimane e giorni --->
                    <div class="pg-header">
                        <div class="pg-corner" :style="{ width: labelWidth + 'px' }">
                            {{ groupBy === 'people' ? 'Persona' : 'Preventivo' }}
                        </div>
                        <div class="pg-header-days">
                            <div class="pg-header-top">
                                <div v-for="span in headerSpans" :key="span.key" class="pg-header-span"
                                     :style="{ width: ( span.count * colWidth ) + 'px' }">{{ span.label }}</div>
                            </div>
                            <div class="pg-header-bottom">
                                <div v-for="day in days" :key="day.key" class="pg-header-day"
                                     :class="dayClasses( day )" :style="{ width: colWidth + 'px' }"
                                     :title="day.nonWorking ? day.nonWorking.name : ''">
                                    <span class="pg-dow">{{ day.dowLabel }}</span>
                                    <span class="pg-dom">{{ day.dom }}</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!--- righe --->
                    <template v-for="group in rowGroups">
                        <div class="pg-group-row" :key="'g-' + group.key" @click="toggleGroup( group.key )"
                             :class="dueState( group.item ) ? 'pg-due-' + dueState( group.item ) : ''">
                            <div class="pg-label pg-group-label" :style="{ width: labelWidth + 'px' }">
                                <i class="fas" :class="collapsedGroups[ group.key ] ? 'fa-caret-right' : 'fa-caret-down'"></i>
                                <span v-if="group.color" class="pg-swatch" :style="{ backgroundColor: group.color }"></span>
                                <i v-else class="fas text-muted" :class="group.project ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                                <!--- scaduto / in scadenza entro 30 giorni --->
                                <i v-if="dueState( group.item )" class="fas pg-due-alert"
                                   :class="dueState( group.item ) === 'overdue' ? 'fa-exclamation-circle' : 'fa-exclamation-triangle'"
                                   :title="dueStateTitle( group.item )"></i>
                                <!--- clic sul nome del preventivo / progetto: dettagli e note ( sul resto della riga: apri / chiudi ) --->
                                <span class="pg-group-title" :class="{ 'pg-group-title-link': group.item }"
                                      @click="group.item && ( $event.stopPropagation(), openItemInfo( group.item ) )"
                                      :title="group.item ? 'Dettagli e note' : ''">{{ group.title }}</span>
                                <!--- preventivo / progetto: priorità, stato se non in corso, data; clic sull'icona: dettagli e note --->
                                <template v-if="group.item">
                                    <span v-if="group.item.priority" class="pg-priority" :class="'pg-priority-' + group.item.priority"
                                          :title="optionName( options.priorities, group.item.priority )">{{ group.item.priority }}</span>
                                    <span v-if="group.item.planningStatusId !== 'COR'" class="pg-planning-status"
                                          :title="group.item.assignable ? 'Stato in Ore progetti' : 'Non si possono assegnare persone: cambia lo stato in Ore progetti'">{{ optionName( options.statuses, group.item.planningStatusId ) }}</span>
                                    <span v-if="group.item.dueDate" class="pg-due" :class="{ tassativa: group.item.dateType === 'TAS' }"
                                          :title="dueTitle( group.item )"><i class="far fa-calendar"></i> {{ formatDay( group.item.dueDate ) }}</span>
                                    <i class="fas pg-info-icon" :class="group.item.note ? 'fa-sticky-note has-note' : 'fa-info-circle'"
                                       @click.stop="openItemInfo( group.item )" :title="group.item.note ? 'Note e dettagli' : 'Dettagli'"></i>
                                </template>
                                <span class="pg-group-subtitle" v-if="group.subtitle">{{ group.subtitle }}</span>
                            </div>
                            <div class="pg-group-fill" :style="{ width: ( days.length * colWidth ) + 'px' }">
                                <!--- data di consegna sulla riga del preventivo / progetto: rossa se tassativa --->
                                <span v-if="group.item && dueIndex( group.item ) !== -1" class="pg-due-marker"
                                      :class="{ tassativa: group.item.dateType === 'TAS' }"
                                      :style="{ left: ( dueIndex( group.item ) * colWidth + colWidth / 2 ) + 'px' }"
                                      :title="dueTitle( group.item )"><i class="fas fa-flag"></i></span>
                            </div>
                        </div>

                        <template v-if="!collapsedGroups[ group.key ]">
                            <div v-for="row in group.rows" :key="row.key" class="pg-row"
                                 :class="rowDropClasses( row )"
                                 :data-row-key="row.key"
                                 :data-person-id="row.person ? row.person.id : ''"
                                 :style="{ height: rowHeight( row ) + 'px' }">

                                <!--- vista Persone: il nome si trascina su un giorno per aggiungere un'attività ( extra ) --->
                                <div class="pg-label" :class="{ 'pg-label-draggable': !!row.person }" :style="{ width: labelWidth + 'px' }"
                                     :draggable="!!row.person"
                                     :title="row.person ? personDragHint() : ''"
                                     @dragstart="row.person && startPersonDrag( $event, row.person )"
                                     @dragend="endBacklogDrag">
                                    <div class="pg-label-title">
                                        <span v-if="row.dotColor" class="pg-chip-dot" :style="{ backgroundColor: row.dotColor }"></span>
                                        {{ row.title }}
                                        <i v-if="row.person && !row.person.active" class="fas fa-user-slash pg-no-access" title="Senza accesso all'app"></i>
                                        <!--- nuova attività ex novo ( come trascinare il nome su un giorno ) --->
                                        <button v-if="row.person" type="button" class="btn btn-default btn-xs pg-add-activity"
                                                @click.stop="openExtraFor( row.person )" @pointerdown.stop draggable="false"
                                                title="Nuova attività ( es. ore extra )"><i class="fas fa-plus"></i></button>
                                    </div>
                                    <div class="pg-label-subtitle" v-if="row.subtitle">{{ row.subtitle }}</div>
                                </div>

                                <div class="pg-lane-area" :style="{ width: ( days.length * colWidth ) + 'px' }"
                                     @dragover="backlogDragOver( $event, row )"
                                     @dragleave="backlogDragLeave( row )"
                                     @drop="backlogDrop( $event, row )">
                                    <!--- celle dei giorni, con il carico della persona --->
                                    <div v-for="( day, dayIndexInRow ) in days" :key="day.key" class="pg-cell"
                                         :class="cellClasses( day, row, dayIndexInRow )"
                                         :style="{ width: colWidth + 'px' }">
                                        <div v-if="row.person && dayLoad( row.person, day ).planned > 0" class="pg-load"
                                             :class="{ over: dayLoad( row.person, day ).over }"
                                             :style="{ width: loadWidth( row.person, day ) }"
                                             :title="format( dayLoad( row.person, day ).planned ) + ' h su ' + format( dayLoad( row.person, day ).capacity ) + ' h disponibili'"></div>
                                    </div>

                                    <!--- blocchi --->
                                    <div v-for="bar in row.bars" :key="bar.block.id" class="pg-bar"
                                         :class="{ 'clipped-start': bar.clippedStart, 'clipped-end': bar.clippedEnd, compact: !bar.timed && barCompact( bar ), 'with-days': !bar.timed && showDayHours(), timed: bar.timed, extra: bar.block.extra, locked: bar.block.locked, selected: isSelected( bar.block ) }"
                                         :style="barStyle( bar )"
                                         :title="isSelected( bar.block ) ? '' : barTitle( bar.block )"
                                         @pointerdown="startBarDrag( $event, bar, row )"
                                         @dblclick="openDayEditorAt( $event, bar )">
                                        <!--- scala giornaliera: un pezzo per giorno nella sua fascia oraria, uniti da una linea --->
                                        <template v-if="bar.timed">
                                            <div class="pg-bar-link"></div>
                                            <div v-for="piece in bar.pieces" :key="'piece-' + piece.key" class="pg-bar-piece"
                                                 :class="{ compact: piece.width < 80 }"
                                                 :style="{ left: piece.left + 'px', width: piece.width + 'px', backgroundColor: barColor( bar ) }">
                                                <div class="pg-bar-top">
                                                    <i v-if="bar.block.locked" class="fas fa-lock pg-lock-icon"></i>
                                                    <span v-if="bar.block.extra && piece.width >= 80" class="pg-extra-tag">EXTRA</span>
                                                    <span class="pg-bar-label">{{ barMain( bar.block, piece.width < 80 ) }}</span>
                                                    <span v-if="piece.width >= 80" class="pg-bar-hours">{{ format( piece.hours ) }} h</span>
                                                </div>
                                                <div class="pg-bar-sub">{{ piece.width < 80 ? format( piece.hours ) + ' h' : barSub( bar.block ) }}</div>
                                                <div class="pg-bar-time">{{ piece.time }}</div>
                                            </div>
                                        </template>

                                        <template v-else>
                                            <!--- prima riga: sempre il preventivo ( vista Persone ) o la persona ( vista Preventivi ) --->
                                            <div class="pg-bar-top">
                                                <i v-if="bar.block.locked" class="fas fa-lock pg-lock-icon"></i>
                                                <span v-if="bar.block.extra && !barCompact( bar )" class="pg-extra-tag">EXTRA</span>
                                                <span class="pg-bar-label">{{ barMain( bar.block, barCompact( bar ) ) }}</span>
                                                <span v-if="!barCompact( bar )" class="pg-bar-hours">{{ format( bar.block.total ) }} h</span>
                                            </div>
                                            <!--- seconda riga: cliente / preventivo; nelle barre strette le ore --->
                                            <div class="pg-bar-sub">
                                                {{ barCompact( bar ) ? format( bar.block.total ) + ' h' : barSub( bar.block ) }}
                                            </div>
                                            <!--- scala giornaliera: le ore di ogni giorno sotto l'etichetta --->
                                            <div v-if="showDayHours()" class="pg-bar-days">
                                                <span v-for="cell in bar.cells" :key="cell.key" class="pg-bar-day"
                                                      :style="{ left: cell.left + 'px', width: colWidth + 'px' }">{{ cell.hours ? format( cell.hours ) + ' h' : '' }}</span>
                                            </div>
                                            <!--- giorni attraversati senza ore: non lavorati --->
                                            <div v-for="gap in bar.gaps" :key="'gap-' + gap.key" class="pg-bar-gap"
                                                 :style="{ left: ( gap.left - 2 ) + 'px', width: gap.width + 'px' }"
                                                 title="Giorno non lavorato"></div>
                                        </template>
                                        <!--- bordo destro: allunga / accorcia ( non con il lucchetto ) --->
                                        <div v-if="!bar.clippedEnd && !bar.block.locked" class="pg-bar-resize" title="Trascina per allungare o accorciare"
                                             @pointerdown.stop="startBarResize( $event, bar )"></div>
                                    </div>

                                    <!--- pulsanti del blocco selezionato ( come nel posizionamento in pianta ) --->
                                    <template v-for="bar in row.bars">
                                        <div v-if="isSelected( bar.block )" :key="'tb-' + bar.block.id" class="pg-block-toolbar"
                                             :style="toolbarStyle( bar )" @pointerdown.stop @click.stop @dblclick.stop>
                                            <!--- il preventivo su cui si lavora --->
                                            <div class="pg-block-toolbar-head" v-if="quotationOf( bar.block )">
                                                <div>
                                                    <strong>{{ quotationLabel( quotationOf( bar.block ) ) }}</strong>
                                                    <span v-if="quotationOf( bar.block ).customer"> · {{ quotationOf( bar.block ).customer }}</span>
                                                </div>
                                                <div v-if="quotationOf( bar.block ).rifLibero" class="pg-block-toolbar-ref">
                                                    Rif. {{ quotationOf( bar.block ).rifLibero }}
                                                </div>
                                            </div>

                                            <!--- orari: cambiandone uno l'altro si adegua alla durata --->
                                            <div class="pg-block-toolbar-times">
                                                <label>
                                                    Inizio <span class="text-muted">{{ formatDayLong( bar.block.start ) }}</span>
                                                    <select class="form-select form-select-sm" :value="blockStart( bar.block )" :disabled="bar.block.locked"
                                                            @change="setBlockTime( bar.block, 'start', $event.target.value )">
                                                        <option v-for="time in timeOptions()" :key="'s' + time" :value="time">{{ time }}</option>
                                                    </select>
                                                </label>
                                                <label>
                                                    Fine <span class="text-muted">{{ formatDayLong( bar.block.end ) }}</span>
                                                    <select class="form-select form-select-sm" :value="blockEnd( bar.block )" :disabled="bar.block.locked"
                                                            @change="setBlockTime( bar.block, 'end', $event.target.value )">
                                                        <option v-for="time in timeOptions()" :key="'e' + time" :value="time">{{ time }}</option>
                                                    </select>
                                                </label>
                                                <span class="pg-block-toolbar-total">{{ format( bar.block.total ) }} h</span>
                                            </div>

                                            <!--- nota del blocco: di cosa si tratta ( facoltativa ) --->
                                            <div class="pg-block-toolbar-note">
                                                <input type="text" class="form-control form-control-sm" maxlength="1000"
                                                       :value="bar.block.note" placeholder="Note: di cosa si tratta ( facoltativo )"
                                                       @change="setBlockNote( bar.block, $event.target.value )"
                                                       @keyup.enter="$event.target.blur()">
                                            </div>

                                            <div class="pg-block-toolbar-buttons">
                                                <button type="button" class="btn btn-default btn-xs" @click="toggleDayEditor" :class="{ active: dayEditor.open }" title="Ore di ogni giorno">
                                                    <i class="fas fa-clock"></i> Ore
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" @click="splitSelected" :disabled="bar.block.locked || !canSplit( bar.block )"
                                                        :title="canSplit( bar.block ) ? 'Dividi in due blocchi: ' + format( splitHours( bar.block )[ 0 ] ) + ' h + ' + format( splitHours( bar.block )[ 1 ] ) + ' h' : 'Servono almeno 1 h per dividere'">
                                                    <i class="fas fa-cut"></i> Dividi
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.useSaturday || bar.block.forceHolidays }"
                                                        @click="toggleFlag( bar.block, 'useSaturday' )" :disabled="bar.block.locked || bar.block.forceHolidays" title="Usa anche i sabati">
                                                    <i class="fas fa-calendar-week"></i> Sabati
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.forceHolidays }"
                                                        @click="toggleFlag( bar.block, 'forceHolidays' )" :disabled="bar.block.locked" title="Usa anche domeniche e festivi">
                                                    <i class="fas fa-calendar-plus"></i> Festivi
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.extra }"
                                                        @click="toggleExtra( bar.block )" title="Ore extra: oltre la stima del progetto, costo in più">
                                                    <i class="fas fa-plus-circle"></i> Extra
                                                </button>
                                                <a class="btn btn-default btn-xs" :href="( quotationsById[ bar.block.quotationId ] || {} ).url || '/manager/planning/projects'" target="_blank"
                                                   :title="( quotationsById[ bar.block.quotationId ] || {} ).kind === 'project' ? 'Apri Ore progetti' : 'Apri il preventivo'">
                                                    <i class="fas fa-external-link-alt"></i>
                                                </a>
                                                <!--- lucchetto: lo mette chiunque, lo toglie solo un ADM --->
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.locked }"
                                                        @click="toggleLock( bar.block )" :disabled="!canToggleLock( bar.block )" :title="lockTitle( bar.block )">
                                                    <i class="fas" :class="bar.block.locked ? 'fa-lock' : 'fa-lock-open'"></i> {{ bar.block.locked ? 'Bloccato' : 'Blocca' }}
                                                </button>
                                                <button type="button" class="btn btn-danger btn-xs" @click="deleteSelected" :disabled="bar.block.locked" title="Elimina il blocco">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" @click="clearSelection" title="Chiudi">
                                                    <i class="fas fa-times"></i>
                                                </button>
                                            </div>

                                            <!--- ore di ogni giorno, forzabili a mano --->
                                            <div v-if="dayEditor.open" class="pg-day-editor">
                                                <div v-for="day in bar.block.days" :key="day.day" class="pg-day-editor-row"
                                                     :class="{ current: selected.day === day.day }">
                                                    <span class="pg-day-editor-label">{{ formatDayLong( day.day ) }}</span>
                                                    <input type="number" min="0" max="24" step="0.5" class="form-control form-control-sm"
                                                           :disabled="bar.block.locked" :value="day.hours" @change="setDayHours( bar.block, day.day, $event.target.value )"
                                                           :ref="'dayInput-' + day.day">
                                                    <span>h</span>
                                                </div>
                                                <div class="small text-muted mt-1">0 toglie il giorno dal blocco.</div>
                                            </div>
                                        </div>
                                    </template>
                                </div>
                            </div>

                            <div v-if="!group.rows.length" class="pg-row pg-row-empty">
                                <div class="pg-label text-muted" :style="{ width: labelWidth + 'px' }">{{ group.emptyText }}</div>
                                <div class="pg-lane-area" :style="{ width: ( days.length * colWidth ) + 'px' }"></div>
                            </div>
                        </template>
                    </template>

                    <div v-if="!rowGroups.length && !loading" class="pg-empty">
                        <template v-if="groupBy === 'people'">
                            Nessuna persona da pianificare: assegna un tipo di lavoro dalla pagina
                            <a href="/manager/planning/people">Disponibilità persone</a>.
                        </template>
                        <template v-else>
                            Nessun preventivo in corso o da programmare ( si escludono i persi, gli estinti, i conclusi e i sospesi ).
                        </template>
                    </div>

                </div>
            </div>

            <!--- nuova attività ( extra ): persona trascinata su un giorno --->
            <!--- dettagli di un preventivo / progetto: pianificazione e note ( si modificano in Ore progetti ) --->
            <div id="pg-item-modal" class="modal fade" tabindex="-1">
                <section class="modal-dialog">
                    <div class="modal-content" v-if="itemInfo">
                        <header class="modal-header">
                            <h5 class="modal-title">
                                <i class="fas text-muted" :class="itemInfo.kind === 'project' ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                                {{ quotationLabel( itemInfo ) }}
                            </h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </header>
                        <div class="modal-body">
                            <div class="text-muted mb-2" v-if="itemSubtitle( itemInfo )">{{ itemSubtitle( itemInfo ) }}</div>
                            <dl class="row mb-2 pg-item-details">
                                <dt class="col-4">Stato</dt>
                                <dd class="col-8">{{ optionName( options.statuses, itemInfo.planningStatusId ) }}</dd>
                                <dt class="col-4">Priorità</dt>
                                <dd class="col-8">{{ optionName( options.priorities, itemInfo.priority ) || "—" }}</dd>
                                <dt class="col-4">Data</dt>
                                <dd class="col-8">
                                    <template v-if="itemInfo.dueDate">
                                        {{ formatDayLong( itemInfo.dueDate ) }}
                                        <span v-if="itemInfo.dateType" class="pg-due ms-1" :class="{ tassativa: itemInfo.dateType === 'TAS' }">{{ optionName( options.dateTypes, itemInfo.dateType ) }}</span>
                                    </template>
                                    <template v-else>—</template>
                                </dd>
                                <template v-if="itemInfo.kind !== 'project'">
                                    <dt class="col-4">Evasione prevista</dt>
                                    <dd class="col-8">{{ itemInfo.deliveryDate ? formatDayLong( itemInfo.deliveryDate ) : "—" }}</dd>
                                </template>
                            </dl>
                            <label class="form-label fw-bold mb-1">Note</label>
                            <div class="pg-item-note" v-if="itemInfo.note">{{ itemInfo.note }}</div>
                            <div class="text-muted small" v-else>Nessuna nota.</div>
                        </div>
                        <footer class="modal-footer">
                            <a v-if="itemInfo.url" :href="itemInfo.url" target="_blank" class="btn btn-default">
                                <i class="fas fa-external-link-alt"></i> Apri il preventivo
                            </a>
                            <a href="/manager/planning/projects" target="_blank" class="btn btn-primary">
                                <i class="fas fa-pen"></i> Modifica in Ore progetti
                            </a>
                        </footer>
                    </div>
                </section>
            </div>

            <!--- pianificazione automatica: anteprima di cosa cambierebbe, poi conferma --->
            <div id="pg-auto-modal" class="modal fade" tabindex="-1">
                <section class="modal-dialog modal-xl modal-dialog-scrollable">
                    <div class="modal-content" v-if="autoPlan.result">
                        <header class="modal-header">
                            <h5 class="modal-title"><i class="fas fa-magic text-muted"></i> Pianificazione automatica: anteprima</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </header>
                        <div class="modal-body">
                            <p class="mb-2">
                                Si ripianificano <strong>{{ autoPlan.result.items.length }}</strong> preventivi / progetti:
                                <strong>{{ autoPlan.result.moved }}</strong> blocchi spostati ( eliminati e ricreati ),
                                <strong>{{ autoPlan.result.created }}</strong> blocchi dopo la pianificazione.
                                Restano fermi <strong>{{ autoPlan.result.kept }}</strong> blocchi da oggi in poi ( con lucchetto, già iniziati, ore extra, o di voci non ripianificate ).
                            </p>
                            <p class="small text-muted mb-3">
                                Ordine: data tassativa, poi priorità A, B, C; a parità la data più vicina. Ogni attività va a ritroso dalla data
                                alla persona con la priorità più alta sulla tipologia ( Disponibilità persone ), poi alle successive; quello che
                                non ci sta va dopo la data. Senza data: da oggi. Sabati, domeniche e festivi esclusi.
                            </p>
                            <div v-if="!autoPlan.result.items.length" class="text-muted">Nessuna attività da pianificare.</div>
                            <table v-else class="table table-sm align-middle pg-auto-table">
                                <thead>
                                    <tr>
                                        <th>Preventivo / progetto</th>
                                        <th>Data</th>
                                        <th>Priorità</th>
                                        <th>Attività</th>
                                        <th>Fine</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr v-for="item in autoPlan.result.items" :key="item.id" :class="{ 'pg-auto-late': item.late, 'pg-auto-missing': !item.late && item.missing }">
                                        <td>
                                            <i class="fas text-muted" :class="item.kind === 'project' ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                                            <strong>{{ item.label }}</strong>
                                            <span v-if="item.statusId !== 'COR'" class="pg-planning-status">{{ optionName( options.statuses, item.statusId ) }}</span>
                                            <div class="small text-muted" v-if="item.subtitle">{{ item.subtitle }}</div>
                                        </td>
                                        <td class="text-nowrap">
                                            <template v-if="item.dueDate">
                                                {{ formatDay( item.dueDate ) }}
                                                <span v-if="item.dateType" class="pg-due" :class="{ tassativa: item.dateType === 'TAS' }">{{ optionName( options.dateTypes, item.dateType ) }}</span>
                                            </template>
                                            <span v-else class="text-muted">—</span>
                                        </td>
                                        <td>
                                            <span v-if="item.priority" class="pg-priority" :class="'pg-priority-' + item.priority">{{ item.priority }}</span>
                                        </td>
                                        <td>
                                            <div v-for="activity in item.activities" :key="activity.workTypeId" class="pg-auto-activity">
                                                <span class="pg-chip-dot" :style="{ backgroundColor: workType( activity.workTypeId ).color }"></span>
                                                <strong>{{ activity.activity }}</strong> {{ format( activity.hours ) }} h
                                                <span v-for="person in activity.people" :key="person.name" class="pg-auto-person">
                                                    {{ person.name }} {{ format( person.hours ) }} h
                                                    <span class="text-muted">{{ person.from === person.to ? formatDay( person.from ) : formatDay( person.from ) + "–" + formatDay( person.to ) }}</span>
                                                </span>
                                                <span v-if="activity.late" class="badge bg-danger">in ritardo</span>
                                                <div v-if="activity.problem" class="small text-danger">{{ activity.problem }}</div>
                                            </div>
                                        </td>
                                        <td class="text-nowrap">
                                            <template v-if="item.finish">{{ formatDay( item.finish ) }}</template>
                                            <i v-if="item.late" class="fas fa-exclamation-circle text-danger" title="Finisce dopo la data"></i>
                                            <i v-else-if="item.missing" class="fas fa-exclamation-triangle text-warning" :title="format( item.missing ) + ' h non pianificate'"></i>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        <footer class="modal-footer">
                            <span class="me-auto small text-muted">Confermando si ricalcola e si salva: i blocchi spostabili attuali vengono sostituiti.</span>
                            <button type="button" class="btn btn-default" data-bs-dismiss="modal">Annulla</button>
                            <button type="button" class="btn btn-primary" @click="applyAutoPlan" :disabled="autoPlan.loading || !autoPlan.result.items.length">
                                <i class="fas" :class="autoPlan.loading ? 'fa-spinner fa-spin' : 'fa-check'"></i> Applica la pianificazione
                            </button>
                        </footer>
                    </div>
                </section>
            </div>

            <div id="pg-extra-modal" class="modal fade" tabindex="-1">
                <section class="modal-dialog">
                    <div class="modal-content">
                        <header class="card-header d-flex align-items-center justify-content-between">
                            <h2 class="card-title">Nuova attività</h2>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Chiudi"></button>
                        </header>
                        <div class="card-body" v-if="extraForm.person">
                            <div class="row g-2 mb-2 align-items-end">
                                <div class="col-6">
                                    <label class="col-form-label">Persona</label>
                                    <div class="form-control-plaintext fw-bold">{{ extraForm.person.name }}</div>
                                </div>
                                <div class="col-6">
                                    <label class="col-form-label">Giorno <span v-if="extraDayNote()" class="text-muted">( {{ extraDayNote().toLowerCase() }} )</span></label>
                                    <input type="date" class="form-control" v-model="extraForm.day">
                                </div>
                            </div>

                            <div class="mb-2">
                                <label class="col-form-label">Progetto</label>
                                <select class="form-select" v-model="extraForm.quotationId">
                                    <option value="">-- scegli il progetto</option>
                                    <option v-for="quotation in openProjects()" :key="quotation.id" :value="quotation.id">{{ projectOptionLabel( quotation ) }}</option>
                                </select>
                            </div>

                            <div class="row g-2 mb-2">
                                <div class="col-5">
                                    <label class="col-form-label">Attività</label>
                                    <select class="form-select" v-model="extraForm.workTypeId">
                                        <option v-for="type in personActivities( extraForm.person )" :key="type.id" :value="type.id">{{ type.activity }}</option>
                                    </select>
                                </div>
                                <div class="col-3">
                                    <label class="col-form-label">Ore</label>
                                    <input type="number" min="0.5" max="24" step="0.5" class="form-control" v-model.number="extraForm.hours">
                                </div>
                                <div class="col-4">
                                    <label class="col-form-label">Inizio</label>
                                    <select class="form-select" v-model="extraForm.startTime">
                                        <option value="">primo spazio libero</option>
                                        <option v-for="time in timeOptions()" :key="time" :value="time">{{ time }}</option>
                                    </select>
                                </div>
                            </div>

                            <div class="mb-2">
                                <label class="col-form-label">Note</label>
                                <input type="text" class="form-control" maxlength="1000" v-model="extraForm.note" placeholder="Facoltative">
                            </div>

                            <div class="form-check mb-3">
                                <input class="form-check-input" type="checkbox" id="pg-extra-flag" v-model="extraForm.extra">
                                <label class="form-check-label" for="pg-extra-flag">
                                    Ore extra: oltre la stima del progetto ( costo in più ), tutte in questo giorno
                                </label>
                            </div>

                            <div class="text-end">
                                <button type="button" class="btn btn-default btn-sm" data-bs-dismiss="modal">Annulla</button>
                                <button type="button" class="btn btn-primary btn-sm" @click="saveExtra" :disabled="!extraForm.quotationId">
                                    <i class="fas fa-save"></i> Crea
                                </button>
                            </div>
                        </div>
                    </div>
                </section>
            </div>

            <div class="pg-legend">
                <span><span class="pg-legend-box non-working"></span> Sabato / domenica</span>
                <span><span class="pg-legend-box holiday"></span> Festivo / chiusura</span>
                <span><span class="pg-legend-box today"></span> Oggi</span>
                <span><span class="pg-legend-load"></span> Ore pianificate sulla disponibilità</span>
                <span><span class="pg-legend-load over"></span> Oltre la disponibilità</span>
                <span><span class="pg-legend-box pg-legend-soon"></span> Scade entro 30 giorni</span>
                <span><span class="pg-legend-box pg-legend-overdue"></span> Scaduto</span>
                <span><i class="fas fa-lock"></i> Con lucchetto</span>
            </div>
        </div>

    </div>
</div>
</cfoutput>
