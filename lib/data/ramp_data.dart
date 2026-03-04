import '../models/ramp.dart';

/// ✅ Mackay region ramps (QLD) — subset for backward compatibility.
const List<Ramp> mackayRamps = [
  Ramp(id: 'andergrove_apsley_way', name: 'Andergrove, Apsley Way', lat: -21.074310, lon: 149.193460),
  Ramp(id: 'bucasia_bucasia_esplanade', name: 'Bucasia, Bucasia Esplanade', lat: -21.037587, lon: 149.169471),
  Ramp(id: 'campwin_beach_boat_ramp_road', name: 'Campwin Beach, Boat Ramp Road', lat: -21.374407, lon: 149.312709),
  Ramp(id: 'carpet_snake_point_st_helens_beach', name: 'Carpet Snake Point, St Helens Beach', lat: -20.822982, lon: 148.835860),
  Ramp(id: 'constant_creek', name: 'Constant Creek', lat: -21.009701, lon: 148.997468),
  Ramp(id: 'dunnrock_dunnrock_esplanade', name: 'Dunnrock, Dunnrock Esplanade', lat: -20.781587, lon: 148.900167),
  Ramp(id: 'eimeo_sunset_boulevard', name: 'Eimeo, Sunset Boulevard', lat: -21.037315, lon: 149.173797),
  Ramp(id: 'slade_point_seagull_street', name: 'Slade Point, Seagull Street (Boat Ramp)', lat: -21.0711, lon: 149.2236),
  Ramp(id: 'freshwater_point_miran_kahn_drive', name: 'Freshwater Point, Miran Kahn Drive', lat: -21.425300, lon: 149.326720),
  Ramp(id: 'mackay_harbour_mulherin_drive', name: 'Mackay Harbour, Mulherin Drive', lat: -21.110247, lon: 149.225225),
  Ramp(id: 'mackay_river_street', name: 'Mackay, River Street', lat: -21.139519, lon: 149.189107),
  Ramp(id: 'grasstree_beach_boat_ramp_road', name: 'Grasstree Beach, Boat Ramp Road', lat: -21.374587, lon: 149.309913),
  Ramp(id: 'haliday_bay_haliday_bay_road', name: 'Haliday Bay, Haliday Bay Road', lat: -20.913170, lon: 148.926252),
  Ramp(id: 'hay_point_half_tide_tug_harbour', name: 'Hay Point (Half Tide) Tug Harbour', lat: -21.293631, lon: 149.297713),
  Ramp(id: 'laguna_quays_marina', name: 'Laguna Quays Marina', lat: -20.603546, lon: 148.679750),
  Ramp(id: 'murray_creek_landing_road', name: 'Murray Creek, Landing Road', lat: -20.849592, lon: 148.957395),
  Ramp(id: 'sarina_beach_sunset_drive_perpetua_point', name: 'Sarina Beach, Sunset Drive, Perpetua Point', lat: -21.396075, lon: 149.312405),
  Ramp(id: 'seaforth_creek', name: 'Seaforth Creek, Seaforth', lat: -20.901404, lon: 148.981642),
  Ramp(id: 'victor_creek_seaforth', name: 'Victor Creek, Seaforth', lat: -20.896898, lon: 148.985807),
  Ramp(id: 'woodwark_bay', name: 'Woodwark Bay', lat: -20.837732, lon: 148.929994),
  Ramp(id: 'west_point_beach_west_point_road', name: 'West Point Beach, West Point Road', lat: -20.780064, lon: 148.856889),
  Ramp(id: 'eungella_dam', name: 'Eungella Dam, Eungella Dam Road', lat: -21.146587, lon: 148.386857),
  Ramp(id: 'kinchant_dam', name: 'Kinchant Dam, Kinchant Dam Road', lat: -21.216713, lon: 148.894319),
  Ramp(id: 'teemburra_dam', name: 'Teemburra Dam, Lucas Paddock Road', lat: -21.348054, lon: 148.911160),
  Ramp(id: 'midge_point', name: 'Midge Point', lat: -20.632291, lon: 148.726889),
  Ramp(id: 'koumala_dannell_st', name: 'Koumala, Dannell Street', lat: -21.548419, lon: 149.300239),
  Ramp(id: 'pleystowe', name: 'Pleystowe', lat: -21.378059, lon: 149.026597),
];

