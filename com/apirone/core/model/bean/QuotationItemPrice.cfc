component extends="com.apirone.core.model.bean.AbsBean" accessors="true" {

	property name="quotationItemId" type="String";
	
	property name="amount" type="Numeric"; <!--- use getTotal() for total :-) ---> 
	property name="discount1" type="Numeric";
	property name="discount2" type="Numeric";
	property name="quantity" type="Numeric";
	// true se almeno un prodotto della riga non ha prezzo configurato (calcolato a 0).
	// Vedi PriceCalculatorService.calculate() e QuotationItemService.get*Pricing().
	property name="missingPrice" type="Boolean" default="false";
	//property name="flatDiscount" type="Numeric";

	property name="lines" type="com.apirone.core.model.bean.QuotationItemPriceLine[]";
	property name="method" type="com.apirone.core.model.bean.PriceMethod";

	public QuotationItemPrice function init(){
		var method = new com.apirone.core.model.bean.PriceMethod();

		// C = Calculated, F = fixed
		setMethod( method.setId( "C" ) );
		setLines( [] );

		return this;
	}

	public Numeric function getTotalGoods(){
		var total = 0;

		for ( var line in getLines() ) {
			total = total + line.getAmount();
		}

		return total;
	}

	public Numeric function getCost(){
		var total = 0;

		for ( var line in getLines() ) {
			total = total + line.getCost();
		}

		return total;
	}

	public Numeric function getTotal(){
		// A prezzo fisso l'importo inserito è il prezzo pieno: gli sconti si applicano anche lì
		var total = isFixed() ? Val( getAmount() ) : getTotalGoods();

		if ( StructKeyExists( variables, "discount1" ) && variables.discount1 > 0 ) {
			total = total - ( total * variables.discount1 / 100 );
		}

		if ( StructKeyExists( variables, "discount2" ) && variables.discount2 > 0 ) {
			total = total - ( total * variables.discount2 / 100 );
		}

		return val(NumberFormat(total, "9.9999"));
	}

	public Boolean function isFixed(){
		if ( getMethod().getId() == "F" ) {
			return true;
		}
		
		return false;
	
	}

}
