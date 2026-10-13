<cfoutput>
<!---
    PLANNING/GANTT.CFM
    ==================
    Gantt della pianificazione: persone sui preventivi attivi ( qualunque stato
    tranne Perso ed Estinto ) e sui progetti. App Vue 2 montata su ##planning-gantt-app ( logica in
    app-planning-gantt.js, stile in css/planning.css ).

    - Viste giornaliera ( 2 settimane ), settimanale ( 6 settimane ), mensile
      ( mese di calendario, default sul mese corrente ).
    - Raggruppamento per Persone ( righe per tipo di lavoro, barre con il numero
      del preventivo ) o per Preventivi ( righe per tipo di attività, barre con il
      nome della persona ). I colori sono solo dei tipi di attività.
    - Colonna "Da pianificare": ore stimate non ancora pianificate.
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

        <div class="btn-group btn-group-sm ms-auto" role="group">
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

                <div v-for="item in backlog" :key="item.quotation.id" class="pg-backlog-quotation">
                    <div class="pg-backlog-quotation-title">
                        <!--- preventivo: link alla pagina; progetto: il nome ( si gestisce in Ore progetti ) --->
                        <i class="fas text-muted" :class="item.quotation.kind === 'project' ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                        <a v-if="item.quotation.url" :href="item.quotation.url" target="_blank">{{ quotationLabel( item.quotation ) }}</a>
                        <a v-else href="/manager/planning/projects" target="_blank" title="Progetto: si gestisce in Ore progetti">{{ quotationLabel( item.quotation ) }}</a>
                    </div>
                    <div class="pg-backlog-customer" v-if="itemSubtitle( item.quotation )">{{ itemSubtitle( item.quotation ) }}</div>
                    <!--- priorità, data con tipo, note ( dettagli al clic ) --->
                    <div class="pg-item-meta" v-if="item.quotation.priority || item.quotation.dueDate || item.quotation.note">
                        <span v-if="item.quotation.priority" class="pg-priority" :class="'pg-priority-' + item.quotation.priority"
                              :title="optionName( options.priorities, item.quotation.priority )">{{ item.quotation.priority }}</span>
                        <span v-if="item.quotation.dueDate" class="pg-due" :class="{ tassativa: item.quotation.dateType === 'TAS' }"
                              :title="dueTitle( item.quotation )"><i class="far fa-calendar"></i> {{ formatDay( item.quotation.dueDate ) }}</span>
                        <a v-if="item.quotation.note" href="##" class="pg-note-link" @click.prevent="openItemInfo( item.quotation )" title="Note e dettagli">
                            <i class="fas fa-sticky-note"></i> note
                        </a>
                    </div>
                    <!--- riquadri da trascinare su una persona del tipo giusto, nel giorno di inizio --->
                    <div class="pg-backlog-chips">
                        <span v-for="chip in item.chips" :key="chip.workTypeId" class="pg-chip pg-chip-draggable"
                              draggable="true"
                              @dragstart="startBacklogDrag( $event, item.quotation, chip )"
                              @dragend="endBacklogDrag"
                              :style="{ borderColor: workType( chip.workTypeId ).color }"
                              :title="workType( chip.workTypeId ).activity + ': ' + format( chip.planned ) + ' h pianificate su ' + format( chip.estimated ) + ' h. Trascina su una persona per pianificare.'">
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
                        <div class="pg-group-row" :key="'g-' + group.key" @click="toggleGroup( group.key )">
                            <div class="pg-label pg-group-label" :style="{ width: labelWidth + 'px' }">
                                <i class="fas" :class="collapsedGroups[ group.key ] ? 'fa-caret-right' : 'fa-caret-down'"></i>
                                <span v-if="group.color" class="pg-swatch" :style="{ backgroundColor: group.color }"></span>
                                <i v-else class="fas text-muted" :class="group.project ? 'fa-folder-open' : 'fa-file-invoice'"></i>
                                <!--- clic sul nome del preventivo / progetto: dettagli e note ( sul resto della riga: apri / chiudi ) --->
                                <span class="pg-group-title" :class="{ 'pg-group-title-link': group.item }"
                                      @click="group.item && ( $event.stopPropagation(), openItemInfo( group.item ) )"
                                      :title="group.item ? 'Dettagli e note' : ''">{{ group.title }}</span>
                                <!--- preventivo / progetto: priorità, stato se non in corso, data; clic sull'icona: dettagli e note --->
                                <template v-if="group.item">
                                    <span v-if="group.item.priority" class="pg-priority" :class="'pg-priority-' + group.item.priority"
                                          :title="optionName( options.priorities, group.item.priority )">{{ group.item.priority }}</span>
                                    <span v-if="!group.item.assignable" class="pg-planning-status"
                                          title="Non si possono assegnare persone: cambia lo stato in Ore progetti">{{ optionName( options.statuses, group.item.planningStatusId ) }}</span>
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
                                         :class="{ 'clipped-start': bar.clippedStart, 'clipped-end': bar.clippedEnd, compact: !bar.timed && barCompact( bar ), 'with-days': !bar.timed && showDayHours(), timed: bar.timed, extra: bar.block.extra, selected: isSelected( bar.block ) }"
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
                                        <!--- bordo destro: allunga / accorcia --->
                                        <div v-if="!bar.clippedEnd" class="pg-bar-resize" title="Trascina per allungare o accorciare"
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
                                                    <select class="form-select form-select-sm" :value="blockStart( bar.block )"
                                                            @change="setBlockTime( bar.block, 'start', $event.target.value )">
                                                        <option v-for="time in timeOptions()" :key="'s' + time" :value="time">{{ time }}</option>
                                                    </select>
                                                </label>
                                                <label>
                                                    Fine <span class="text-muted">{{ formatDayLong( bar.block.end ) }}</span>
                                                    <select class="form-select form-select-sm" :value="blockEnd( bar.block )"
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
                                                <button type="button" class="btn btn-default btn-xs" @click="splitSelected" :disabled="!canSplit( bar.block )"
                                                        :title="canSplit( bar.block ) ? 'Dividi in due blocchi: ' + format( splitHours( bar.block )[ 0 ] ) + ' h + ' + format( splitHours( bar.block )[ 1 ] ) + ' h' : 'Servono almeno 1 h per dividere'">
                                                    <i class="fas fa-cut"></i> Dividi
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.useSaturday || bar.block.forceHolidays }"
                                                        @click="toggleFlag( bar.block, 'useSaturday' )" :disabled="bar.block.forceHolidays" title="Usa anche i sabati">
                                                    <i class="fas fa-calendar-week"></i> Sabati
                                                </button>
                                                <button type="button" class="btn btn-default btn-xs" :class="{ active: bar.block.forceHolidays }"
                                                        @click="toggleFlag( bar.block, 'forceHolidays' )" title="Usa anche domeniche e festivi">
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
                                                <button type="button" class="btn btn-danger btn-xs" @click="deleteSelected" title="Elimina il blocco">
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
                                                           :value="day.hours" @change="setDayHours( bar.block, day.day, $event.target.value )"
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
                            Nessun preventivo da pianificare ( si escludono i persi, gli estinti e i conclusi ).
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
                                <dt class="col-4">{{ itemInfo.kind === 'project' ? 'Data' : 'Data prevista evasione' }}</dt>
                                <dd class="col-8">
                                    <template v-if="itemInfo.dueDate">
                                        {{ formatDayLong( itemInfo.dueDate ) }}
                                        <span v-if="itemInfo.dateType" class="pg-due ms-1" :class="{ tassativa: itemInfo.dateType === 'TAS' }">{{ optionName( options.dateTypes, itemInfo.dateType ) }}</span>
                                    </template>
                                    <template v-else>—</template>
                                </dd>
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

            <div id="pg-extra-modal" class="modal fade" tabindex="-1">
                <section class="modal-dialog">
                    <div class="modal-content">
                        <header class="card-header d-flex align-items-center justify-content-between">
                            <h2 class="card-title">Nuova attività</h2>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Chiudi"></button>
                        </header>
                        <div class="card-body" v-if="extraForm.person">
                            <p class="mb-3">
                                <strong>{{ extraForm.person.name }}</strong>, <span class="text-capitalize">{{ extraForm.dayLabel }}</span>
                            </p>

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
            </div>
        </div>

    </div>
</div>
</cfoutput>
