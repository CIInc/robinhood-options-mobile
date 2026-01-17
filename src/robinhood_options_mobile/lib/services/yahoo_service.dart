import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:robinhood_options_mobile/model/insider_transaction.dart';
import 'package:robinhood_options_mobile/model/institutional_ownership.dart';

// Yahoo Finance screener ID with display name
class ScreenerId {
  final String id;
  final String display;
  const ScreenerId(this.id, this.display);
}

class YahooService {
  final http.Client httpClient = http.Client();
  String? _crumb;
  String? _cookie;

  // List of supported Yahoo Finance screener IDs (scrIds) with display names
  // Organized by category for better user experience
  static const List<ScreenerId> scrIds = [
    // === Popular & Most Used ===
    ScreenerId('most_actives', 'Most Actives'),
    ScreenerId('growth_technology_stocks', 'Growth Technology Stocks'),
    ScreenerId('undervalued_growth_stocks', 'Undervalued Growth Stocks'),
    ScreenerId('undervalued_large_caps', 'Undervalued Large Caps'),
    ScreenerId('aggressive_small_caps', 'Aggressive Small Caps'),
    ScreenerId('small_cap_gainers', 'Small Cap Gainers'),
    // ScreenerId('high_dividend_stocks', 'High Dividend Stocks'),

    // === Day Performance ===
    ScreenerId('day_gainers', 'Day Gainers'),
    ScreenerId('day_gainers_americas', 'Day Gainers (Americas)'),
    ScreenerId('day_gainers_asia', 'Day Gainers (Asia)'),
    ScreenerId('day_gainers_au', 'Day Gainers (AU)'),
    ScreenerId('day_gainers_br', 'Day Gainers (BR)'),
    ScreenerId('day_gainers_ca', 'Day Gainers (CA)'),
    ScreenerId('day_gainers_de', 'Day Gainers (DE)'),
    ScreenerId('day_gainers_dji', 'Day Gainers (DJI)'),
    ScreenerId('day_gainers_es', 'Day Gainers (ES)'),
    ScreenerId('day_gainers_europe', 'Day Gainers (Europe)'),
    ScreenerId('day_gainers_fr', 'Day Gainers (FR)'),
    ScreenerId('day_gainers_gb', 'Day Gainers (GB)'),
    ScreenerId('day_gainers_hk', 'Day Gainers (HK)'),
    ScreenerId('day_gainers_in', 'Day Gainers (IN)'),
    ScreenerId('day_gainers_it', 'Day Gainers (IT)'),
    ScreenerId('day_gainers_ndx', 'Day Gainers (NDX)'),
    ScreenerId('day_gainers_nz', 'Day Gainers (NZ)'),
    ScreenerId('day_gainers_sg', 'Day Gainers (SG)'),
    ScreenerId('day_losers', 'Day Losers'),
    ScreenerId('day_losers_americas', 'Day Losers (Americas)'),
    ScreenerId('day_losers_asia', 'Day Losers (Asia)'),
    ScreenerId('day_losers_au', 'Day Losers (AU)'),
    ScreenerId('day_losers_br', 'Day Losers (BR)'),
    ScreenerId('day_losers_ca', 'Day Losers (CA)'),
    ScreenerId('day_losers_de', 'Day Losers (DE)'),
    ScreenerId('day_losers_dji', 'Day Losers (DJI)'),
    ScreenerId('day_losers_es', 'Day Losers (ES)'),
    ScreenerId('day_losers_europe', 'Day Losers (Europe)'),
    ScreenerId('day_losers_fr', 'Day Losers (FR)'),
    ScreenerId('day_losers_gb', 'Day Losers (GB)'),
    ScreenerId('day_losers_hk', 'Day Losers (HK)'),
    ScreenerId('day_losers_in', 'Day Losers (IN)'),
    ScreenerId('day_losers_it', 'Day Losers (IT)'),
    ScreenerId('day_losers_ndx', 'Day Losers (NDX)'),
    ScreenerId('day_losers_nz', 'Day Losers (NZ)'),
    ScreenerId('day_losers_sg', 'Day Losers (SG)'),

    // === Sector Specific ===
    ScreenerId('biotechnology', 'Biotechnology'),
    ScreenerId('communication_equipment', 'Communication Equipment'),
    ScreenerId('semiconductors', 'Semiconductors'),
    ScreenerId('software_infrastructure', 'Software - Infrastructure'),
    ScreenerId('application_software', 'Application Software'),
    ScreenerId('asset_management', 'Asset Management'),
    ScreenerId('credit_services', 'Credit Services'),
    ScreenerId('department_stores', 'Department Stores'),
    // ScreenerId('diagnostic_substances', 'Diagnostic Substances'),
    // ScreenerId('discount_variety_stores', 'Discount & Variety Stores'),
    // ScreenerId('diversified_communication_services',
    //     'Diversified Communication Services'),
    // ScreenerId('diversified_computer_systems', 'Diversified Computer Systems'),
    // ScreenerId('diversified_electronics', 'Diversified Electronics'),
    // ScreenerId('diversified_investments', 'Diversified Investments'),
    // ScreenerId('diversified_machinery', 'Diversified Machinery'),
    // ScreenerId('diversified_utilities', 'Diversified Utilities'),
    // ScreenerId('drug_delivery', 'Drug Delivery'),
    // ScreenerId('drug_manufacturers_major', 'Drug Manufacturers - Major'),
    // ScreenerId('drug_manufacturers_other', 'Drug Manufacturers - Other'),
    // ScreenerId('drug_related_products', 'Drug Related Products'),
    // ScreenerId('drug_stores', 'Drug Stores'),
    // ScreenerId('drugs_generic', 'Drugs - Generic'),
    // ScreenerId('drugs_wholesale', 'Drugs Wholesale'),
    ScreenerId('education_training_services', 'Education & Training Services'),
    // ScreenerId('electric_utilities', 'Electric Utilities'),
    // ScreenerId('electronic_equipment', 'Electronic Equipment'),
    // ScreenerId('electronics_stores', 'Electronics Stores'),
    // ScreenerId('electronics_wholesale', 'Electronics Wholesale'),
    // ScreenerId('entertainment_diversified', 'Entertainment - Diversified'),
    // ScreenerId('fair_value_screener', 'Fair Value Screener'),
    // ScreenerId('farm_construction_machinery', 'Farm & Construction Machinery'),
    ScreenerId('farm_products', 'Farm Products'),
    // ScreenerId('financial', 'Financial'),
    // ScreenerId('food_major_diversified', 'Food - Major Diversified'),
    // ScreenerId('food_wholesale', 'Food Wholesale'),
    // ScreenerId('foreign_money_center_banks', 'Foreign Money Center Banks'),
    // ScreenerId('foreign_regional_banks', 'Foreign Regional Banks'),
    // ScreenerId('foreign_utilities', 'Foreign Utilities'),
    // ScreenerId('gaming_activities', 'Gaming Activities'),
    // ScreenerId('gas_utilities', 'Gas Utilities'),
    // ScreenerId('general_building_materials', 'General Building Materials'),
    // ScreenerId('general_contractors', 'General Contractors'),
    // ScreenerId('general_entertainment', 'General Entertainment'),
    ScreenerId('gold', 'Gold'),
    ScreenerId('grocery_stores', 'Grocery Stores'),
    // ScreenerId('growth_technology_stocks', 'Growth Technology Stocks'),
    // ScreenerId('health_care_plans', 'Health Care Plans'),
    // ScreenerId('healthcare', 'Healthcare'),
    // ScreenerId(
    //     'healthcare_information_services', 'Healthcare Information Services'),
    // ScreenerId('heavy_construction', 'Heavy Construction'),
    ScreenerId('high_yield_bond', 'High Yield Bond'),
    // ScreenerId('home_furnishing_stores', 'Home Furnishing Stores'),
    // ScreenerId('home_furnishings_fixtures', 'Home Furnishings & Fixtures'),
    // ScreenerId('home_health_care', 'Home Health Care'),
    // ScreenerId('home_improvement_stores', 'Home Improvement Stores'),
    // ScreenerId('hospitals', 'Hospitals'),
    // ScreenerId('housewares_accessories', 'Housewares & Accessories'),
    // ScreenerId('independent_oil_gas', 'Independent Oil & Gas'),
    // ScreenerId(
    //     'industrial_electrical_equipment', 'Industrial Electrical Equipment'),
    // ScreenerId(
    //     'industrial_equipment_components', 'Industrial Equipment Components'),
    // ScreenerId(
    //     'industrial_equipment_wholesale', 'Industrial Equipment Wholesale'),
    // ScreenerId('industrial_goods', 'Industrial Goods'),
    // ScreenerId('industrial_metals_minerals', 'Industrial Metals & Minerals'),
    // ScreenerId(
    //     'information_delivery_services', 'Information Delivery Services'),
    ScreenerId(
        'information_technology_services', 'Information Technology Services'),
    ScreenerId('insurance_brokers', 'Insurance Brokers'),
    // ScreenerId(
    //     'internet_information_providers', 'Internet Information Providers'),
    // ScreenerId('internet_service_providers', 'Internet Service Providers'),
    // ScreenerId('internet_software_services', 'Internet Software & Services'),
    // ScreenerId(
    //     'investment_brokerage_national', 'Investment Brokerage - National'),
    // ScreenerId(
    //     'investment_brokerage_regional', 'Investment Brokerage - Regional'),
    // ScreenerId('jewelry_stores', 'Jewelry Stores'),
    // ScreenerId('life_insurance', 'Life Insurance'),
    ScreenerId('lodging', 'Lodging'),
    // ScreenerId('long_distance_carriers', 'Long Distance Carriers'),
    // ScreenerId('longterm_care_facilities', 'Long-Term Care Facilities'),
    ScreenerId('lumber_wood_production', 'Lumber & Wood Production'),
    // ScreenerId('machine_tools_accessories', 'Machine Tools & Accessories'),
    // ScreenerId('major_airlines', 'Major Airlines'),
    // ScreenerId('major_integrated_oil_gas', 'Major Integrated Oil & Gas'),
    // ScreenerId('management_services', 'Management Services'),
    // ScreenerId('marketing_services', 'Marketing Services'),
    // ScreenerId('meat_products', 'Meat Products'),
    // ScreenerId(
    //     'medical_appliances_equipment', 'Medical Appliances & Equipment'),
    // ScreenerId('medical_equipment_wholesale', 'Medical Equipment Wholesale'),
    ScreenerId(
        'medical_instruments_supplies', 'Medical Instruments & Supplies'),
    // ScreenerId(
    //     'medical_laboratories_research', 'Medical Laboratories & Research'),
    ScreenerId('mega_cap_hc', 'Mega Cap HC'),
    ScreenerId('metal_fabrication', 'Metal Fabrication'),
    // ScreenerId('money_center_banks', 'Money Center Banks'),
    // ScreenerId('mortgage_investment', 'Mortgage Investment'),
    // ScreenerId('most_actives', 'Most Actives'),
    ScreenerId('most_actives_americas', 'Most Actives (Americas)'),
    ScreenerId('most_actives_asia', 'Most Actives (Asia)'),
    ScreenerId('most_actives_au', 'Most Actives (AU)'),
    ScreenerId('most_actives_br', 'Most Actives (BR)'),
    ScreenerId('most_actives_ca', 'Most Actives (CA)'),
    ScreenerId('most_actives_de', 'Most Actives (DE)'),
    ScreenerId('most_actives_dji', 'Most Actives (DJI)'),
    ScreenerId('most_actives_es', 'Most Actives (ES)'),
    ScreenerId('most_actives_europe', 'Most Actives (Europe)'),
    ScreenerId('most_actives_fr', 'Most Actives (FR)'),
    ScreenerId('most_actives_gb', 'Most Actives (GB)'),
    ScreenerId('most_actives_hk', 'Most Actives (HK)'),
    ScreenerId('most_actives_in', 'Most Actives (IN)'),
    ScreenerId('most_actives_it', 'Most Actives (IT)'),
    ScreenerId('most_actives_ndx', 'Most Actives (NDX)'),
    ScreenerId('most_actives_nz', 'Most Actives (NZ)'),
    ScreenerId('most_actives_sg', 'Most Actives (SG)'),
    ScreenerId('most_watched_tickers', 'Most Watched Tickers'),
    // ScreenerId('movie_production_theaters', 'Movie Production & Theaters'),
    ScreenerId('ms_basic_materials', 'MS Basic Materials'),
    ScreenerId('ms_communication_services', 'MS Communication Services'),
    ScreenerId('ms_consumer_cyclical', 'MS Consumer Cyclical'),
    ScreenerId('ms_consumer_defensive', 'MS Consumer Defensive'),
    ScreenerId('ms_energy', 'MS Energy'),
    ScreenerId('ms_financial_services', 'MS Financial Services'),
    ScreenerId('ms_healthcare', 'MS Healthcare'),
    ScreenerId('ms_industrials', 'MS Industrials'),
    ScreenerId('ms_real_estate', 'MS Real Estate'),
    ScreenerId('ms_technology', 'MS Technology'),
    ScreenerId('ms_utilities', 'MS Utilities'),
    // ScreenerId(
    //     'multimedia_graphics_software', 'Multimedia & Graphics Software'),
    // ScreenerId('networking_communication_devices',
    //     'Networking & Communication Devices'),
    // ScreenerId('nonmetallic_mineral_mining', 'Nonmetallic Mineral Mining'),
    // ScreenerId('office_supplies', 'Office Supplies'),
    // ScreenerId(
    //     'oil_gas_drilling_exploration', 'Oil & Gas Drilling & Exploration'),
    ScreenerId('oil_gas_equipment_services', 'Oil & Gas Equipment & Services'),
    // ScreenerId('oil_gas_pipelines', 'Oil & Gas Pipelines'),
    ScreenerId('oil_gas_refining_marketing', 'Oil & Gas Refining & Marketing'),
    ScreenerId('packaging_containers', 'Packaging & Containers'),
    ScreenerId('paper_paper_products', 'Paper & Paper Products'),
    // ScreenerId('personal_products', 'Personal Products'),
    ScreenerId('personal_services', 'Personal Services'),
    // ScreenerId(
    //     'photographic_equipment_supplies', 'Photographic Equipment & Supplies'),
    ScreenerId(
        'pollution_treatment_controls', 'Pollution Treatment & Controls'),
    ScreenerId('portfolio_anchors', 'Portfolio Anchors'),
    // ScreenerId('printed_circuit_boards', 'Printed Circuit Boards'),
    // ScreenerId('processed_packaged_goods', 'Processed & Packaged Goods'),
    // ScreenerId('processing_systems_products', 'Processing Systems & Products'),
    // ScreenerId('property_casualty_insurance', 'Property & Casualty Insurance'),
    // ScreenerId('property_management', 'Property Management'),
    // ScreenerId('publishing_books', 'Publishing - Books'),
    // ScreenerId('publishing_newspapers', 'Publishing - Newspapers'),
    // ScreenerId('publishing_periodicals', 'Publishing - Periodicals'),
    ScreenerId('railroads', 'Railroads'),
    ScreenerId('real_estate_development', 'Real Estate Development'),
    // ScreenerId('recreational_goods_other', 'Recreational Goods, Other'),
    ScreenerId('recreational_vehicles', 'Recreational Vehicles'),
    // ScreenerId('regional_airlines', 'Regional Airlines'),
    // ScreenerId('regional_midatlantic_banks', 'Regional Mid-Atlantic Banks'),
    // ScreenerId('regional_midwest_banks', 'Regional Midwest Banks'),
    // ScreenerId('regional_northeast_banks', 'Regional Northeast Banks'),
    // ScreenerId('regional_pacific_banks', 'Regional Pacific Banks'),
    // ScreenerId('regional_southeast_banks', 'Regional Southeast Banks'),
    // ScreenerId('regional_southwest_banks', 'Regional Southwest Banks'),
    ScreenerId('reit_diversified', 'REIT - Diversified'),
    ScreenerId('reit_healthcare_facilities', 'REIT - Healthcare Facilities'),
    ScreenerId('reit_hotel_motel', 'REIT - Hotel & Motel'),
    ScreenerId('reit_industrial', 'REIT - Industrial'),
    ScreenerId('reit_office', 'REIT - Office'),
    ScreenerId('reit_residential', 'REIT - Residential'),
    ScreenerId('reit_retail', 'REIT - Retail'),
    ScreenerId('rental_leasing_services', 'Rental & Leasing Services'),
    // ScreenerId('research_services', 'Research Services'),
    ScreenerId('residential_construction', 'Residential Construction'),
    ScreenerId('resorts_casinos', 'Resorts & Casinos'),
    ScreenerId('restaurants', 'Restaurants'),
    // ScreenerId('rubber_plastics', 'Rubber & Plastics'),
    // ScreenerId('savings_loans', 'Savings & Loans'),
    ScreenerId('scientific_technical_instruments',
        'Scientific & Technical Instruments'),
    ScreenerId(
        'security_protection_services', 'Security & Protection Services'),
    // ScreenerId('security_software_services', 'Security Software & Services'),
    // ScreenerId('semiconductor_broad_line', 'Semiconductor - Broad Line'),
    ScreenerId('semiconductor_equipment_materials',
        'Semiconductor Equipment & Materials'),
    // ScreenerId('semiconductor_integrated_circuits',
    //     'Semiconductor - Integrated Circuits'),
    // ScreenerId('semiconductor_memory_chips', 'Semiconductor - Memory Chips'),
    // ScreenerId('semiconductor_specialized', 'Semiconductor - Specialized'),
    // ScreenerId('services', 'Services'),
    // ScreenerId('shipping', 'Shipping'),
    ScreenerId('silver', 'Silver'),
    // ScreenerId('small_cap_gainers', 'Small Cap Gainers'),
    // ScreenerId('small_tools_accessories', 'Small Tools & Accessories'),
    ScreenerId('solid_large_growth_funds', 'Solid Large Growth Funds'),
    ScreenerId('solid_midcap_growth_funds', 'Solid Midcap Growth Funds'),
    // ScreenerId('specialized_health_services', 'Specialized Health Services'),
    ScreenerId('specialty_chemicals', 'Specialty Chemicals'),
    // ScreenerId('specialty_eateries', 'Specialty Eateries'),
    // ScreenerId('specialty_retail_other', 'Specialty Retail, Other'),
    // ScreenerId('sporting_activities', 'Sporting Activities'),
    // ScreenerId('sporting_goods', 'Sporting Goods'),
    // ScreenerId('sporting_goods_stores', 'Sporting Goods Stores'),
    // ScreenerId(
    //     'staffing_outsourcing_services', 'Staffing & Outsourcing Services'),
    // ScreenerId('steel_iron', 'Steel & Iron'),
    // ScreenerId('surety_title_insurance', 'Surety & Title Insurance'),
    // ScreenerId('synthetics', 'Synthetics'),
    // ScreenerId('technical_services', 'Technical Services'),
    // ScreenerId('technical_system_software', 'Technical System Software'),
    // ScreenerId('technology', 'Technology'),
    // ScreenerId('telecom_services_domestic', 'Telecom Services - Domestic'),
    // ScreenerId('telecom_services_foreign', 'Telecom Services - Foreign'),
    // ScreenerId('textile_apparel_clothing', 'Textile - Apparel Clothing'),
    // ScreenerId('textile_apparel_footwear_accessories',
    //     'Textile - Apparel Footwear & Accessories'),
    // ScreenerId('textile_industrial', 'Textile - Industrial'),
    // ScreenerId('tobacco_products_other', 'Tobacco Products, Other'),
    ScreenerId('top_energy_us', 'Top Energy (US)'),
    // ScreenerId('top_etfs', 'Top ETFs'),
    // ScreenerId('top_etfs_hk', 'Top ETFs (HK)'),
    // ScreenerId('top_etfs_in', 'Top ETFs (IN)'),
    ScreenerId('top_etfs_us', 'Top ETFs (US)'),
    // ScreenerId('top_iv_options_us', 'Top IV Options (US)'),
    ScreenerId('top_mutual_funds', 'Top Mutual Funds'),
    ScreenerId('top_mutual_funds_au', 'Top Mutual Funds (AU)'),
    ScreenerId('top_mutual_funds_br', 'Top Mutual Funds (BR)'),
    ScreenerId('top_mutual_funds_ca', 'Top Mutual Funds (CA)'),
    ScreenerId('top_mutual_funds_de', 'Top Mutual Funds (DE)'),
    ScreenerId('top_mutual_funds_es', 'Top Mutual Funds (ES)'),
    ScreenerId('top_mutual_funds_fr', 'Top Mutual Funds (FR)'),
    ScreenerId('top_mutual_funds_gb', 'Top Mutual Funds (GB)'),
    ScreenerId('top_mutual_funds_hk', 'Top Mutual Funds (HK)'),
    ScreenerId('top_mutual_funds_in', 'Top Mutual Funds (IN)'),
    ScreenerId('top_mutual_funds_it', 'Top Mutual Funds (IT)'),
    ScreenerId('top_mutual_funds_nz', 'Top Mutual Funds (NZ)'),
    ScreenerId('top_mutual_funds_sg', 'Top Mutual Funds (SG)'),
    ScreenerId('top_mutual_funds_us', 'Top Mutual Funds (US)'),
    ScreenerId(
        'top_options_implied_volatality', 'Top Options - Implied Volatility'),
    ScreenerId('top_options_open_interest', 'Top Options - Open Interest'),
    // ScreenerId('toy_hobby_stores', 'Toy & Hobby Stores'),
    // ScreenerId('toys_games', 'Toys & Games'),
    ScreenerId('trucking', 'Trucking'),
    // ScreenerId('trucks_other_vehicles', 'Trucks & Other Vehicles'),
    // ScreenerId('undervalued_growth_stocks', 'Undervalued Growth Stocks'),
    // ScreenerId('undervalued_large_caps', 'Undervalued Large Caps'),
    // ScreenerId('utilities', 'Utilities'),
    ScreenerId('waste_management', 'Waste Management'),
    // ScreenerId('water_utilities', 'Water Utilities'),
    // ScreenerId('wireless_communications', 'Wireless Communications'),
  ];

