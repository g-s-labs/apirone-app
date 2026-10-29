component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		prc.title = "Costi per linea/finitura";

		prc.page['categories'] = super.fire( "ProductCategory.list" );
		prc.page['lines']      = super.fire( "Line.list" );

		prc.jsFiles.add( "app-line-cost" );

		event.setView( "line/cost/list" );
	}
}
