import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import '../providers/license_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/main_layout.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersNotifierProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getMaxCashiers(Map<String, dynamic>? features) {
    if (features == null) return 0;
    final val = features['max_cashiers'] ?? features['max_users'];
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  void _showUserFormDialog({UserModel? userToEdit}) {
    final isEditing = userToEdit != null;
    final nameController = TextEditingController(text: userToEdit?.fullname ?? '');
    final usernameController = TextEditingController(text: userToEdit?.username ?? '');
    final pinController = TextEditingController();
    final String rawRole = (userToEdit?.role ?? 'user').toLowerCase();
    String selectedRole = (rawRole == 'admin') ? 'admin' : 'user';
    bool isActive = userToEdit?.isActive ?? true;
    bool obscurePin = true;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final licenseFeatures = ref.watch(licenseProvider).features;
            final maxCashiers = _getMaxCashiers(licenseFeatures);
            final users = ref.watch(usersNotifierProvider).users;
            final activeCashiers = users.where((u) => u.role.toLowerCase() != 'admin' && u.isActive).length;
            final isQuotaReached = !isEditing && selectedRole == 'user' && maxCashiers > 0 && activeCashiers >= maxCashiers;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.person_add_alt_1,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Pengguna' : 'Tambah Pengguna Baru',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isQuotaReached)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Batas lisensi kasir tercapai ($activeCashiers / $maxCashiers). Silakan upgrade lisensi untuk menambah kasir.',
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap *',
                            hintText: 'Contoh: Ahmad Kasir',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username *',
                            hintText: 'Contoh: ahmad01',
                            prefixIcon: const Icon(Icons.account_circle_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Peran (Role) *',
                            prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User / Kasir'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Administrator (Owner)'),
                            ),
                          ],
                          onChanged: isEditing && (userToEdit.role.toLowerCase() == 'admin')
                              ? null // Protect primary admin role
                              : (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedRole = val;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: pinController,
                          obscureText: obscurePin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            labelText: isEditing ? 'PIN Baru (Kosongkan jika tidak diubah)' : 'PIN Masuk (4-6 Digit) *',
                            hintText: 'Contoh: 1234',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setDialogState(() {
                                  obscurePin = !obscurePin;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (!isEditing && trimmed.isEmpty) {
                              return 'PIN wajib diisi';
                            }
                            if (trimmed.isNotEmpty) {
                              if (trimmed.length < 4) {
                                return 'PIN minimal 4 digit angka';
                              }
                              // Check duplicate PIN across all users
                              final existingUsers = ref.read(usersNotifierProvider).users;
                              final duplicateUser = existingUsers.firstWhere(
                                (u) => u.pin == trimmed && (!isEditing || u.uid != userToEdit.uid),
                                orElse: () => UserModel(uid: '', username: '', fullname: '', role: '', pin: ''),
                              );
                              if (duplicateUser.uid.isNotEmpty) {
                                return 'PIN sudah dipakai (${duplicateUser.fullname})';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Status Pengguna Aktif', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            isActive ? 'Pengguna dapat login ke sistem' : 'Pengguna dinonaktifkan',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          value: isActive,
                          onChanged: isEditing && (userToEdit.role.toLowerCase() == 'admin')
                              ? null // Admin must stay active
                              : (val) {
                                  setDialogState(() {
                                    isActive = val;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isQuotaReached
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          final user = UserModel(
                            uid: isEditing ? userToEdit.uid : '',
                            fullname: nameController.text.trim(),
                            username: usernameController.text.trim(),
                            role: selectedRole,
                            pin: pinController.text.trim(),
                            isActive: isActive,
                          );

                          Navigator.of(dialogContext).pop();

                          bool success;
                          if (isEditing) {
                            success = await ref.read(usersNotifierProvider.notifier).updateUser(user);
                          } else {
                            success = await ref.read(usersNotifierProvider.notifier).createUser(user);
                          }

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Pengguna berhasil diperbarui' : 'Pengguna baru berhasil ditambahkan'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              final errMsg = ref.read(usersNotifierProvider).errorMessage ?? 'Gagal memproses data pengguna';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errMsg),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Pengguna'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(UserModel user) {
    if (user.role.toLowerCase() == 'admin') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Akses Dilindungi'),
            ],
          ),
          content: const Text('Akun dengan peran Administrator utama tidak dapat dihapus demi keamanan sistem.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Pengguna'),
          content: Text('Apakah Anda yakin ingin menghapus akun "${user.fullname}" (${user.username})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await ref.read(usersNotifierProvider.notifier).deleteUser(user.uid);
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pengguna berhasil dihapus'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errMsg = ref.read(usersNotifierProvider).errorMessage ?? 'Gagal menghapus pengguna';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersNotifierProvider);
    final licenseFeatures = ref.watch(licenseProvider).features;
    final maxCashiers = _getMaxCashiers(licenseFeatures);
    final activeCashiers = usersState.users.where((u) => u.role == 'cashier' && u.isActive).length;
    final isQuotaFull = maxCashiers > 0 && activeCashiers >= maxCashiers;

    final filteredUsers = usersState.users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return u.fullname.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.role.toLowerCase().contains(query);
    }).toList();

    return MainLayout(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/inventory'),
            tooltip: 'Kembali ke Inventori',
          ),
          title: const Text('Manajemen Pengguna (User)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(usersNotifierProvider.notifier).loadUsers(),
              tooltip: 'Muat Ulang',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.read(usersNotifierProvider.notifier).loadUsers(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info & Quota Header
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.people_alt_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daftar Kasir & Administrator',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kelola hak akses dan akun kasir toko Anda. Batas kuota kasir diatur berdasarkan paket lisensi.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // License Quota Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isQuotaFull ? Colors.orange.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isQuotaFull ? Colors.orange.shade300 : Colors.blue.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 16,
                                        color: isQuotaFull ? Colors.orange.shade800 : Colors.blue.shade800,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Lisensi Multi-User',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isQuotaFull ? Colors.orange.shade800 : Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kasir: $activeCashiers / ${maxCashiers > 0 ? maxCashiers : 'Tak Terbatas'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isQuotaFull ? Colors.orange.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action & Search Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari nama, username, atau role...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showUserFormDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Users List
                    if (usersState.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (filteredUsers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada pengguna yang cocok dengan pencarian'
                                    : 'Belum ada data pengguna',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isAdmin = user.role.toLowerCase() == 'admin';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: isAdmin
                                    ? Colors.purple.shade100
                                    : Colors.blue.shade100,
                                child: Text(
                                  user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isAdmin ? Colors.purple.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    user.fullname,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  // Role badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? Colors.purple.shade50 : Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isAdmin ? Colors.purple.shade200 : Colors.teal.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'USER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isAdmin ? Colors.purple.shade800 : Colors.teal.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: user.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: user.isActive ? Colors.green.shade200 : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      user.isActive ? 'AKTIF' : 'NONAKTIF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: user.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Username: @${user.username}  •  PIN: ••••',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    tooltip: 'Edit Pengguna',
                                    onPressed: () => _showUserFormDialog(userToEdit: user),
                                  ),
                                  if (isAdmin)
                                    Tooltip(
                                      message: 'Akun Admin utama tidak dapat dihapus',
                                      child: IconButton(
                                        icon: Icon(Icons.delete_forever, color: Colors.grey.shade400),
                                        onPressed: () => _showDeleteConfirmDialog(user),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      tooltip: 'Hapus Kasir',
                                      onPressed: () => _showDeleteConfirmDialog(user),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