  /*
{
  "chart": {
    "result": [
      {
        "meta": {
          "currency": "USD",
          "symbol": "^IXIC",
          "exchangeName": "NIM",
          "fullExchangeName": "Nasdaq GIDS",
          "instrumentType": "INDEX",
          "firstTradeDate": 34612200,
          "regularMarketTime": 1740176159,
          "hasPrePostMarketData": false,
          "gmtoffset": -18000,
          "timezone": "EST",
          "exchangeTimezoneName": "America/New_York",
          "regularMarketPrice": 19524.006,
          "fiftyTwoWeekHigh": 20204.58,
          "fiftyTwoWeekLow": 15222.78,
          "regularMarketDayHigh": 20016.662,
          "regularMarketDayLow": 19510.908,
          "regularMarketVolume": 7873054000,
          "longName": "NASDAQ Composite",
          "shortName": "NASDAQ Composite",
          "chartPreviousClose": 19310.79,
          "priceHint": 2,
          "currentTradingPeriod": {
            "pre": {
              "timezone": "EST",
              "end": 1740148200,
              "start": 1740128400,
              "gmtoffset": -18000
            },
            "regular": {
              "timezone": "EST",
              "end": 1740171600,
              "start": 1740148200,
              "gmtoffset": -18000
            },
            "post": {
              "timezone": "EST",
              "end": 1740186000,
              "start": 1740171600,
              "gmtoffset": -18000
            }
          },
          "dataGranularity": "1d",
          "range": "ytd",
          "validRanges": [
            "1d",
            "5d",
            "1mo",
            "3mo",
            "6mo",
            "1y",
            "2y",
            "5y",
            "10y",
            "ytd",
            "max"
          ]
        },
        "timestamp": [
          1735828200,
          1735914600,
          1736173800,
          1736260200,
          1736346600,
          1736519400,
          1736778600,
          1736865000,
          1736951400,
          1737037800,
          1737124200,
          1737469800,
          1737556200,
          1737642600,
          1737729000,
          1737988200,
          1738074600,
          1738161000,
          1738247400,
          1738333800,
          1738593000,
          1738679400,
          1738765800,
          1738852200,
          1738938600,
          1739197800,
          1739284200,
          1739370600,
          1739457000,
          1739543400,
          1739889000,
          1739975400,
          1740061800,
          1740176159
        ],
        "indicators": {
          "quote": [
            {
              "high": [
                19517.869140625,
                19638.66015625,
                20007.94921875,
                19940.2109375,
                19544.509765625,
                19315.109375,
                19099.970703125,
                19273.140625,
                19548.900390625,
                19579.849609375,
                19709.640625,
                19789.630859375,
                20068.51953125,
                20053.6796875,
                20118.609375,
                19514.349609375,
                19759.4296875,
                19699.8203125,
                19785.7890625,
                19969.169921875,
                19502.130859375,
                19666.439453125,
                19696.939453125,
                19793.359375,
                19862.5390625,
                19772.0390625,
                19731.9296875,
                19682.509765625,
                19952.169921875,
                20045.759765625,
                20110.119140625,
                20099.390625,
                20041.150390625,
                20016.662109375
              ],
              "open": [
                19403.900390625,
                19395.509765625,
                19851.990234375,
                19938.080078125,
                19469.369140625,
                19312.259765625,
                18903.66015625,
                19207.75,
                19350.310546875,
                19573.869140625,
                19655.55078125,
                19734.390625,
                19903.05078125,
                19906.990234375,
                20087.109375,
                19234.0390625,
                19418.220703125,
                19695.6796875,
                19697.529296875,
                19832.330078125,
                19215.380859375,
                19422.169921875,
                19533.05078125,
                19725.830078125,
                19774.869140625,
                19668.1796875,
                19602.109375,
                19436.509765625,
                19696.919921875,
                19956.8203125,
                20090.55078125,
                19994.5,
                20029.189453125,
                20006.69921875
              ],
              "low": [
                19117.58984375,
                19379.5703125,
                19785.0,
                19421.01953125,
                19308.5390625,
                19018.75,
                18831.91015625,
                18926.599609375,
                19299.3203125,
                19335.6796875,
                19543.3203125,
                19551.169921875,
                19903.05078125,
                19892.55078125,
                19897.130859375,
                19204.94921875,
                19294.619140625,
                19479.509765625,
                19483.830078125,
                19575.2109375,
                19141.150390625,
                19408.1796875,
                19498.900390625,
                19654.109375,
                19489.359375,
                19650.7890625,
                19579.76953125,
                19415.48046875,
                19675.869140625,
                19932.150390625,
                19909.740234375,
                19928.890625,
                19795.01953125,
                19510.908203125
              ],
              "close": [
                19280.7890625,
                19621.6796875,
                19864.98046875,
                19489.6796875,
                19478.880859375,
                19161.630859375,
                19088.099609375,
                19044.390625,
                19511.23046875,
                19338.2890625,
                19630.19921875,
                19756.779296875,
                20009.33984375,
                20053.6796875,
                19954.30078125,
                19341.830078125,
                19733.58984375,
                19632.3203125,
                19681.75,
                19627.439453125,
                19391.9609375,
                19654.01953125,
                19692.330078125,
                19791.990234375,
                19523.400390625,
                19714.26953125,
                19643.859375,
                19649.94921875,
                19945.640625,
                20026.76953125,
                20041.259765625,
                20056.25,
                19962.359375,
                19524.005859375
              ],
              "volume": [
                8737550000,
                8214050000,
                9586840000,
                13371130000,
                8851720000,
                8608880000,
                7830760000,
                7168110000,
                7260250000,
                7085990000,
                7996360000,
                8015780000,
                7219060000,
                6837700000,
                7708150000,
                8870200000,
                7121740000,
                6497710000,
                6679500000,
                7947370000,
                8272460000,
                6477050000,
                6712220000,
                6642100000,
                7748940000,
                9535440000,
                9269380000,
                7946550000,
                8414510000,
                7995720000,
                8683170000,
                8171530000,
                7329270000,
                7873054000
              ]
            }
          ],
          "adjclose": [
            {
              "adjclose": [
                19280.7890625,
                19621.6796875,
                19864.98046875,
                19489.6796875,
                19478.880859375,
                19161.630859375,
                19088.099609375,
                19044.390625,
                19511.23046875,
                19338.2890625,
                19630.19921875,
                19756.779296875,
                20009.33984375,
                20053.6796875,
                19954.30078125,
                19341.830078125,
                19733.58984375,
                19632.3203125,
                19681.75,
                19627.439453125,
                19391.9609375,
                19654.01953125,
                19692.330078125,
                19791.990234375,
                19523.400390625,
                19714.26953125,
                19643.859375,
                19649.94921875,
                19945.640625,
                20026.76953125,
                20041.259765625,
                20056.25,
                19962.359375,
                19524.005859375
              ]
            }
          ]
        }
      }
    ],
    "error": null
  }
}  */
  Future<dynamic> getMarketIndexHistoricals(
      {String symbol = "^GSP",
      String range = "ytd", // 1y
      String interval = "1d"}) async {
    var url =
        "https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeFull(symbol)}?events=capitalGain%7Cdiv%7Csplit&formatted=true&includeAdjustedClose=true&interval=$interval&range=$range&symbol=${Uri.encodeFull(symbol)}&userYfid=true&lang=en-US&region=US";
    var entryJson = await getJson(url);
    return entryJson;
  }

