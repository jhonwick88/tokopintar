import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/unit_model.dart';
import '../../presentation/providers/unit_provider.dart';

String getUnitName(String unitValue, AsyncValue<List<UnitModel>> unitsState) {
  if (unitValue.isEmpty) return 'PCS';
  
  final parsedId = int.tryParse(unitValue);
  if (parsedId == null) {
    return unitValue;
  }
  
  return unitsState.maybeWhen(
    data: (units) {
      final unit = units.firstWhere((u) => u.id == parsedId, orElse: () => UnitModel(id: 0, name: unitValue));
      return unit.name;
    },
    orElse: () => unitValue,
  );
}