// ---------------------------
// NSW
// ---------------------------
const List<Ramp> _rampsNSW = [
  Ramp(id: 'nsw_rose_bay', name: 'Rose Bay Boat Ramp, Sydney', lat: -33.8715, lon: 151.2650),
  Ramp(id: 'nsw_parsley_bay', name: 'Parsley Bay, Sydney Harbour', lat: -33.8320, lon: 151.2700),
  Ramp(id: 'nsw_balmoral', name: 'Balmoral Boat Ramp, Sydney', lat: -33.8230, lon: 151.2520),
  Ramp(id: 'nsw_cronulla', name: 'Cronulla Boat Ramp', lat: -34.0580, lon: 151.1520),
  Ramp(id: 'nsw_botany_boat_ramp', name: 'Botany Bay Boat Ramp, Kurnell', lat: -34.0080, lon: 151.2080),
  Ramp(id: 'nsw_newcastle_ferry', name: 'Newcastle Harbour Boat Ramp', lat: -32.9280, lon: 151.7820),
  Ramp(id: 'nsw_port_macquarie', name: 'Port Macquarie Boat Ramp', lat: -31.4350, lon: 152.9080),
  Ramp(id: 'nsw_coffs_harbour', name: 'Coffs Harbour Boat Ramp', lat: -30.2980, lon: 153.1380),
  Ramp(id: 'nsw_eden', name: 'Eden Boat Ramp', lat: -37.0680, lon: 149.9080),
  Ramp(id: 'nsw_batemans_bay', name: 'Batemans Bay Boat Ramp', lat: -35.7180, lon: 150.1780),
  Ramp(id: 'nsw_huskinson', name: 'Huskisson Boat Ramp, Jervis Bay', lat: -35.0480, lon: 150.6680),
  Ramp(id: 'nsw_lake_macquarie', name: 'Lake Macquarie Boat Ramp, Belmont', lat: -33.0380, lon: 151.6580),
];

