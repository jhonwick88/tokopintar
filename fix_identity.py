import os

# 1. Update settings_model.dart fromJson
model_path = r'H:\FlutterProject\tokopintar\lib\data\models\settings_model.dart'
with open(model_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "shopName: json['shop_name'] as String? ?? 'Toko Pintar',",
    "shopName: json['shop_name'] as String? ?? dotenv.env['SHOP_NAME'] ?? 'Toko Pintar',"
)
content = content.replace(
    "shopAddress: json['shop_address'] as String? ?? 'Jl. Kaliurang KM 5, Yogyakarta',",
    "shopAddress: json['shop_address'] as String? ?? dotenv.env['SHOP_ADDRESS'] ?? 'Jl. Kaliurang KM 5, Yogyakarta',"
)
content = content.replace(
    "shopPhone: json['shop_phone'] as String? ?? '081234567890',",
    "shopPhone: json['shop_phone'] as String? ?? dotenv.env['SHOP_PHONE'] ?? '081234567890',"
)

with open(model_path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update settings_repository_impl.dart
repo_path = r'H:\FlutterProject\tokopintar\lib\data\repositories\settings_repository_impl.dart'
with open(repo_path, 'r', encoding='utf-8') as f:
    r_content = f.read()

old_repo = "SettingsModel globalSettings = SettingsModel(restApiUrl: localUrl);"
new_repo = """SettingsModel globalSettings = SettingsModel(
      restApiUrl: localUrl,
      shopName: dotenv.env['SHOP_NAME'] ?? 'Toko Pintar',
      shopAddress: dotenv.env['SHOP_ADDRESS'] ?? 'Jl. Kaliurang KM 5, Yogyakarta',
      shopPhone: dotenv.env['SHOP_PHONE'] ?? '081234567890',
    );"""

r_content = r_content.replace(old_repo, new_repo)

with open(repo_path, 'w', encoding='utf-8') as f:
    f.write(r_content)
