public class UPIProductFactory {

    public String detectarYResolverUPI(Map<String, Object> raw, UPIProductFactory factory, UPIResolver resolver) {
        Object producto = factory.construirProductoDesdeEvento(raw);
        if (producto == null) return null;
        return resolver.resolveUPI(producto);
    }
	
	public Object construirProductoDesdeEvento(Map<String, Object> raw) {
        String instrument = (String) raw.get("instrument");
        if (instrument == null) return null;

        switch (instrument) {
            case "IRSwap", "CCS" -> {
                boolean leg1Fixed = "Fixed".equalsIgnoreCase((String) raw.get("leg1_type"));
                boolean leg2Fixed = "Fixed".equalsIgnoreCase((String) raw.get("leg2_type"));
                String currency1 = (String) raw.get("currency1");
                String currency2 = (String) raw.get("currency2");
                boolean isInflation = raw.getOrDefault("inflation", false).equals(true);
                String freq1 = (String) raw.get("frequency1");
                String freq2 = (String) raw.get("frequency2");

                if (!currency1.equals(currency2)) {
                    if (!leg1Fixed && !leg2Fixed) return 6;
                    if (leg1Fixed && leg2Fixed) return 7;
                    return 8;
                } else {
                    if (isInflation) return 5;
                    if ("O/N".equals(freq1) || "O/N".equals(freq2)) return 2;
                    if (leg1Fixed && leg2Fixed) return 3;
                    if (!leg1Fixed && !leg2Fixed) return 4;
                    return 1;
                }
            }
            case "FRA", "CapFloor", "Exotic" -> {
                return instrument;
            }
            case "CDS" -> {
                CreditInfo credit = new CreditInfo();
                credit.creditType = (int) raw.getOrDefault("creditType", 0);
                credit.docClause = (String) raw.getOrDefault("docClause", "");
                credit.basketType = (String) raw.getOrDefault("basketType", "");
                credit.eqCDOCLO = (boolean) raw.getOrDefault("eqCDOCLO", false);
                credit.strategy = (int) raw.getOrDefault("strategy", -1);
                credit.bdeSector = (int) raw.getOrDefault("bdeSector", -1);
                credit.instrumType = (int) raw.getOrDefault("instrumType", -1);
                return credit;
            }
            case "FXFwd", "FXNDF", "FXDelSpot", "FXNDS" -> {
                FXProduct fx = new FXProduct();
                fx.instrumentCode = instrument;
                fx.spotDays = (int) raw.getOrDefault("spotDays", 0);
                return fx;
            }
            case "FXOption" -> {
                FXOption fxo = new FXOption();
                fxo.optionType = (String) raw.getOrDefault("optionType", "");
                fxo.settleType = (String) raw.getOrDefault("settleType", "Cash");
                fxo.isDeliverable = (boolean) raw.getOrDefault("deliverable", true);
                fxo.isFlex = (boolean) raw.getOrDefault("isFlex", false);
                fxo.flexSubtype = (String) raw.getOrDefault("flexSubtype", "");
                return fxo;
            }
			case "Equity" -> {
				EquityProduct eq = new EquityProduct();
				eq.productType = (String) raw.getOrDefault("productType", "Option");
				eq.performanceType = (String) raw.getOrDefault("performanceType", null);
				eq.returnType = (String) raw.getOrDefault("returnType", null);
				eq.underlyingType = (String) raw.getOrDefault("underlyingType", null);
				eq.optionType = (String) raw.getOrDefault("optionType", null);
				eq.settleType = (String) raw.getOrDefault("settleType", null);
				eq.isDeliverable = (Boolean) raw.getOrDefault("deliverable", null);
				return eq;
			}
 
			case "Commodity" -> {
                CommodityProduct p = new CommodityProduct();
                p.assetClass = (String) raw.getOrDefault("assetClass", "Energy");
                p.sector = (String) raw.getOrDefault("sector", "Oil");
                p.productType = (String) raw.getOrDefault("productType", "SpotFwd");
                p.deliveryType = (String) raw.getOrDefault("deliveryType", "Physical");
                return p;
            }
            case "FXSwap" -> {
                FXSwap fx = new FXSwap();
                fx.extensionType = (String) raw.getOrDefault("extensionType", "NearFwd");
                return fx;
            }
        }
        return null;
    }
	
    public String resolveUPI(Object productInfo) {
        if (productInfo instanceof Integer subtype) return getInterestRateUPI(subtype);
        if (productInfo instanceof String tipo) return getInterestRateUPIExtended(tipo);
        if (productInfo instanceof CreditInfo c) return getCreditUPI(c);
        if (productInfo instanceof FXProduct fx) return getFXProductUPI(fx.instrumentCode, fx.spotDays);
        if (productInfo instanceof FXOption fxopt) return getFXOptionUPI(fxopt.optionType, fxopt.settleType, fxopt.isDeliverable, fxopt.isFlex, fxopt.flexSubtype);
        if (productInfo instanceof FXSwap fxs) return getFXSwapUPI(fxs.extensionType);
        if (productInfo instanceof EquityProduct eq) return getEquityUPI(eq);
        if (productInfo instanceof CommodityProduct p) return getCommodityProductUPI(p);
        return null;
    }

    // Métodos get...UPI() se deben agregar aquí

