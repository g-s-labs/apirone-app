<cfoutput>
<!---
    PLANNING/STATS.CFM
    ==================
    Statistiche dei progetti: costo ( ore pianificate nel Gantt × costo orario
    della persona in vigore quel giorno ) rispetto al budget delle attività
    ( Ore progetti ). "Svolto" sono i giorni fino a oggi. App Vue 2 montata su
    ##planning-stats-app ( app-planning-stats.js ).
--->
<script src="/assets/#prc.staticVersion#/main/js/vue2.js"></script>

<div id="planning-stats-app" v-cloak>

    <div class="row">
        <div class="col-12">
            #pageTitle()#
        </div>
    </div>

    <!--- riepilogo dei progetti filtrati --->
    <div class="ps-tiles">
        <div class="ps-tile">
            <div class="ps-tile-label">Costo pianificato</div>
            <div class="ps-tile-value">{{ money( summary.cost ) }}</div>
            <div class="ps-tile-note">di cui svolto {{ money( summary.doneCost ) }}</div>
        </div>
        <div class="ps-tile">
            <div class="ps-tile-label">Budget</div>
            <div class="ps-tile-value">{{ summary.budget !== null ? money( summary.budget ) : '–' }}</div>
            <div class="ps-tile-note">{{ summary.withBudget }} {{ summary.withBudget === 1 ? 'progetto' : 'progetti' }} con budget</div>
        </div>
        <div class="ps-tile">
            <div class="ps-tile-label">Ore pianificate</div>
            <div class="ps-tile-value">{{ hours( summary.hours ) }}</div>
            <div class="ps-tile-note">su {{ hours( summary.estimatedHours ) }} stimate</div>
        </div>
        <div class="ps-tile" :class="{ alert: summary.overBudget > 0 }">
            <div class="ps-tile-label">Oltre il budget</div>
            <div class="ps-tile-value">{{ summary.overBudget }}</div>
            <div class="ps-tile-note">{{ summary.overBudget === 1 ? 'progetto' : 'progetti' }}</div>
        </div>
    </div>

    <section class="card">
        <div class="card-body">

            <div class="row d-flex align-items-end mb-3">
                <div class="col-sm-4">
                    <label class="col-form-label">Cerca</label>
                    <input type="text" class="form-control" v-model="filters.str" placeholder="Numero, nome o cliente">
                </div>
                <div class="col-sm-3">
                    <label class="col-form-label">Progetti</label>
                    <select class="form-select" v-model="filters.state">
                        <option value="all">Tutti</option>
                        <option value="open">In corso</option>
                        <option value="completed">Conclusi</option>
                        <option value="over">Oltre il budget</option>
                    </select>
                </div>
                <div class="col-sm-5 text-end text-muted small">
                    Costo = ore pianificate nel <a href="/manager/planning/gantt">Gantt</a> × costo orario della persona
                    ( <a href="/manager/planning/people">Disponibilità persone</a> ) in vigore quel giorno.
                    Budget da <a href="/manager/planning/projects">Ore progetti</a>.
                </div>
            </div>

            <div class="table-responsive">
                <table class="table table-sm align-middle ps-table">
                    <thead>
                        <tr>
                            <th>Progetto</th>
                            <th class="text-end">Ore stimate</th>
                            <th class="text-end">Ore pianificate</th>
                            <th class="text-end">Costo</th>
                            <th class="text-end">Budget</th>
                            <th style="width: 200px;">Utilizzo budget</th>
                            <th class="text-end">Scostamento</th>
                        </tr>
                    </thead>
                    <tbody>
                        <template v-for="project in filteredProjects">
                            <tr :key="project.id" class="ps-project-row" :class="{ 'ps-completed': project.completed }" @click="toggle( project.id )">
                                <td>
                                    <i class="fas" :class="expanded[ project.id ] ? 'fa-caret-down' : 'fa-caret-right'"></i>
                                    <a v-if="project.url" :href="project.url" target="_blank" class="fw-bold" @click.stop>{{ project.label }}</a>
                                    <template v-else><span class="badge bg-primary me-1">Progetto</span><span class="fw-bold">{{ project.label }}</span></template>
                                    <span v-if="project.completed" class="badge bg-secondary ms-1">concluso</span>
                                    <div class="small text-muted ps-project-name">{{ project.kind === 'project' ? project.rifLibero : ( project.customer || project.name ) }}</div>
                                </td>
                                <td class="text-end">{{ hours( project.totals.estimatedHours ) }}</td>
                                <td class="text-end">
                                    {{ hours( project.totals.hours ) }}
                                    <div class="small text-muted">svolte {{ hours( project.totals.doneHours ) }}</div>
                                </td>
                                <td class="text-end">
                                    {{ money( project.totals.cost ) }}
                                    <i v-if="project.totals.missingRateHours > 0" class="fas fa-exclamation-triangle text-warning ms-1"
                                       :title="hours( project.totals.missingRateHours ) + ' pianificate da persone senza costo orario: il costo è sottostimato'"></i>
                                    <div class="small text-muted">svolto {{ money( project.totals.doneCost ) }}</div>
                                    <div v-if="project.totals.extraCost > 0 || project.totals.extraHours > 0" class="small ps-extra">
                                        di cui extra {{ money( project.totals.extraCost ) }} ( {{ hours( project.totals.extraHours ) }} )
                                    </div>
                                </td>
                                <td class="text-end">{{ project.totals.budget !== '' ? money( project.totals.budget ) : '–' }}</td>
                                <td>
                                    <div v-if="project.totals.budget !== ''" class="ps-usage" :title="usageTitle( project.totals )">
                                        <div class="ps-usage-track">
                                            <div class="ps-usage-done" :class="usageClass( project.totals )" :style="{ width: usageWidth( project.totals.doneCost, project.totals.budget ) }"></div>
                                            <div class="ps-usage-planned" :class="usageClass( project.totals )" :style="{ width: usageWidth( project.totals.cost, project.totals.budget ) }"></div>
                                        </div>
                                        <span class="ps-usage-pct" :class="usageClass( project.totals )">{{ usagePct( project.totals ) }}</span>
                                    </div>
                                    <span v-else class="small text-muted">nessun budget</span>
                                </td>
                                <td class="text-end fw-bold" :class="deltaClass( project.totals )">{{ delta( project.totals ) }}</td>
                            </tr>

                            <tr v-if="expanded[ project.id ]" v-for="activity in project.activities" :key="project.id + '-' + activity.workTypeId" class="ps-activity-row">
                                <td>
                                    <span class="ps-dot" :style="{ backgroundColor: workType( activity.workTypeId ).color }"></span>
                                    {{ workType( activity.workTypeId ).activity }}
                                </td>
                                <td class="text-end">{{ hours( activity.estimatedHours ) }}</td>
                                <td class="text-end">
                                    <span :class="{ 'text-danger fw-bold': activity.hours > activity.estimatedHours && activity.estimatedHours > 0 }">{{ hours( activity.hours ) }}</span>
                                    <span class="small text-muted"> · svolte {{ hours( activity.doneHours ) }}</span>
                                </td>
                                <td class="text-end">
                                    {{ money( activity.cost ) }}
                                    <i v-if="activity.missingRateHours > 0" class="fas fa-exclamation-triangle text-warning ms-1"
                                       :title="hours( activity.missingRateHours ) + ' senza costo orario'"></i>
                                    <div v-if="activity.extraHours > 0" class="small ps-extra">di cui extra {{ money( activity.extraCost ) }}</div>
                                </td>
                                <td class="text-end">{{ activity.budget !== '' ? money( activity.budget ) : '–' }}</td>
                                <td>
                                    <div v-if="activity.budget !== ''" class="ps-usage" :title="usageTitle( activity )">
                                        <div class="ps-usage-track">
                                            <div class="ps-usage-done" :class="usageClass( activity )" :style="{ width: usageWidth( activity.doneCost, activity.budget ) }"></div>
                                            <div class="ps-usage-planned" :class="usageClass( activity )" :style="{ width: usageWidth( activity.cost, activity.budget ) }"></div>
                                        </div>
                                        <span class="ps-usage-pct" :class="usageClass( activity )">{{ usagePct( activity ) }}</span>
                                    </div>
                                </td>
                                <td class="text-end" :class="deltaClass( activity )">{{ delta( activity ) }}</td>
                            </tr>
                        </template>

                        <tr v-if="!loading && !filteredProjects.length">
                            <td colspan="7" class="text-center text-muted py-3">
                                Nessun progetto con ore o budget. Ore e budget si inseriscono in
                                <a href="/manager/planning/projects">Ore progetti</a>.
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="ps-legend small text-muted">
                <span><span class="ps-legend-box done"></span> Costo svolto ( fino a oggi )</span>
                <span><span class="ps-legend-box planned"></span> Costo pianificato totale</span>
                <span><span class="ps-legend-box warn"></span> Oltre l'85% del budget</span>
                <span><span class="ps-legend-box over"></span> Oltre il budget</span>
            </div>

        </div>
    </section>

