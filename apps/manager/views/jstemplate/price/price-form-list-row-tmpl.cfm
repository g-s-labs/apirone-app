<cfprocessingdirective pageEncoding="UTF-8">

<cfoutput>
	<nmscript type="text/template" id="price-form-list-row-tmpl">

		<div class="mb-3 row" data-bind="css: { price-deleted: deleted }">
			<label class="col-sm-4 col-form-label text-end">
				<span data-bind="text: type.name"></span>
				<br>
				<span class="small-code">(<span data-bind="text: type.id"></span> <span data-bind="text: id"></span>)</span>
				## if ( data.type && data.type.id == "PROD_ITEM_GEN" ) { ##
				<br>
				<span class="small text-warning">Non usato nel calcolo: è sempre uguale al ricarico dell'articolo. Verrà rimosso.</span>
				## } ##
			</label>
			<div class="col-sm-8">

				<div class="row g-2 align-items-center">

					<div class="col-sm-5">

						<select required
							name="methodId_##=id##"
							class="form-control"
							data-bind="source: methods, value: method }" 
							data-value-field="id"
							data-text-field="name">
						</select>

					</div>

					<div class="col-sm-4">
						<input type="text" required class="form-control text-end" 
							name="amount_##=id##"
							maxlength="8"
							data-bind="value: amount">
					</div>

					<div class="col-sm-1">
						<span data-bind="text: method.simbol"></span>
					</div>

					<div class="col-sm-2">
						#iconButton( bind="click:delete", icon="trash", size="sm" )#
						<span data-bind=""></span>
					</div>

				</div>
				
			</div>
		</div>

	</nmscript>

</cfoutput>