// ---------------------------
// VIC (Melbourne & regional)
// ---------------------------
const List<Ramp> _rampsVIC = [
  // Port Phillip – inner Melbourne
  Ramp(id: 'vic_st_kilda', name: 'St Kilda Boat Ramp, Port Phillip', lat: -37.8620, lon: 144.9680),
  Ramp(id: 'vic_elwood', name: 'Elwood Boat Ramp, Port Phillip', lat: -37.8820, lon: 144.9820),
  Ramp(id: 'vic_brighton', name: 'Brighton Boat Ramp, Port Phillip', lat: -37.9080, lon: 144.9880),
  Ramp(id: 'vic_sandringham', name: 'Sandringham Boat Ramp, Port Phillip', lat: -37.9520, lon: 145.0080),
  Ramp(id: 'vic_black_rock', name: 'Black Rock Boat Ramp, Port Phillip', lat: -37.9680, lon: 145.0180),
  Ramp(id: 'vic_beaumaris', name: 'Beaumaris Boat Ramp, Port Phillip', lat: -37.9880, lon: 145.0380),
  Ramp(id: 'vic_mordialloc', name: 'Mordialloc Boat Ramp, Port Phillip', lat: -38.0080, lon: 145.0880),
  Ramp(id: 'vic_chelsea', name: 'Chelsea Boat Ramp, Port Phillip', lat: -38.0680, lon: 145.1180),
  Ramp(id: 'vic_bonbeach', name: 'Bonbeach Boat Ramp, Port Phillip', lat: -38.1180, lon: 145.1280),
  Ramp(id: 'vic_carrum', name: 'Carrum Boat Ramp, Port Phillip', lat: -38.0780, lon: 145.1280),
  Ramp(id: 'vic_frankston', name: 'Frankston Boat Ramp, Port Phillip', lat: -38.1420, lon: 145.1280),
  Ramp(id: 'vic_olivers_hill', name: 'Olivers Hill Boat Ramp, Frankston', lat: -38.1480, lon: 145.1320),
  Ramp(id: 'vic_mornington', name: 'Mornington Boat Ramp, Port Phillip', lat: -38.2180, lon: 145.0380),
  Ramp(id: 'vic_mt_martha', name: 'Mt Martha Boat Ramp, Port Phillip', lat: -38.2680, lon: 145.0180),
  Ramp(id: 'vic_safety_beach', name: 'Safety Beach Boat Ramp, Marine Drive', lat: -38.3180, lon: 144.9580),
  Ramp(id: 'vic_dromana', name: 'Dromana Boat Ramp, Port Phillip', lat: -38.3380, lon: 144.9580),
  Ramp(id: 'vic_mccrae', name: 'McCrae Boat Ramp, Port Phillip', lat: -38.3580, lon: 144.9280),
  Ramp(id: 'vic_rosebud', name: 'Rosebud Boat Ramp, Port Phillip', lat: -38.3680, lon: 144.8980),
  Ramp(id: 'vic_rye', name: 'Rye Boat Ramp, Point Nepean Rd', lat: -38.3780, lon: 144.8280),
  Ramp(id: 'vic_blairgowrie', name: 'Blairgowrie Boat Ramp, Port Phillip', lat: -38.3580, lon: 144.7780),
  Ramp(id: 'vic_sorrento', name: 'Sorrento Boat Ramp, St Aubins Way', lat: -38.3380, lon: 144.7380),
  Ramp(id: 'vic_portsea', name: 'Portsea Boat Ramp, Port Phillip', lat: -38.3280, lon: 144.7180),
  Ramp(id: 'vic_fishermans_beach', name: 'Fishermans Beach Boat Ramp, Mornington Peninsula', lat: -38.2180, lon: 145.0580),
  Ramp(id: 'vic_schnapper_point', name: 'Schnapper Point Boat Ramp, Mornington', lat: -38.2280, lon: 145.0480),
  // Western Port
  Ramp(id: 'vic_hastings', name: 'Hastings Boat Ramp, Western Port', lat: -38.3080, lon: 145.1980),
  Ramp(id: 'vic_tooradin', name: 'Tooradin Boat Ramp, Western Port', lat: -38.2180, lon: 145.3880),
  Ramp(id: 'vic_warneet', name: 'Warneet Boat Ramp, Western Port', lat: -38.2180, lon: 145.3280),
  Ramp(id: 'vic_corinella', name: 'Corinella Boat Ramp, Western Port', lat: -38.4180, lon: 145.4180),
  Ramp(id: 'vic_cowes', name: 'Cowes Boat Ramp, Phillip Island', lat: -38.4480, lon: 145.2380),
  Ramp(id: 'vic_newhaven', name: 'Newhaven Boat Ramp, Phillip Island', lat: -38.5180, lon: 145.3180),
  // Geelong & Bellarine
  Ramp(id: 'vic_geelong', name: 'Geelong Boat Ramp, Corio Bay', lat: -38.1480, lon: 144.3580),
  Ramp(id: 'vic_st_leonards', name: 'St Leonards Boat Ramp, Port Phillip', lat: -38.1680, lon: 144.7180),
  Ramp(id: 'vic_queenscliff', name: 'Queenscliff Boat Ramp, Port Phillip', lat: -38.2680, lon: 144.6580),
  Ramp(id: 'vic_portarlington', name: 'Portarlington Boat Ramp, Port Phillip', lat: -38.1180, lon: 144.6580),
  Ramp(id: 'vic_indented_head', name: 'Indented Head Boat Ramp, Port Phillip', lat: -38.1480, lon: 144.7080),
  Ramp(id: 'vic_leopold', name: 'Leopold Boat Ramp, Bellarine', lat: -38.1880, lon: 144.4680),
  // Melbourne west / river
  Ramp(id: 'vic_williamstown', name: 'Williamstown Boat Ramp, Port Phillip', lat: -37.8580, lon: 144.8980),
  Ramp(id: 'vic_altona', name: 'Altona Boat Ramp, Port Phillip', lat: -37.8680, lon: 144.8280),
  Ramp(id: 'vic_werribee_south', name: 'Werribee South Boat Ramp, Port Phillip', lat: -37.9880, lon: 144.6680),
  // Gippsland & regional VIC
  Ramp(id: 'vic_lakes_entrance', name: 'Lakes Entrance Boat Ramp', lat: -37.8780, lon: 147.9880),
  Ramp(id: 'vic_paynesville', name: 'Paynesville Boat Ramp, Gippsland Lakes', lat: -37.8580, lon: 147.7180),
  Ramp(id: 'vic_metung', name: 'Metung Boat Ramp, Gippsland Lakes', lat: -37.8780, lon: 147.8580),
  Ramp(id: 'vic_portland', name: 'Portland Boat Ramp', lat: -38.3480, lon: 141.6080),
  Ramp(id: 'vic_apollo_bay', name: 'Apollo Bay Boat Ramp', lat: -38.7580, lon: 143.6680),
  Ramp(id: 'vic_warrnambool', name: 'Warrnambool Boat Ramp, Lady Bay', lat: -38.3980, lon: 142.4880),
];

// ---------------------------
// QLD (Brisbane / SE / Cairns — Mackay already in mackayRamps)
// ---------------------------
const List<Ramp> _rampsQLD = [
  Ramp(id: 'qld_colmslie', name: 'Colmslie Boat Ramp, Brisbane River', lat: -27.4980, lon: 153.0680),
  Ramp(id: 'qld_manly', name: 'Manly Boat Harbour, Brisbane', lat: -27.4580, lon: 153.1880),
  Ramp(id: 'qld_gold_coast_southport', name: 'Southport Boat Ramp, Gold Coast', lat: -27.9680, lon: 153.4180),
  Ramp(id: 'qld_broadwater', name: 'Broadwater Boat Ramp, Gold Coast', lat: -27.9380, lon: 153.4080),
  Ramp(id: 'qld_cairns_trinity', name: 'Trinity Inlet Boat Ramp, Cairns', lat: -16.9180, lon: 145.7780),
  Ramp(id: 'qld_townsville_breakwater', name: 'Townsville Breakwater Boat Ramp', lat: -19.2580, lon: 146.8280),
  Ramp(id: 'qld_bundaberg_burnett', name: 'Burnett River Boat Ramp, Bundaberg', lat: -24.8680, lon: 152.3580),
  Ramp(id: 'qld_gladstone', name: 'Gladstone Marina Boat Ramp', lat: -23.8480, lon: 151.2580),
];

