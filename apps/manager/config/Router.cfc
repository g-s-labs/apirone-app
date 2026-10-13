component {

	function configure(){
		// var settings = new config.Settings();

		setFullRewrites( true );

		get( "/live", function( event, rc, prc ){
			return "<meta http-equiv='refresh' content='120'>
				Live #Now()#";
		} );

		get( "/util/tmp" ).to( "MainController.tmp" ).end();

		get( "/ajax/search" ).to( "SearchAjaxController.list" ).end();
		get( "/batch/update-terms" ).to( "BatchController.updateSearchTerms" ).end();

		post( "/ajax/verticale-sync/run" ).to( "VerticaleSyncAjaxController.run" ).end();
		get( "/ajax/verticale-sync/status" ).to( "VerticaleSyncAjaxController.status" ).end();
		get( "/ajax/verticale/claim-invoices" ).to( "VerticaleSyncAjaxController.claimInvoices" ).end();

		post( "/ajax/crm-sync/run" ).to( "CrmSyncAjaxController.run" ).end();
		get( "/ajax/crm-sync/status" ).to( "CrmSyncAjaxController.status" ).end();

		/*
			dashboard
		*/
		get( "/dashboard" ).to( "MainController.dashboard" ).end();
		get( "/plate/designer" ).to( "PlateController.designer" ).end();
		get( "/plate/map" ).to( "PlateController.map" ).end();


		/*
			prices types
		*/
		get( "/ajax/prices/types/exists" ).to( "PriceTypeAjaxController.idExists" ).end();
		get( "/ajax/prices/types/:id" ).to( "PriceTypeAjaxController.get" ).end();
		post( "/ajax/prices/types" ).to( "PriceTypeAjaxController.save" ).end();
		delete( "/ajax/prices/types" ).to( "PriceTypeAjaxController.delete" ).end();
		get( "/ajax/prices/types" ).to( "PriceTypeAjaxController.list" ).end();
		get( "/prices/types" ).to( "PriceTypeController.list" ).end();

		/*
			prices
		*/
		post( "/ajax/prices/reassign" ).to( "PriceAjaxController.reassign" ).end();
		post( "/ajax/:by-regex:(products|product-items)/:id/price/simulate" ).to( "PriceAjaxController.simulate" ).end();
		post( "/ajax/products/:id/price/simulate-signage" ).to( "PriceAjaxController.simulateSignage" ).end();
		post( "/ajax/products/:id/save-margins" ).to( "ProductAjaxController.saveMargins" ).end();
		post( "/ajax/products/save-line-heights/:id" ).to( "ProductAjaxController.saveLineHeights" ).end();
		get( "/prices/manage" ).to( "PriceController.manage" ).end();

		get( "/ajax/:by-regex:(products|product-items)/:id/prices" ).to( "PriceAjaxController.list" ).end();
		post( "/ajax/:by-regex:(products|product-items)/:id/prices" ).to( "PriceAjaxController.save" ).end();
		post( "/ajax/:by-regex:(products|product-items)/:id/price/calculate" ).to( "PriceAjaxController.calculate" ).end();


		/*
			catalog bundle
		*/
		post( "/ajax/catalog-bundles/detail" ).to( "CatalogBundleAjaxController.saveDetail" ).end();
		get( "/ajax/catalog-bundles" ).to( "CatalogBundleAjaxController.list" ).end();
		post( "/ajax/catalog-bundles" ).to( "CatalogBundleAjaxController.save" ).end();
		delete( "/signages/catalog-bundles" ).to( "CatalogBundleAjaxController.delete" ).end();
		get( "/catalog-bundles" ).to( "CatalogBundleController.list" ).end();


		/*
			signages
		*/
		get( "/signages/rows-config-item/:id/product/:productId" ).to( "SignageConfigItemController.get" ).end();
		get( "/signages/rows-config-item/:id" ).to( "SignageConfigItemController.get" ).end();
		post( "/ajax/signages/rows-config" ).to( "SignageConfigAjaxController.save" ).end();
		get( "/signages/rows-config/:id" ).to( "SignageConfigController.rowConfig" ).end();
		get( "/signages/rows-config" ).to( "SignageConfigController.rowConfig" ).end();

		/*
			metadata global
		*/
		get( "/global-metadata" ).to( "GlobalMetadataController.list" ).end();
		get( "/ajax/global-metadata/:id" ).to( "GlobalMetadataAjaxController.get" ).end();
		post( "/ajax/global-metadata" ).to( "GlobalMetadataAjaxController.save" ).end();
		get( "/ajax/global-metadata" ).to( "GlobalMetadataAjaxController.list" ).end();

		/*
			metadata type
		*/
		get( "/ajax/metadata-types/code-exists" ).to( "MetadataTypeAjaxController.codeExists" ).end();
		get( "/ajax/metadata-types/:id" ).to( "MetadataTypeAjaxController.get" ).end();
		post( "/ajax/metadata-types" ).to( "MetadataTypeAjaxController.save" ).end();
		get( "/ajax/metadata-types" ).to( "MetadataTypeAjaxController.list" ).end();
		delete( "/ajax/metadata-types" ).to( "MetadataTypeAjaxController.delete" ).end();
		get( "/metadata-types" ).to( "MetadataTypeController.list" ).end();

		/*
			metadata
		*/
		get( "/ajax/:by-regex:(raw-values)/:id/metadata" ).to( "MetadataAjaxController.list" ).end();
		post( "/ajax/:by-regex:(raw-values)/:id/metadata" ).to( "MetadataAjaxController.save" ).end();
		get( "/ajax/metadata" ).to( "MetadataTypeAjaxController.list" ).end();
		delete( "/ajax/metadata" ).to( "MetadataTypeAjaxController.delete" ).end();
		get( "/metadata" ).to( "MetadataTypeController.list" ).end();

		/*
			audit entry
		*/
		get( "/ajax/audit-entries/:id" ).to( "AuditEntryAjaxController.get" ).end();
		get( "/ajax/audit-entries" ).to( "AuditEntryAjaxController.list" ).end();
		get( "/audit-entries" ).to( "AuditEntryController.list" ).end();

		/*
			error log ( errori registrati da apps/utils/errorReport.cfm )
		*/
		get( "/error-logs/:id/report" ).to( "ErrorLogController.report" ).end();
		get( "/error-logs/:id" ).to( "ErrorLogController.detail" ).end();
		get( "/error-logs" ).to( "ErrorLogController.list" ).end();


		/*
			fruits
		*/
		get( "/ajax/fruits/code-exists" ).to( "FruitAjaxController.codeExists" ).end();
		// TODO: consider to remove the 2 follow routes ("/items")
		post( "/ajax/fruits/:id/items" ).to( "FruitAjaxController.addItem" ).end();
		get( "/ajax/fruits/:id/items" ).to( "FruitAjaxController.listItems" ).end();
		get( "/ajax/fruits/:id" ).to( "FruitAjaxController.get" ).end();
		get( "/ajax/fruits" ).to( "FruitAjaxController.list" ).end();
		post( "/ajax/fruits" ).to( "FruitAjaxController.save" ).end();
		delete( "/ajax/fruits" ).to( "FruitAjaxController.delete" ).end();
		get( "/fruits" ).to( "FruitController.list" ).end();


		/*
			articles (servizi)
		*/
		get( "/ajax/articles/code-exists" ).to( "ArticleAjaxController.codeExists" ).end();
		// TODO: consider to remove the 2 follow routes ("/items")
		post( "/ajax/articles/:id/items" ).to( "ArticleAjaxController.addItem" ).end();
		get( "/ajax/articles/:id/items" ).to( "ArticleAjaxController.listItems" ).end();
		get( "/ajax/articles/:id" ).to( "ArticleAjaxController.get" ).end();
		get( "/ajax/articles" ).to( "ArticleAjaxController.list" ).end();
		post( "/ajax/articles" ).to( "ArticleAjaxController.save" ).end();
		delete( "/ajax/articles" ).to( "ArticleAjaxController.delete" ).end();
		get( "/articles" ).to( "ArticleController.list" ).end();


		/*
			current account
		*/
		post( "/ajax/change-pwd" ).to( "CurrentUserAjaxController.changePwd" ).end();
		get( "/my/account" ).to( "CurrentUserController.get" ).end();
		get( "/my/settings" ).to( "CurrentUserController.settings" ).end();


		/*
			finishes
		*/
		get( "/ajax/finishes/code-exists" ).to( "FinishAjaxController.codeExists" ).end();
		get( "/ajax/finishes" ).to( "FinishAjaxController.list" ).end();
		post( "/ajax/finishes" ).to( "FinishAjaxController.save" ).end();
		delete( "/ajax/finishes" ).to( "FinishAjaxController.delete" ).end();
		get( "/finishes" ).to( "FinishController.list" ).end();


		/*
			raw value
		*/
		get( "/ajax/raw-values/code-exists" ).to( "RawValueAjaxController.codeExists" ).end();
		get( "/ajax/raw-values/:id" ).to( "RawValueAjaxController.get" ).end();
		post( "/ajax/raw-values" ).to( "RawValueAjaxController.save" ).end();
		delete( "/ajax/raw-values" ).to( "RawValueAjaxController.delete" ).end();
		get( "/ajax/raw-values" ).to( "RawValueAjaxController.list" ).end();
		get( "/raw-values" ).to( "RawValueController.list" ).end();

		/*
			raw products
		*/
		get( "/ajax/raw-products" ).to( "RawProductAjaxController.list" ).end();

		/*
			countries
		*/
		get( "/countries" ).to( "CountryController.list" ).end();
		get( "/ajax/countries/code-exists" ).to( "CountryAjaxController.codeExists" ).end();
		post( "/ajax/countries" ).to( "CountryAjaxController.save" ).end();
		delete( "/ajax/countries" ).to( "CountryAjaxController.delete" ).end();
		get( "/ajax/countries" ).to( "CountryAjaxController.list" ).end();


		/*
			production times
		*/
		get( "/ajax/production-times/:id" ).to( "ProductionTimeAjaxController.get" ).end();
		post( "/ajax/production-times" ).to( "ProductionTimeAjaxController.save" ).end();
		delete( "/ajax/production-times" ).to( "ProductionTimeAjaxController.delete" ).end();
		get( "/ajax/production-times" ).to( "ProductionTimeAjaxController.list" ).end();
		get( "/production-times" ).to( "ProductionTimeController.list" ).end();

		/*
			fonts
		*/
		get( "/ajax/fonts/code-exists" ).to( "FontAjaxController.codeExists" ).end();
		get( "/ajax/fonts/:id" ).to( "FontAjaxController.get" ).end();
		delete( "/ajax/fonts" ).to( "FontAjaxController.delete" ).end();
		get( "/ajax/fonts" ).to( "FontAjaxController.list" ).end();
		post( "/ajax/fonts" ).to( "FontAjaxController.save" ).end();
		get( "/fonts" ).to( "FontController.list" ).end();

		/*
			font families
		*/
		get( "/ajax/font-families/code-exists" ).to( "FontFamilyAjaxController.codeExists" ).end();
		get( "/ajax/font-families/get-by-signage-config-id" ).to( "FontFamilyAjaxController.getBySignageConfigId" ).end();
		get( "/ajax/font-families/:id" ).to( "FontFamilyAjaxController.get" ).end();
		delete( "/ajax/font-families" ).to( "FontFamilyAjaxController.delete" ).end();
		get( "/ajax/font-families" ).to( "FontFamilyAjaxController.list" ).end();
		post( "/ajax/font-families" ).to( "FontFamilyAjaxController.save" ).end();
		get( "/font-families" ).to( "FontFamilyController.list" ).end();

		/*
			pictograms
		*/
		// TODO: non usato
		get( "/ajax/pictograms/font-family-exists" ).to( "PictogramAjaxController.fontFamilyExists" ).end();
		get( "/ajax/pictograms/:id/dimensions" ).to( "PictogramAjaxController.listDimensions" ).end();
		post( "/ajax/pictograms/:id/dimensions" ).to( "PictogramAjaxController.saveDimensions" ).end();
		get( "/ajax/pictograms/:id" ).to( "PictogramAjaxController.get" ).end();
		delete( "/ajax/pictograms" ).to( "PictogramAjaxController.delete" ).end();
		get( "/ajax/pictograms" ).to( "PictogramAjaxController.list" ).end();
		post( "/ajax/pictograms" ).to( "PictogramAjaxController.save" ).end();


		get( "/ajax/font-family/:id/pictograms" ).to( "PictogramAjaxController.fontFamilyList" ).end();

		/*
			font family sizes
		*/
		get( "/ajax/font-family-sizes/:id" ).to( "FontFamilySizeAjaxController.get" ).end();
		delete( "/ajax/font-family-sizes" ).to( "FontFamilySizeAjaxController.delete" ).end();
		get( "/ajax/font-family-sizes" ).to( "FontFamilySizeAjaxController.list" ).end();
		post( "/ajax/font-family-sizes" ).to( "FontFamilySizeAjaxController.save" ).end();

		// TODO: non torna famiglie ma una serie di sizes (riv. nome metodo)
		get( "/ajax/font-family/:id/sizes" ).to( "FontFamilySizeAjaxController.fontFamilyList" ).end();

		/*
			auth // login
		*/
		post( "/login/pincode/check" ).toHandler( "AuthController.checkPincode" );
		post( "/login/check" ).toHandler( "AuthController.checkLogin" );
		post( "/login/recover/check" ).toHandler( "AuthController.checkRecover" );
		get( "/login/recover" ).toHandler( "AuthController.recover" );
		post( "/login/reset-password/check" ).toHandler( "AuthController.checkResetPassword" );
		get( "/login/reset-password" ).toHandler( "AuthController.resetPassword" );
		get( "/login/pincode" ).toHandler( "AuthController.pincode" );
		get( "/login" ).toHandler( "AuthController.login" );
		get( "/logout" ).toHandler( "AuthController.logout" );
		get( "/change-user/:id" ).toHandler( "AuthController.changeUser" );


		/*
			accounts
		*/
		get( "/ajax/accounts/email-exists" ).to( "AccountAjaxController.emailExists" ).end();
		post( "/ajax/accounts/pwd" ).to( "AccountAjaxController.updatePwd" ).end();
		get( "/ajax/accounts" ).to( "AccountAjaxController.list" ).end();
		post( "/ajax/accounts" ).to( "AccountAjaxController.save" ).end();
		delete( "/ajax/accounts" ).to( "AccountAjaxController.delete" ).end();
		get( "/accounts" ).to( "AccountController.list" ).end();
		get( "/accounts/print" ).to( "AccountController.print" ).end();


		/*
			users
		*/
		get( "/ajax/users" ).to( "UserAjaxController.list" ).end();
		post( "/ajax/users" ).to( "UserAjaxController.save" ).end();
		delete( "/ajax/users" ).to( "UserAjaxController.delete" ).end();
		get( "/users" ).to( "UserController.list" ).end();
		get( "/users/print" ).to( "UserController.print" ).end();


		/*
			attribute values
		*/
		post( "/ajax/attributes/:id/raw-values/add" ).to( "AttributeValueAjaxController.addValue" ).end();
		post( "/ajax/attributes/:id/raw-values/sort" ).to( "AttributeValueAjaxController.sort" ).end();
		delete( "/ajax/attributes/:id/raw-values" ).to( "AttributeValueAjaxController.deleteValues" ).end();


		/*
			attributes
		*/
		get( "/ajax/attributes/code-exists" ).to( "AttributeAjaxController.codeExists" ).end();
		get( "/ajax/attributes/raw-values" ).to( "AttributeAjaxController.listRawValues" ).end();
		get( "/ajax/attributes/new" ).to( "AttributeAjaxController.new" ).end();
		get( "/ajax/attributes/:id" ).to( "AttributeAjaxController.get" ).end();
		post( "/ajax/attributes" ).to( "AttributeAjaxController.save" ).end();
		delete( "/ajax/attributes" ).to( "AttributeAjaxController.delete" ).end();
		get( "/ajax/attributes" ).to( "AttributeAjaxController.list" ).end();
		get( "/attributes" ).to( "AttributeController.list" ).end();


		/*
			reports
		*/
		get( "/ajax/reports/:id" ).toHandler( "ReportAjaxController.get" );
		get( "/ajax/reports" ).toHandler( "ReportAjaxController.list" );
		get( "/reports/:id" ).toHandler( "ReportController.get" );
		get( "/reports" ).toHandler( "ReportController.list" );


		/*
			texts
		*/
		get( "/ajax/texts/:id/all" ).to( "TextAjaxController.all" ).end();
		get( "/ajax/texts/:id" ).to( "TextAjaxController.get" ).end();
		get( "/ajax/texts_createtraduzionimancanti/:id" ).to( "TextAjaxController.createTraduzioniMancanti" ).end();
		get( "/ajax/texts_createalltraduzionimancanti" ).to( "TextAjaxController.createAllTraduzioniMancanti" ).end();
		get( "/ajax/texts" ).to( "TextAjaxController.list" ).end();
		post( "/ajax/texts" ).to( "TextAjaxController.save" ).end();
		get( "/texts" ).to( "TextController.list" ).end();


		/*
			planning ( Gantt )
		*/
		// prima le rotte più specifiche: un pattern più corto cattura anche gli URL più lunghi
		get( "/ajax/planning/people/:id/costs" ).to( "PlanningAjaxController.listPersonCosts" ).end();
		post( "/ajax/planning/people/:id/costs" ).to( "PlanningAjaxController.savePersonCost" ).end();
		delete( "/ajax/planning/costs/:id" ).to( "PlanningAjaxController.deletePersonCost" ).end();
		get( "/ajax/planning/stats" ).to( "PlanningAjaxController.stats" ).end();
		post( "/ajax/planning/people/:id" ).to( "PlanningAjaxController.savePerson" ).end();
		get( "/ajax/planning/people" ).to( "PlanningAjaxController.listPeople" ).end();
		post( "/ajax/planning/people" ).to( "PlanningAjaxController.createPerson" ).end();
		delete( "/ajax/planning/closures/:id" ).to( "PlanningAjaxController.deleteClosure" ).end();
		get( "/ajax/planning/closures" ).to( "PlanningAjaxController.listClosures" ).end();
		post( "/ajax/planning/closures" ).to( "PlanningAjaxController.saveClosure" ).end();
		post( "/ajax/planning/blocks/:id/move" ).to( "PlanningAjaxController.moveBlock" ).end();
		post( "/ajax/planning/blocks/:id/resize" ).to( "PlanningAjaxController.resizeBlock" ).end();
		post( "/ajax/planning/blocks/:id/split" ).to( "PlanningAjaxController.splitBlock" ).end();
		post( "/ajax/planning/blocks/:id/day" ).to( "PlanningAjaxController.setBlockDay" ).end();
		post( "/ajax/planning/blocks/:id/flags" ).to( "PlanningAjaxController.setBlockFlags" ).end();
		post( "/ajax/planning/blocks/:id/times" ).to( "PlanningAjaxController.setBlockTimes" ).end();
		post( "/ajax/planning/blocks/:id/note" ).to( "PlanningAjaxController.setBlockNote" ).end();
		post( "/ajax/planning/blocks/:id/extra" ).to( "PlanningAjaxController.setBlockExtra" ).end();
		delete( "/ajax/planning/blocks/:id" ).to( "PlanningAjaxController.deleteBlock" ).end();
		post( "/ajax/planning/blocks" ).to( "PlanningAjaxController.createBlock" ).end();
		delete( "/ajax/planning/projects/:id/quotations/:quotationId" ).to( "PlanningAjaxController.unlinkQuotation" ).end();
		post( "/ajax/planning/projects/:id/quotations" ).to( "PlanningAjaxController.linkQuotation" ).end();
		post( "/ajax/planning/projects/:id/details" ).to( "PlanningAjaxController.updateProject" ).end();
		delete( "/ajax/planning/projects/:id" ).to( "PlanningAjaxController.deleteProject" ).end();
		post( "/ajax/planning/projects/:id" ).to( "PlanningAjaxController.saveProject" ).end();
		post( "/ajax/planning/projects" ).to( "PlanningAjaxController.createProject" ).end();
		get( "/ajax/planning/quotations" ).to( "PlanningAjaxController.searchQuotations" ).end();
		get( "/ajax/planning/projects" ).to( "PlanningAjaxController.listProjects" ).end();
		get( "/ajax/planning/gantt" ).to( "PlanningAjaxController.gantt" ).end();
		get( "/planning/people" ).to( "PlanningController.people" ).end();
		get( "/planning/gantt" ).to( "PlanningController.gantt" ).end();
		get( "/planning/projects" ).to( "PlanningController.projects" ).end();
		get( "/planning/stats" ).to( "PlanningController.stats" ).end();


		/*
			frames
		*/
		get( "/ajax/frames/code-exists" ).to( "FrameAjaxController.codeExists" ).end();
		get( "/ajax/frames/:id" ).to( "FrameAjaxController.get" ).end();
		delete( "/ajax/frames" ).to( "FrameAjaxController.delete" ).end();
		post( "/ajax/frames" ).to( "FrameAjaxController.save" ).end();
		get( "/ajax/frames" ).to( "FrameAjaxController.list" ).end();
		get( "/frames" ).to( "FrameController.builder" ).end();


		/*
			components
		*/
		post( "/ajax/components/reassign" ).to( "ComponentAjaxController.reassign" ).end();
		delete( "/ajax/components/delete" ).to( "ComponentAjaxController.massiveDelete" ).end();
		get( "/ajax/components/by-type" ).to( "ComponentAjaxController.listByType" ).end();
		post( "/ajax/components/by-type" ).to( "ComponentAjaxController.save" ).end();
		get( "/ajax/components" ).to( "ComponentAjaxController.list" ).end();
		post( "/ajax/components" ).to( "ComponentAjaxController.save" ).end(); // TODO: to remove
		get( "/components/reassign" ).to( "ComponentController.reassign" ).end();
		get( "/components" ).to( "ComponentController.list" ).end();


		/*
			files
		*/
		delete( "/ajax/files/:id" ).to( "FileAjaxController.delete" ).end();
		get( "/ajax/:by-regex:(products|product-items|combinations|attributes-values|quotation-items|quotation-zones)/:id/images" )
			.to( "FileAjaxController.list" )
			.end();

		post( "/ajax/:by-regex:(products|product-items|combinations|attributes-values|quotation-items|quotation-zones)/:id/images" )
			.to( "FileAjaxController.upload" )
			.end();


		/*
			products items

		*/
		// TODO: should be "ajax/products/:id/product-items"
		get( "/ajax/product-items" ).to( "ProductItemAjaxController.productItemsByProduct" ).end();
		get( "/technical-reports/print" ).to( "TechnicalReportController.print" ).end();

		/*
			products
		*/

		get( "/ajax/massiveproductreorder" ).to( "ProductAjaxController.massiveProductReorder" ).end();
		get( "/ajax/products/get-id-and-file-by-params" ).to( "ProductAjaxController.getIdAndFileByParams" ).end();
		get( "/ajax/products/code-exists" ).to( "ProductAjaxController.codeExists" ).end();
		post( "/ajax/products/:id/combinations/calculate" ).to( "ProductAjaxController.calculateCombinations" ).end();
		delete( "/ajax/products/:id/combinations" ).to( "ProductAjaxController.deleteCombinations" ).end();
		get( "/ajax/products/:id/combinations" ).to( "ProductAjaxController.combinations" ).end();
		post( "/ajax/products/:id/items/order" ).to( "ProductAjaxController.sortItems" ).end();
		get( "/ajax/products/:id/items/order" ).to( "ProductAjaxController.listItemsForSort" ).end();
		// la POST (path piu' lungo) va prima della GET: ColdBox prende la prima rotta il cui
		// pattern combacia con l'inizio dell'URL e poi controlla il verbo
		post( "/ajax/products/:id/engraving-markers/:attributeId" ).to( "ProductEngravingMarkerAjaxController.save" ).end();
		get( "/ajax/products/:id/engraving-markers" ).to( "ProductEngravingMarkerAjaxController.list" ).end();
		post( "/ajax/products/:id/items/clone" ).to( "ProductAjaxController.cloneItems" ).end();
		get( "/ajax/products/:id/attributes/order" ).to( "ProductAjaxController.listAttributesForSort" ).end();
		post( "/ajax/products/:id/attributes/order" ).to( "ProductAjaxController.sortAttributes" ).end();
		post( "/ajax/products/:id/items/importants" ).to( "ProductAjaxController.updateImportants" ).end();
		post( "/ajax/products/:id/items" ).to( "ProductAjaxController.addItem" ).end();
		post( "/ajax/products/:id/values" ).to( "ProductAjaxController.addValue" ).end();
		get( "/ajax/products/:id/items" ).to( "ProductAjaxController.listItems" ).end();
		delete( "/ajax/products/:id/items" ).to( "ProductAjaxController.removeItems" ).end();
		post( "/ajax/products/:id/detail" ).to( "ProductAjaxController.saveDetail" ).end();
		get( "/ajax/products/:id" ).to( "ProductAjaxController.get" ).end();
		delete( "/ajax/products" ).to( "ProductAjaxController.delete" ).end();
		post( "/ajax/products" ).to( "ProductAjaxController.save" ).end();
		get( "/ajax/products" ).to( "ProductAjaxController.list" ).end();
		get( "/products/print/:id" ).to( "ProductController.print" ).end();
		get( "/products/:id/combinations" ).to( "ProductController.combinations" ).end();
		get( "/products/category/:id" ).to( "ProductController.listByCategoryId" ).end();
		get( "/products/:id" ).to( "ProductController.detail" ).end();
		get( "/products" ).to( "ProductController.list" ).end();


		/*
			product category
		*/
		get( "/ajax/product-categories/code-exists" ).to( "ProductCategoryAjaxController.codeExists" ).end();
		get( "/ajax/product-categories" ).to( "ProductCategoryAjaxController.list" ).end();
		post( "/ajax/product-categories" ).to( "ProductCategoryAjaxController.save" ).end();
		delete( "/ajax/product-categories" ).to( "ProductCategoryAjaxController.delete" ).end();
		get( "/product-categories" ).to( "ProductCategoryController.list" ).end();

		/*
			line costs
		*/
		get( "/ajax/lines_costs" ).to( "LineCostAjaxController.list" ).end();
		post( "/ajax/lines_costs" ).to( "LineCostAjaxController.save" ).end();
		delete( "/ajax/lines_costs" ).to( "LineCostAjaxController.delete" ).end();

		get( "/lines/costs" ).to( "LineCostController.list" ).end();

		/*
			line/model costs
		*/
		get( "/ajax/lines_model_costs" ).to( "LineModelCostAjaxController.list" ).end();
		post( "/ajax/lines_model_costs" ).to( "LineModelCostAjaxController.save" ).end();
		delete( "/ajax/lines_model_costs" ).to( "LineModelCostAjaxController.delete" ).end();

		get( "/lines/model-costs" ).to( "LineModelCostController.list" ).end();

		/*
			lines
		*/
		post( "/ajax/lines/clone" ).to( "LineAjaxController.clone" ).end();
		get( "/ajax/lines/code-exists" ).to( "LineAjaxController.codeExists" ).end();
		get( "/ajax/lines/categories/:categoryId" ).to( "LineAjaxController.listByCategoryId" ).end();
		post( "/ajax/lines/categories/:categoryId" ).to( "LineAjaxController.saveMarkup" ).end();
		delete( "/ajax/lines/:id/products" ).to( "LineAjaxController.deleteProduct" ).end();
		post( "/ajax/lines/:id/products" ).to( "LineAjaxController.createProduct" ).end();
		get( "/ajax/lines/attributes" ).to( "LineAjaxController.attributes" ).end();
		get( "/ajax/lines/:id" ).to( "LineAjaxController.get" ).end();
		get( "/ajax/lines" ).to( "LineAjaxController.list" ).end();
		post( "/ajax/lines" ).to( "LineAjaxController.save" ).end();
		delete( "/ajax/lines" ).to( "LineAjaxController.delete" ).end();

		get( "/lines/categories/:categoryId" ).to( "LineController.listByCategoryId" ).end();
		get( "/lines/categories" ).to( "LineController.listByCategoryId" ).end();
		get( "/lines/:id/categories/:categoryId/products" ).to( "LineController.products" ).end(); // TODO: better naming
		get( "/lines/:id/categories/:categoryId/attributes" ).to( "LineController.attributes" ).end();
		get( "/lines" ).to( "LineController.list" ).end();


		/*
			model configs
		*/
		get( "/ajax/model-config/get-by-params" ).to( "ModelConfigAjaxController.getByParams" ).end();
		post( "/ajax/model-config/" ).to( "ModelConfigAjaxController.save" ).end();


		/*
			model
		*/
		get( "/ajax/models/code-exists" ).to( "ModelAjaxController.codeExists" ).end();
		get( "/ajax/models" ).to( "ModelAjaxController.list" ).end();
		post( "/ajax/models" ).to( "ModelAjaxController.save" ).end();
		delete( "/ajax/models" ).to( "ModelAjaxController.delete" ).end();
		get( "/models/print" ).to( "ModelController.print" ).end();
		get( "/models" ).to( "ModelController.list" ).end();


		/*
			profiles
		*/
		get( "/ajax/profiles/:id" ).to( "ProfileAjaxController.get" ).end();
		get( "/ajax/profiles" ).to( "ProfileAjaxController.list" ).end();


		/*
			quotations
		*/
		get( "/ajax/quotations-export/:id" ).to( "QuotationAjaxController.export" ).end();
		get( "/ajax/quotations/categories" ).to( "QuotationAjaxController.listCategories" ).end();
		get( "/ajax/quotations/lines/:categoryId" ).to( "QuotationAjaxController.listLines" ).end();
		get( "/ajax/quotations/models/:lineId" ).to( "QuotationAjaxController.listModels" ).end();
		get( "/ajax/quotations/crmcustomers" ).to( "QuotationAjaxController.crmCustomers" ).end();
		get( "/ajax/quotations/crmopportunities" ).to( "QuotationAjaxController.crmOpportunities" ).end();
		get( "/ajax/quotations/crmleads" ).to( "QuotationAjaxController.crmLeads" ).end();
		get( "/ajax/quotations/finishes/:categoryId/:lineId" ).to( "QuotationAjaxController.listFinishes" ).end();
		get( "/ajax/quotations/signage-configs" ).to( "QuotationSignageAjaxController.list" ).end();
		get( "/ajax/quotations/signage/:id" ).to( "QuotationItemAjaxController.get" ).end();
		get( "/ajax/quotations_approve/:id" ).to( "QuotationAjaxController.approveQuotation" ).end();
		post( "/ajax/quotations/:id/markasSent" ).to( "QuotationAjaxController.markAsSent" ).end();
		post( "/ajax/quotations/:id/createrevision" ).to( "QuotationAjaxController.createRevision" ).end();
		post( "/ajax/quotations/:id/clone" ).to( "QuotationAjaxController.clone" ).end();
		get( "/ajax/quotations/:id/not-in-catalog" ).to( "QuotationAjaxController.notInCatalog" ).end();

		get( "/ajax/quotations/zones/:zoneId/positions" ).to( "QuotationZoneAjaxController.listPositions" ).end();
		post( "/ajax/quotations/zones" ).to( "QuotationZoneAjaxController.save" ).end();
		post( "/ajax/quotations/duplicatezone" ).to( "QuotationZoneAjaxController.duplicate" ).end();
		delete( "/ajax/quotations/zones" ).to( "QuotationZoneAjaxController.delete" ).end();
		get( "/ajax/quotations/:quotationId/zones" ).to( "QuotationZoneAjaxController.list" ).end();

		get( "/ajax/quotations/:id/updateallprices" ).to( "QuotationItemAjaxController.updateAllPrices" ).end();
		post( "/ajax/quotations/:id/items/:typeId/discount" ).to( "QuotationItemAjaxController.applyDiscountByType" ).end();
		get( "/ajax/quotations/:id/items/:typeId" ).to( "QuotationItemAjaxController.list" ).end();
		get( "/ajax/quotations/:id/missing-prices" ).to( "QuotationItemAjaxController.missingPrices" ).end();
		get( "/ajax/quotations/:id/itemsbyzone/:zoneId" ).to( "QuotationItemAjaxController.listByZone" ).end();
		get( "/ajax/quotations/:id/plates-export3d" ).to( "QuotationItemAjaxController.plates3dExport" ).end();

		get( "/ajax/quotations/:id/totals" ).to( "QuotationAjaxController.totals" ).end();
		post( "/ajax/quotations/:id/totals" ).to( "QuotationAjaxController.updateTotals" ).end();

		post( "/ajax/quotations/:quotationId/statuses/:statusId/files" ).to( "QuotationStatusHistoryAjaxController.saveFile" ).end();
		get( "/ajax/quotations/:quotationId/statuses" ).to( "QuotationStatusHistoryAjaxController.list" ).end();
		post( "/ajax/quotations/:quotationId/statuses" ).to( "QuotationStatusHistoryAjaxController.save" ).end();
		delete( "/ajax/quotations/:quotationId/statuses" ).to( "QuotationStatusHistoryAjaxController.delete" ).end();

		post( "/ajax/quotations/:quotationId/documents/reorder" ).to( "QuotationDocumentAjaxController.reorder" ).end();
		post( "/ajax/quotations/:quotationId/documents/delete" ).to( "QuotationDocumentAjaxController.deleteDoc" ).end();
		get( "/ajax/quotations/:quotationId/documents/:id/download" ).to( "QuotationDocumentAjaxController.download" ).end();
		get( "/ajax/quotations/:quotationId/proformas/:id/download" ).to( "QuotationProformaAjaxController.download" ).end();
		get( "/ajax/quotations/:quotationId/proformas" ).to( "QuotationProformaAjaxController.list" ).end();
		get( "/ajax/quotations/:quotationId/documents" ).to( "QuotationDocumentAjaxController.list" ).end();
		post( "/ajax/quotations/:quotationId/documents" ).to( "QuotationDocumentAjaxController.upload" ).end();

		get( "/ajax/quotations/:id/draft-count" ).to( "QuotationAjaxController.draftCount" ).end();
		get( "/ajax/quotations/:id" ).to( "QuotationAjaxController.get" ).end();

		get( "/quotations/new" ).to( "QuotationController.new" ).end();
		get( "/quotations/:id" ).to( "QuotationController.edit" ).end();
		post( "/quotations" ).to( "QuotationController.create" ).end(); // Da togliere
		get( "/quotations" ).to( "QuotationController.list" ).end();
		get( "/quotation-plant-positions/:id" ).to( "QuotationController.plantPositions" ).end();
		delete( "/ajax/quotation-item-positions/:key" ).to( "QuotationItemPositionAjaxController.delete" ).end();
		post( "/ajax/quotation-item-positions/" ).to( "QuotationItemPositionAjaxController.save" ).end();
		post( "/ajax/quotation-item-positions-print" ).to( "QuotationItemPositionAjaxController.print" ).end();

		get( "/ajax/quotation-item-drafts/zone/:zoneId" ).to( "QuotationItemDraftAjaxController.list" ).end();
		post( "/ajax/quotation-item-drafts/:id/position" ).to( "QuotationItemDraftAjaxController.updatePosition" ).end();
		post( "/ajax/quotation-item-drafts/:id/convert" ).to( "QuotationItemDraftAjaxController.convert" ).end();
		post( "/ajax/quotation-item-drafts/:id/apply" ).to( "QuotationItemDraftAjaxController.applyToItem" ).end();
		get( "/ajax/quotation-item-drafts/:id" ).to( "QuotationItemDraftAjaxController.get" ).end();
		delete( "/ajax/quotation-item-drafts/:id" ).to( "QuotationItemDraftAjaxController.delete" ).end();
		post( "/ajax/quotation-item-drafts/" ).to( "QuotationItemDraftAjaxController.create" ).end();

		get( "/ajax/quotations" ).to( "QuotationAjaxController.list" ).end();
		delete( "/ajax/quotations" ).to( "QuotationAjaxController.delete" ).end();
		post( "/ajax/quotations" ).to( "QuotationAjaxController.save" ).end();


		get( "/quotation-items-exported" ).to( "QuotationItemExportedController.list" ).end();
		get( "/ajax/quotation-items-exported/:key" ).to( "QuotationItemExportedAjaxController.listRows" ).end();
		delete( "/ajax/quotation-items-exported/:key" ).to( "QuotationItemExportedAjaxController.delete" ).end();
		post( "/ajax/quotation-items-exported" ).to( "QuotationItemExportedAjaxController.deleteMulti" ).end();
		get( "/ajax/quotation-items-exported" ).to( "QuotationItemExportedAjaxController.list" ).end();
		delete( "/ajax/quotation-item-exported-rows" ).to( "QuotationItemExportedAjaxController.deleteRow" ).end();

		get( "/quotations-exported" ).to( "QuotationExportedController.list" ).end();
		get( "/ajax/quotations-exported/:key" ).to( "QuotationExportedAjaxController.listRows" ).end();
		delete( "/ajax/quotations-exported/:key" ).to( "QuotationExportedAjaxController.delete" ).end();
		post( "/ajax/quotations-exported" ).to( "QuotationExportedAjaxController.deleteMulti" ).end();
		get( "/ajax/quotations-exported" ).to( "QuotationExportedAjaxController.list" ).end();
		delete( "/ajax/quotation-exported-rows" ).to( "QuotationExportedAjaxController.deleteRow" ).end();
		delete( "/ajax/quotations/:id" ).to( "QuotationAjaxController.delete" ).end();

		/*
			quotation items
		*/
		delete( "/ajax/quotation-items/signagerow" ).to( "QuotationSignageAjaxController.deleteRow" ).end();
		post( "/ajax/quotation-items/type/:type/pricing" ).to( "QuotationItemAjaxController.calculate" ).end();
		get( "/ajax/quotation-items/signage/:id/export" ).to( "QuotationItemAjaxController.signageExport" ).end();
		get( "/ajax/quotation-items/signage/:id" ).to( "QuotationItemAjaxController.editSignage" ).end();
		get( "/ajax/quotation-items/plate/:id/fruits" ).to( "QuotationItemAjaxController.listFruits" ).end();
		get( "/ajax/quotation-items/plate/:id/export3d" ).to( "QuotationItemAjaxController.plate3dExport" ).end();
		get( "/ajax/quotation-items/plate/:id/export" ).to( "QuotationItemAjaxController.plateExport" ).end();
		get( "/ajax/quotation-items/plate/:id" ).to( "QuotationItemAjaxController.editPlate" ).end();
		post( "/ajax/quotation-items/export-code-preview" ).to( "QuotationItemAjaxController.exportCodePreview" ).end();
		post( "/ajax/quotation-items/signage" ).to( "QuotationItemAjaxController.saveSignage" ).end();
		post( "/ajax/quotation-items/plate" ).to( "QuotationItemAjaxController.savePlate" ).end();
		get( "/ajax/quotation-items/accessory/:id" ).to( "QuotationItemAjaxController.editAccessory" ).end();
		post( "/ajax/quotation-items/accessory" ).to( "QuotationItemAjaxController.saveAccessory" ).end();
		get( "/ajax/quotation-items/article/:id" ).to( "QuotationItemAjaxController.editArticle" ).end();
		post( "/ajax/quotation-items/article" ).to( "QuotationItemAjaxController.saveArticle" ).end();

		get( "/ajax/quotation-items/product/by-params" ).to( "QuotationPlateAjaxController.getProductByParams" ).end();
		get( "/ajax/quotation-items/fruits/:id/product-items" ).to( "QuotationItemAjaxController.fruitProductItems" ).end();
		get( "/ajax/quotation-items/:id/product-items" ).to( "QuotationItemAjaxController.productItems" ).end();
		get( "/ajax/quotation-items/:id/not-in-catalog" ).to( "QuotationItemAjaxController.notInCatalog" ).end();
		post( "/ajax/quotation-items/reorder" ).to( "QuotationItemAjaxController.reorder" ).end();
		post( "/ajax/quotation-items/:id/duplicate" ).to( "QuotationItemAjaxController.duplicate" ).end();
		delete( "/ajax/quotation-items" ).to( "QuotationItemAjaxController.delete" ).end();
		//get( "/ajax/quotation-items" ).to( "QuotationItemAjaxController.list" ).end();


		/*
			combinations
		*/
		post( "/ajax/combinations/findByListOfProductItemIds" ).to( "CombinationAjaxController.findByListOfProductItemIds" ).end();

		/*
			roles
		*/
		get( "/roles" ).to( "RoleController.list" ).end();
		post( "/ajax/roles" ).to( "RoleAjaxController.save" ).end();
		get( "/roles/print" ).to( "RolController.print" ).end();

		get( "/ajax/roles/:roleId/permissions" ).to( "RolePermissionAjaxController.list" ).end();
		get( "/ajax/roles/:roleId" ).to( "RoleAjaxController.get" ).end();
		post( "/roles-permissions" ).to( "RolePermissionAjaxController.save" ).end();


		/*
			system
		*/
		get( "/system" ).to( "SystemController.get" ).end();


		/*
			lookup
			[TODO] "JSDATA" non funziona
		*/
		// get( "/(.*)/datajs" ).to( "LookupController.datajs" ).end();
	}

}