  Future<dynamic> getESGScores(String symbol) async {
    var url =
        "https://query1.finance.yahoo.com/v10/finance/quoteSummary/${Uri.encodeFull(symbol)}?modules=esgScores";
    var responseJson = await getJson(url);
    return responseJson;
  }

  Future<dynamic> getAssetProfile(String symbol) async {
    var url =
        "https://query1.finance.yahoo.com/v10/finance/quoteSummary/${Uri.encodeFull(symbol)}?modules=assetProfile";
    var responseJson = await getJson(url);
    return responseJson;
  }

  Future<dynamic> getOptionChain(String symbol, {int? date}) async {
    var url =
        "https://query1.finance.yahoo.com/v7/finance/options/${Uri.encodeFull(symbol)}?formatted=true&lang=en-US&region=US&corsDomain=finance.yahoo.com";
    if (date != null) {
      url += "&date=$date";
    }
    var responseJson = await getJson(url);

    if (responseJson['optionChain'] == null ||
        responseJson['optionChain']['result'] == null ||
        (responseJson['optionChain']['result'] as List).isEmpty) {
      return {};
    }

    var result = responseJson['optionChain']['result'][0];

    // return responseJson;
    return {
      'expirationDates': (result['expirationDates'] as List?)
              ?.map((ts) =>
                  DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000))
              .toList() ??
          [],
      'hasMiniOptions': result['hasMiniOptions'],
      'quote': result['quote'],
      'options': (result['options'] as List?)?.map((opt) {
            var optMap = Map<String, dynamic>.from(opt);

            Map<String, dynamic> cleanContract(Map<String, dynamic> contract) {
              var cleaned = <String, dynamic>{};
              contract.forEach((key, value) {
                if (value is Map && value.containsKey('raw')) {
                  cleaned[key] = value['raw'];
                } else {
                  cleaned[key] = value;
                }
              });

              if (cleaned['expiration'] is int) {
                cleaned['expiration'] = DateTime.fromMillisecondsSinceEpoch(
                    cleaned['expiration'] * 1000);
              }
              if (cleaned['lastTradeDate'] is int) {
                cleaned['lastTradeDate'] = DateTime.fromMillisecondsSinceEpoch(
                    cleaned['lastTradeDate'] * 1000);
              }
              return cleaned;
            }

            if (optMap['calls'] != null) {
              optMap['calls'] = (optMap['calls'] as List)
                  .map((c) => cleanContract(Map<String, dynamic>.from(c)))
                  .toList();
            }
            if (optMap['puts'] != null) {
              optMap['puts'] = (optMap['puts'] as List)
                  .map((p) => cleanContract(Map<String, dynamic>.from(p)))
                  .toList();
            }
            if (optMap['expirationDate'] != null) {
              optMap['expirationDate'] = DateTime.fromMillisecondsSinceEpoch(
                  optMap['expirationDate'] * 1000);
            }
            return optMap;
          }).toList() ??
          [],
      'strikes': result['strikes'] ?? [],
      'underlyingSymbol': result['underlyingSymbol'],
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Fetch stock screener results from Yahoo Finance predefined screeners
  ///
  /// Uses Yahoo Finance's public API to retrieve stocks matching preset screening criteria.
  /// Available screeners include day gainers/losers, most actives, growth stocks, and more.
  ///
  /// **Parameters:**
  /// - [count]: Number of results to return (default: 25)
  /// - [scrIds]: Screener ID from the [scrIds] list (default: 'most_actives')
  /// - [start]: Starting offset for pagination (default: 0)
  /// - [lang]: Language code (default: 'en-US')
  /// - [region]: Region code (default: 'US')
  /// - [sortField]: Field to sort results by
  /// - [sortType]: Sort direction ('ASC' or 'DESC')
  /// - [formatted]: Whether to return formatted values (default: true)
  /// - [useRecordsResponse]: Use records response format (default: true)
  /// - [betaFeatureFlag]: Enable beta features (default: true)
  ///
  /// **Returns:** JSON response containing screener results with stock data
  ///
  /// **Example:**
  /// ```dart
  /// var results = await yahooService.getStockScreener(
  ///   scrIds: 'day_gainers',
  ///   count: 50,
  /// );
  /// ```
  Future<dynamic> getStockScreener({
    int count = 25,
    String scrIds = 'most_actives',
    int start = 0,
    String lang = 'en-US',
    String region = 'US',
    String sortField = '',
    String sortType = '',
    bool formatted = true,
    bool useRecordsResponse = true,
    bool betaFeatureFlag = true,
  }) async {
    final url = Uri.parse(
        'https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved'
        '?count=$count'
        '&formatted=$formatted'
        '&scrIds=$scrIds'
        '&sortField=$sortField'
        '&sortType=$sortType'
        '&start=$start'
        '&useRecordsResponse=$useRecordsResponse'
        '&betaFeatureFlag=$betaFeatureFlag'
        '&lang=$lang'
        '&region=$region');
    var responseJson = await getJson(url.toString());
    return responseJson;
  }

  Future<dynamic> getJson(String url) async {
    if (_crumb == null) {
      await _fetchCrumb();
    }

    if (_crumb != null) {
      if (url.contains('?')) {
        if (!url.contains('crumb=')) {
          url += '&crumb=$_crumb';
        }
      } else {
        url += '?crumb=$_crumb';
      }
    }

    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    // String responseStr = await httpClient.read(Uri.parse(url));
    var uri = Uri.parse(url);
    var headers = {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };
    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
    }

    var response = await httpClient.get(uri, headers: headers);

    // Retry once if unauthorized
    if (response.statusCode == 401) {
      debugPrint("Yahoo API 401, retrying with new crumb...");
      await _fetchCrumb();
      if (_crumb != null) {
        // Rebuild URL with new crumb
        var uriObj = Uri.parse(url);
        var queryParams = Map<String, String>.from(uriObj.queryParameters);
        queryParams['crumb'] = _crumb!;
        uri = uriObj.replace(queryParameters: queryParams);
        if (_cookie != null) {
          headers['Cookie'] = _cookie!;
        }
        response = await httpClient.get(uri, headers: headers);
      }
    }

    debugPrint(
        "${(response.body.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");

    if (response.statusCode == 200) {
      dynamic responseJson = jsonDecode(response.body);
      return responseJson;
    } else {
      debugPrint("Yahoo API Error: ${response.statusCode} ${response.body}");
      throw Exception("Failed to load data: ${response.statusCode}");
    }
  }

