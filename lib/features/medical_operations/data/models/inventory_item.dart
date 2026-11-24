import 'package:cloud_firestore/cloud_firestore.dart';

/// One medicine in the BAUST Medical Center pharmacy.
class InventoryItem {
  final String id;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String unit;
  final String manufacturer;
  final String batchNumber;
  final DateTime? expiryDate;
  final int stockUnits;
  final int threshold;
  final String rack;
  final String notes;
  final DateTime? updatedAt;

  const InventoryItem({
    required this.id,
    required this.brandName,
    this.genericName = '',
    this.strength = '',
    this.dosageForm = 'TABLET',
    this.unit = 'Units',
    this.manufacturer = '',
    this.batchNumber = '',
    this.expiryDate,
    this.stockUnits = 0,
    this.threshold = 10,
    this.rack = 'Unassigned',
    this.notes = '',
    this.updatedAt,
  });

  bool get isLowStock => stockUnits < threshold;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Expires within the next 30 days (and isn't already expired).
  bool get isExpiringSoon =>
      expiryDate != null && !isExpired && expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

  static String idFor(String brandName) => 'med_${brandName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  static String formatDate(DateTime? d) =>
      d == null ? 'Not set' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  InventoryItem copyWith({int? stockUnits}) => InventoryItem(
    id: id,
    brandName: brandName,
    genericName: genericName,
    strength: strength,
    dosageForm: dosageForm,
    unit: unit,
    manufacturer: manufacturer,
    batchNumber: batchNumber,
    expiryDate: expiryDate,
    stockUnits: stockUnits ?? this.stockUnits,
    threshold: threshold,
    rack: rack,
    notes: notes,
    updatedAt: updatedAt,
  );

  factory InventoryItem.fromMap(String id, Map<String, dynamic> d) {
    DateTime? date(dynamic v) => v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);
    String str(String k, [String fallback = '']) {
      final v = d[k]?.toString().trim() ?? '';
      return v.isEmpty ? fallback : v;
    }

    return InventoryItem(
      id: id,
      brandName: str('brandName', id),
      genericName: str('genericName'),
      strength: str('strength'),
      dosageForm: str('dosageForm', 'OTHER'),
      unit: str('unit', 'Units'),
      manufacturer: str('manufacturer'),
      batchNumber: str('batchNumber'),
      expiryDate: date(d['expiryDate']),
      stockUnits: (d['stockUnits'] as num?)?.toInt() ?? 0,
      threshold: (d['threshold'] as num?)?.toInt() ?? 10,
      rack: str('rack', 'Unassigned'),
      notes: str('notes'),
      updatedAt: date(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'brandName': brandName,
    'genericName': genericName,
    'strength': strength,
    'dosageForm': dosageForm,
    'unit': unit,
    'manufacturer': manufacturer,
    'batchNumber': batchNumber,
    'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
    'stockUnits': stockUnits,
    'threshold': threshold,
    'rack': rack,
    'notes': notes,
  };

  /// Starting stock, used the first time a pharmacist opens an empty pharmacy.
  static const List<InventoryItem> defaults = [
    InventoryItem(
      id: 'med_001',
      brandName: 'Napa 500mg',
      genericName: 'Paracetamol',
      strength: '500 mg',
      dosageForm: 'TABLET',
      unit: 'Tablets',
      stockUnits: 20,
      threshold: 10,
      rack: 'Rack A-1 (Analgesics)',
    ),
    InventoryItem(
      id: 'med_002',
      brandName: 'Seclo 20mg',
      genericName: 'Omeprazole',
      strength: '20 mg',
      dosageForm: 'CAPSULE',
      unit: 'Capsules',
      stockUnits: 20,
      threshold: 10,
      rack: 'Rack B-1 (Gastric / PPI)',
    ),
    InventoryItem(
      id: 'med_003',
      brandName: 'Metronidazole 400mg',
      genericName: 'Metronidazole',
      strength: '400 mg',
      dosageForm: 'TABLET',
      unit: 'Tablets',
      stockUnits: 20,
      threshold: 10,
      rack: 'Rack A-2 (Antimicrobial)',
    ),
    InventoryItem(
      id: 'med_004',
      brandName: 'Orsaline-N / SMC ORS',
      genericName: 'Oral Rehydration Salts',
      dosageForm: 'SACHET',
      unit: 'Sachets',
      stockUnits: 20,
      threshold: 10,
      rack: 'Rack C-1 (Electrolytes)',
    ),
    InventoryItem(
      id: 'med_005',
      brandName: 'Povidone Iodine 10%',
      genericName: 'Povidone Iodine Antiseptic Solution',
      strength: '10%',
      dosageForm: 'SOLUTION',
      unit: 'Bottles / First Aid',
      stockUnits: 20,
      threshold: 5,
      rack: 'First-Aid Rack (Dressing)',
    ),
  ];
}
