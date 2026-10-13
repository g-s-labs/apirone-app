<cfoutput>
<!---
    PLANNING/PROJECTS.CFM
    =====================
    Ore progetti per la pianificazione ( Gantt ): elenco dei preventivi attivi
    in qualunque stato tranne Perso ed Estinto e dei progetti ( nome +
    rif. libero, con zero o più preventivi collegati ) con le ore di attività
    stimate per tipo e lo stato. Un preventivo collegato a un progetto non
    compare da solo: è nel Gantt tramite il progetto. Una voce conclusa esce
    dall'elenco e dal Gantt ( colonna "Da pianificare" e vista Preventivi ).
    App Vue 2 montata su ##planning-projects-app ( app-planning-projects.js ).
--->
<script src="/assets/#prc.staticVersion#/main/js/vue2.js"></script>

<div id="planning-projects-app" v-cloak>

    <div class="row">
        <div class="col-12">
            #pageTitle()#
        </div>
    </div>

    <section class="card">
        <div class="card-body">

            <div class="row d-flex align-items-end mb-3">
                <div class="col-sm-4">
                    <label class="col-form-label">Cerca</label>
                    <input type="text" class="form-control" v-model="filters.str" placeholder="Numero, nome, rif. o cliente">
                </div>
                <div class="col-sm-2">
                    <button type="button" class="btn btn-primary mt-4" @click="openNewProject" :disabled="newProject.open">
                        <i class="fas fa-plus"></i> Nuovo progetto
                    </button>
                </div>
                <div class="col-sm-2">
                    <label class="col-form-label">Stato</label>
                    <select class="form-select" v-model="filters.statusId">
                        <option value="">-- tutti tranne i conclusi</option>
                        <option v-for="status in options.statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
                        <option value="_all">-- tutti</option>
                    </select>
                </div>
                <div class="col-sm-4 text-end text-muted small">
                    Per ogni attività: ore stimate ( si pianificano nel <a href="/manager/planning/gantt">Gantt</a> sulle persone con la
                    tipologia corrispondente, solo se il progetto è In corso ) e budget in euro, facoltativo.
                    <div class="pp-legend mt-1">
                        Sotto ogni attività le ore già pianificate:
                        <span class="pp-planned">pianificate</span>
                        <span class="pp-planned done">pari alla stima</span>
                        <span class="pp-planned over">oltre la stima</span>
                        <span class="pp-planned extra">+ extra</span>
                    </div>
                </div>
            </div>

            <!--- nuovo progetto: nome obbligatorio, rif. libero facoltativo --->
            <form v-if="newProject.open" class="pp-new-project row g-2 align-items-end mb-3" @submit.prevent="createProject">
                <div class="col-sm-4">
                    <label class="col-form-label">Nome del progetto *</label>
                    <input type="text" class="form-control" v-model="newProject.name" maxlength="255" ref="newProjectName">
                </div>
                <div class="col-sm-4">
                    <label class="col-form-label">Rif. libero</label>
                    <input type="text" class="form-control" v-model="newProject.rifLibero" maxlength="255">
                </div>
                <div class="col-sm-4">
                    <button type="submit" class="btn btn-primary" :disabled="newProject.saving || !newProject.name.trim()">
                        <i class="fas fa-save"></i> Crea progetto
                    </button>
                    <button type="button" class="btn btn-default" @click="newProject.open = false">Annulla</button>
                </div>
                <div class="col-12 small text-muted">
                    Il progetto compare nel Gantt come un preventivo, con ore stimate e budget propri. Puoi collegargli
                    uno o più preventivi: un preventivo collegato non compare più da solo nel Gantt e i suoi blocchi
                    già pianificati passano al progetto.
                </div>
            </form>

            <div class="table-responsive">
                <table class="table table-sm table-hover align-middle planning-projects-table">
                    <thead>
                        <tr>
                            <th>Preventivo / progetto</th>
                            <th class="pp-planning-col" title="Si assegnano persone nel Gantt solo ai progetti In corso">Pianificazione</th>
                            <th v-for="type in workTypes" :key="type.id" class="text-center pp-hours-col">
                                <span class="pp-dot" :style="{ backgroundColor: type.color }"></span>{{ type.activity }}
                            </th>
                            <th class="text-end">Totale</th>
                            <th style="width: 30px;"></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="project in filteredProjects" :key="project.id" :class="{ 'pp-completed': project.planning.statusId === 'CLS' }">
                            <td v-if="project.kind === 'project'" class="pp-project-cell">
                                <!--- progetto: nome e rif. libero, preventivi collegati --->
                                <template v-if="!project.editing">
                                    <span class="badge bg-primary me-1">Progetto</span>
                                    <span class="fw-bold">{{ project.name }}</span>
                                    <button type="button" class="btn btn-link btn-sm p-0 ms-1" @click="startEdit( project )" title="Modifica nome e rif. libero">
                                        <i class="fas fa-pen"></i>
                                    </button>
                                    <button type="button" class="btn btn-link btn-sm p-0 ms-1 text-danger" @click="deleteProject( project )" title="Elimina il progetto">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                    <div class="small pp-project-ref" v-if="project.rifLibero">{{ project.rifLibero }}</div>
                                </template>
                                <form v-else class="pp-edit-project" @submit.prevent="saveDetails( project )">
                                    <input type="text" class="form-control form-control-sm mb-1" v-model="project.edit.name" maxlength="255" placeholder="Nome del progetto *">
                                    <input type="text" class="form-control form-control-sm mb-1" v-model="project.edit.rifLibero" maxlength="255" placeholder="Rif. libero">
                                    <button type="submit" class="btn btn-primary btn-xs" :disabled="!project.edit.name.trim()">Salva</button>
                                    <button type="button" class="btn btn-default btn-xs" @click="project.editing = false">Annulla</button>
                                </form>

                                <div class="pp-linked">
                                    <span v-for="quotation in project.quotations" :key="quotation.id" class="pp-linked-chip"
                                          :title="[ quotation.name, quotation.customer ].filter( Boolean ).join( ' · ' )">
                                        <a :href="quotation.url" target="_blank">{{ quotation.label }}</a>
                                        <span class="pp-linked-customer" v-if="quotation.customer">{{ quotation.customer }}</span>
                                        <i class="fas fa-times pp-linked-remove" @click="unlinkQuotation( project, quotation )" title="Scollega dal progetto"></i>
                                    </span>
                                    <span v-if="!project.quotations.length" class="small text-muted">Nessun preventivo collegato</span>
                                </div>

                                <!--- collega un preventivo: ricerca per numero, nome, rif. libero o cliente --->
                                <div class="pp-link-search">
                                    <input type="text" class="form-control form-control-sm" v-model="project.search.str"
                                           @input="searchQuotations( project )" @keydown.esc="clearSearch( project )"
                                           placeholder="Collega un preventivo: numero, nome o cliente">
                                    <div v-if="project.search.results.length || project.search.empty" class="pp-link-results">
                                        <div v-if="project.search.empty" class="pp-link-result text-muted">Nessun preventivo trovato</div>
                                        <div v-for="quotation in project.search.results" :key="quotation.id" class="pp-link-result"
                                             :class="{ disabled: quotation.projectId }"
                                             @click="!quotation.projectId && linkQuotation( project, quotation )">
                                            <strong>{{ quotation.label }}</strong>
                                            <span class="text-muted">{{ [ quotation.customer, quotation.rifLibero || quotation.name ].filter( Boolean ).join( ' · ' ) }}</span>
                                            <span v-if="quotation.projectId === project.id" class="badge bg-secondary ms-1">già collegato</span>
                                            <span v-else-if="quotation.projectId" class="badge bg-warning text-dark ms-1">in un altro progetto</span>
                                        </div>
                                    </div>
                                </div>
                            </td>
                            <td v-else>
                                <a :href="project.url" target="_blank" class="fw-bold">{{ project.label }}</a>
                                <span v-if="project.statusName" class="badge ms-1" :class="statusClass( project.statusId )">{{ project.statusName }}</span>
                                <div class="small pp-project-ref">
                                    {{ project.rifLibero || project.name }}<span v-if="project.customer" class="text-muted"><template v-if="project.rifLibero || project.name"> · </template>{{ project.customer }}</span>
                                </div>
                            </td>
                            <td class="pp-planning-cell">
                                <!--- pianificazione: stato, priorità, data con tipo, note; ogni modifica si salva --->
                                <select class="form-select form-select-sm pp-status" :class="'pp-status-' + project.planning.statusId"
                                        v-model="project.planning.statusId" @change="changeStatus( project )" title="Stato">
                                    <option v-for="status in options.statuses" :key="status.id" :value="status.id">{{ status.name }}</option>
                                </select>
                                <select class="form-select form-select-sm mt-1" v-model="project.planning.priority" @change="save( project )" title="Priorità">
                                    <option value="">-- priorità</option>
                                    <option v-for="priority in options.priorities" :key="priority.id" :value="priority.id">{{ priority.name }}</option>
                                </select>
                                <div class="d-flex gap-1 mt-1">
                                    <!--- progetto: data modificabile; preventivo: la data prevista evasione, si cambia nella testata del preventivo --->
                                    <input v-if="project.kind === 'project'" type="date" class="form-control form-control-sm" v-model="project.planning.dueDate" @change="save( project )" title="Data">
                                    <span v-else class="form-control form-control-sm pp-due-readonly" title="Data prevista evasione del preventivo: si modifica nella testata del preventivo">
                                        {{ formatDate( project.planning.dueDate ) || "evasione: —" }}
                                    </span>
                                    <select class="form-select form-select-sm pp-date-type" v-model="project.planning.dateType" @change="save( project )" title="Tipo di data">
                                        <option value="">-- tipo</option>
                                        <option v-for="type in options.dateTypes" :key="type.id" :value="type.id">{{ type.name }}</option>
                                    </select>
                                </div>
                                <textarea class="form-control form-control-sm mt-1 pp-note" rows="2" maxlength="4000"
                                          v-model="project.planning.note" @change="save( project )" placeholder="Note ( visibili nel Gantt )"></textarea>
                            </td>
                            <td v-for="type in workTypes" :key="type.id" class="text-center">
                                <div class="pp-input-group" title="Ore stimate">
                                    <input type="number" min="0" step="0.5"
                                           class="form-control form-control-sm text-center pp-hours-input"
                                           v-model.number="project.form[ type.id ]"
                                           @change="save( project )">
                                    <span class="pp-unit">h</span>
                                </div>
                                <div class="pp-input-group mt-1" title="Budget ( costo stimato ), facoltativo">
                                    <input type="number" min="0" step="10"
                                           class="form-control form-control-sm text-center pp-hours-input pp-budget-input"
                                           v-model="project.budgets[ type.id ]"
                                           placeholder="budget"
                                           @change="save( project )">
                                    <span class="pp-unit">€</span>
                                </div>
                                <!--- riga di altezza fissa: gli input restano allineati anche senza ore pianificate --->
                                <div class="pp-planned-line">
                                    <span v-if="planned( project, type.id ) > 0" class="pp-planned" :class="plannedClass( project, type.id )"
                                          title="Ore già pianificate nel Gantt">{{ format( planned( project, type.id ) ) }} h</span>
                                    <span v-if="extra( project, type.id ) > 0" class="pp-planned extra"
                                          title="Ore extra pianificate, oltre la stima">+{{ format( extra( project, type.id ) ) }}</span>
                                </div>
                            </td>
                            <td class="text-end">
                                <strong>{{ format( total( project ) ) }} h</strong>
                                <div class="small text-muted" title="Ore già pianificate nel Gantt">{{ format( totalPlanned( project ) ) }} h pianificate</div>
                                <div class="small" v-if="totalBudget( project ) !== null">{{ formatMoney( totalBudget( project ) ) }}</div>
                            </td>
                            <td class="text-center">
                                <i v-if="project.saving" class="fas fa-spinner fa-spin text-muted"></i>
                                <i v-else-if="project.saved" class="fas fa-check text-success"></i>
                            </td>
                        </tr>
                        <tr v-if="!loading && !filteredProjects.length">
                            <td :colspan="workTypes.length + 4" class="text-center text-muted py-3">
                                Nessun progetto. Compaiono qui i preventivi attivi ( tranne persi ed estinti )
                                e i progetti creati con "Nuovo progetto".
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

        </div>
    </section>