// ---------------------------
// WA
// ---------------------------
const List<Ramp> _rampsWA = [
  Ramp(id: 'wa_fremantle', name: 'Fremantle Boat Ramp', lat: -32.0580, lon: 115.7380),
  Ramp(id: 'wa_hillarys', name: 'Hillarys Boat Ramp, Perth', lat: -31.8080, lon: 115.7480),
  Ramp(id: 'wa_mandurah', name: 'Mandurah Ocean Marina Boat Ramp', lat: -32.5280, lon: 115.7180),
  Ramp(id: 'wa_bunbury', name: 'Bunbury Boat Ramp, Koombana Bay', lat: -33.3280, lon: 115.6380),
  Ramp(id: 'wa_busselton', name: 'Busselton Jetty Boat Ramp', lat: -33.6480, lon: 115.3480),
  Ramp(id: 'wa_albany', name: 'Albany Boat Ramp, Princess Royal Harbour', lat: -35.0280, lon: 117.8880),
  Ramp(id: 'wa_broome', name: 'Broome Boat Ramp', lat: -18.0080, lon: 122.2180),
];

// ---------------------------
// SA
// ---------------------------
const List<Ramp> _rampsSA = [
  Ramp(id: 'sa_north_haven', name: 'North Haven Boat Ramp, Adelaide', lat: -34.7880, lon: 138.4880),
  Ramp(id: 'sa_glenelg', name: 'Glenelg Boat Ramp, Gulf St Vincent', lat: -34.9780, lon: 138.5080),
  Ramp(id: 'sa_port_adelaide', name: 'Port Adelaide Boat Ramp', lat: -34.8480, lon: 138.5080),
  Ramp(id: 'sa_goolwa', name: 'Goolwa Boat Ramp, Murray Mouth', lat: -35.5180, lon: 138.7780),
  Ramp(id: 'sa_port_lincoln', name: 'Port Lincoln Boat Ramp', lat: -34.7280, lon: 135.8580),
  Ramp(id: 'sa_whyalla', name: 'Whyalla Boat Ramp', lat: -33.0380, lon: 137.5580),
];

// ---------------------------
// TAS
// ---------------------------
const List<Ramp> _rampsTAS = [
  Ramp(id: 'tas_selfs_point', name: 'Selfs Point Boat Ramp, Hobart', lat: -42.8580, lon: 147.3280),
  Ramp(id: 'tas_bellerive', name: 'Bellerive Boat Ramp, Hobart', lat: -42.8680, lon: 147.3680),
  Ramp(id: 'tas_tamar_launceston', name: 'Tamar River Boat Ramp, Launceston', lat: -41.4380, lon: 147.1280),
  Ramp(id: 'tas_devonport', name: 'Devonport Boat Ramp', lat: -41.1780, lon: 146.3580),
  Ramp(id: 'tas_st_helens', name: 'St Helens Boat Ramp', lat: -41.3280, lon: 148.2380),
  Ramp(id: 'tas_strahan', name: 'Strahan Boat Ramp, Macquarie Harbour', lat: -42.1580, lon: 145.3280),
];

// ---------------------------
// NT
// ---------------------------
const List<Ramp> _rampsNT = [
  Ramp(id: 'nt_dinah_beach', name: 'Dinah Beach Boat Ramp, Darwin', lat: -12.4580, lon: 130.8380),
  Ramp(id: 'nt_stokes_hill', name: 'Stokes Hill Wharf Boat Ramp, Darwin', lat: -12.4680, lon: 130.8480),
  Ramp(id: 'nt_channel_island', name: 'Channel Island Boat Ramp, Darwin', lat: -12.5580, lon: 131.0280),
  Ramp(id: 'nt_katherine', name: 'Katherine (Low Level) Boat Ramp', lat: -14.4680, lon: 132.2680),
];

/// ✅ Nationwide list of Australian boat ramps (all states/territories).
/// Used for postcode-based local ramps and "Use my location" nearest ramp.
/// IDs are unique across the list.
const List<Ramp> australianRamps = [
  ...mackayRamps,
  ..._rampsNSW,
  ..._rampsVIC,
  ..._rampsQLD,
  ..._rampsWA,
  ..._rampsSA,
  ..._rampsTAS,
  ..._rampsNT,
];