</div>

<style>
    ##planning-stats-app[v-cloak] { display: none; }

    .ps-tiles { display: grid; grid-template-columns: repeat( auto-fit, minmax( 200px, 1fr ) ); gap: 12px; margin-bottom: 16px; }
    .ps-tile { background: ##fff; border: 1px solid ##dfe5ee; border-radius: 8px; padding: 12px 16px; }
    .ps-tile-label { font-size: 12px; color: ##6b7684; text-transform: uppercase; letter-spacing: .03em; }
    .ps-tile-value { font-size: 24px; font-weight: 700; margin-top: 2px; }
    .ps-tile-note { font-size: 12px; color: ##6b7684; }
    .ps-tile.alert .ps-tile-value { color: ##e03131; }

    .ps-project-row { cursor: pointer; }
    .ps-project-row td { border-top: 1px solid ##dfe5ee; }
    .ps-project-name { max-width: 320px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .ps-completed td { opacity: .7; }
    .ps-activity-row td { background: ##f8fafc; font-size: 13px; border-top: 0; }
    .ps-activity-row td:first-child { padding-left: 30px; }
    .ps-extra { color: ##b08900; font-weight: 600; }
    .ps-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 4px; }

    .ps-usage { display: flex; align-items: center; gap: 8px; }
    .ps-usage-track { position: relative; flex: 1; height: 10px; background: ##e9edf3; border-radius: 5px; overflow: hidden; }
    .ps-usage-planned, .ps-usage-done { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 5px; }
    .ps-usage-planned { opacity: .4; }
    .ps-usage-done, .ps-usage-planned { background: ##2f9e44; }
    .ps-usage-done.warn, .ps-usage-planned.warn { background: ##f08c00; }
    .ps-usage-done.over, .ps-usage-planned.over { background: ##e03131; }
    .ps-usage-done { z-index: 1; }
    .ps-usage-pct { width: 46px; text-align: right; font-size: 12px; font-weight: 600; color: ##2f9e44; }
    .ps-usage-pct.warn { color: ##f08c00; }
    .ps-usage-pct.over { color: ##e03131; }

    .ps-legend { display: flex; flex-wrap: wrap; gap: 16px; margin-top: 8px; }
    .ps-legend > span { display: inline-flex; align-items: center; gap: 5px; }
    .ps-legend-box { display: inline-block; width: 16px; height: 8px; border-radius: 4px; background: ##2f9e44; }
    .ps-legend-box.planned { opacity: .4; }
    .ps-legend-box.warn { background: ##f08c00; }
    .ps-legend-box.over { background: ##e03131; }
</style>
</cfoutput>