</div>

<style>
    ##planning-projects-app[v-cloak] { display: none; }
    .pp-hours-col { width: 96px; white-space: nowrap; }
    .pp-hours-input { width: 74px; padding-left: 4px; padding-right: 4px; }
    .pp-input-group { display: flex; align-items: center; justify-content: center; gap: 3px; }
    .pp-unit { width: 10px; font-size: 11px; color: ##6b7684; }
    .pp-budget-input { background: ##fbfcfe; }
    .pp-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 4px; }
    .pp-planned-line { height: 18px; margin-top: 3px; }
    .pp-planned { display: inline-block; padding: 0 6px; font-size: 11px; line-height: 16px; color: ##6b7684; background: ##eef1f5; border-radius: 999px; }
    .pp-planned.done { color: ##fff; background: ##2f9e44; }
    .pp-planned.over { color: ##fff; background: ##e03131; font-weight: 600; }
    .pp-planned.extra { color: ##1d2b3a; background: ##ffd43b; font-weight: 600; }
    .pp-legend .pp-planned { margin-left: 4px; }
    .pp-project-ref { max-width: 360px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .pp-planning-col, .pp-planning-cell { width: 230px; min-width: 230px; }
    .pp-date-type { width: 105px; flex: none; }
    .pp-note { font-size: 12px; resize: vertical; }
    .pp-due-readonly { background: ##f1f3f5; color: ##495057; white-space: nowrap; overflow: hidden; cursor: default; }
    .pp-status { font-weight: 600; }
    .pp-status-COR { color: ##2b8a3e; border-color: ##8ce99a; }
    .pp-status-DAP { color: ##1971c2; border-color: ##a5d8ff; }
    .pp-status-SOS { color: ##e67700; border-color: ##ffd43b; }
    .pp-status-CLS { color: ##868e96; }
    .pp-completed td { opacity: .6; }
    .pp-new-project { padding: 12px; background: ##f6f8fb; border: 1px solid ##e3e8ef; border-radius: 6px; }
    .pp-project-cell { min-width: 320px; max-width: 420px; }
    .pp-edit-project { max-width: 360px; }
    .pp-linked { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
    .pp-linked-chip { display: inline-flex; align-items: center; gap: 4px; padding: 1px 6px; font-size: 12px; background: ##eef1f5; border-radius: 999px; }
    .pp-linked-customer { color: ##6b7684; max-width: 140px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .pp-linked-remove { color: ##868e96; cursor: pointer; }
    .pp-linked-remove:hover { color: ##e03131; }
    .pp-link-search { position: relative; margin-top: 6px; max-width: 360px; }
    .pp-link-results { position: absolute; z-index: 20; left: 0; right: 0; max-height: 260px; overflow-y: auto; background: ##fff; border: 1px solid ##dee2e6; border-radius: 4px; box-shadow: 0 4px 12px rgba( 0, 0, 0, .12 ); }
    .pp-link-result { padding: 5px 8px; font-size: 12px; cursor: pointer; border-bottom: 1px solid ##f1f3f5; }
    .pp-link-result:hover { background: ##f1f6ff; }
    .pp-link-result.disabled { cursor: default; opacity: .6; background: ##fff; }
</style>
</cfoutput>