  Future<void> _fetchCrumb() async {
    try {
      // 1. Get Cookie from fc.yahoo.com
      final response1 = await httpClient.get(
        Uri.parse('https://fc.yahoo.com'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        },
      );

      _updateCookie(response1);

      // Fallback to finance.yahoo.com if no cookie
      if (_cookie == null) {
        final responseHome = await httpClient.get(
          Uri.parse('https://finance.yahoo.com'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          },
        );
        _updateCookie(responseHome);
      }

      if (_cookie != null) {
        // 2. Get Crumb
        final response2 = await httpClient.get(
          Uri.parse('https://query1.finance.yahoo.com/v1/test/getcrumb'),
          headers: {
            'Cookie': _cookie!,
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          },
        );

        if (response2.statusCode == 200) {
          _crumb = response2.body;
          debugPrint('Yahoo Crumb fetched: $_crumb');
        }
      }
    } catch (e) {
      debugPrint('Error fetching Yahoo crumb: $e');
    }
  }

  void _updateCookie(http.Response response) {
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      _cookie = rawCookie;
    }
  }

  /// Fetch institutional ownership for a given symbol
  Future<InstitutionalOwnership?> getInstitutionalOwnership(
      String symbol) async {
    try {
      final url =
          "https://query1.finance.yahoo.com/v10/finance/quoteSummary/${Uri.encodeFull(symbol)}?modules=institutionOwnership,majorHoldersBreakdown";
      final jsonResponse = await getJson(url);

      if (jsonResponse['quoteSummary'] != null &&
          jsonResponse['quoteSummary']['result'] != null) {
        final result = (jsonResponse['quoteSummary']['result'] as List);
        if (result.isNotEmpty) {
          final data = result[0];
          final holdersList = data['institutionOwnership']?['ownershipList'];
          final breakdown = data['majorHoldersBreakdown'];

          double? percentageHeld;
          double? floatPercentageHeld;
          double? insidersPercentageHeld;
          int? institutionCount;

          if (breakdown != null) {
            if (breakdown['institutionsPercentHeld'] != null) {
              percentageHeld =
                  (breakdown['institutionsPercentHeld']['raw'] as num?)
                      ?.toDouble();
            }
            if (breakdown['institutionsFloatPercentHeld'] != null) {
              floatPercentageHeld =
                  (breakdown['institutionsFloatPercentHeld']['raw'] as num?)
                      ?.toDouble();
            }
            if (breakdown['insidersPercentHeld'] != null) {
              insidersPercentageHeld =
                  (breakdown['insidersPercentHeld']['raw'] as num?)?.toDouble();
            }
            if (breakdown['institutionsCount'] != null) {
              institutionCount =
                  (breakdown['institutionsCount']['raw'] as num?)?.toInt();
            }
          }

          List<InstitutionalHolder> topHolders = [];
          if (holdersList != null) {
            topHolders = (holdersList as List).map((h) {
              return InstitutionalHolder(
                name: h['organization'] ?? 'Unknown',
                sharesHeld: (h['position']?['raw'] as num?)?.toDouble() ?? 0,
                change: null, // Change not provided in this module
                percentageChange: (h['pctHeld']?['raw'] as num?)?.toDouble(),
                dateReported: h['reportDate']?['fmt'] != null
                    ? DateTime.tryParse(h['reportDate']['fmt'])
                    : (h['reportDate']?['raw'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            h['reportDate']['raw'] * 1000)
                        : null),
              );
            }).toList();
          }

          return InstitutionalOwnership(
            symbol: symbol,
            percentageHeld: percentageHeld,
            floatPercentageHeld: floatPercentageHeld,
            insidersPercentageHeld: insidersPercentageHeld,
            institutionCount: institutionCount,
            topHolders: topHolders,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching institutional ownership: $e');
    }
    return null;
  }

  /// Fetch insider transactions for a given symbol
  Future<List<InsiderTransaction>> getInsiderTransactions(String symbol) async {
    try {
      final url =
          "https://query1.finance.yahoo.com/v10/finance/quoteSummary/${Uri.encodeFull(symbol)}?modules=insiderTransactions";
      final jsonResponse = await getJson(url);

      if (jsonResponse['quoteSummary'] != null &&
          jsonResponse['quoteSummary']['result'] != null) {
        final result = jsonResponse['quoteSummary']['result'];
        if ((result as List).isNotEmpty) {
          final insiderTransactions =
              result[0]['insiderTransactions']['transactions'];
          if (insiderTransactions != null) {
            return (insiderTransactions as List)
                .map((e) => InsiderTransaction.fromJson(e))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching insider transactions: $e');
    }
    return [];
  }
}

class MarketIndicesModel extends ValueNotifier<dynamic> {
  MarketIndicesModel(super.initialValue);

  void set(dynamic newValue) {
    value = newValue;
  }
}