    private String getInterestRateUPI(int subtypeCode) {
        return switch (subtypeCode) {
            case 1 -> "InterestRate:IRSwap:FixedFloat";
            case 2 -> "InterestRate:IRSwap:OIS";
            case 3 -> "InterestRate:IRSwap:FixedFixed";
            case 4 -> "InterestRate:IRSwap:Basis";
            case 5 -> "InterestRate:IRSwap:Inflation";
            case 6 -> "InterestRate:CrossCurrency:Basis";
            case 7 -> "InterestRate:CrossCurrency:FixedFixed";
            case 8 -> "InterestRate:CrossCurrency:FixedFloat";
            default -> null;
        };
    }

    private String getInterestRateUPIExtended(String tipo) {
        return switch (tipo) {
            case "FRA" -> "InterestRate:FRA";
            case "CapFloor" -> "InterestRate:CapFloor";
            case "Exotic" -> "InterestRate:Exotic";
            default -> null;
        };
    }

/*
    private String getCreditUPI(CreditInfo info) {
        if (info.creditType == 100 && "2014CR".equals(info.docClause) && info.strategy == 200 && info.bdeSector == 300 && info.instrumType == 10) {
            return "Credit:CDS:Standard";
        }
        if (info.creditType == 101 && "ISDA-Basket-A".equals(info.basketType)) {
            return "Credit:CDSBasket:Standard";
        }
        if (info.creditType == 102 && info.eqCDOCLO) {
            return "Credit:STCDO:CDO";
        }
        if (info.creditType == 103) {
            return "Credit:NthToDef:Default";
        }
        return null;
    }
	
	*/

//Cargar correctamente el creditUPILookup desde una fuente confiable (CSV, base local, archivo de configuración) permite simular la lógica de la tabla T_PGT_GTR_UPI_CFG_S del SQL, y cubrir todos los casos de CDS, CDO, CLO, etc.
	private final Map<String, String> creditUPILookup;
    public UPIProductFactory(Map<String, String> creditUPILookup) {
        this.creditUPILookup = creditUPILookup;
    }
	
	private String getCreditUPI(CreditInfo info) {
        String key = info.creditType + ":" + info.docClause + ":" + info.strategy + ":" + info.bdeSector + ":" + info.instrumType + ":" + info.basketType + ":" + info.eqCDOCLO;
        return creditUPILookup.getOrDefault(key, null);
    }

    private String getFXProductUPI(String instrumentCode, int spotDays) {
        return switch (instrumentCode) {
            case "FXDelSpot", "FXNDS" -> "ForeignExchange:Spot";
            case "FXFwd" -> "ForeignExchange:Forward";
            case "FXNDF" -> (spotDays <= 2) ? "ForeignExchange:Spot" : "ForeignExchange:NDF";
            default -> null;
        };
    }

    private String getFXOptionUPI(String optionType, String settleType, boolean isDeliverable, boolean isFlex, String flexSubtype) {
        if ("PlainVanilla".equals(optionType)) {
            if ("Digital".equals(settleType)) return "ForeignExchange:SimpleExotic:Digital";
            if (!isDeliverable) return "ForeignExchange:NDO";
            return "ForeignExchange:VanillaOption";
        } else if ("Barrier".equals(optionType)) {
            return "ForeignExchange:SimpleExotic:Barrier";
        } else if ("Asian".equals(optionType) || (isFlex && !flexSubtype.contains("Barrier"))) {
            return "ForeignExchange:ComplexExotic";
        } else if (isFlex && flexSubtype.contains("AmerFwd")) {
            return "ForeignExchange:Forward";
        }
        return null;
    }

    private String getFXSwapUPI(String extensionType) {
        return switch (extensionType) {
            case "NearSpot", "FarSpot" -> "ForeignExchange:Spot";
            case "NearFwd", "FarFwd" -> "ForeignExchange:Forward";
            default -> null;
        };
    }
	
		private String getEquityUPI(EquityProduct eq) {
		if (eq.performanceType != null && eq.underlyingType != null) {
			return "Equity:" + eq.productType + ":" + eq.performanceType + ":" + eq.underlyingType;
		} else if (eq.returnType != null && eq.underlyingType != null) {
			return "Equity:" + eq.productType + ":" + eq.returnType + ":" + eq.underlyingType;
		} else if (eq.optionType != null && eq.settleType != null) {
			return getOTCEquityUPI(eq.optionType, eq.isDeliverable != null ? eq.isDeliverable : true, eq.settleType);
		}
		return null;
	}

    private String getOTCEquityUPI(String optionType, boolean isDeliverable, String settleType) {
        if ("PlainVanilla".equals(optionType)) {
            if (!isDeliverable) return "Equity:NDO";
            if ("Digital".equals(settleType)) return "Equity:SimpleExotic:Digital";
            return "Equity:VanillaOption";
        } else if ("Barrier".equals(optionType)) {
            return "Equity:SimpleExotic:Barrier";
        } else if ("Asian".equals(optionType)) {
            return "Equity:ComplexExotic";
        }
        return null;
    }

    private String getCommodityProductUPI(CommodityProduct p) {
        return "Commodity:" + p.assetClass + ":" + p.sector + ":" + p.productType + ":" + p.deliveryType;
    }
} 
