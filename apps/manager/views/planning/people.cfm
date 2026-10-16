<cfoutput>
<!---
    PLANNING/PEOPLE.CFM
    ===================
    Disponibilità persone per la pianificazione ( Gantt ). App Vue 2 montata su
    ##planning-people-app ( logica in app-planning-people.js ).

    - Persone: tipo di lavoro e ore disponibili da lunedì a domenica. È una vista
      separata della tabella utenti; "Nuova persona" crea un utente senza accesso.
    - Calendario: festivi di San Marino ( calcolati ) e chiusure aziendali.
--->
<script src="/assets/#prc.staticVersion#/main/js/vue2.js"></script>

<div id="planning-people-app" v-cloak>

    <div class="row">
        <div class="col-6">
            #pageTitle()#
        </div>
        <div class="col-6 text-end pb-3">
            <button type="button" class="btn btn-primary btn-sm" @click="openNewPerson">
                <i class="fas fa-plus"></i> Nuova persona
            </button>
        </div>
    </div>

    <ul class="nav nav-tabs mb-3">
        <li class="nav-item">
            <a class="nav-link" :class="{ active: tab === 'people' }" href="##" @click.prevent="tab = 'people'">
                <i class="fas fa-user-clock"></i> Persone
            </a>
        </li>
        <li class="nav-item">
            <a class="nav-link" :class="{ active: tab === 'calendar' }" href="##" @click.prevent="tab = 'calendar'">
                <i class="fas fa-calendar-times"></i> Festivi e chiusure
            </a>
        </li>
    </ul>

    <!--- ======================= PERSONE ======================= --->
    <section class="card" v-if="tab === 'people'">
        <div class="card-body">

            <div class="row d-flex align-items-end mb-3">
                <div class="col-sm-4">
                    <label class="col-form-label">Cerca</label>
                    <input type="text" class="form-control" v-model="filters.str" placeholder="Nome">
                </div>
                <div class="col-sm-3">
                    <label class="col-form-label">Tipologia</label>
                    <select class="form-select" v-model="filters.workTypeId">
                        <option value="">-- tutti</option>
                        <option value="_none">-- non pianificati</option>
                        <option v-for="type in workTypes" :value="type.id" :key="type.id">{{ type.name }}</option>
                    </select>
                </div>
                <div class="col-sm-5 text-end text-muted small">
                    Le ore valgono per ogni settimana. Sabato e domenica si usano solo se un'attività lo richiede.
                </div>
            </div>

            <div v-if="newPerson.open" class="planning-new-person mb-3">
                <div class="row g-2 align-items-end">
                    <div class="col-sm-5">
                        <label class="col-form-label">Nome</label>
                        <input type="text" class="form-control" v-model="newPerson.name" ref="newPersonName" placeholder="Nome e cognome" @keyup.enter="createPerson">
                    </div>
                    <div class="col-sm-4">
                        <label class="col-form-label">Tipologie</label>
                        <div class="planning-type-chips">
                            <span v-for="type in workTypes" :key="type.id" class="planning-type-chip"
                                  :class="{ active: newPerson.workTypeIds.indexOf( type.id ) !== -1 }"
                                  :style="chipStyle( type, newPerson.workTypeIds )"
                                  @click="toggleType( newPerson.workTypeIds, type.id )">{{ type.name }}</span>
                        </div>
                    </div>
                    <div class="col-sm-3">
                        <button type="button" class="btn btn-primary btn-sm" @click="createPerson" :disabled="!newPerson.name.trim()">
                            <i class="fas fa-save"></i> Crea
                        </button>
                        <button type="button" class="btn btn-default btn-sm" @click="newPerson.open = false">Annulla</button>
                    </div>
                </div>
                <div class="small text-muted mt-1">
                    La persona viene creata come utente senza accesso all'app. Si può abilitare in seguito dalla pagina Utenti.
                </div>
            </div>

            <div class="table-responsive">
                <table class="table table-sm table-hover align-middle planning-people-table">
                    <thead>
                        <tr>
                            <th>Nome</th>
                            <th style="width: 300px;" title="Clicca per attivare / togliere: la persona riceve le attività di queste tipologie">Tipologie</th>
                            <th v-for="day in dayNames" :key="day" class="text-center planning-hours-col">{{ day }}</th>
                            <th class="text-center" style="width: 100px;" title="Ora di inizio della giornata: le ore partono da qui, senza pausa">Inizio</th>
                            <th class="text-end">Settimana</th>
                            <th class="text-end" style="width: 150px;">Costo orario</th>
                            <th style="width: 30px;"></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="person in filteredPeople" :key="person.id" :class="{ 'text-muted': !planned( person ) }">
                            <td>
                                {{ person.name }}
                                <i v-if="!person.active" class="fas fa-user-slash planning-no-access ms-1" title="Senza accesso all'app"></i>
                            </td>
                            <td>
                                <!--- tipologie della persona: nessuna = non si pianifica --->
                                <!--- tipologie attive: priorità della persona su quella tipologia ( 1 = la più alta ) --->
                                <div class="planning-type-chips">
                                    <span v-for="type in workTypes" :key="type.id" class="planning-type-chip"
                                          :class="{ active: person.workTypeIds.indexOf( type.id ) !== -1 }"
                                          :style="chipStyle( type, person.workTypeIds )"
                                          @click="toggleType( person.workTypeIds, type.id ); changeType( person )">
                                        {{ type.name }}
                                        <input v-if="person.workTypeIds.indexOf( type.id ) !== -1" type="number" min="1" step="1"
                                               class="planning-type-priority" placeholder="–"
                                               v-model="person.workTypePriorities[ type.id ]"
                                               @click.stop @change="save( person )"
                                               title="Priorità nella pianificazione automatica: 1 = la più alta; vuota = dopo le numerate">
                                    </span>
                                </div>
                            </td>
                            <td v-for="( day, index ) in dayNames" :key="day" class="text-center"
                                :class="{ 'planning-weekend': index >= 5 }">
                                <input type="number" min="0" max="24" step="0.5"
                                       class="form-control form-control-sm text-center planning-hours-input"
                                       v-model.number="person.hours[ index ]"
                                       :disabled="!planned( person )"
                                       @change="save( person )">
                            </td>
                            <td class="text-center">
                                <select class="form-select form-select-sm" v-model="person.dayStart" :disabled="!planned( person )" @change="save( person )">
                                    <option v-for="time in timeOptions" :key="time" :value="time">{{ time }}</option>
                                </select>
                            </td>
                            <td class="text-end">{{ weekTotal( person ) }} h</td>
                            <td class="text-end">
                                <a href="##" @click.prevent="openCosts( person )" class="planning-cost-link" title="Storico dei costi orari">
                                    <template v-if="person.hourlyCost !== ''">
                                        {{ formatMoney( person.hourlyCost ) }}/h
                                        <div class="small text-muted">dal {{ formatDate( person.costValidFrom ) }}</div>
                                    </template>
                                    <template v-else><i class="fas fa-euro-sign"></i> Imposta</template>
                                </a>
                            </td>
                            <td class="text-center">
                                <i v-if="person.saving" class="fas fa-spinner fa-spin text-muted"></i>
                                <i v-else-if="person.saved" class="fas fa-check text-success"></i>
                            </td>
                        </tr>
                        <tr v-if="!filteredPeople.length">
                            <td :colspan="dayNames.length + 6" class="text-center text-muted py-3">Nessuna persona</td>
                        </tr>
                    </tbody>
                </table>
            </div>

        </div>
    </section>

    <!--- ======================= COSTI ORARI ( storico ) ======================= --->
    <div id="planning-costs-modal" class="modal fade" tabindex="-1">
        <section class="modal-dialog">
            <div class="modal-content">
                <header class="card-header d-flex align-items-center justify-content-between">
                    <h2 class="card-title">Costo orario <span v-if="costEditor.person">– {{ costEditor.person.name }}</span></h2>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Chiudi"></button>
                </header>
                <div class="card-body">
                    <p class="small text-muted">
                        Ogni costo vale dalla sua data fino a quella del costo successivo: i giorni già pianificati
                        mantengono il costo in vigore in quel giorno.
                    </p>

                    <div class="row g-2 align-items-end mb-3">
                        <div class="col-5">
                            <label class="col-form-label">Valido dal</label>
                            <input type="date" class="form-control form-control-sm" v-model="costEditor.form.validFrom">
                        </div>
                        <div class="col-4">
                            <label class="col-form-label">€ / ora</label>
                            <input type="number" min="0" step="0.5" class="form-control form-control-sm" v-model.number="costEditor.form.hourlyCost" @keyup.enter="addCost">
                        </div>
                        <div class="col-3">
                            <button type="button" class="btn btn-primary btn-sm w-100" @click="addCost"
                                    :disabled="!costEditor.form.validFrom || costEditor.form.hourlyCost === ''">
                                <i class="fas fa-plus"></i> Aggiungi
                            </button>
                        </div>
                    </div>

                    <table class="table table-sm">
                        <thead>
                            <tr><th>Valido dal</th><th class="text-end">€ / ora</th><th></th></tr>
                        </thead>
                        <tbody>
                            <tr v-for="cost in costEditor.costs" :key="cost.id">
                                <td>
                                    {{ formatDate( cost.validFrom ) }}
                                    <span v-if="cost.current" class="badge bg-success ms-1">in vigore</span>
                                    <span v-else-if="cost.validFrom > today" class="badge bg-info ms-1">futuro</span>
                                </td>
                                <td class="text-end">{{ formatMoney( cost.hourlyCost ) }}</td>
                                <td class="text-end">
                                    <button type="button" class="btn btn-default btn-xs" @click="deleteCost( cost )" title="Elimina">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </td>
                            </tr>
                            <tr v-if="!costEditor.costs.length">
                                <td colspan="3" class="text-muted">Nessun costo orario: le sue ore pianificate non hanno un costo.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
    </div>

    <!--- ======================= FESTIVI E CHIUSURE ======================= --->
    <section class="card" v-if="tab === 'calendar'">
        <div class="card-body">

            <div class="d-flex align-items-center gap-2 mb-3">
                <button type="button" class="btn btn-default btn-sm" @click="changeYear( -1 )"><i class="fas fa-chevron-left"></i></button>
                <strong class="fs-5">{{ year }}</strong>
                <button type="button" class="btn btn-default btn-sm" @click="changeYear( 1 )"><i class="fas fa-chevron-right"></i></button>
            </div>

            <div class="row">
                <div class="col-md-6">
                    <h5>Festivi di San Marino</h5>
                    <p class="small text-muted">Calcolati in automatico, compresi Pasqua, Lunedì dell'Angelo e Corpus Domini.</p>
                    <table class="table table-sm">
                        <tbody>
                            <tr v-for="holiday in holidays" :key="holiday.day">
                                <td style="width: 130px;">{{ formatDay( holiday.day ) }}</td>
                                <td>{{ holiday.name }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div class="col-md-6">
                    <h5>Chiusure aziendali</h5>
                    <p class="small text-muted">Giorni non lavorati in aggiunta ai festivi ( es. ponti, ferie collettive ).</p>

                    <div class="row g-2 align-items-end mb-3">
                        <div class="col-sm-4">
                            <input type="date" class="form-control form-control-sm" v-model="newClosure.day">
                        </div>
                        <div class="col-sm-6">
                            <input type="text" class="form-control form-control-sm" v-model="newClosure.description" placeholder="Descrizione" @keyup.enter="addClosure">
                        </div>
                        <div class="col-sm-2">
                            <button type="button" class="btn btn-primary btn-sm w-100" @click="addClosure" :disabled="!newClosure.day">
                                <i class="fas fa-plus"></i>
                            </button>
                        </div>
                    </div>

                    <table class="table table-sm">
                        <tbody>
                            <tr v-for="closure in closures" :key="closure.id">
                                <td style="width: 130px;">{{ formatDay( closure.day ) }}</td>
                                <td>{{ closure.description || 'Chiusura aziendale' }}</td>
                                <td class="text-end">
                                    <button type="button" class="btn btn-default btn-xs" @click="deleteClosure( closure )" title="Elimina">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </td>
                            </tr>
                            <tr v-if="!closures.length">
                                <td colspan="3" class="text-muted">Nessuna chiusura nel {{ year }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    </section>

</div>

<style>
    ##planning-people-app[v-cloak] { display: none; }
    .planning-hours-col { width: 72px; }
    .planning-hours-input { width: 64px; margin: 0 auto; padding-left: 4px; padding-right: 4px; }
    .planning-weekend { background-color: rgba( 0, 0, 0, .035 ); }
    .planning-new-person { background: ##f4f7fc; border: 1px solid ##dbe4f3; border-radius: 6px; padding: 10px 12px; }
    .planning-cost-link { text-decoration: none; white-space: nowrap; }
    .planning-no-access { color: ##c3c9d2; font-size: 11px; }
    .planning-type-chips { display: flex; flex-wrap: wrap; gap: 3px; min-width: 280px; }
    .planning-type-chip { padding: 1px 7px; font-size: 11px; line-height: 17px; border: 1px solid ##ced4da; border-radius: 999px; color: ##6b7684; background: ##fff; cursor: pointer; user-select: none; }
    .planning-type-chip.active { color: ##fff; font-weight: 600; }
    .planning-type-priority { width: 30px; margin-left: 3px; padding: 0 2px; font-size: 10px; line-height: 14px; text-align: center; color: ##1d2b3a; background: rgba( 255, 255, 255, .9 ); border: 0; border-radius: 3px; -moz-appearance: textfield; }
    .planning-type-priority::-webkit-outer-spin-button, .planning-type-priority::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
</style>
</cfoutput>
