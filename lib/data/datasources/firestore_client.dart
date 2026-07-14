import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import '../models/sale_model.dart';
import '../models/user_model.dart';
import '../models/audit_log_model.dart';
import '../models/settings_model.dart';
import '../models/quick_item_model.dart';
import '../models/cash_reconciliation_model.dart';

class FirestoreClient {
  bool get isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (isFirebaseInitialized) {
      try {
        return FirebaseFirestore.instance;
      } catch (e) {
        dev.log('FirebaseFirestore instance error: $e');
      }
    }
    return null;
  }

  // --- LOCAL MOCK DATABASE FOR OFFLINE / NON-FIREBASE MODE ---
  final Map<String, SaleModel> _mockSales = {};
  final Map<String, UserModel> _mockUsers = {
    'admin': UserModel(uid: 'u_admin', username: 'admin', fullname: 'Administrator', role: 'admin', pin: '1234'),
    'kasir': UserModel(uid: 'u_kasir', username: 'kasir', fullname: 'Kasir Utama', role: 'cashier', pin: '0000'),
  };
  final List<AuditLogModel> _mockLogs = [];
  final Map<String, QuickItemModel> _mockQuickItems = {};
  final List<CashReconciliationModel> _mockReconciliations = [];
  SettingsModel _mockSettings = SettingsModel();

  // --- SALES METHODS ---
  Future<void> saveSale(SaleModel sale) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        // Save sale header
        await firestore.collection('sales').doc(sale.invoiceNo).set(sale.toJson());
        
        // Save subcollection items
        final itemsColl = firestore.collection('sales').doc(sale.invoiceNo).collection('items');
        for (var item in sale.items) {
          await itemsColl.doc(item.itemNo).set(item.toJson());
        }
        dev.log('Sale saved to Firestore: ${sale.invoiceNo}');
        return;
      } catch (e) {
        dev.log('Firestore error in saveSale: $e. Falling back to local cache.');
      }
    }
    
    // Fallback: save to memory
    _mockSales[sale.invoiceNo] = sale;
    dev.log('Sale saved to Memory: ${sale.invoiceNo}');
  }

  Future<List<SaleModel>> getSalesHistory({DateTime? startDate, DateTime? endDate}) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        Query query = firestore.collection('sales').orderBy('date', descending: true);
        if (startDate != null) {
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          // include the whole end date day by adding 23h 59m 59s
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
        }

        final snapshot = await query.get();
        List<SaleModel> sales = [];
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // Fetch subcollection items
          final itemsSnap = await doc.reference.collection('items').get();
          final items = itemsSnap.docs
              .map((i) => SaleItemModel.fromJson(i.data()))
              .toList();
          sales.add(SaleModel.fromJson(data, items));
        }
        return sales;
      } catch (e) {
        dev.log('Firestore error in getSalesHistory: $e. Falling back to memory.');
      }
    }

    // Fallback: local memory filter
    var filteredSales = _mockSales.values.toList();
    if (startDate != null) {
      filteredSales = filteredSales.where((s) => s.date.isAfter(startDate) || s.date.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filteredSales = filteredSales.where((s) => s.date.isBefore(endOfDay)).toList();
    }
    filteredSales.sort((a, b) => b.date.compareTo(a.date));
    return filteredSales;
  }

  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user}) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final Map<String, dynamic> updateMap = {
          'status': status,
        };
        if (status == 'voided') {
          updateMap['void_reason'] = reason ?? 'Canceled';
          updateMap['voided_at'] = Timestamp.fromDate(DateTime.now());
          updateMap['voided_by'] = user ?? 'Admin';
        } else if (status == 'refunded') {
          updateMap['refund_reason'] = reason ?? 'Returned';
          updateMap['refunded_at'] = Timestamp.fromDate(DateTime.now());
          updateMap['refunded_by'] = user ?? 'Admin';
        }
        await firestore.collection('sales').doc(invoiceNo).update(updateMap);
        dev.log('Sale status updated in Firestore: $invoiceNo -> $status');
        return;
      } catch (e) {
        dev.log('Firestore error in updateSaleStatus: $e');
      }
    }

    // Fallback: local memory
    final sale = _mockSales[invoiceNo];
    if (sale != null) {
      final updated = SaleModel(
        invoiceNo: sale.invoiceNo,
        date: sale.date,
        cashier: sale.cashier,
        subtotal: sale.subtotal,
        discount: sale.discount,
        grandTotal: sale.grandTotal,
        paymentMethod: sale.paymentMethod,
        paidAmount: sale.paidAmount,
        changeAmount: sale.changeAmount,
        status: status,
        voidReason: status == 'voided' ? (reason ?? 'Canceled') : sale.voidReason,
        voidedAt: status == 'voided' ? DateTime.now() : sale.voidedAt,
        voidedBy: status == 'voided' ? (user ?? 'Admin') : sale.voidedBy,
        refundReason: status == 'refunded' ? (reason ?? 'Returned') : sale.refundReason,
        refundedAt: status == 'refunded' ? DateTime.now() : sale.refundedAt,
        refundedBy: status == 'refunded' ? (user ?? 'Admin') : sale.refundedBy,
        items: sale.items,
      );
      _mockSales[invoiceNo] = updated;
      dev.log('Sale status updated in Memory: $invoiceNo -> $status');
    }
  }

  // --- USER METHODS ---
  Future<UserModel?> verifyUserPIN(String pin) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('users')
            .where('pin', isEqualTo: pin)
            .where('is_active', isEqualTo: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          return UserModel.fromJson(snap.docs.first.data());
        }
        // If Firestore users collection is empty, create initial mock users so they can log in
        final countSnap = await firestore.collection('users').limit(1).get();
        if (countSnap.docs.isEmpty) {
          // Initialize default users in Firestore
          for (var user in _mockUsers.values) {
            await firestore.collection('users').doc(user.uid).set(user.toJson());
          }
          if (pin == '1234') return _mockUsers['admin'];
          if (pin == '0000') return _mockUsers['kasir'];
        }
        return null;
      } catch (e) {
        dev.log('Firestore error in verifyUserPIN: $e. Falling back to memory.');
      }
    }

    // Fallback: check memory
    for (var u in _mockUsers.values) {
      if (u.pin == pin && u.isActive) {
        return u;
      }
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('users').doc(user.uid).set(user.toJson());
        return;
      } catch (e) {
        dev.log('Firestore error in saveUser: $e');
      }
    }
    _mockUsers[user.username] = user;
  }

  Future<List<UserModel>> getUsers() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('users').get();
        return snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
      } catch (e) {
        dev.log('Firestore error in getUsers: $e');
      }
    }
    return _mockUsers.values.toList();
  }

  // --- SETTINGS METHODS ---
  Future<SettingsModel> getSettings() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore.collection('settings').doc('shop_config').get();
        if (doc.exists && doc.data() != null) {
          return SettingsModel.fromJson(doc.data()!);
        }
        // Save initial default settings to firestore
        await firestore.collection('settings').doc('shop_config').set(_mockSettings.toJson());
        return _mockSettings;
      } catch (e) {
        dev.log('Firestore error in getSettings: $e. Using local settings.');
      }
    }
    return _mockSettings;
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('settings').doc('shop_config').set(settings.toJson());
        return;
      } catch (e) {
        dev.log('Firestore error in saveSettings: $e');
      }
    }
    _mockSettings = settings;
    dev.log('Settings saved to memory.');
  }

  // --- AUDIT LOGS ---
  Future<void> logActivity(String userId, String username, String action, String details) async {
    final log = AuditLogModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      userId: userId,
      username: username,
      action: action,
      details: details,
    );

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('audit_logs').doc(log.id).set(log.toJson());
        dev.log('Audit logged: [$action] - $details');
        return;
      } catch (e) {
        dev.log('Firestore error in logActivity: $e');
      }
    }
    _mockLogs.add(log);
    dev.log('Audit logged to memory: [$action] - $details');
  }

  Future<List<AuditLogModel>> getAuditLogs() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('audit_logs').orderBy('timestamp', descending: true).limit(100).get();
        return snap.docs.map((d) => AuditLogModel.fromJson(d.data())).toList();
      } catch (e) {
        dev.log('Firestore error in getAuditLogs: $e');
      }
    }
    return List.from(_mockLogs..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  // --- QUICK ITEMS METHODS ---
  Future<List<QuickItemModel>> getQuickItems() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('quick_items').orderBy('display_order').get();
        return snap.docs.map((doc) => QuickItemModel.fromJson(doc.data())).toList();
      } catch (e) {
        dev.log('Firestore error in getQuickItems: $e. Falling back to memory.');
      }
    }
    final list = _mockQuickItems.values.toList();
    list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  Future<void> saveQuickItem(QuickItemModel item) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('quick_items').doc(item.id).set(item.toJson());
        return;
      } catch (e) {
        dev.log('Firestore error in saveQuickItem: $e');
      }
    }
    _mockQuickItems[item.id] = item;
  }

  Future<void> deleteQuickItem(String id) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('quick_items').doc(id).delete();
        return;
      } catch (e) {
        dev.log('Firestore error in deleteQuickItem: $e');
      }
    }
    _mockQuickItems.remove(id);
  }

  Future<void> saveQuickItemsBatch(List<QuickItemModel> items) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final batch = firestore.batch();
        for (var item in items) {
          final docRef = firestore.collection('quick_items').doc(item.id);
          batch.set(docRef, item.toJson());
        }
        await batch.commit();
        return;
      } catch (e) {
        dev.log('Firestore error in saveQuickItemsBatch: $e');
      }
    }
    for (var item in items) {
      _mockQuickItems[item.id] = item;
    }
  }

  // --- CASH RECONCILIATION METHODS ---
  Future<void> saveCashReconciliation(CashReconciliationModel reconciliation) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('cash_reconciliations').doc(reconciliation.id).set(reconciliation.toJson());
        dev.log('Cash reconciliation saved to Firestore: ${reconciliation.id}');
        return;
      } catch (e) {
        dev.log('Firestore error in saveCashReconciliation: $e. Falling back to local cache.');
      }
    }
    _mockReconciliations.add(reconciliation);
    dev.log('Cash reconciliation saved to Memory: ${reconciliation.id}');
  }

  Future<List<CashReconciliationModel>> getCashReconciliations() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore.collection('cash_reconciliations').orderBy('date', descending: true).get();
        return snap.docs.map((doc) => CashReconciliationModel.fromJson(doc.data())).toList();
      } catch (e) {
        dev.log('Firestore error in getCashReconciliations: $e. Falling back to memory.');
      }
    }
    return List.from(_mockReconciliations..sort((a, b) => b.date.compareTo(a.date)));
  }
}
